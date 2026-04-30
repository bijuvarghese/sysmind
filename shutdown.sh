#!/bin/bash
set -euo pipefail

echo "Checking if Docker is running..."
if ! docker info > /dev/null 2>&1; then
  echo "Docker is not running. Starting Docker Desktop..."
  open -a Docker
  echo "Waiting for Docker to start..."
  while ! docker info > /dev/null 2>&1; do
    sleep 2
  done
  echo "Docker is now running."
fi

echo "Shutting down Docker Compose services..."
docker compose down --remove-orphans

echo "Shutdown complete!"
