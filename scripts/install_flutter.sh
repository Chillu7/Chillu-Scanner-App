#!/bin/bash

set -e

FLUTTER_VERSION="3.47.1"
FLUTTER_DIR="$HOME/flutter"

echo "Installing Flutter $FLUTTER_VERSION..."

git clone https://github.com/flutter/flutter.git \
  --depth 1 \
  --branch $FLUTTER_VERSION \
  "$FLUTTER_DIR"

export PATH="$FLUTTER_DIR/bin:$PATH"

echo "Flutter version:"
flutter --version

echo "Enabling Flutter Web..."
flutter config --enable-web

echo "Downloading Flutter Web dependencies..."
flutter precache --web

echo "Getting project dependencies..."
flutter pub get

echo "Building Flutter Web..."
flutter build web --release

echo "Flutter Web build completed successfully!"