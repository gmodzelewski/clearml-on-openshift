#!/bin/bash
set -e

echo "🔧 ClearML OpenShift Cache Permission Fix - Setting up writable cache..."

# Create writable cache directory
mkdir -p /tmp/clearml-cache
chmod 755 /tmp/clearml-cache

# Create writable cache file
touch /tmp/clearml-cache/_cache.json
chmod 666 /tmp/clearml-cache/_cache.json

# Set proper ownership (if possible)
chown $(id -u):$(id -g) /tmp/clearml-cache/_cache.json 2>/dev/null || true

echo "✅ Cache permission setup completed!"
echo "📁 Created writable cache at: /tmp/clearml-cache/_cache.json"

# List cache directory for verification
ls -la /tmp/clearml-cache/ || true 