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

    @field_validator("cors_origins", mode="before")
    @classmethod
    def parse_cors_origins(cls, v: str | list[str]) -> list[str]:
        if isinstance(v, str):
            return [origin.strip() for origin in v.split(",")]
        return v


settings = Settings()
