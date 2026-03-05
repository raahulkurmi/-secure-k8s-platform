# ── Stage 1: Build React app ──────────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app
COPY package*.json ./
RUN npm ci && npm cache clean --force
COPY . .
RUN npm run build                   # Outputs to /app/dist

# ── Stage 2: Serve with hardened Nginx ───────────────────────────────────────
FROM nginx:1.25-alpine AS runtime

# Security: remove default nginx user, create non-root user (UID 1001)
RUN addgroup -g 1001 appgroup && \
    adduser  -u 1001 -G appgroup -s /bin/sh -D appuser && \
    # Allow nginx to run on port 8080 as non-root (not port 80)
    touch /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/run/nginx.pid && \
    chown -R appuser:appgroup /var/cache/nginx && \
    chown -R appuser:appgroup /var/log/nginx && \
    chown -R appuser:appgroup /etc/nginx/conf.d

# Copy hardened nginx config
COPY --chown=appuser:appgroup nginx.conf /etc/nginx/conf.d/default.conf

# Copy built React app
COPY --from=builder --chown=appuser:appgroup /app/dist /usr/share/nginx/html

USER 1001

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:8080/healthz || exit 1

CMD ["nginx", "-g", "daemon off;"]
