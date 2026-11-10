import asyncio
import json
import logging
from contextlib import asynccontextmanager

import asyncpg
import aio_pika
import redis.asyncio as aioredis
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

# --- Настройки подключения ---
DB_DSN = "postgresql://cinema_user:cinema_secret_password@postgres:5432/cinema_db"
REDIS_DSN = "redis://redis:6379/0"
RABBIT_DSN = "amqp://admin:admin@rabbitmq/"

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("cinema_service")


# --- Pydantic модели ---
class MovieCreate(BaseModel):
    title: str
    genre: str
    duration_minutes: int


class MovieResponse(BaseModel):
    id: int
    title: str
    genre: str
    duration_minutes: int


# --- Consumer: фоновый обработчик сообщений ---
async def on_message(message: aio_pika.IncomingMessage):
    async with message.process():
        body = json.loads(message.body)
        logger.info(f"📩 CONSUMER RECEIVED EVENT: {body}")


# --- Жизненный цикл приложения ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    # 1. Подключение к PostgreSQL (с защитой от долгого старта)
    while True:
        try:
            app.state.db_pool = await asyncpg.create_pool(dsn=DB_DSN)
            logger.info("✅ Connected to PostgreSQL")
            break
        except Exception as e:
            logger.warning(f"Postgres not ready, retrying... ({e})")
            await asyncio.sleep(2)

    # Создаём таблицу, если её нет
    async with app.state.db_pool.acquire() as conn:
        await conn.execute("""
            CREATE TABLE IF NOT EXISTS movies (
                id SERIAL PRIMARY KEY,
                title VARCHAR(255) NOT NULL,
                genre VARCHAR(100) NOT NULL,
                duration_minutes INT NOT NULL
            );
        """)

    # 2. Подключение к Redis
    app.state.redis = aioredis.from_url(REDIS_DSN, decode_responses=True)
    logger.info("✅ Connected to Redis")

    # 3. Подключение к RabbitMQ + создание СВОЕГО exchange
    while True:
        try:
            app.state.rabbit_conn = await aio_pika.connect_robust(RABBIT_DSN)
            app.state.rabbit_channel = await app.state.rabbit_conn.channel()

            # Создаём собственный exchange (дефолтный в RabbitMQ 3.x+ запрещён для admin)
            app.state.exchange = await app.state.rabbit_channel.declare_exchange(
                "cinema_events",
                aio_pika.ExchangeType.DIRECT,
                durable=True
            )

            # Объявляем очередь и привязываем к exchange
            queue = await app.state.rabbit_channel.declare_queue(
                "movie_events",
                durable=True,
                auto_delete=False
            )
            await queue.bind(app.state.exchange, routing_key="movie.created")

            # Запускаем consumer
            await queue.consume(on_message)
            logger.info("✅ Connected to RabbitMQ & Consumer started")
            break
        except Exception as e:
            logger.warning(f"RabbitMQ not ready, retrying... ({e})")
            await asyncio.sleep(2)

    yield

    # Shutdown
    await app.state.rabbit_conn.close()
    await app.state.redis.close()
    await app.state.db_pool.close()


app = FastAPI(title="Cinema Booking Service", lifespan=lifespan)


# --- Health check endpoint ---
@app.get("/health")
def health_check():
    return {"status": "ok"}

# --- ENDPOINT 1: Запись (Create) ---
@app.post("/movies", response_model=MovieResponse)
async def create_movie(movie: MovieCreate):
    # 1. Запись в БД
    async with app.state.db_pool.acquire() as conn:
        row = await conn.fetchrow(
            "INSERT INTO movies (title, genre, duration_minutes) VALUES ($1, $2, $3) "
            "RETURNING id, title, genre, duration_minutes",
            movie.title, movie.genre, movie.duration_minutes
        )
        movie_id = row['id']

    # 2. Инвалидация кэша (Cache-Aside паттерн)
    await app.state.redis.delete(f"movie:{movie_id}")
    logger.info(f"🗑️ Cache invalidated for movie {movie_id}")

    # 3. Публикация события в брокер
    try:
        await app.state.exchange.publish(
            aio_pika.Message(
                body=json.dumps({
                    "event": "movie_created",
                    "movie_id": movie_id,
                    "title": movie.title
                }).encode(),
                content_type="application/json"
            ),
            routing_key="movie.created"
        )
        logger.info(f"📤 Event published to RabbitMQ for movie {movie_id}")
    except Exception as e:
        logger.error(f"Failed to publish event: {e}")

    return dict(row)


# --- ENDPOINT 2: Чтение (Read) ---
@app.get("/movies/{movie_id}", response_model=MovieResponse)
async def get_movie(movie_id: int):
    # 1. Попытка чтения из кэша
    cached = await app.state.redis.get(f"movie:{movie_id}")
    if cached:
        logger.info(f"⚡ Cache HIT for movie {movie_id}")
        return json.loads(cached)

    # 2. Чтение из БД (Cache MISS)
    async with app.state.db_pool.acquire() as conn:
        row = await conn.fetchrow(
            "SELECT id, title, genre, duration_minutes FROM movies WHERE id = $1",
            movie_id
        )

    if not row:
        raise HTTPException(status_code=404, detail="Movie not found")

    # 3. Запись в кэш с TTL 5 минут
    movie_dict = dict(row)
    await app.state.redis.set(
        f"movie:{movie_id}",
        json.dumps(movie_dict),
        ex=300
    )
    logger.info(f"💾 Cache MISS. Read from DB and saved to Redis for movie {movie_id}")

    return movie_dict