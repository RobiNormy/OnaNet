from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.gzip import GZipMiddleware
from contextlib import asynccontextmanager
from backend.api.auth import router as auth_router
from backend.api.provider import router as provider_router
from backend.api.subscription import router as subscription_router
from backend.db.session import init_db_pool, close_db_pool
from backend.db.performance import ensure_performance_indexes
from backend.api.phone_verification import router as phone_router
from backend.api.installation_requests import (
    ensure_installation_requests_schema,
    router as installation_requests_router,
)
from backend.api.reviews import ensure_reviews_schema, router as reviews_router
from backend.api.pro_analytics import ensure_pro_analytics_schema, router as pro_analytics_router
from backend.api.provider_staff import (
    ensure_provider_staff_schema,
    router as provider_staff_router,
)
from backend.api.admin import router as admin_router
from backend.services.provider_access import provider_staff_access_middleware
@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db_pool()
    await ensure_installation_requests_schema()
    await ensure_reviews_schema()
    await ensure_pro_analytics_schema()
    await ensure_provider_staff_schema()
    await ensure_performance_indexes()
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
        "https://onanet-production.up.railway.app",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(GZipMiddleware, minimum_size=1000, compresslevel=5)
app.middleware("http")(provider_staff_access_middleware)

app.include_router(auth_router)
app.include_router(provider_router)
app.include_router(phone_router)
app.include_router(installation_requests_router)
app.include_router(reviews_router)
app.include_router(subscription_router)
app.include_router(pro_analytics_router)
app.include_router(provider_staff_router)
app.include_router(admin_router)
@app.get("/")
async def root():
    return {
        "status": "OnaNet API is running"
    }
