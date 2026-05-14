import logging
from typing import Annotated

from pydantic import field_validator
from pydantic_settings import BaseSettings, NoDecode, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env.local",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # Existing
    api_env: str = "development"
    debug: bool = True
    cors_origins: Annotated[list[str], NoDecode] = ["http://localhost:5173"]

    # API Security (empty = skip verification, useful for local dev)
    api_key_hash: str = ""

    # NBA API
    balldontlie_api_key: str = ""

    # Sentry (empty DSN = disabled — keeps local dev a no-op).
    sentry_dsn: str = ""
    # Perf-trace sampling, 0.0–1.0. OFF by default — the Sentry free plan
    # bundles only 10k performance units/month and any non-zero rate on a busy
    # endpoint chews through that fast. Bump to e.g. 0.1 via env if you need
    # traces; no redeploy required.
    sentry_traces_sample_rate: float = 0.0
    # Threshold for Sentry's Logs product (separate pipeline from Issues /
    # breadcrumbs). Raise to "WARNING" if the 5GB/mo log quota gets tight —
    # info-level logs stop shipping to Sentry Logs without affecting error
    # capture. Accepts level names ("INFO", "WARNING", …) from env.
    sentry_logs_level: int = logging.INFO

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v

    @field_validator("sentry_logs_level", mode="before")
    @classmethod
    def parse_log_level(cls, v: str | int) -> int:
        if isinstance(v, str):
            # Accept either a numeric string ("20") or a level name ("INFO").
            if v.isdigit():
                return int(v)
            level = logging.getLevelNamesMapping().get(v.upper())
            if level is None:
                raise ValueError(f"Unknown log level: {v!r}")
            return level
        return v


settings = Settings()
