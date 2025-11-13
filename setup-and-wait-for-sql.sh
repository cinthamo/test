#!/bin/bash
set -e

# --- Read and Validate Parameters ---
SQL_CONTAINER_NAME="$1"
SQL_IMAGE="$2"
SQL_PASSWORD="$3"
SQL_USER="SA"

if [ -z "$SQL_CONTAINER_NAME" ] || [ -z "$SQL_IMAGE" ] || [ -z "$SQL_PASSWORD" ]; then
  echo "❌ Error: Missing arguments."
  echo "   Usage: $0 <container_name> <image_name> <sa_password>"
  exit 1
fi

# --- Step 1: Discover Network ---
echo "--- Discovering Network Information ---"
MY_CONTAINER_ID=$(hostname)
MY_NETWORK_NAME=$(docker inspect --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}' "$MY_CONTAINER_ID")
echo "Builder Container ID:   $MY_CONTAINER_ID"
echo "Target Network:         $MY_NETWORK_NAME"
echo "-------------------------------------"

# --- Step 2: Start the SQL Container ---
echo "--- Starting SQL container '$SQL_CONTAINER_NAME' on network '$MY_NETWORK_NAME' ---"
docker run -d --rm \
  --name "$SQL_CONTAINER_NAME" \
  --network="$MY_NETWORK_NAME" \
  -e ACCEPT_EULA=Y \
  -e SA_PASSWORD="$SQL_PASSWORD" \
  "$SQL_IMAGE"

# --- Step 3: Get the SQL Container's IP Address ---
echo "--- Discovering SQL Container's IP Address ---"

FORMAT_STRING="{{.NetworkSettings.Networks.$MY_NETWORK_NAME.IPAddress}}"
SQL_IP_ADDRESS=$(docker inspect --format="$FORMAT_STRING" "$SQL_CONTAINER_NAME")

if [ -z "$SQL_IP_ADDRESS" ]; then
    echo "❌ CRITICAL ERROR: Could not find the IP address for '$SQL_CONTAINER_NAME' on network '$MY_NETWORK_NAME'."
    echo "--- Full container inspection for debugging: ---"
    docker inspect "$SQL_CONTAINER_NAME"
    exit 1
fi
echo "SQL Container IP:       $SQL_IP_ADDRESS"
echo "------------------------------------------"

# --- Step 4: Wait for the SQL Container to be Ready using its IP ---
echo "--- Waiting for SQL Server to be ready at $SQL_IP_ADDRESS ---"
sleep 15

for i in {1..30}; do
  echo "⏳ Attempting connection to '$SQL_IP_ADDRESS' ($i/30)..."
  if sqlcmd -S "$SQL_IP_ADDRESS" -U "$SQL_USER" -P "$SQL_PASSWORD" -l 5 -b -Q "SELECT 1" &>/dev/null; then
    echo "✅ SQL Server is ready."
    echo "$SQL_IP_ADDRESS"
    exit 0
  fi
  sleep 5
done

# --- Step 5: Handle Failure ---
echo "❌ SQL Server on container '$SQL_CONTAINER_NAME' did not become ready in time."
echo "--- Displaying last logs from container for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1
