# ── Build stage ──────────────────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

# Copy only the web package manifest first to leverage layer caching
COPY web/package.json web/package-lock.json* ./web/

# Install production + dev dependencies needed for the build
RUN cd web && npm ci

# Copy the rest of the web source
COPY web/ ./web/

# Build the Next.js app (output: standalone is set in next.config.ts)
RUN cd web && npm run build

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Copy the self-contained standalone server produced by Next.js
COPY --from=builder /app/web/.next/standalone ./
# Copy static assets (JS chunks, CSS, images) into the expected location
COPY --from=builder /app/web/.next/static ./.next/static
# Copy the public directory (favicons, robots.txt, etc.)
COPY --from=builder /app/web/public ./public

EXPOSE 3000

# next.config.ts sets output:"standalone", which emits a Node.js server at
# server.js — this is the correct entrypoint for the standalone build.
CMD ["node", "server.js"]
