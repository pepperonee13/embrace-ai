# LLM File Prompter

A web-based tool for sending prompts to LLM APIs (OpenAI, Google Gemini) with the ability to attach file contents to your prompts.

## Features

- Browse files recursively in any directory
- Select multiple files to include in your prompt
- Support for OpenAI and Google Gemini APIs
- Streaming response display
- Clean, intuitive interface

## Prerequisites

- Node.js (v14 or higher)
- API key for your chosen LLM provider (OpenAI or Google Gemini)

## Installation

1. Install dependencies:
```bash
npm install
```

## Usage

1. Start the server with your target directory:
```bash
node server.js <path-to-directory>
```

Example:
```bash
node server.js ../../projects/my-project
```

2. Open your browser to: `http://localhost:3000`

3. Configure your LLM provider:
   - Select provider (OpenAI or Gemini)
   - Choose model
   - Enter your API key

4. Select files:
   - Click files in the left panel to add them to selection
   - Click files in the right panel to remove them
   - Selected files will be appended to your prompt

5. Enter your prompt and click Submit

## API Keys

### OpenAI
Get your API key from: https://platform.openai.com/api-keys

### Google Gemini
Get your API key from: https://makersuite.google.com/app/apikey

## Security Note

API keys are only stored in memory and are not persisted. Always keep your API keys secure and never commit them to version control.

## Development

Run with auto-restart:
```bash
npm run dev
```