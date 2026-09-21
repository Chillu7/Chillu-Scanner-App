FROM ubuntu:24.04 AS build

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

RUN git clone --depth 1 --branch 3.47.1 \
    https://github.com/flutter/flutter.git

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"

# Disable Flutter analytics
RUN flutter config --no-analytics

# Pre-cache the web SDK
RUN flutter precache --web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./

# Fix ownership problems caused by Flutter's Gradle wrapper download
RUN mkdir -p /opt/flutter/bin/cache/artifacts/gradle_wrapper && \
    chmod -R 777 /opt/flutter/bin/cache

RUN flutter pub get

COPY . .

RUN flutter build web --release --no-wasm-dry-run


FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]