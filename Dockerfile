# Stage 1: Build the frontend web assets
FROM node:22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git libc6-compat openssh-client && npm install -g pnpm
COPY package*.json pnpm-lock.yaml* ./
COPY . .
RUN pnpm install --frozen-lockfile && pnpm run build

# Stage 2: Serve via Nginx and configure internal proxy routing
FROM nginx:alpine

# 1. Automatically tell the browser client to look at its relative subpath
RUN echo '<script>\
  if (!localStorage.getItem("harbor_streaming_server")) {\
    localStorage.setItem("harbor_streaming_server", window.location.origin + "/stremio-server/");\
  }\
</script>' > /usr/share/nginx/html/inject.html

RUN sed -i '/<head>/r /usr/share/nginx/html/inject.html' /usr/share/nginx/html/index.html

# 2. Configure Nginx inside the container to route traffic over the internal Docker network
RUN echo 'server {\
    listen 80;\
    location / {\
        root /usr/share/nginx/html;\
        index index.html index.htm;\
        try_files $uri $uri/ /index.html;\
    }\
    location /stremio-server/ {\
        proxy_pass http://torrent-engine:8080/stremio-server/;\
        proxy_set_header Host $host;\
        proxy_set_header X-Real-IP $remote_addr;\
        proxy_buffering off;\
        proxy_read_timeout 3600s;\
        proxy_send_timeout 3600s;\
    }\
}' > /etc/nginx/conf.d/default.conf

COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
