# Secure Gemini LLM Interface

A secure web application that allows users to send prompts to Google's Gemini LLM with optional file attachments from a file tree interface.

## Features

### Security Features
- **Path Traversal Protection**: Prevents directory traversal attacks (../ sequences)
- **Input Sanitization**: All user inputs are properly sanitized and validated
- **Rate Limiting**: Prevents API abuse with configurable rate limits
- **Content Security Policy**: CSP headers to prevent XSS attacks
- **File Type Validation**: Only allows safe text-based file types
- **File Size Limits**: Maximum 10MB per file to prevent memory exhaustion
- **CORS Protection**: Configurable CORS settings for production
- **Helmet Security**: Additional security headers via Helmet.js

### Functionality
- **Interactive File Tree**: Browse and select files from a specified directory
- **Multiple File Selection**: Select multiple files to include in prompts
- **Real-time Validation**: Input validation with immediate feedback
- **Error Handling**: Comprehensive error handling and user feedback
- **Responsive Design**: Mobile-friendly responsive interface
- **Gemini API Integration**: Direct integration with Google's Gemini API

## Setup Instructions

### Prerequisites
- Node.js 16.0.0 or higher
- A Google Gemini API key

### Installation

1. Install dependencies:
```bash
npm install
```

2. Start the server:
```bash
npm start
```

3. Open your browser and navigate to:
```
http://localhost:3000
```

### Development Mode
For development with auto-restart:
```bash
npm run dev
```

## Usage

1. **Get a Gemini API Key**:
   - Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
   - Create a new API key
   - Copy the API key for use in the application

2. **Using the Application**:
   - Enter your Gemini API key in the designated field
   - Specify a base path to browse files (defaults to current directory)
   - Click "Load Files" to populate the file tree
   - Click on files to select/deselect them for inclusion
   - Enter your prompt in the text area
   - Click "Send to Gemini" to get the AI response

## Security Considerations

### Server-Side Security
- All file paths are validated and sanitized
- Directory traversal attacks are prevented
- Only relative paths within the application directory are allowed
- File type restrictions prevent execution of dangerous files
- Rate limiting prevents API abuse

### Client-Side Security
- Input validation and sanitization
- XSS prevention through HTML escaping
- CSP headers to prevent script injection
- Rate limiting on the frontend

### API Security
- Gemini API key is never stored on the server
- API requests include safety settings to filter harmful content
- Error messages don't expose sensitive system information

## File Structure

```
.
├── index.html          # Main HTML interface
├── styles.css          # CSS styling
├── script.js           # Frontend JavaScript
├── server.js           # Node.js backend server
├── package.json        # Node.js dependencies
└── README.md          # This file
```

## Configuration

### Environment Variables
- `PORT`: Server port (default: 3000)
- `NODE_ENV`: Environment mode (development/production)

### Rate Limiting
- Frontend: 10 requests per minute per user
- Backend: 100 requests per 15 minutes per IP

### Supported File Types
Text-based files only:
- .txt, .md, .js, .ts, .jsx, .tsx
- .html, .css, .scss, .json, .xml
- .yaml, .yml, .py, .java, .c, .cpp
- .php, .rb, .go, .rs, .swift, .kt
- .sql, .sh, .bat

## Troubleshooting

### Common Issues

1. **"Failed to load files" Error**:
   - Ensure the specified path exists and is readable
   - Check that the path doesn't contain invalid characters
   - Verify the server has permission to access the directory

2. **"Rate limit exceeded" Error**:
   - Wait for the rate limit window to reset
   - Reduce the frequency of requests

3. **"API request failed" Error**:
   - Verify your Gemini API key is correct
   - Check your internet connection
   - Ensure you have API quota remaining

### Development

To modify the application:
1. Edit the HTML structure in `index.html`
2. Modify styling in `styles.css`
3. Update frontend logic in `script.js`
4. Modify backend API in `server.js`

## License

MIT License - see the source code for details.

## Disclaimer

This application is for educational and development purposes. Always review the security implications before deploying to production environments. Ensure proper authentication and authorization mechanisms are in place for production use.