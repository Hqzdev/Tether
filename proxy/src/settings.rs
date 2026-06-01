use axum::{Json, Router, extract::State, routing::get};
use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::Row;
use uuid::Uuid;

use crate::{
    AppState,
    auth::{extractor::AuthBearer, normalize_email, require_auth},
    error::ApiError,
};

#[derive(Debug, Serialize)]
struct ProfileResponse {
    id: Uuid,
    email: String,
    name: String,
    created_at: DateTime<Utc>,
}

#[derive(Debug, Deserialize)]
struct ProfileUpdateRequest {
    name: Option<String>,
    email: Option<String>,
}

#[derive(Debug, Serialize)]
struct AppSettingsResponse {
    theme: String,
    proxy_port: i32,
    local_cache_enabled: bool,
    has_openai_key: bool,
    has_anthropic_key: bool,
}

#[derive(Debug, Deserialize)]
struct AppSettingsUpdateRequest {
    theme: Option<String>,
    proxy_port: Option<i32>,
    local_cache_enabled: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct ApiKeysUpdateRequest {
    api_key_openai: Option<String>,
    api_key_anthropic: Option<String>,
}

#[derive(Debug, Serialize)]
struct UpdateResponse {
    ok: bool,
}

pub(crate) fn router() -> Router<AppState> {
    Router::new()
        .route("/api/settings/profile", get(profile))
        .route(
            "/api/settings/profile/update",
            axum::routing::post(update_profile),
        )
        .route("/api/settings/app", get(app_settings))
        .route(
            "/api/settings/app/update",
            axum::routing::post(update_app_settings),
        )
        .route("/api/settings/keys", axum::routing::post(update_api_keys))
}

async fn profile(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
) -> Result<Json<ProfileResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let row = sqlx::query("SELECT id, email, name, created_at FROM users WHERE id = $1")
        .bind(auth_bearer.user_id)
        .fetch_optional(&auth.pool)
        .await?
        .ok_or_else(|| ApiError::unauthorized("user no longer exists"))?;

    Ok(Json(ProfileResponse {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    }))
}

async fn update_profile(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<ProfileUpdateRequest>,
) -> Result<Json<ProfileResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let current = sqlx::query("SELECT email, name FROM users WHERE id = $1")
        .bind(auth_bearer.user_id)
        .fetch_optional(&auth.pool)
        .await?
        .ok_or_else(|| ApiError::unauthorized("user no longer exists"))?;

    let name = match payload.name {
        Some(name) => normalize_name(&name)?,
        None => current.try_get("name")?,
    };
    let email = match payload.email {
        Some(email) => normalize_email(&email)?,
        None => current.try_get("email")?,
    };

    let row = sqlx::query(
        "UPDATE users
         SET name = $1, email = $2
         WHERE id = $3
         RETURNING id, email, name, created_at",
    )
    .bind(&name)
    .bind(&email)
    .bind(auth_bearer.user_id)
    .fetch_one(&auth.pool)
    .await
    .map_err(map_unique_email_error)?;

    Ok(Json(ProfileResponse {
        id: row.try_get("id")?,
        email: row.try_get("email")?,
        name: row.try_get("name")?,
        created_at: row.try_get("created_at")?,
    }))
}

async fn app_settings(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
) -> Result<Json<AppSettingsResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let row = ensure_settings(&auth.pool, auth_bearer.user_id).await?;
    Ok(Json(row_to_app_settings(row)?))
}

async fn update_app_settings(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<AppSettingsUpdateRequest>,
) -> Result<Json<AppSettingsResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let current = ensure_settings(&auth.pool, auth_bearer.user_id).await?;
    let theme = match payload.theme {
        Some(theme) => validate_theme(&theme)?,
        None => current.try_get("theme")?,
    };
    let proxy_port = match payload.proxy_port {
        Some(port) => validate_port(port)?,
        None => current.try_get("proxy_port")?,
    };
    let local_cache_enabled = payload
        .local_cache_enabled
        .unwrap_or(current.try_get("local_cache_enabled")?);

    let row = sqlx::query(
        "UPDATE user_settings
         SET theme = $1, proxy_port = $2, local_cache_enabled = $3
         WHERE user_id = $4
         RETURNING theme, proxy_port, local_cache_enabled, api_key_openai, api_key_anthropic",
    )
    .bind(&theme)
    .bind(proxy_port)
    .bind(local_cache_enabled)
    .bind(auth_bearer.user_id)
    .fetch_one(&auth.pool)
    .await?;

    Ok(Json(row_to_app_settings(row)?))
}

async fn update_api_keys(
    State(state): State<AppState>,
    auth_bearer: AuthBearer,
    Json(payload): Json<ApiKeysUpdateRequest>,
) -> Result<Json<UpdateResponse>, ApiError> {
    let auth = require_auth(&state)?;
    let cipher = auth
        .key_cipher
        .as_ref()
        .ok_or_else(|| ApiError::unavailable("AGENTTRACE_KEYS_SECRET is not configured"))?;
    let current = ensure_settings(&auth.pool, auth_bearer.user_id).await?;

    let openai_key = match payload.api_key_openai {
        Some(value) if value.trim().is_empty() => None,
        Some(value) => Some(cipher.encrypt(value.trim())?),
        None => current.try_get("api_key_openai")?,
    };
    let anthropic_key = match payload.api_key_anthropic {
        Some(value) if value.trim().is_empty() => None,
        Some(value) => Some(cipher.encrypt(value.trim())?),
        None => current.try_get("api_key_anthropic")?,
    };

    sqlx::query(
        "UPDATE user_settings
         SET api_key_openai = $1, api_key_anthropic = $2
         WHERE user_id = $3",
    )
    .bind(openai_key)
    .bind(anthropic_key)
    .bind(auth_bearer.user_id)
    .execute(&auth.pool)
    .await?;

    Ok(Json(UpdateResponse { ok: true }))
}

async fn ensure_settings(
    pool: &sqlx::PgPool,
    user_id: Uuid,
) -> Result<sqlx::postgres::PgRow, ApiError> {
    sqlx::query("INSERT INTO user_settings (user_id) VALUES ($1) ON CONFLICT (user_id) DO NOTHING")
        .bind(user_id)
        .execute(pool)
        .await?;

    sqlx::query(
        "SELECT theme, proxy_port, local_cache_enabled, api_key_openai, api_key_anthropic
         FROM user_settings
         WHERE user_id = $1",
    )
    .bind(user_id)
    .fetch_one(pool)
    .await
    .map_err(Into::into)
}

fn row_to_app_settings(row: sqlx::postgres::PgRow) -> Result<AppSettingsResponse, ApiError> {
    let openai_key: Option<String> = row.try_get("api_key_openai")?;
    let anthropic_key: Option<String> = row.try_get("api_key_anthropic")?;

    Ok(AppSettingsResponse {
        theme: row.try_get("theme")?,
        proxy_port: row.try_get("proxy_port")?,
        local_cache_enabled: row.try_get("local_cache_enabled")?,
        has_openai_key: openai_key.is_some(),
        has_anthropic_key: anthropic_key.is_some(),
    })
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

fn validate_theme(theme: &str) -> Result<String, ApiError> {
    match theme {
        "system" | "light" | "dark" => Ok(theme.to_string()),
        _ => Err(ApiError::bad_request(
            "theme must be system, light, or dark",
        )),
    }
}

fn validate_port(port: i32) -> Result<i32, ApiError> {
    if !(1..=65535).contains(&port) {
        return Err(ApiError::bad_request(
            "proxy_port must be between 1 and 65535",
        ));
    }
    Ok(port)
}

fn map_unique_email_error(error: sqlx::Error) -> ApiError {
    if let sqlx::Error::Database(db_error) = &error {
        if db_error.code().as_deref() == Some("23505") {
            return ApiError::conflict("email already exists");
        }
    }
    error.into()
}
