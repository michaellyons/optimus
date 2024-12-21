# syntax = docker/dockerfile:1

# Adjust BUN_VERSION as desired
ARG BUN_VERSION=1.1.26
FROM oven/bun:${BUN_VERSION}-slim AS base

# Bun app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# Install packages needed to build node modules, including pixman-1, cairo, and node-pre-gyp dependencies
# Also install the missing shared libraries required by Playwright's Chromium
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    pkg-config \
    python-is-python3 \
    libpixman-1-dev \
    libcairo2-dev \
    libjpeg-dev \
    libpango1.0-dev \
    libgif-dev \
    librsvg2-dev \
    libglib2.0-0 \
    libnss3 \
    libnspr4 \
    libatk1.0-0 \
    libatk-bridge2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxrandr2 \
    libgbm1 \
    libpango-1.0-0 \
    libcairo-gobject2 \
    libatspi2.0-0

# Install node-pre-gyp globally
RUN bun add -g node-pre-gyp

# Install playwright and log the installation directory
RUN bun add -g playwright@1.48.2 && \
    bunx playwright install --with-deps chromium && \
    echo "Listing installation directories:" && \
    ls -la /root/.cache/ms-playwright/ && \
    ls -la /root/.cache/ms-playwright/chromium-*/ && \
    ls -la /root/.cache/ms-playwright/chromium-*/chrome-linux/

# Copy the necessary Playwright browsers to the /app directory to align with the expected path in src/index.ts
RUN mkdir -p /app/.cache/ms-playwright && \
    cp -r /root/.cache/ms-playwright/* /app/.cache/ms-playwright/

# Copy both package files first
COPY package.json bun.lockb ./

# Install sharp with specific architecture and platform
RUN bun install sharp --arch=arm64 --platform=linux

# Use --frozen-lockfile to ensure exact versions are installed
RUN bun install

# Copy application code
COPY . .

# Final stage for app image
FROM base AS production

# Copy built application and the .cache directory containing the Chrome executable
# Set the PLAYWRIGHT_BROWSERS_PATH environment variable to point to the copied browsers
ENV PLAYWRIGHT_BROWSERS_PATH=/app/.cache/ms-playwright
COPY --from=base /app /app

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD [ "bun", "run", "start" ]