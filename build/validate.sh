#!/bin/bash

set -e

echo "🔍 Validating source files..."

# Check syntax of all shell files
for file in src/*.sh; do
    if [ -f "$file" ]; then
        echo "Checking syntax: $file"
        bash -n "$file" || exit 1
    fi
done

# Run shellcheck if available
if command -v shellcheck >/dev/null 2>&1; then
    echo "Running shellcheck..."
    shellcheck src/*.sh || echo "Warning: shellcheck issues found"
else
    echo "Warning: shellcheck not available"
fi

echo "✓ Validation completed"