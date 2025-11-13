#!/bin/bash

# This script orchestrates the entire Docker setup and wait process.
# It discovers the network of the container it's running in,
# launches the SQL container on that same network, and then
# waits until the database is ready for connections.
#
# It exits with code 0 on success and 1 on failure.

# Exit immediately if any command fails.
set -e

# --- Read and Validate Parameters ---
SQL_CONTAINER_NAME="$1"
SQL_IMAGE="$2"
SQL_PASSWORD="$3"
SQL_USER="SA" # The user is always SA for this setup

if [ -z "$SQL_CONTAINER_NAME" ] || [ -z "$SQL_IMAGE" ] || [ -z "$SQL_PASSWORD" ]; then
  echo "❌ Error: Missing arguments."
  echo "   Usage: $0 <container_name> <image_name> <sa_password>"
  exit 1
fi

# --- Step 1: Discover Network and Print Debug Info ---
echo "--- Discovering Network Information ---"
# Get the ID/hostname of the current (builder) container.
MY_CONTAINER_ID=$(hostname)

# Inspect this container to find the name of the network it is attached to.
# The Go template is quoted to be safe for the shell.
MY_NETWORK_NAME=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$MY_CONTAINER_ID")

echo "Builder Container ID:   $MY_CONTAINER_ID"
echo "Attaching SQL container to Network: $MY_NETWORK_NAME"
echo "-------------------------------------"


# --- Step 2: Start the SQL Container on the Discovered Network ---
echo "--- Starting SQL container '$SQL_CONTAINER_NAME' ---"
docker run -d \
  --name "$SQL_CONTAINER_NAME" \
  --network="$MY_NETWORK_NAME" \
  -e ACCEPT_EULA=Y \
  -e SA_PASSWORD="$SQL_PASSWORD" \
  "$SQL_IMAGE"

# --- Step 3: Wait for the SQL Container to be Ready ---
echo "--- Waiting for SQL Server to be ready for connections ---"
# Initial sleep to allow the container to start its boot process.
sleep 15

# Loop and attempt a real connection using sqlcmd.
for i in {1..30}; do
  echo "⏳ Attempting connection to '$SQL_CONTAINER_NAME' ($i/30)..."
  # The hostname for the connection (-S) is the container name, because they are on the same network.
  if sqlcmd -S "$SQL_CONTAINER_NAME" -U "$SQL_USER" -P "$SQL_PASSWORD" -l 5 -b -Q "SELECT 1" &>/dev/null; then
    echo "✅ SQL Server is ready."
    exit 0 # Success!
  fi
  sleep 5
done

# --- Step 4: Handle Failure ---
echo "❌ SQL Server on container '$SQL_CONTAINER_NAME' did not become ready in time."
echo "--- Displaying last logs from container for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1
