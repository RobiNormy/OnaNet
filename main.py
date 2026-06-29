from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from backend.api.auth import router as auth_router
from backend.api.provider import router as provider_router
from backend.db.session import init_db_pool, close_db_pool
from backend.api.phone_verification import router as phone_router
from backend.api.installation_requests import router as installation_requests_router
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db_pool()
    yield
    await close_db_pool()

app = FastAPI(
    title="OnaNet API",
    version="1.0.0",
    lifespan=lifespan,

)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost",
        "http://127.0.0.1",
        "http://localhost:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(provider_router)
app.include_router(phone_router)
app.include_router(installation_requests_router)
@app.get("/")
async def root():
    return {
        "status": "OnaNet API is running"
    }
