# ===================================================
# Stage 1: Build Stage
# ===================================================
FROM node:22-alpine AS builder

# Install system dependencies, build tools, and git for cloning the repository
RUN apk update && \
    apk add --no-cache \
        libc6-compat \
        python3 \
        make \
        g++ \
        build-base \
        cairo-dev \
        pango-dev \
        chromium \
        git \
        curl && \
    npm install -g pnpm

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
ENV NODE_OPTIONS=--max-old-space-size=8192

WORKDIR /usr/src/flowise

# Clone the official Flowise repository at the specific version tag (flowise@3.1.2)
RUN git clone --depth 1 --branch flowise@3.1.2 https://github.com/FlowiseAI/Flowise.git .

# Install dependencies and build (excluding sdk packages not needed for Docker)
RUN pnpm install && \
    pnpm build:docker

# Remove development dependencies to reduce image size
RUN pnpm prune --prod


# ===================================================
# Stage 2: Runner Stage (Final Image)
# ===================================================
FROM node:22-alpine AS runner

# Install minimal runtime dependencies needed for execution (git is not needed here)
RUN apk update && \
    apk add --no-cache \
        libc6-compat \
        cairo \
        pango \
        chromium \
        curl && \
    npm install -g pnpm

# Install mcp-remote globally as requested
RUN npm install -g mcp-remote

ENV PUPPETEER_SKIP_DOWNLOAD=true
ENV PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser

WORKDIR /usr/src/flowise

# Copy built artifacts and production dependencies from the builder stage
COPY --from=builder /usr/src/flowise ./

# Give the node user ownership of the application files
RUN chown -R node:node .

# Switch to non-root user (node user already exists in node:22-alpine)
USER node

EXPOSE 3000

CMD [ "pnpm", "start" ]