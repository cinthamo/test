#!/bin/bash
set -e # Exit immediately if a command fails

# The container name is passed as the first argument from MSBuild
SQL_CONTAINER_NAME=$1

if [ -z "$SQL_CONTAINER_NAME" ]; then
  echo "❌ Error: SQL Container Name was not provided."
  exit 1
fi

echo "⏳ Initial sleep (10s)..."
sleep 10

i=1
while [ $i -le 30 ]; do
  # Check if the port is open inside the container
  if docker exec "$SQL_CONTAINER_NAME" bash -c "timeout 1 bash -c '</dev/tcp/localhost/1433'" &>/dev/null; then
    echo "✅ SQL Server port 1433 is open"
    exit 0 # Success
  fi
  
  echo "⏳ Waiting for SQL Server to start ($i/30)..."
  sleep 2
  i=$((i + 1))
done

echo "❌ SQL Server did not start in time"
docker logs "$SQL_CONTAINER_NAME"
exit 1 # Failure
