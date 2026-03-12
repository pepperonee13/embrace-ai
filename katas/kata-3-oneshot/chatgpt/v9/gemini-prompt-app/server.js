import express from 'express';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { exec } from 'child_process';
import { getFileTree } from './utils/fileTree.js';
import AdmZip from 'adm-zip';

dotenv.config();
const __dirname = path.dirname(fileURLToPath(import.meta.url));

const app = express();
const PORT = process.env.PORT || 3000;
const FILE_BASE_PATH = process.env.FILE_BASE_PATH || './user_files';

app.use(express.static(path.join(__dirname, 'public')));
app.use(express.json());

app.get('/api/files', (req, res) => {
    const tree = getFileTree(FILE_BASE_PATH);
    res.json(tree);
});

app.post('/api/send', async (req, res) => {
    const { prompt, selectedFiles } = req.body;
    let content = `Prompt: ${prompt}\n\nAttached Files:\n`;

    for (const file of selectedFiles) {
        const filePath = path.join(FILE_BASE_PATH, file);
        if (fs.existsSync(filePath) && fs.lstatSync(filePath).isFile()) {
            const fileContent = fs.readFileSync(filePath, 'utf-8');
            content += `\n--- ${file} ---\n${fileContent}\n`;
        }
    }

    // Dummy Gemini call replacement
    const response = {
        result: `Gemini (simulated) response for:
${prompt}

Files included:
${selectedFiles.join(', ')}`
    };

    res.json(response);
});

app.post('/api/zip', (req, res) => {
    const { selectedFiles } = req.body;
    const zip = new AdmZip();

    for (const file of selectedFiles) {
        const filePath = path.join(FILE_BASE_PATH, file);
        if (fs.existsSync(filePath) && fs.lstatSync(filePath).isFile()) {
            zip.addLocalFile(filePath, path.dirname(file));
        }
    }

    const zipPath = path.join(__dirname, 'public', 'download.zip');
    zip.writeZip(zipPath);
    res.json({ url: '/download.zip' });
});

app.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}`);
});
