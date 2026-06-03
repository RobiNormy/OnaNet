import asyncpg
from contextlib import asynccontextmanager

from backend.core.config import settings

_pool: asyncpg.Pool | None = None


async def init_db_pool():
    global _pool

    if _pool is None:
        _pool = await asyncpg.create_pool(
            dsn=settings.DATABASE_URL,
            min_size=1,
            max_size=10,
            ssl="require",
        )


async def close_db_pool():
    global _pool

    if _pool is not None:
        await _pool.close()
        _pool = None


@asynccontextmanager
async def get_db_connection():
    if _pool is None:
        raise RuntimeError("Database pool not initialized")

    async with _pool.acquire() as connection:
        yield connection