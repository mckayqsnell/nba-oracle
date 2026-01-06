# NBA Oracle Backend - Multi-stage Dockerfile
# Using Amazon ECR Public to avoid Docker Hub rate limits

FROM public.ecr.aws/docker/library/python:3.13-slim AS base

# Install uv (pinned version for reproducibility)
ENV UV_VERSION=0.5.14
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | sh \
    && cp /root/.local/bin/uv /usr/local/bin/uv \
    && apt-get purge -y curl \
    && apt-get autoremove -y \
    && rm -rf /var/lib/apt/lists/*

ENV UV_COMPILE_BYTECODE=1
ENV UV_LINK_MODE=copy

WORKDIR /app

# Development stage - with hot reload
FROM base AS dev
COPY pyproject.toml uv.lock* ./
RUN uv sync --frozen || uv sync
COPY . .
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]

# Production stage
FROM base AS prod
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-dev
COPY . .
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
