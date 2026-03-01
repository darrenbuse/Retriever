#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
COMMAND_NAME="retriever"
TARGET="$SCRIPT_DIR/retriever"

echo "Installing $COMMAND_NAME..."

# Create ~/.local/bin if needed
if [ ! -d "$BIN_DIR" ]; then
    mkdir -p "$BIN_DIR"
    echo "Created $BIN_DIR"
fi

# Make executable
chmod +x "$TARGET"

# Handle existing symlink or file
LINK="$BIN_DIR/$COMMAND_NAME"
if [ -L "$LINK" ]; then
    CURRENT="$(readlink "$LINK")"
    if [ "$CURRENT" = "$TARGET" ]; then
        echo "$COMMAND_NAME already installed."
        exit 0
    fi
    echo "Updating existing symlink..."
    rm "$LINK"
elif [ -e "$LINK" ]; then
    echo "Warning: $LINK exists and is not a symlink. Skipping."
    exit 1
fi

ln -s "$TARGET" "$LINK"
echo "Installed: $COMMAND_NAME -> $TARGET"
