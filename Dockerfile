FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
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

# Install Flutter 3.47.1
WORKDIR /opt

RUN git clone --depth 1 --branch 3.47.1 \
    https://github.com/flutter/flutter.git

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"

# Flutter configuration
RUN flutter config --enable-web
RUN flutter config --no-analytics

# Project
WORKDIR /app

# Copy project
COPY . .

# We only need Web for this Render deployment
RUN rm -rf android ios macos windows linux

# Get dependencies
RUN flutter pub get

# Build Web
RUN flutter build web --release


# =========================
# NGINX
# =========================

FROM nginx:alpine

# Copy Flutter Web build
COPY --from=build /app/build/web /usr/share/nginx/html

# Configure Nginx for Render
RUN sed -i 's/listen       80;/listen       10000;/' /etc/nginx/conf.d/default.conf

EXPOSE 10000

CMD ["nginx", "-g", "daemon off;"]