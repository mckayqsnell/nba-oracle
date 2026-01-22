"""API Key authentication for securing endpoints."""

import hashlib
import secrets
from typing import Annotated

from fastapi import Depends, HTTPException, Security, status
from fastapi.security import APIKeyHeader

from app.config import settings
from app.core.logging import get_logger

logger = get_logger(__name__)

# API Key header scheme
api_key_header = APIKeyHeader(
    name="X-API-Key",
    auto_error=False,  # We'll handle the error ourselves for better logging
    description="API key for authenticating requests from the frontend",
)


def _hash_key(key: str) -> str:
    """Hash an API key using SHA-256."""
    return hashlib.sha256(key.encode()).hexdigest()


async def verify_api_key(
    api_key: str | None = Security(api_key_header),
) -> str:
    """
    Verify the API key from the X-API-Key header.

    Compares the SHA-256 hash of the provided key against the stored hash.
    This way we never store the actual key, only its hash.
    """
    # If no API key hash is configured, skip verification (dev mode)
    if not settings.api_key_hash:
        logger.debug("api_key_verification_skipped", reason="no_hash_configured")
        return "dev-mode"

    # Check if API key was provided
    if not api_key:
        logger.warning("api_key_missing", endpoint="protected")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing API key",
            headers={"WWW-Authenticate": "ApiKey"},
        )

    # Hash the incoming key and compare to stored hash
    incoming_hash = _hash_key(api_key)

    if not secrets.compare_digest(incoming_hash, settings.api_key_hash):
        logger.warning(
            "api_key_invalid",
            provided_hash_prefix=incoming_hash[:8],
        )
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid API key",
        )

    logger.debug("api_key_verified")
    return api_key


# Type alias for dependency injection
ApiKeyDep = Annotated[str, Depends(verify_api_key)]


def generate_api_key_and_hash() -> tuple[str, str]:
    """
    Generate a new API key and its hash.

    Useful for initial setup. Run this once to get values for 1Password:
        python -c "from app.core.security import generate_api_key_and_hash; k,h = generate_api_key_and_hash(); print(f'API_KEY={k}\\nAPI_KEY_HASH={h}')"
    """
    # Generate a secure random key (32 bytes = 64 hex chars)
    api_key = secrets.token_hex(32)
    api_key_hash = _hash_key(api_key)
    return api_key, api_key_hash
