from __future__ import annotations

from typing import Literal, Optional

from pydantic import BaseModel, Field, HttpUrl


ItemStatus = Literal["unread", "read", "deleted"]
ItemSource = Literal["web", "ios_share", "chrome_extension", "api"]


class ItemCreate(BaseModel):
    url: HttpUrl
    title: Optional[str] = Field(default=None, max_length=500)
    source: ItemSource = "web"


class ItemUpdate(BaseModel):
    status: Optional[ItemStatus] = None
    is_favorite: Optional[bool] = None
    title: Optional[str] = Field(default=None, max_length=500)


class Item(BaseModel):
    id: int
    url: str
    canonical_url: Optional[str] = None
    title: Optional[str] = None
    author: Optional[str] = None
    site_name: Optional[str] = None
    excerpt: Optional[str] = None
    content_html: Optional[str] = None
    content_text: Optional[str] = None
    cover_url: Optional[str] = None
    status: ItemStatus
    is_favorite: bool
    source: Optional[str] = None
    created_at: str
    updated_at: str
    read_at: Optional[str] = None


class ItemSummary(BaseModel):
    id: int
    url: str
    canonical_url: Optional[str] = None
    title: Optional[str] = None
    author: Optional[str] = None
    site_name: Optional[str] = None
    excerpt: Optional[str] = None
    cover_url: Optional[str] = None
    status: ItemStatus
    is_favorite: bool
    source: Optional[str] = None
    created_at: str
    updated_at: str
    read_at: Optional[str] = None


class ItemListResponse(BaseModel):
    items: list[ItemSummary]
    limit: int
    offset: int


class LoginRequest(BaseModel):
    username: str = Field(min_length=1, max_length=120)
    password: str = Field(min_length=1, max_length=500)


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    username: str


class AuthMeResponse(BaseModel):
    username: str
