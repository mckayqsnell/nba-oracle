# NBA Oracle Frontend - Development Dockerfile
# Production goes to Vercel (no Docker needed)
# Using Amazon ECR Public to avoid Docker Hub rate limits

FROM public.ecr.aws/docker/library/node:22-bookworm-slim AS base
RUN corepack enable && corepack prepare pnpm@latest --activate
WORKDIR /app

# Development stage (only stage needed - prod goes to Vercel)
FROM base AS dev

# pnpm v10+ refuses to run any package's postinstall script by default — exits
# non-zero with ERR_PNPM_IGNORED_BUILDS unless the package is in the
# `allowBuilds` map in pnpm-workspace.yaml. See that file for the full why +
# the workflow for allowing a new dep. (In v11 the old `onlyBuiltDependencies`
# key was removed entirely — `allowBuilds` is the only working form now.)
COPY package.json pnpm-workspace.yaml pnpm-lock.yaml* ./
RUN pnpm install --frozen-lockfile || pnpm install
COPY . .
CMD ["pnpm", "dev", "--host"]
