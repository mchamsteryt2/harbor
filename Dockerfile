# Stage 1: Build the app assets
FROM node:22-alpine AS builder
WORKDIR /app
RUN apk add --no-cache git libc6-compat openssh-client && npm install -g pnpm
COPY package*.json pnpm-lock.yaml* ./
COPY . .
RUN pnpm install --frozen-lockfile && pnpm run build

# Stage 2: Serve the frontend and inject the connection logic
FROM nginx:alpine

# CRITICAL: This script forces the browser to connect back to the streaming engine
# via the shared VPS proxy address, meaning your friends don't have to configure anything.
RUN echo '<script>\
  if (!localStorage.getItem("harbor_streaming_server")) {\
    const streamUrl = window.location.protocol + "//" + window.location.hostname + ":11470";\
    localStorage.setItem("harbor_streaming_server", streamUrl);\
  }\
</script>' > /usr/share/nginx/html/inject.html

# Inject the discovery script right inside Harbor's entry <head>
RUN sed -i '/<head>/r /usr/share/nginx/html/inject.html' /usr/share/nginx/html/index.html

COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
