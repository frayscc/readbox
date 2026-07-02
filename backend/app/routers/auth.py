from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, status

from ..auth import authenticate, configured_username, create_access_token, require_token
from ..schemas import AuthMeResponse, LoginRequest, LoginResponse


router = APIRouter(prefix="/api/auth")


@router.post("/login", response_model=LoginResponse)
def login(payload: LoginRequest) -> LoginResponse:
    if not authenticate(payload.username, payload.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    token, expires_in = create_access_token(payload.username)
    return LoginResponse(
        access_token=token,
        expires_in=expires_in,
        username=payload.username,
    )


@router.get("/me", response_model=AuthMeResponse)
def me(username: str = Depends(require_token)) -> AuthMeResponse:
    return AuthMeResponse(username=username or configured_username())
