# syntax=docker/dockerfile:1

ARG NODE_VERSION=24.19.0

FROM node:${NODE_VERSION}-slim AS base
WORKDIR /app
ENV NEXT_TELEMETRY_DISABLED=1
RUN apt-get update \
	&& apt-get install --yes --no-install-recommends openssl \
	&& rm -rf /var/lib/apt/lists/*

FROM base AS dependencies
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN --mount=type=cache,target=/root/.npm npm ci

FROM base AS builder
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN --mount=type=cache,target=/app/.next/cache \
	BETTER_AUTH_GITHUB_CLIENT_ID=build-only-client-id \
	BETTER_AUTH_GITHUB_CLIENT_SECRET=build-only-client-secret \
	BETTER_AUTH_SECRET=build-only-secret-that-is-never-used-at-runtime \
	BETTER_AUTH_URL=http://localhost:3000 \
	DATABASE_URL=postgresql://postgres:build-only@localhost:5432/supportdesk \
	SKIP_ENV_VALIDATION=1 \
	npm run build

FROM base AS runner
ENV NODE_ENV=production
ENV HOSTNAME=0.0.0.0
ENV PORT=3000

RUN groupadd --system --gid 1001 nodejs \
	&& useradd --system --uid 1001 --gid nodejs nextjs

COPY --from=builder --chown=nextjs:nodejs /app/public ./public
RUN mkdir .next && chown nextjs:nodejs .next
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
	CMD ["node", "-e", "fetch('http://127.0.0.1:3000/api/health').then((response) => { if (!response.ok) process.exit(1) }).catch(() => process.exit(1))"]

CMD ["node", "server.js"]
