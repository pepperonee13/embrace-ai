
# Gemini Prompt Sender

A simple Node.js web app to send prompts and optional file uploads to the Gemini API.

## Features

- Express.js web interface with EJS templating
- File upload support using Multer
- Send prompts to Gemini API with optional files
- Tree view expandable UI (to be improved)
- Secure API key via `.env`

## Setup

1. Rename `.env.example` to `.env` and add your Gemini API key.
2. Install dependencies:

```bash
npm install
```

3. Start the server:

```bash
npm start
```

Visit `http://localhost:3000` in your browser.

## Notes

- Uploaded files are temporarily saved and deleted after the request.
- You need to have a valid Gemini API key from Google.
