#!/bin/bash

# First, upload your PDF to the Files API and capture the response
echo "Uploading PDF to Files API..."
upload_response=$(curl -s -X POST https://api.anthropic.com/v1/files \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: files-api-2025-04-14" \
  -F "file=@description.pdf")

# Extract the file_id from the response using jq
file_id=$(echo "$upload_response" | jq -r '.id')

if [ "$file_id" = "null" ] || [ -z "$file_id" ]; then
  echo "Error: Failed to extract file_id from upload response"
  echo "Response: $upload_response"
  exit 1
fi

echo "File uploaded successfully. File ID: $file_id"

# Use the extracted file_id in the analysis request
echo "Analyzing document..."
analysis_response=$(curl -s https://api.anthropic.com/v1/messages \
  -H "content-type: application/json" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: files-api-2025-04-14" \
  -d '{
    "model": "claude-opus-4-20250514", 
    "max_tokens": 1024,
    "messages": [{
      "role": "user",
      "content": [{
        "type": "document",
        "source": {
          "type": "file",
          "file_id": "'"$file_id"'"
        }
      },
      {
        "type": "text",
        "text": "Create an implementation guide for claude code CLI that describes how to use the TimeToAct DocumentAI Spec to parse business documents. The guide should include examples of how to load contracts, procedures, and other business documents into AI Assistants using this spec."
      }]
    }]
  }')

# Extract the text content from the response and save to analysis.md
echo "$analysis_response" | jq -r '.content[0].text' > analysis.md

echo "Analysis complete. Results saved to analysis.md"