#!/bin/bash
set -euo pipefail

if [ "${1:-}" != "--force" ]; then
  echo "This script stops and removes every Docker container, then prunes unused Docker images, networks, and volumes."
  echo "Run './cleanup-docker-global.sh --force' if you really want global Docker cleanup."
  exit 1
fi

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

echo "Stopping and removing all Docker containers..."
if [ "$(docker ps -aq)" ]; then
  docker stop $(docker ps -aq)
  docker rm -f $(docker ps -aq)
fi

echo "Removing unused Docker networks, images, and volumes..."
docker system prune -af --volumes

echo "Global Docker cleanup complete!"
