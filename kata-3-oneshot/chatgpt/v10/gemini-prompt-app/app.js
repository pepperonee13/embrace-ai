require('dotenv').config();
const express = require('express');
const path = require('path');
const fs = require('fs');
const bodyParser = require('body-parser');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3000;

app.set('view engine', 'ejs');
app.use(express.static('public'));
app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

// Recursive file tree reader
function readDirectoryTree(dirPath, base = "") {
    const items = fs.readdirSync(dirPath, { withFileTypes: true });
    return items.map(item => {
        const relativePath = path.join(base, item.name);
        if (item.isDirectory()) {
            return {
                name: item.name,
                path: relativePath,
                children: readDirectoryTree(path.join(dirPath, item.name), relativePath)
            };
        } else {
            return {
                name: item.name,
                path: relativePath
            };
        }
    });
}

app.get('/', (req, res) => {
    const tree = readDirectoryTree(path.join(__dirname, 'files'));
    res.render('index', { tree });
});

app.post('/send', async (req, res) => {
    const { prompt, selectedFiles } = req.body;

    try {
        const fileContents = (selectedFiles || []).map(fp => {
            const content = fs.readFileSync(path.join(__dirname, 'files', fp), 'utf-8');
            return `File: ${fp}\n${content}`;
        }).join("\n\n");

        const finalPrompt = `${prompt}\n\nContext:\n${fileContents}`;

        const response = await axios.post(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=' + process.env.GEMINI_API_KEY,
            {
                contents: [{
                    parts: [{ text: finalPrompt }]
                }]
            }
        );

        const result = response.data.candidates[0].content.parts[0].text;
        res.json({ result });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.listen(PORT, () => {
    console.log(`Server running on http://localhost:${PORT}`);
});