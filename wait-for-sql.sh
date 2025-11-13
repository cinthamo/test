#!/bin/bash

# --- Read input arguments ---
SQL_HOSTNAME="$1"
SQL_CONTAINER_NAME="$2"
SQL_USER="$3"
SQL_PASSWORD="$4"

# --- Validate arguments ---
if [ -z "$SQL_HOSTNAME" ] || [ -z "$SQL_CONTAINER_NAME" ] || [ -z "$SQL_USER" ] || [ -z "$SQL_PASSWORD" ]; then
  echo "❌ Error: Missing arguments."
  echo "   Usage: $0 <hostname> <container_name> <user> <password>"
  exit 1
fi

echo "--- Waiting for SQL Server on host '$SQL_HOSTNAME' (from container '$SQL_CONTAINER_NAME') ---"
echo "⏳ Initial sleep (15s)..."
sleep 15

# --- Poll the database with sqlcmd ---
for i in {1..30}; do
  echo "⏳ Attempting connection to '$SQL_HOSTNAME' ($i/30)..."
  
  # Connect to the HOSTNAME provided
  if sqlcmd -S "$SQL_HOSTNAME" -U "$SQL_USER" -P "$SQL_PASSWORD" -l 5 -b -Q "SELECT 1" &>/dev/null; then
    echo "✅ SQL Server is ready to accept connections."
    exit 0 # Success
  fi
  
  sleep 5
done

# --- Failure Condition ---
echo "❌ SQL Server on host '$SQL_HOSTNAME' did not become ready in time."
echo "--- Displaying last logs from container '$SQL_CONTAINER_NAME' for debugging ---"
docker logs "$SQL_CONTAINER_NAME"
exit 1 # Failure
