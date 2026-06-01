pub(crate) mod extractor;
mod oauth;

use std::{
    collections::HashMap,
    sync::{Arc, Mutex},
    time::{Duration, Instant},
};

use argon2::{
    Argon2,
    password_hash::{PasswordHash, PasswordHasher, PasswordVerifier, SaltString},
};
use axum::{Json, Router, extract::State, http::StatusCode, routing::get};
use chrono::{DateTime, Utc};
use jsonwebtoken::{DecodingKey, EncodingKey, Header, Validation, decode, encode};
use rand_core::OsRng;
use serde::{Deserialize, Serialize};
use sqlx::{PgPool, Row, postgres::PgPoolOptions};
use uuid::Uuid;

use crate::{AppState, crypto::KeyCipher, error::ApiError};

pub(crate) const ACCESS_TOKEN_TTL_SECONDS: i64 = 60 * 60;

#[derive(Clone)]
pub(crate) struct AuthContext {
    pub(crate) pool: PgPool,
    pub(crate) jwt: JwtConfig,
    pub(crate) google: Option<GoogleOAuthConfig>,
    pub(crate) key_cipher: Option<KeyCipher>,
    pub(crate) http: reqwest::Client,
    oauth_states: Arc<Mutex<HashMap<String, PkceSession>>>,
}

#[derive(Clone)]
pub(crate) struct JwtConfig {
    encoding_key: EncodingKey,
    decoding_key: DecodingKey,
    issuer: String,
    audience: String,
}

#[derive(Clone)]
pub(crate) struct GoogleOAuthConfig {
    pub(crate) client_id: String,
    pub(crate) client_secret: String,
    pub(crate) redirect_uri: String,
}

#[derive(Clone)]
pub(crate) struct PkceSession {
    verifier: String,
    expires_at: Instant,
}

#[derive(Debug, Serialize, Deserialize)]
pub(crate) struct Claims {
    pub(crate) sub: Uuid,
    pub(crate) iat: i64,
    pub(crate) exp: i64,
    pub(crate) iss: String,
    pub(crate) aud: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct UserDto {
    pub(crate) id: Uuid,
    pub(crate) email: String,
    pub(crate) name: String,
    pub(crate) created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
pub(crate) struct RegisterRequest {
    pub(crate) email: String,
    pub(crate) name: String,
    pub(crate) password: String,
}

#[derive(Debug, Deserialize)]
pub(crate) struct LoginRequest {
    pub(crate) email: String,
    pub(crate) password: String,
}

#[derive(Debug, Serialize)]
pub(crate) struct AuthResponse {
    pub(crate) access_token: String,
    pub(crate) token_type: &'static str,
    pub(crate) expires_in: i64,
    pub(crate) user: UserDto,
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/auth/register", axum::routing::post(register))
        .route("/api/auth/login", axum::routing::post(login))
        .route("/api/auth/oauth/google", get(oauth::google_start))
        .route(
            "/api/auth/oauth/google/callback",
            get(oauth::google_callback),
        )
}

impl AuthContext {
    pub(crate) async fn from_env(http: reqwest::Client) -> Result<Option<Self>, ApiError> {
        let Ok(database_url) = std::env::var("DATABASE_URL") else {
            return Ok(None);
        };

        let jwt_secret = std::env::var("JWT_SECRET").map_err(|_| {
            ApiError::unavailable("JWT_SECRET must be configured when DATABASE_URL is set")
        })?;
        if jwt_secret.len() < 32 {
            return Err(ApiError::unavailable(
                "JWT_SECRET must be at least 32 bytes for HS256 signing",
            ));
        }

        let pool = PgPoolOptions::new()
            .max_connections(5)
            .connect(&database_url)
            .await
            .map_err(|error| {
                eprintln!("failed to connect auth database: {error}");
                ApiError::unavailable("failed to connect auth database")
            })?;

        sqlx::migrate!("./migrations")
            .run(&pool)
            .await
            .map_err(|error| {
                eprintln!("failed to run auth migrations: {error}");
                ApiError::internal("failed to run auth migrations")
            })?;

        let issuer = std::env::var("JWT_ISSUER").unwrap_or_else(|_| "agenttrace".to_string());
        let audience =
            std::env::var("JWT_AUDIENCE").unwrap_or_else(|_| "agenttrace-app".to_string());
        let jwt = JwtConfig {
            encoding_key: EncodingKey::from_secret(jwt_secret.as_bytes()),
            decoding_key: DecodingKey::from_secret(jwt_secret.as_bytes()),
            issuer,
            audience,
        };

        let google = match (
            std::env::var("GOOGLE_CLIENT_ID"),
            std::env::var("GOOGLE_CLIENT_SECRET"),
            std::env::var("GOOGLE_REDIRECT_URI"),
        ) {
            (Ok(client_id), Ok(client_secret), Ok(redirect_uri)) => Some(GoogleOAuthConfig {
                client_id,
                client_secret,
                redirect_uri,
            }),
            _ => None,
        };

        let key_cipher = std::env::var("AGENTTRACE_KEYS_SECRET")
            .ok()
            .map(|secret| KeyCipher::from_secret(&secret));

        Ok(Some(Self {
            pool,
            jwt,
            google,
            key_cipher,
            http,
            oauth_states: Arc::new(Mutex::new(HashMap::new())),
        }))
    }

    pub(crate) fn take_pkce_session(&self, state: &str) -> Result<PkceSession, ApiError> {
        let mut states = self
            .oauth_states
            .lock()
            .map_err(|_| ApiError::internal("oauth state store is unavailable"))?;
        states.retain(|_, session| session.expires_at > Instant::now());
        let session = states
            .remove(state)
            .ok_or_else(|| ApiError::bad_request("invalid or expired OAuth state"))?;

        if session.expires_at <= Instant::now() {
            return Err(ApiError::bad_request("expired OAuth state"));
        }

        Ok(session)
    }

    pub(crate) fn store_pkce_session(
        &self,
        state: String,
        verifier: String,
    ) -> Result<(), ApiError> {
        let mut states = self
            .oauth_states
            .lock()
            .map_err(|_| ApiError::internal("oauth state store is unavailable"))?;
        states.insert(
            state,
            PkceSession {
                verifier,
                expires_at: Instant::now() + Duration::from_secs(10 * 60),
            },
        );
        Ok(())
    }
}

impl JwtConfig {
    pub(crate) fn issue(&self, user_id: Uuid) -> Result<String, ApiError> {
        let iat = Utc::now().timestamp();
        let claims = Claims {
            sub: user_id,
            iat,
            exp: iat + ACCESS_TOKEN_TTL_SECONDS,
            iss: self.issuer.clone(),
            aud: self.audience.clone(),
        };
        encode(&Header::default(), &claims, &self.encoding_key)
            .map_err(|_| ApiError::internal("failed to sign access token"))
    }

    pub(crate) fn verify(&self, token: &str) -> Result<Claims, ApiError> {
        let mut validation = Validation::default();
        validation.set_issuer(&[self.issuer.as_str()]);
        validation.set_audience(&[self.audience.as_str()]);

        // JWT verification happens in one place:
        // 1. HS256 signature is verified using the server-side JWT_SECRET.
        // 2. `exp` is checked by jsonwebtoken so expired tokens are rejected.
        // 3. issuer and audience are pinned to this AgentTrace backend/app pair.
        decode::<Claims>(token, &self.decoding_key, &validation)
            .map(|data| data.claims)
            .map_err(|_| ApiError::unauthorized("invalid or expired access token"))
    }
}

pub(crate) fn require_auth(state: &AppState) -> Result<Arc<AuthContext>, ApiError> {
    state
        .auth
        .clone()
        .ok_or_else(|| ApiError::unavailable("auth database is not configured"))
}

async fn register(
    State(state): State<AppState>,
    Json(payload): Json<RegisterRequest>,
) -> Result<(StatusCode, Json<AuthResponse>), ApiError> {
    let auth = require_auth(&state)?;
    let email = normalize_email(&payload.email)?;
    let name = normalize_name(&payload.name)?;
    validate_password(&payload.password)?;
    let password_hash = hash_password(&payload.password)?;

    let mut tx = auth.pool.begin().await?;
    let user = sqlx::query(
        "INSERT INTO users (email, name, password_hash)
         VALUES ($1, $2, $3)
         RETURNING id, email, name, created_at",
    )
    .bind(&email)
    .bind(&name)
    .bind(&password_hash)
    .fetch_one(&mut *tx)
    .await
    .map_err(map_unique_user_error)?;

    let user = row_to_user(user)?;
    sqlx::query("INSERT INTO user_settings (user_id) VALUES ($1)")
        .bind(user.id)
        .execute(&mut *tx)
        .await?;
    tx.commit().await?;

    let response = auth_response(&auth, user)?;
    Ok((StatusCode::CREATED, Json(response)))
}

async fn login(
    State(state): State<AppState>,
    Json(payload): Json<LoginRequest>,
) -> Result<Json<AuthResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let email = normalize_email(&payload.email)?;

    let row = sqlx::query(
        "SELECT id, email, name, password_hash, created_at
         FROM users
         WHERE email = $1",
    )
    .bind(&email)
    .fetch_optional(&auth.pool)
    .await?;

    let Some(row) = row else {
        return Err(ApiError::unauthorized("invalid email or password"));
    };

    let password_hash = row
        .try_get::<Option<String>, _>("password_hash")?
        .ok_or_else(|| ApiError::unauthorized("this account uses Google sign-in"))?;
    verify_password(&payload.password, &password_hash)?;

    let user = row_to_user(row)?;
    Ok(Json(auth_response(&auth, user)?))
}

pub(crate) fn auth_response(auth: &AuthContext, user: UserDto) -> Result<AuthResponse, ApiError> {
    let access_token = auth.jwt.issue(user.id)?;
    Ok(AuthResponse {
        access_token,
        token_type: "Bearer",
        expires_in: ACCESS_TOKEN_TTL_SECONDS,
        user,
    })
}

pub(crate) fn row_to_user(row: sqlx::postgres::PgRow) -> Result<UserDto, ApiError> {
    Ok(UserDto {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    })
}

pub(crate) fn normalize_email(email: &str) -> Result<String, ApiError> {
    let email = email.trim().to_ascii_lowercase();
    if !email.contains('@') || email.len() > 320 {
        return Err(ApiError::bad_request("valid email is required"));
    }
    Ok(email)
}

fn normalize_name(name: &str) -> Result<String, ApiError> {
    let name = name.trim();
    if name.is_empty() || name.len() > 120 {
        return Err(ApiError::bad_request(
            "name must be between 1 and 120 characters",
        ));
    }
    Ok(name.to_string())
}

fn validate_password(password: &str) -> Result<(), ApiError> {
    if password.len() < 12 {
        return Err(ApiError::bad_request(
            "password must be at least 12 characters",
        ));
    }
    Ok(())
}

fn hash_password(password: &str) -> Result<String, ApiError> {
    let salt = SaltString::generate(&mut OsRng);
    Argon2::default()
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
        .map_err(|_| ApiError::internal("failed to hash password"))
}

fn verify_password(password: &str, password_hash: &str) -> Result<(), ApiError> {
    let parsed_hash = PasswordHash::new(password_hash)
        .map_err(|_| ApiError::internal("stored password hash is invalid"))?;
    Argon2::default()
        .verify_password(password.as_bytes(), &parsed_hash)
        .map_err(|_| ApiError::unauthorized("invalid email or password"))
}

fn map_unique_user_error(error: sqlx::Error) -> ApiError {
    if let sqlx::Error::Database(db_error) = &error {
        if db_error.code().as_deref() == Some("23505") {
            return ApiError::conflict("email already exists");
        }
    }
    error.into()
}
