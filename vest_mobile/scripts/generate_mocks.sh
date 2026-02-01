#!/bin/bash
set -euo pipefail

# Mock generation script using Mockolo
# Usage:
#   ./scripts/generate_mocks.sh           # Generate mocks for all modules
#   ./scripts/generate_mocks.sh Domain    # Generate mocks for a specific module

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
MODULES_DIR="$PROJECT_ROOT/Modules"

if ! command -v mockolo &> /dev/null; then
    echo "Error: mockolo is not installed. Install it with: brew install mockolo"
    exit 1
fi

generate_mocks() {
    local module="$1"
    local sources_dir="$MODULES_DIR/$module/Sources/$module"
    local tests_dir="$MODULES_DIR/$module/Tests/${module}Tests"
    local output_file="$tests_dir/Generated${module}Mocks.swift"

    if [ ! -d "$sources_dir" ]; then
        echo "Warning: Sources directory not found for $module, skipping."
        return
    fi

    mkdir -p "$tests_dir"

    # Collect source directories: module itself + dependencies
    local source_dirs=("$sources_dir")

    case "$module" in
        Data)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            ;;
        Core)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            source_dirs+=("$MODULES_DIR/Data/Sources/Data")
            ;;
        Presentation)
            source_dirs+=("$MODULES_DIR/Domain/Sources/Domain")
            source_dirs+=("$MODULES_DIR/Core/Sources/Core")
            ;;
    esac

    local src_args=""
    for dir in "${source_dirs[@]}"; do
        if [ -d "$dir" ]; then
            src_args="$src_args -s $dir"
        fi
    done

    echo "Generating mocks for $module..."
    mockolo $src_args -d "$output_file" --enable-args-history --mock-final
    echo "  -> $output_file"
}

if [ $# -eq 1 ]; then
    generate_mocks "$1"
else
    for module in Domain Data Core Presentation; do
        generate_mocks "$module"
    done
fi

echo "Mock generation complete."
