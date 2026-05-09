#!/bin/bash
set -e

# deploy.sh — Deploy Cuttlefish to a provisioned server.
#
# Usage:
#   ./deploy.sh <server-ip-or-hostname>
#
# The server must already be provisioned with provision_production.sh.
# This script SSHes as the deploy user (whose SSH key was authorized during provisioning).
#
# On first run, it clones the repo; on subsequent runs, it pulls latest code.

REMOTE_HOST="${1:-}"
if [ -z "$REMOTE_HOST" ]; then
  echo "Usage: $0 <server-hostname-or-ip>"
  echo "Example: $0 67.219.102.201"
  exit 1
fi

REPO_URL="https://github.com/PIPE-Project/cuttlefish.git"
APP_DIR="/srv/www"
RVM="/usr/local/lib/rvm/bin/rvm"

echo "==> Deploying Cuttlefish to $REMOTE_HOST"

ssh "deploy@$REMOTE_HOST" bash -s << ENDSSH
set -e

APP_DIR="$APP_DIR"
REPO_URL="$REPO_URL"
RVM="$RVM"

if [ ! -d "\$APP_DIR/current/.git" ]; then
  echo "=== First deploy: cloning repository ==="
  git clone "\$REPO_URL" "\$APP_DIR/current"
fi

cd "\$APP_DIR/current"

echo "=== Pulling latest code ==="
git pull

echo "=== Linking shared config files ==="
mkdir -p tmp log
ln -sf "\$APP_DIR/shared/.env" .env
ln -sf "\$APP_DIR/shared/database.yml" config/database.yml

echo "=== Installing gems ==="
"\$RVM" . do bundle install --without development test

echo "=== Running migrations ==="
"\$RVM" . do bundle exec rake db:migrate RAILS_ENV=production

echo "=== Precompiling assets ==="
"\$RVM" . do bundle exec rake assets:precompile RAILS_ENV=production

echo "=== Restarting app (Passenger reads tmp/restart.txt) ==="
touch tmp/restart.txt

echo "=== Reloading nginx ==="
sudo service nginx reload

echo "=== Done! ==="
ENDSSH

echo "==> Deploy complete!"
