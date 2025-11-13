#!/bin/bash
set -e

# --- Function to Install SQLCMD if it's not present ---
install_sqlcmd_if_needed() {
  # The full path to the sqlcmd executable
  local SQLCMD_PATH="/opt/mssql-tools18/bin/sqlcmd"

  # Check if the command already exists
  if [ -f "$SQLCMD_PATH" ]; then
    echo "✅ mssql-tools18 (sqlcmd) is already installed."
    return 0
  fi

  echo "--- Installing mssql-tools18 ---"
  # Non-interactive frontend to prevent prompts during installation
  export DEBIAN_FRONTEND=noninteractive
  
  apt-get update
  apt-get install -y curl apt-transport-https gnupg
  
  # Add Microsoft repository key
  curl -sSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft.gpg
  
  # Add Microsoft repository
  echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/debian/12/prod bookworm main" > /etc/apt/sources.list.d/mssql-release.list
  
  apt-get update
  
  # Install the tools, accepting the EULA
  ACCEPT_EULA=Y apt-get install -y mssql-tools18 unixodbc-dev
  
  echo "✅ mssql-tools18 installation complete."
}


# --- Main script execution starts here ---

# Step 0: Ensure SQLCMD is installed
install_sqlcmd_if_needed

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
sleep 5

# --- Step 4: Attempt SQL Connection ---
SQLCMD_PATH="/opt/mssql-tools18/bin/sqlcmd"
echo "--- Connecting with sqlcmd ---"
for i in {1..10}; do
  echo "⏳ Attempting SQL connection to '$SQL_CONTAINER_NAME' ($i/10)..."
  
  if $SQLCMD_PATH -S "$SQL_CONTAINER_NAME" -U "$SQL_USER" -P "$SQL_PASSWORD" -C -l 10 -b -Q "SELECT 1" > /tmp/sqlcmd.log 2>&1; then
    echo "✅ SQL Server is ready."
    exit 0
  fi
  
  echo "--- sqlcmd output from last attempt: ---"
  cat /tmp/sqlcmd.log
  echo "----------------------------------------"
  sleep 5
done

# --- Step 5: Handle Failure ---
echo "❌ SQL Server on container '$SQL_CONTAINER_NAME' did not become ready in time."
echo "--- Displaying last logs from container for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1
