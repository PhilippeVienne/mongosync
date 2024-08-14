#!/bin/bash

set -e

# This script is used to migrate the data from one server to another server
# using mongosync tool.

# Set the source and destination server details
if [ -z "$MONGODB_CLUSTER0" ]; then
  # Try to get cluster0 from /mnt/secrets/cluster0
    if [ -f /mnt/secrets/cluster0 ]; then
        MONGODB_CLUSTER0=$(cat /mnt/secrets/cluster0)
    else
        echo "MONGODB_CLUSTER0 is not set"
        exit 1
    fi
fi

if [ -z "$MONGODB_CLUSTER1" ]; then
  # Try to get cluster1 from /mnt/secrets/cluster1
    if [ -f /mnt/secrets/cluster1 ]; then
        MONGODB_CLUSTER1=$(cat /mnt/secrets/cluster1)
    else
        echo "MONGODB_CLUSTER1 is not set"
        exit 1
    fi
fi

# Write migration configuration file
cat <<EOF > /tmp/migrate.yaml
cluster0: $MONGODB_CLUSTER0
cluster1: $MONGODB_CLUSTER1
verbosity: ${MIGRATE_VERBOSITY:-"WARN"}
disableTelemetry: ${MIGRATE_DISABLE_TELEMETRY:-true}
loadLevel: ${MIGRATE_LOAD_LEVEL:-"3"}
port: ${MIGRATE_PORT:-"27182"}
EOF

# Start NGINX in the background if NGINX_ENABLED
if [ "$NGINX_ENABLED" == "true" ]; then
    echo "Starting NGINX"
    nginx -g "daemon off;" &
    NGINX_PID=$!
    trap "kill $NGINX_PID" EXIT
fi

mongosync --config /tmp/migrate.yaml &

MONGOSYNC_PID=$!

trap "kill $MONGOSYNC_PID" EXIT

echo "Waiting for mongosync to start"

while true; do
  if curl -s http://localhost:${MIGRATE_PORT:-"27182"}/api/v1/progress > /dev/null; then
    progress=$(curl -s http://localhost:${MIGRATE_PORT:-"27182"}/api/v1/progress | jq -r '.progress')
    state=$(echo $progress | jq -r '.state')
    if [ "$state" == "IDLE" ]; then
        echo "Waiting for migration to start, you can run ' curl -X POST http://localhost:${MIGRATE_PORT:-"27182"}/api/v1/start -H \"Content-Type: application/json\" -d '{\"source\": \"cluster0\",\"destination\": \"cluster1\", \"enableUserWriteBlocking\": true}' ' to start the migration"
    fi
    if [ "$state" == "COMMITTED" ]; then
        echo "Migration has already been completed"
    fi
    if [ "$state" == "RUNNING" ]; then
        echo "Migration is progressing"
        echo "Migration progress: $(echo $progress | jq -r '.state') - $(echo $progress | jq -r '.info')"
        canCommit=$(echo $progress | jq -r '.canCommit')
        if [ "$canCommit" == "true" ]; then
            echo "Migration can be committed, you can run ' curl -X POST http://localhost:${MIGRATE_PORT:-"27182"}/api/v1/commit -d '{}' ' to commit the migration"
        fi
    fi
    if [ "$state" == "COMMITTING" ]; then
        echo "Migration is committing"
        echo "Migration progress: $(echo $progress | jq -r '.state') - $(echo $progress | jq -r '.info')"
    fi
    if [ "$state" == "PAUSED" ]; then
        echo "Migration is paused"
        echo "Migration progress: $(echo $progress | jq -r '.state') - $(echo $progress | jq -r '.info')"
    fi
  else
    echo "Waiting for mongosync to start (note that it may take a few minutes to start on retries)"
  fi
  sleep 1
done


