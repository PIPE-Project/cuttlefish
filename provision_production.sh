#!/bin/bash

# Error handler to show what went wrong
error_handler() {
    echo "ERROR: Command failed at line $1" >&2
    echo "Failed command: $2" >&2
    exit 1
}

# Set up error trapping
set -e
set -E
trap 'error_handler ${LINENO} "$BASH_COMMAND"' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# as per .gitignore's recommendation
VENV_DIR="$SCRIPT_DIR/.ansible"
PROVISIONING_DIR="$SCRIPT_DIR/provisioning"

case "$1" in
clobber)
  echo "Clobbering .ansible virtualenv and imported roles ..."
  rm -rf "${VENV_DIR}" \
  "${PROVISIONING_DIR}/roles/newrelic.newrelic-infra" \
  "${PROVISIONING_DIR}/roles/rvm.ruby" \
  "${PROVISIONING_DIR}/roles/geerlingguy.certbot" \
  "${PROVISIONING_DIR}/roles/DavidWittman.redis" \
  "${PROVISIONING_DIR}/roles/ANXS.postgresql" \
  "${PROVISIONING_DIR}/roles/abtris.nginx-passenger" \
  "${PROVISIONING_DIR}/roles/nickhammond.logrotate"
  exit
  ;;
esac
# Find python — prefer python3, fall back to python, then try $LOCALAPPDATA (Windows Git Bash)
PYTHON=$(command -v python3 2>/dev/null)
if [ -z "$PYTHON" ] || ! "$PYTHON" --version &>/dev/null 2>&1; then
    PYTHON=$(command -v python 2>/dev/null)
fi
if [ -z "$PYTHON" ] || ! "$PYTHON" --version &>/dev/null 2>&1; then
    if [ -n "$LOCALAPPDATA" ]; then
        WIN_PYTHON=$(cygpath -u "$LOCALAPPDATA" 2>/dev/null || echo "$LOCALAPPDATA" | sed 's|\\|/|g; s|^\([A-Za-z]\):|/\L\1|')
        PYTHON="$WIN_PYTHON/Programs/Python/Python312/python"
    fi
fi
if [ -z "$PYTHON" ] || ! "$PYTHON" --version &>/dev/null 2>&1; then
    echo "ERROR: No working python found. On Windows, run from WSL or use the server-side approach." >&2
    exit 1
fi

# Create and activate virtual environment if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment in .ansible/"
    "$PYTHON" -m venv "$VENV_DIR"
fi

# Activate virtual environment
source "$VENV_DIR/Scripts/activate" 2>/dev/null || source "$VENV_DIR/bin/activate"

# Install/upgrade ansible if needed
ANSIBLE_BIN="$VENV_DIR/Scripts/ansible-playbook"
[ -f "$ANSIBLE_BIN" ] || ANSIBLE_BIN="$VENV_DIR/bin/ansible-playbook"
if ! pip show ansible &>/dev/null || [ "$ANSIBLE_BIN" -ot "$PROVISIONING_DIR/requirements.txt" ]; then
    echo "Installing Ansible from requirements.txt"
    pip install -r "$PROVISIONING_DIR/requirements.txt"
fi

# Install roles if needed
if [ ! -d "$PROVISIONING_DIR/roles/DavidWittman.redis" ]; then
    echo "Installing Ansible roles"
    ansible-galaxy install -r "$PROVISIONING_DIR/requirements.yml" -p "$PROVISIONING_DIR/roles"
fi

# Build extra arguments
extra_args=''

# Vault support: if .vault_pass exists, use it automatically
if [ -f "$SCRIPT_DIR/.vault_pass" ]; then
    extra_args="$extra_args --vault-password-file $SCRIPT_DIR/.vault_pass"
fi

case "$TAGS" in
?*)
    extra_args="$extra_args --tags=facts,$TAGS"
    ;;
esac

case "$SKIP_TAGS" in
?*)
    extra_args="$extra_args --skip-tags=$SKIP_TAGS"
    ;;
esac

case "$START_AT_TASK" in
?*)
    sat=$(echo "*${START_AT_TASK}*" | sed 's/ /*/g')
    extra_args="$extra_args --start-at-task=$sat"
    ;;
esac

set -x
ansible-playbook -i "$PROVISIONING_DIR/hosts" "$PROVISIONING_DIR/playbook.yml" $extra_args "$@"
