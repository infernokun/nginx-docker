# syntax=docker/dockerfile:1.4.2
FROM nginx:alpine AS runtime-stage

# Add SSL certificates (replace these with your actual certificates or mount them)
COPY --link certs/server.crt /etc/nginx/certs/server.crt
COPY --link certs/server.key /etc/nginx/certs/server.key

# Add a simple "Hello World" HTML page
RUN mkdir -p /usr/share/nginx/html
RUN echo "<!DOCTYPE html><html><head><title>Hello</title></head><body><h1>Hello, World!</h1></body></html>" > /usr/share/nginx/html/index.html

# Copy NGINX configuration files
COPY --link nginx/nginx.conf /etc/nginx/nginx.conf

# Set permissions for NGINX directories
RUN set -eux \
    && chown nginx:nginx -R /var/cache/nginx \
    && chown nginx:nginx -R /var/log/nginx \
    && chown nginx:nginx -R /etc/nginx \
    && chown nginx:nginx -R /usr/share/nginx \
    && touch /var/run/nginx.pid \
    && chown nginx:nginx /var/run/nginx.pid

# Expose port 443 for HTTPS
EXPOSE 443

# Run NGINX as the nginx user
USER nginx
CMD ["nginx", "-g", "daemon off;"]
