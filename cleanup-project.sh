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

echo "Removing SysMind Compose services, networks, anonymous volumes, and locally built images..."
docker compose down --volumes --rmi local --remove-orphans

echo "Project cleanup complete!"
