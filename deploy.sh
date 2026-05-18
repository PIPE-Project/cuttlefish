#!/bin/bash
set -e

# deploy.sh — Deploy Cuttlefish to a provisioned server.
#
# Usage:
#   ./deploy.sh <server-ip-or-hostname> [identity-file]
#
# The server must already be provisioned with provision_production.sh.
# This script SSHes as the deploy user (whose SSH key was authorized during provisioning).
# Optionally pass the path to your SSH private key as the second argument;
# otherwise it falls back to your SSH config / agent.
#
# On first run, it clones the repo; on subsequent runs, it pulls latest code.

REMOTE_HOST="${1:-}"
SSH_KEY="${2:-}"
if [ -z "$REMOTE_HOST" ]; then
  echo "Usage: $0 <server-hostname-or-ip> [identity-file]"
  echo "Example: $0 139.84.202.95 ~/.ssh/my_key"
  exit 1
fi

SSH_OPTS="-o StrictHostKeyChecking=accept-new"
if [ -n "$SSH_KEY" ]; then
  SSH_OPTS="$SSH_OPTS -i $SSH_KEY"
fi

REPO_URL="https://github.com/PIPE-Project/cuttlefish.git"
BRANCH="feature/modernise"
APP_DIR="/srv/www"
RVM="/usr/local/lib/rvm/bin/rvm"

echo "==> Deploying Cuttlefish to $REMOTE_HOST"

ssh $SSH_OPTS "deploy@$REMOTE_HOST" bash -s << ENDSSH
set -e

APP_DIR="$APP_DIR"
REPO_URL="$REPO_URL"
BRANCH="$BRANCH"
RVM="$RVM"

if [ ! -d "\$APP_DIR/current/.git" ]; then
  echo "=== First deploy: cloning repository ==="
  git clone --branch "\$BRANCH" "\$REPO_URL" "\$APP_DIR/current"
fi

cd "\$APP_DIR/current"

echo "=== Pulling latest code ==="
git fetch origin
git checkout "\$BRANCH"
git pull origin "\$BRANCH"

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
