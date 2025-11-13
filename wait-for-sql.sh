#!/bin/bash

# --- Read input arguments ---
SQL_CONTAINER_NAME="$1"
SQL_USER="$2"
SQL_PASSWORD="$3"

# --- Validate arguments ---
if [ -z "$SQL_CONTAINER_NAME" ] || [ -z "$SQL_USER" ] || [ -z "$SQL_PASSWORD" ]; then
  echo "❌ Error: Missing arguments."
  echo "   Usage: $0 <container_name> <user> <password>"
  exit 1
fi

echo "--- Waiting for SQL Server in container '$SQL_CONTAINER_NAME' to be ready for connections ---"

# Give the container a generous amount of time to initialize before we start polling.
# SQL Server can take a while to create system databases on the first run.
echo "⏳ Initial sleep (15s) for container initialization..."
sleep 15

# --- Poll the database with sqlcmd ---
# This loop runs from the CALLING container (your 'builder') and connects to the SQL container by name.
for i in {1..30}; do
  echo "⏳ Attempting connection ($i/30)..."
  
  # Use sqlcmd to attempt a real login and query.
  # -S: The server name, which is the other container's name. This tests the Docker network.
  # -l 5: Set a login timeout of 5 seconds to fail fast.
  # -b: On error, exit with a non-zero status code, which makes the 'if' statement work.
  # &>/dev/null: Suppress command output unless it fails.
  if sqlcmd -S "$SQL_CONTAINER_NAME" -U "$SQL_USER" -P "$SQL_PASSWORD" -l 5 -b -Q "SELECT 1" &>/dev/null; then
    echo "✅ SQL Server is ready to accept connections."
    exit 0 # Success
  fi
  
  # Wait 5 seconds before the next attempt
  sleep 5
done

# --- Failure Condition ---
echo "❌ SQL Server on container '$SQL_CONTAINER_NAME' did not become ready in time."
echo "--- Displaying last logs from SQL container for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1 # Failure
