#!/usr/bin/env bash
#
# Run Retriever tests
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check for bats
if ! command -v bats &> /dev/null; then
    echo "Bats not found. Install with:"
    echo "  brew install bats-core"
    echo ""
    echo "Or run tests in Docker:"
    echo "  docker run --rm -v \"$PROJECT_DIR:/app\" -w /app bats/bats:latest test/"
    exit 1
fi

echo "Running Retriever tests..."
echo ""

bats "$SCRIPT_DIR"
