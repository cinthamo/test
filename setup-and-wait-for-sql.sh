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
docker run -d \
  --name "$SQL_CONTAINER_NAME" \
  --network="$MY_NETWORK_NAME" \
  -e ACCEPT_EULA=Y \
  -e SA_PASSWORD="$SQL_PASSWORD" \
  -p 1433:1433 \
  "$SQL_IMAGE"

# --- Step 3: Wait and Diagnose ---
echo "--- Waiting for SQL Server to be ready at '$SQL_CONTAINER_NAME' ---"
sleep 20

# --- Step 4: Attempt SQL Connection & CAPTURE OUTPUT ---
SQLCMD_PATH="/opt/mssql-tools18/bin/sqlcmd"
echo "--- Connecting with sqlcmd ---"
for i in {1..10}; do
  echo "⏳ Attempting SQL connection to '$SQL_CONTAINER_NAME' ($i/10)..."
  
  if $SQLCMD_PATH -S "$SQL_CONTAINER_NAME" -U "$SQL_USER" -P "$SQL_PASSWORD" -C -l 10 -b -Q "SELECT 1" > /tmp/sqlcmd.log 2>&1; then
    echo "✅ SQL Server is ready."
    SQL_IP_ADDRESS=$(docker inspect -f "{{.NetworkSettings.Networks.$MY_NETWORK_NAME.IPAddress}}" "$SQL_CONTAINER_NAME")
    echo "$SQL_IP_ADDRESS"
    exit 0
  fi
  
  echo "--- sqlcmd output from last attempt: ---"
  cat /tmp/sqlcmd.log
  echo "----------------------------------------"
  sleep 5
done

# --- Step 5: Handle Failure ---
echo "❌ SQL Server on container '$SQL_CONTAINER_NAME' did not become ready in time."
echo "--- Final sqlcmd output: ---"
cat /tmp/sqlcmd.log
echo "--- Displaying last logs from container for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1
