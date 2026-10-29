#!/bin/sh

echo "🧹 Cleaning environment..."
docker compose down --volumes --remove-orphans
docker system prune --all --force --volumes

echo "🔨 Building fresh image..."
docker compose pull web

echo "🚀 Starting services..."
docker compose up -d