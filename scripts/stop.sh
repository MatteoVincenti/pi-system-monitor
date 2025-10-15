#!/bin/bash
set -e

# Determine the script's directory
SCRIPT_DIR=$(dirname "$(realpath "$0")")
PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

# Function to check if a service is running
is_service_running() {
  docker ps --filter "name=$1" --filter "status=running" | grep -q "$1"
}

# Function to stop a service if it is running
stop_service_if_running() {
  service_name=$1
  compose_file=$2
  if is_service_running "$service_name"; then
    docker compose -f "$compose_file" down
  else
    echo "$service_name is not running."
  fi
}

# Main script logic
echo "Stopping all services..."
docker compose -f $PROJECT_ROOT/docker-compose.yaml down

# Optional services are now managed through docker-compose.optional.yml
# Use ./scripts/deploy.sh stop to stop all services including optional ones

echo "Shutdown complete."