
# Gemini Prompt Sender Web App

This web application allows users to send a prompt, along with optional files from a given path, to the Gemini API. Users can navigate files using an expandable tree view.

## Features

- Send a prompt to Gemini API
- Attach one or more files from a local path (using a tree view interface)
- API key loaded securely from `.env` file

## Setup Instructions

1. **Clone or extract this repository.**
2. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```
3. **Create a `.env` file** in the root folder and add your Gemini API key:
   ```env
   GEMINI_API_KEY=your_api_key_here
   ```
4. **Run the application**:
   ```bash
   python app.py
   ```

5. **Open your browser** at `http://localhost:5000`

