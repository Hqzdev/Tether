use aes_gcm::{
    Aes256Gcm, Nonce,
    aead::{Aead, KeyInit},
};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use rand_core::{OsRng, RngCore};
use sha2::{Digest, Sha256};

use crate::error::ApiError;

#[derive(Clone)]
pub(crate) struct KeyCipher {
    cipher: Aes256Gcm,
}

impl KeyCipher {
    pub(crate) fn from_secret(secret: &str) -> Self {
        let digest = Sha256::digest(secret.as_bytes());
        let cipher = Aes256Gcm::new_from_slice(&digest).expect("sha256 always yields 32 bytes");
        Self { cipher }
    }

    pub(crate) fn encrypt(&self, plaintext: &str) -> Result<String, ApiError> {
        let mut nonce_bytes = [0_u8; 12];
        OsRng.fill_bytes(&mut nonce_bytes);
        let nonce = Nonce::from_slice(&nonce_bytes);
        let ciphertext = self
            .cipher
            .encrypt(nonce, plaintext.as_bytes())
            .map_err(|_| ApiError::internal("failed to encrypt API key"))?;

        Ok(format!(
            "v1:{}:{}",
            URL_SAFE_NO_PAD.encode(nonce_bytes),
            URL_SAFE_NO_PAD.encode(ciphertext)
        ))
    }

    #[allow(dead_code)]
    pub(crate) fn decrypt(&self, encoded: &str) -> Result<String, ApiError> {
        let parts = encoded.split(':').collect::<Vec<_>>();
        if parts.len() != 3 || parts[0] != "v1" {
            return Err(ApiError::internal("unsupported encrypted secret format"));
        }

        let nonce = URL_SAFE_NO_PAD
            .decode(parts[1])
            .map_err(|_| ApiError::internal("invalid encrypted secret nonce"))?;
        let ciphertext = URL_SAFE_NO_PAD
            .decode(parts[2])
            .map_err(|_| ApiError::internal("invalid encrypted secret payload"))?;
        let plaintext = self
            .cipher
            .decrypt(Nonce::from_slice(&nonce), ciphertext.as_ref())
            .map_err(|_| ApiError::internal("failed to decrypt API key"))?;

        String::from_utf8(plaintext).map_err(|_| ApiError::internal("decrypted API key is invalid"))
    }
}
