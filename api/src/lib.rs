//
// Copyright 2021 WithUno, Inc.
// SPDX-License-Identifier: AGPL-3.0-only
//

use std::convert::TryInto;
use std::error;
use std::fmt;
use std::string::String;

mod store;
pub use store::*;

#[derive(PartialEq, Debug)]
pub enum ApiError {
    DecodeError(base64::DecodeError),
    BadRequest(String),
    NotFound,
    Unauthorized,
}

impl From<base64::DecodeError> for ApiError {
    fn from(e: base64::DecodeError) -> Self {
        ApiError::DecodeError(e)
    }
}

impl error::Error for ApiError {
    fn source(&self) -> Option<&(dyn error::Error + 'static)> {
        match *self {
            ApiError::DecodeError(ref s) => Some(s),
            ApiError::BadRequest(_) => None,
            ApiError::NotFound => None,
            ApiError::Unauthorized => None,
        }
    }
}

impl fmt::Display for ApiError {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        match *self {
            ApiError::DecodeError(ref e) => write!(f, "decode error: {}", e),
            ApiError::BadRequest(ref msg) => write!(f, "bad request: {}", msg),
            ApiError::NotFound => write!(f, "api error: not found"),
            ApiError::Unauthorized => write!(f, "api error: unauthorized"),
        }
    }
}

pub fn pubkey_from_id(id: &str) -> Result<uno::Verification, ApiError> {
    let v = base64::decode_config(id, base64::URL_SAFE)?;

    let pk = uno::Verification::from_bytes(&v);
    if pk.is_err() {
        return Err(ApiError::BadRequest("pubkey wrong length".to_string()));
    }

    Ok(pk.unwrap())
}

pub fn signature_from_header(
    header: &str,
) -> Result<uno::Signature, ApiError> {
    let decoded_sig = base64::decode(header)?;

    let sig_array = decoded_sig.try_into();
    if sig_array.is_err() {
        return Err(ApiError::BadRequest("signature wrong length".to_string()));
    }

    Ok(uno::Signature::new(sig_array.unwrap()))
}
