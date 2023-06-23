#!/usr/bin/env bash
set -euo pipefail

# Set cookie file permissions to only be accessible by the owner
chmod 400 /var/lib/rabbitmq/.erlang.cookie

# Fallback to the regular RabbitMQ Docker entrypoint script
/usr/local/bin/docker-entrypoint.sh rabbitmq-server
