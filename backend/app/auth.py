from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import time
from typing import Optional

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer


bearer = HTTPBearer(auto_error=False)
DEFAULT_SESSION_SECONDS = 60 * 60 * 24 * 30


def configured_username() -> str:
    return os.getenv("READBOX_USERNAME", "readbox").strip() or "readbox"


def configured_password() -> str | None:
    value = os.getenv("READBOX_PASSWORD")
    return value if value else None


def legacy_token() -> str | None:
    value = os.getenv("READBOX_TOKEN")
    return value if value else None


def session_secret() -> str | None:
    return os.getenv("READBOX_SESSION_SECRET") or legacy_token() or configured_password()


def token_ttl_seconds() -> int:
    raw = os.getenv("READBOX_SESSION_SECONDS", str(DEFAULT_SESSION_SECONDS))
    try:
        return max(60, int(raw))
    except ValueError:
        return DEFAULT_SESSION_SECONDS


def _b64encode(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _b64decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _sign(payload: str, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), payload.encode("ascii"), hashlib.sha256).digest()
    return _b64encode(digest)


def create_access_token(username: str) -> tuple[str, int]:
    secret = session_secret()
    if not secret:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="READBOX_PASSWORD or READBOX_TOKEN is not configured",
        )

    ttl = token_ttl_seconds()
    payload = {
        "sub": username,
        "exp": int(time.time()) + ttl,
    }
    payload_part = _b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    return f"{payload_part}.{_sign(payload_part, secret)}", ttl


def verify_access_token(token: str) -> str | None:
    secret = session_secret()
    if not secret or "." not in token:
        return None

    payload_part, signature = token.rsplit(".", 1)
    expected = _sign(payload_part, secret)
    if not hmac.compare_digest(signature, expected):
        return None

    try:
        payload = json.loads(_b64decode(payload_part))
    except (ValueError, json.JSONDecodeError):
        return None

    username = str(payload.get("sub") or "")
    expires_at = int(payload.get("exp") or 0)
    if username != configured_username() or expires_at < int(time.time()):
        return None
    return username


def authenticate(username: str, password: str) -> bool:
    expected_password = configured_password()
    if expected_password is None:
        return False
    return hmac.compare_digest(username, configured_username()) and hmac.compare_digest(
        password,
        expected_password,
    )


def require_token(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(bearer),
) -> str:
    if not session_secret():
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="READBOX_PASSWORD or READBOX_TOKEN is not configured",
        )

    if credentials is None or credentials.scheme.lower() != "bearer":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or missing API token",
        )

    token = credentials.credentials
    username = verify_access_token(token)
    if username:
        return username

    # Backward-compatible path for existing web/iOS/extension installs.
    expected = legacy_token()
    if expected and hmac.compare_digest(token, expected):
        return configured_username()

    raise HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Invalid or missing API token",
    )
