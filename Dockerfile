# Stage 1: Install dependencies and build the app assets
FROM node:22-alpine AS builder
WORKDIR /app

# Install git, shell utilities, and system configurations required for pnpm hooks
RUN apk add --no-cache git libc6-compat openssh-client

# Install the package manager globally inside the builder container
RUN npm install -g pnpm

# Copy package descriptors and lockfile first to leverage Docker build cache layers
COPY package*.json pnpm-lock.yaml* ./

# Copy the rest of the application files
COPY . .

# Run the package installer safely now that git is present
RUN pnpm install --frozen-lockfile

# Compile the production distribution bundle
RUN pnpm run build

# Stage 2: Serve the compiled web output via a lightweight web server node
FROM nginx:alpine
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
