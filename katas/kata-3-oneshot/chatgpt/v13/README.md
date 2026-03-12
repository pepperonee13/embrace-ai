# Gemini Zip App

A minimal web app that:
- Scans a server-side directory at startup and shows it as a tree
- Lets you select files as optional **context**
- Sends your **prompt + selected files** to **Google Gemini**
- Returns the model response as a **ZIP** (optionally includes the selected context files)

## Quick start

1. **Install Node.js 18+**

2. Create a new folder, then unzip the provided project ZIP into it (or clone the files).

3. Configure your environment:
   - Copy `.env.example` to `.env`
   - Set `GOOGLE_API_KEY=...` to your key (from Google AI Studio)
   - Optionally set `ROOT_DIR=/absolute/path/to/your/files`
   - Optionally set `DEFAULT_MODEL=gemini-1.5-flash` (or `gemini-1.5-pro`), `PORT=3000`

4. Install dependencies:

```bash
npm install
```

5. Start the server:

```bash
npm start
```

6. Open http://localhost:3000 in your browser.

## How it works

- On startup the server scans `ROOT_DIR` (defaults to `./sample`) and builds an in-memory tree.  
- The UI fetches that tree and renders a collapsible view with checkboxes.  
- When you click **Send to Gemini**, the server:
  - Reads each selected file
  - Passes file content to Gemini using **inlineData** parts (base64) with MIME types
  - Gets the model response text
  - Streams back a **ZIP** with:
    - `response/response.md` — the plain-text result
    - `response/raw.json` — the raw API response
    - (optional) `context/` — a copy of the selected files

### Notes & limits

- The server uses inline data parts for files; very large files may exceed request limits.  
- You can press **Rescan** to rebuild the server’s file index if the directory changes.  
- Paths are strictly validated to stay under `ROOT_DIR`.

## Environment variables

- `GOOGLE_API_KEY` (required): Your Gemini API key
- `ROOT_DIR` (optional): Absolute path to the directory shown in the tree
- `DEFAULT_MODEL` (optional): e.g., `gemini-1.5-flash` (fast) or `gemini-1.5-pro` (higher quality)
- `PORT` (optional): Default `3000`

## Security

- Only files under `ROOT_DIR` can be selected.  
- Hidden folders and `node_modules` are excluded from the tree.

## Tech

- **Backend:** Node.js + Express
- **AI:** `@google/generative-ai`
- **ZIP:** `archiver`
- **Frontend:** No build step — lightweight HTML/CSS/JS

## License

MIT