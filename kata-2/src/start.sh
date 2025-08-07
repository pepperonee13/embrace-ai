#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target-directory>"
    echo "Example: $0 ../../projects/my-project"
    exit 1
fi

TARGET_DIR="$1"

if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist"
    exit 1
fi

echo "Starting LLM File Prompter..."
echo "Target directory: $(realpath "$TARGET_DIR")"
echo "Open http://localhost:3000 in your browser"
echo ""
echo "Press Ctrl+C to stop the server"

node server.js "$TARGET_DIR"