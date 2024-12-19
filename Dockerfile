# syntax = docker/dockerfile:1

# Adjust BUN_VERSION as desired
ARG BUN_VERSION=1.1.26
FROM oven/bun:${BUN_VERSION}-slim AS base

# Bun app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build node modules, including pixman-1, cairo, and node-pre-gyp dependencies
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
    librsvg2-dev

# Install node-pre-gyp globally
RUN bun add -g node-pre-gyp

RUN bun add -g playwright@1.48.2
RUN bunx playwright install --with-deps chromium

# Copy both package files first
COPY package.json bun.lockb ./

RUN bun install sharp --arch=arm64 --platform=linux

# Use --frozen-lockfile to ensure exact versions are installed
RUN bun install

# Copy application code
COPY . .

# Final stage for app image
FROM base

# Copy built application
COPY --from=build /app /app

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD [ "bun", "run", "start" ]