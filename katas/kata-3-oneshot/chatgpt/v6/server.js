const express = require('express');
const fs = require('fs').promises;
const path = require('path');
const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            styleSrc: ["'self'", "'unsafe-inline'"],
            connectSrc: ["'self'", "https://generativelanguage.googleapis.com"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
}));

app.use(cors({
    origin: process.env.NODE_ENV === 'production' ? false : true,
    credentials: true
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.'
});

app.use(limiter);

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files
app.use(express.static(__dirname));

// Security helper functions
function isPathSafe(userPath) {
    // Resolve the path and ensure it doesn't escape the current directory
    const resolvedPath = path.resolve(userPath);
    const currentDir = path.resolve('.');
    
    // Check if the resolved path is within the current directory
    return resolvedPath.startsWith(currentDir);
}

function sanitizePath(userPath) {
    // Remove any dangerous characters and path traversal attempts
    const sanitized = userPath.replace(/\.\./g, '').replace(/[<>:"|?*]/g, '');
    
    // Ensure it's a relative path
    if (path.isAbsolute(sanitized)) {
        throw new Error('Absolute paths are not allowed');
    }
    
    return sanitized;
}

// API endpoint to list files in a directory
app.post('/api/files', async (req, res) => {
    try {
        const { path: userPath } = req.body;
        
        if (!userPath || typeof userPath !== 'string') {
            return res.status(400).json({ error: 'Path is required' });
        }
        
        // Sanitize and validate the path
        const sanitizedPath = sanitizePath(userPath);
        
        if (!isPathSafe(sanitizedPath)) {
            return res.status(403).json({ error: 'Access denied: path outside allowed directory' });
        }
        
        const files = await getDirectoryStructure(sanitizedPath);
        res.json(files);
        
    } catch (error) {
        console.error('Error listing files:', error);
        res.status(500).json({ error: 'Failed to list files: ' + error.message });
    }
});

// API endpoint to get file content
app.post('/api/file-content', async (req, res) => {
    try {
        const { path: userPath } = req.body;
        
        if (!userPath || typeof userPath !== 'string') {
            return res.status(400).json({ error: 'Path is required' });
        }
        
        // Sanitize and validate the path
        const sanitizedPath = sanitizePath(userPath);
        
        if (!isPathSafe(sanitizedPath)) {
            return res.status(403).json({ error: 'Access denied: path outside allowed directory' });
        }
        
        // Check file size limit (10MB)
        const stats = await fs.stat(sanitizedPath);
        if (stats.size > 10 * 1024 * 1024) {
            return res.status(413).json({ error: 'File too large (max 10MB)' });
        }
        
        // Only allow text files
        const allowedExtensions = [
            '.txt', '.md', '.js', '.ts', '.jsx', '.tsx', '.html', '.css', '.scss',
            '.json', '.xml', '.yaml', '.yml', '.py', '.java', '.c', '.cpp', '.h',
            '.php', '.rb', '.go', '.rs', '.swift', '.kt', '.sql', '.sh', '.bat'
        ];
        
        const ext = path.extname(sanitizedPath).toLowerCase();
        if (!allowedExtensions.includes(ext) && ext !== '') {
            return res.status(415).json({ error: 'File type not supported' });
        }
        
        const content = await fs.readFile(sanitizedPath, 'utf-8');
        res.send(content);
        
    } catch (error) {
        console.error('Error reading file:', error);
        res.status(500).json({ error: 'Failed to read file: ' + error.message });
    }
});

async function getDirectoryStructure(dirPath) {
    try {
        const items = await fs.readdir(dirPath, { withFileTypes: true });
        const structure = [];
        
        for (const item of items) {
            // Skip hidden files and common ignored directories
            if (item.name.startsWith('.') || 
                ['node_modules', '__pycache__', 'dist', 'build'].includes(item.name)) {
                continue;
            }
            
            const itemPath = path.join(dirPath, item.name);
            
            if (item.isDirectory()) {
                try {
                    const children = await getDirectoryStructure(itemPath);
                    structure.push({
                        name: item.name,
                        type: 'directory',
                        children: children
                    });
                } catch (error) {
                    // Skip directories we can't read
                    console.warn(`Cannot read directory ${itemPath}:`, error.message);
                }
            } else if (item.isFile()) {
                structure.push({
                    name: item.name,
                    type: 'file'
                });
            }
        }
        
        // Sort: directories first, then files, both alphabetically
        structure.sort((a, b) => {
            if (a.type !== b.type) {
                return a.type === 'directory' ? -1 : 1;
            }
            return a.name.localeCompare(b.name);
        });
        
        return structure;
        
    } catch (error) {
        throw new Error(`Cannot read directory ${dirPath}: ${error.message}`);
    }
}

// Health check endpoint
app.get('/api/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date().toISOString() });
});

// Error handling middleware
app.use((error, req, res, next) => {
    console.error('Unhandled error:', error);
    res.status(500).json({ error: 'Internal server error' });
});

// 404 handler for API routes
app.use('/api/*', (req, res) => {
    res.status(404).json({ error: 'API endpoint not found' });
});

// Start server
app.listen(PORT, () => {
    console.log(`Secure Gemini LLM Interface running on http://localhost:${PORT}`);
    console.log('Press Ctrl+C to stop the server');
});

// Graceful shutdown
process.on('SIGTERM', () => {
    console.log('Received SIGTERM, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    console.log('Received SIGINT, shutting down gracefully');
    process.exit(0);
});