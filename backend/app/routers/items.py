from __future__ import annotations

from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query

from .. import crud
from ..auth import require_token
from ..schemas import Item, ItemCreate, ItemListResponse, ItemUpdate


router = APIRouter(prefix="/api", dependencies=[Depends(require_token)])


@router.post("/items", response_model=Item)
def create_item(payload: ItemCreate) -> dict:
    return crud.create_item(payload)


@router.get("/items", response_model=ItemListResponse)
def list_items(
    status: str = Query("unread", pattern="^(unread|read|deleted|all)$"),
    favorite: Optional[bool] = None,
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
) -> dict:
    return {
        "items": crud.list_items(status=status, favorite=favorite, limit=limit, offset=offset),
        "limit": limit,
        "offset": offset,
    }


@router.get("/items/{item_id}", response_model=Item)
def get_item(item_id: int) -> dict:
    item = crud.get_item(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.patch("/items/{item_id}", response_model=Item)
def update_item(item_id: int, payload: ItemUpdate) -> dict:
    item = crud.update_item(item_id, payload)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.delete("/items/{item_id}", response_model=Item)
def delete_item(item_id: int) -> dict:
    item = crud.soft_delete_item(item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item


@router.get("/search", response_model=ItemListResponse)
def search(
    q: str = Query(..., min_length=1),
    limit: int = Query(30, ge=1, le=100),
    offset: int = Query(0, ge=0),
) -> dict:
    return {
        "items": crud.search_items(q, limit=limit, offset=offset),
        "limit": limit,
        "offset": offset,
    }
