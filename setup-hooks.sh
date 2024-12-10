#!/usr/bin/env bash
HOOKS_DIR=".hooks"
GIT_HOOKS_DIR=".git/hooks"

echo "Installing Git hooks..."

for hook in $HOOKS_DIR/*; do
    hook_name=$(basename "$hook")
    cp "$hook" "$GIT_HOOKS_DIR/$hook_name"
    chmod +x "$GIT_HOOKS_DIR/$hook_name"
    echo "Installed $hook_name"
done

echo "Git hooks installed successfully."
