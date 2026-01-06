# NBA Oracle Frontend - Development Dockerfile
# Production goes to Vercel (no Docker needed)
# Using Amazon ECR Public to avoid Docker Hub rate limits

FROM public.ecr.aws/docker/library/node:22-bookworm-slim AS base
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Development stage (only stage needed - prod goes to Vercel)
FROM base AS dev
COPY package.json pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile || pnpm install
COPY . .
CMD ["pnpm", "dev", "--host"]
