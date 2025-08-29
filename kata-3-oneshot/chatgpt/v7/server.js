const express = require('express');
const fileUpload = require('express-fileupload');
const fs = require('fs');
const path = require('path');
const app = express();
const PORT = 3000;

const BASE_PATH = 'C:\\Users\\peter\\source\\repos\\embrace-ai\\';

app.use(express.static('public'));
app.use(express.json());
app.use(fileUpload());

// Recursive file tree function
function getFileTree(dirPath) {
  const entries = fs.readdirSync(dirPath, { withFileTypes: true });
  return entries.map(entry => {
    const fullPath = path.join(dirPath, entry.name);
    return {
      name: entry.name,
      path: path.relative(BASE_PATH, fullPath),
      isDir: entry.isDirectory(),
      children: entry.isDirectory() ? getFileTree(fullPath) : undefined,
    };
  });
}

app.get('/api/tree', (req, res) => {
  res.json(getFileTree(BASE_PATH));
});

app.post('/api/send', async (req, res) => {
  const { prompt, selectedFiles } = req.body;
  if (!prompt) return res.status(400).json({ error: 'Prompt is required' });

  const fileContents = {};
  for (const relPath of selectedFiles || []) {
    const absPath = path.join(BASE_PATH, relPath);
    if (!absPath.startsWith(BASE_PATH)) return res.status(403).json({ error: 'Forbidden path' });
    fileContents[relPath] = fs.readFileSync(absPath, 'utf-8');
  }

  // Simulated Gemini API call
  console.log('Sending to Gemini:', { prompt, fileContents });

  res.json({ response: "Simulated Gemini LLM response 🚀" });
});

app.listen(PORT, () => console.log(`Server running at http://localhost:${PORT}`));
