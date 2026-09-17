"""A simple FastAPI application."""
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title="docker-project", version="0.1.0")


class Item(BaseModel):
    name: str
    quantity: int = 1


@app.get("/")
def read_root() -> dict[str, str]:
    return {"message": "Hello from docker-project!"}


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/items")
def create_item(item: Item) -> dict[str, str]:
    if item.quantity < 1:
        raise HTTPException(status_code=400, detail="quantity must be >= 1")
    return {"name": item.name, "status": "created"}