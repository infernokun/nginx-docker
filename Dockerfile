# syntax=docker/dockerfile:1.4.2
# Compilation stage for OpenCTI
FROM node:18-bullseye AS compile-stage

VOLUME ["/root/.npm"]

# Use apt-cache for faster builds
RUN --mount=type=cache,id=apt_cache,target=/var/cache/apt,sharing=locked \
    set -eux \
    && apt-get update \
    && apt-get install -y python3 make g++ libsqlite3-dev

WORKDIR /app/

# Copy package definitions and install dependencies
COPY --link package.json package-lock.json /app/
RUN --mount=type=cache,id=npm_cache,target=/root/.npm/_cacache \
    --mount=type=secret,id=npmrc,dst=/root/.npmrc \
    set -eux \
    && npm ci

# Copy application source code
COPY --link src/ /app/src
RUN --mount=type=cache,id=npm_cache,target=/root/.npm/_cacache \
    set -eux \
    && npm run build

# NGINX runtime stage
FROM nginx:alpine AS runtime-stage

# Copy NGINX configuration files
COPY --link --chown=101:101 nginx/nginx.conf /etc/nginx/nginx.conf
COPY --link --chown=101:101 nginx/default.conf.template /etc/nginx/templates/default.conf.template

# Add SSL certificates (replace with actual certificate paths or mount them)
COPY --link --chown=101:101 certs/server.crt /etc/nginx/certs/server.crt
COPY --link --chown=101:101 certs/server.key /etc/nginx/certs/server.key

# Set permissions for NGINX directories
RUN set -eux \
    && chown nginx:nginx -R /var/cache/nginx \
    && chown nginx:nginx -R /var/log/nginx \
    && chown nginx:nginx -R /etc/nginx \
    && chown nginx:nginx -R /usr/share/nginx \
    && touch /var/run/nginx.pid \
    && chown nginx:nginx /var/run/nginx.pid \
    && rm /etc/nginx/conf.d/default.conf

# Copy OpenCTI build output from the compile stage
COPY --link --chown=101:101 --from=compile-stage /app/dist /usr/share/nginx/html/

# Define environment variables and health check
ARG URL_PREFIX
ENV URL_PREFIX=${URL_PREFIX:-/}
ENV PORT=443
EXPOSE ${PORT}

HEALTHCHECK --start-period=5s CMD curl --fail https://localhost:${PORT}/health || exit 1

# Run as the nginx user
USER nginx
