# =========================
# BUILD STAGE
# =========================
FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ca-certificates \
    tar \
    && rm -rf /var/lib/apt/lists/*

# Create normal user
RUN groupadd -g 1000 flutter \
    && useradd -m -u 1000 -g 1000 flutter

# Install Flutter
WORKDIR /opt

RUN git clone --depth 1 --branch 3.47.1 \
    https://github.com/flutter/flutter.git

RUN chown -R flutter:flutter /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"

# Use non-root user
USER flutter

# Check Flutter
RUN flutter --version

# Project
WORKDIR /app

# Copy project
COPY --chown=flutter:flutter . .

# Remove native platforms temporarily.
# We are building WEB only.
RUN rm -rf android ios macos windows linux

# Get Dart/Flutter dependencies
RUN flutter pub get

# Build Flutter Web
RUN flutter build web --release


# =========================
# PRODUCTION STAGE
# =========================
FROM nginx:alpine

# Copy Flutter web output
COPY --from=build /app/build/web /usr/share/nginx/html

# Render uses PORT 10000 by default
RUN sed -i 's/listen       80;/listen       10000;/' /etc/nginx/conf.d/default.conf

EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]