#!/bin/sh

echo "🧹 Cleaning environment..."
docker compose down --volumes --remove-orphans
docker system prune --all --force --volumes