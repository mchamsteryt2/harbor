# Stage 1: Build the app assets
FROM node:22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git libc6-compat openssh-client && npm install -g pnpm
COPY package*.json pnpm-lock.yaml* ./
COPY . .
RUN pnpm install --frozen-lockfile && pnpm run build

# Stage 2: Serve the frontend and default to internal engine discovery
FROM nginx:alpine

# Forces the browser frontend instance to look natively at your local compose proxy route
RUN echo '<script>\
  if (!localStorage.getItem("harbor_streaming_server")) {\
    localStorage.setItem("harbor_streaming_server", "http://torrent-engine:11470");\
  }\
</script>' > /usr/share/nginx/html/inject.html

# Inject the discovery script right inside Harbor's entry <head>
RUN sed -i '/<head>/r /usr/share/nginx/html/inject.html' /usr/share/nginx/html/index.html

COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
