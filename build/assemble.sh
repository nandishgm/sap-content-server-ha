#!/bin/bash

set -e

RESOURCE_NAME="S3FgwFailOver"
SRC_DIR="src"
BUILD_CONFIG="build.yaml"

# Check if yq is available, fallback to manual parsing
if command -v yq >/dev/null 2>&1; then
    assembly_order=$(yq eval '.assembly_order[]' $BUILD_CONFIG)
else
    # Fallback: read assembly order manually
    assembly_order="01-header.sh 02-metadata.sh 03-validation.sh 03a-dependencies.sh 04-aws-metadata.sh 05-storage-gateway.sh 06-nlb-management.sh 07-resource-actions.sh 08-main.sh"
fi

# Create header with build info
cat > $RESOURCE_NAME << EOF
#!/usr/bin/sh
#
# Auto-generated OCF Resource Agent
# Generated: $(date)
# Commit: ${CI_COMMIT_SHA:-$(git rev-parse HEAD 2>/dev/null || echo "unknown")}
#

EOF

# Assemble source files in order
for file in $assembly_order; do
    if [ -f "$SRC_DIR/$file" ]; then
        echo "# === $file ===" >> $RESOURCE_NAME
        cat "$SRC_DIR/$file" >> $RESOURCE_NAME
        echo "" >> $RESOURCE_NAME
    else
        echo "Warning: $SRC_DIR/$file not found"
    fi
done

chmod +x $RESOURCE_NAME
echo "✓ Generated $RESOURCE_NAME"