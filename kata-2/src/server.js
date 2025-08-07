const express = require('express');
const fs = require('fs');
const path = require('path');
const cors = require('cors');

// Simple rate limiting
const rateLimiter = new Map();

const app = express();
const PORT = 3000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));
app.use(express.static(path.join(__dirname, 'public')));

let targetDirectory = '';

function getAllFiles(dirPath, arrayOfFiles = []) {
    const files = fs.readdirSync(dirPath);

    files.forEach(file => {
        const fullPath = path.join(dirPath, file);
        const relativePath = path.relative(targetDirectory, fullPath);

        if (fs.statSync(fullPath).isDirectory()) {
            if (!file.startsWith('.') && file !== 'node_modules') {
                getAllFiles(fullPath, arrayOfFiles);
            }
        } else {
            if (!file.startsWith('.')) {
                arrayOfFiles.push({
                    path: relativePath,
                    fullPath: fullPath,
                    name: file,
                    size: fs.statSync(fullPath).size
                });
            }
        }
    });

    return arrayOfFiles;
}

app.get('/api/files', (req, res) => {
    try {
        if (!targetDirectory) {
            return res.status(400).json({ error: 'Target directory not set' });
        }
        
        const files = getAllFiles(targetDirectory);
        res.json(files);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/read-file', (req, res) => {
    try {
        const { filePath } = req.body;
        const fullPath = path.join(targetDirectory, filePath);
        
        if (!fullPath.startsWith(targetDirectory)) {
            return res.status(403).json({ error: 'Access denied' });
        }
        
        const content = fs.readFileSync(fullPath, 'utf8');
        res.json({ content });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

app.post('/api/chat', async (req, res) => {
    try {
        const { prompt, files, provider, apiKey, model } = req.body;
        
        // Rate limiting check
        const clientKey = `${req.ip}-${provider}`;
        const now = Date.now();
        const lastRequest = rateLimiter.get(clientKey);
        
        if (lastRequest && (now - lastRequest) < 3000) { // 3 second cooldown
            return res.status(429).json({ 
                error: 'Rate limit: Please wait 3 seconds between requests' 
            });
        }
        
        rateLimiter.set(clientKey, now);
        
        let fullPrompt = prompt;
        
        if (files && files.length > 0) {
            fullPrompt += '\n\n--- Attached Files ---\n';
            
            for (const file of files) {
                const content = fs.readFileSync(path.join(targetDirectory, file.path), 'utf8');
                fullPrompt += `\n**File: ${file.path}**\n\`\`\`\n${content}\n\`\`\`\n`;
            }
        }
        
        let response;
        
        if (provider === 'openai') {
            response = await callOpenAI(fullPrompt, apiKey, model);
        } else if (provider === 'gemini') {
            response = await callGemini(fullPrompt, apiKey, model);
        } else {
            throw new Error('Unsupported provider');
        }
        
        res.setHeader('Content-Type', 'text/plain');
        res.setHeader('Transfer-Encoding', 'chunked');
        
        for (const chunk of response.split(' ')) {
            res.write(chunk + ' ');
            await new Promise(resolve => setTimeout(resolve, 50));
        }
        
        res.end();
        
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

async function callOpenAI(prompt, apiKey, model = 'gpt-3.5-turbo', retries = 2) {
    for (let i = 0; i <= retries; i++) {
        try {
            const response = await fetch('https://api.openai.com/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'Authorization': `Bearer ${apiKey}`
                },
                body: JSON.stringify({
                    model: model,
                    messages: [
                        { role: 'user', content: prompt }
                    ],
                    stream: false
                })
            });
            
            if (!response.ok) {
                const errorData = await response.json().catch(() => ({}));
                if (response.status === 429) {
                    if (i < retries) {
                        const delay = Math.pow(2, i) * 1000; // Exponential backoff: 1s, 2s, 4s
                        console.log(`Rate limited, retrying in ${delay}ms...`);
                        await new Promise(resolve => setTimeout(resolve, delay));
                        continue;
                    }
                    throw new Error(`Rate limit exceeded after ${retries + 1} attempts. Please upgrade your OpenAI plan or wait longer between requests.`);
                }
                throw new Error(`OpenAI API error: ${response.statusText} - ${errorData.error?.message || ''}`);
            }
            
            const data = await response.json();
            return data.choices[0].message.content;
            
        } catch (error) {
            if (i === retries || !error.message.includes('Rate limit')) {
                throw error;
            }
        }
    }
}

async function callGemini(prompt, apiKey, model = 'gemini-pro') {
    const response = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`, {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            contents: [{
                parts: [{
                    text: prompt
                }]
            }]
        })
    });
    
    if (!response.ok) {
        throw new Error(`Gemini API error: ${response.statusText}`);
    }
    
    const data = await response.json();
    return data.candidates[0].content.parts[0].text;
}

function startServer() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.error('Usage: node server.js <target-directory>');
        process.exit(1);
    }
    
    targetDirectory = path.resolve(args[0]);
    
    if (!fs.existsSync(targetDirectory)) {
        console.error(`Directory does not exist: ${targetDirectory}`);
        process.exit(1);
    }
    
    console.log(`Target directory: ${targetDirectory}`);
    
    app.listen(PORT, () => {
        console.log(`Server running at http://localhost:${PORT}`);
        console.log(`Serving files from: ${targetDirectory}`);
    });
}

startServer();