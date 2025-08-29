
const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');
const dotenv = require('dotenv');
const { exploreDirectory } = require('./fileExplorer');

dotenv.config();

const app = express();
const PORT = 4000;

const ALLOWED_ROOT = path.resolve(__dirname, 'files');

app.use(cors());
app.use(express.json());

app.get('/api/files', (req, res) => {
  try {
    const tree = exploreDirectory(ALLOWED_ROOT);
    res.json(tree);
  } catch (err) {
    res.status(500).json({ error: 'Failed to read directory' });
  }
});

app.post('/api/send', async (req, res) => {
  const { prompt, selectedFiles } = req.body;
  if (!prompt) return res.status(400).json({ error: 'Prompt required' });

  try {
    let fileContents = '';
    for (const relPath of selectedFiles || []) {
      const absPath = path.resolve(ALLOWED_ROOT, relPath);
      if (!absPath.startsWith(ALLOWED_ROOT)) throw new Error('Unauthorized path');
      fileContents += `\n\n# File: ${relPath}\n${fs.readFileSync(absPath, 'utf8')}`;
    }

    const finalPrompt = `${prompt}\n\n${fileContents}`;
    const geminiResponse = await mockGeminiAPI(finalPrompt);
    res.json({ response: geminiResponse });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to process prompt' });
  }
});

async function mockGeminiAPI(prompt) {
  return `Gemini received your prompt:\n\n${prompt.slice(0, 500)}...`;
}

app.listen(PORT, () => {
  console.log(`Backend running on http://localhost:${PORT}`);
});
