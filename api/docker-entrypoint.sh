#!/bin/bash
set -e

# Cache configuration, routes, and views for speed in production
echo "Running Laravel optimizations..."
php artisan config:cache || true
php artisan route:cache || true
php artisan view:cache || true

# Run database migrations automatically when server boots
echo "Running database migrations..."
php artisan migrate --force || true

echo "Starting Apache Web Server..."
exec apache2-foreground
