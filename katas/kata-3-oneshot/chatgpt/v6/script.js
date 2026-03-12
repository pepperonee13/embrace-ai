class SecureGeminiApp {
    constructor() {
        this.selectedFiles = new Set();
        this.fileContents = new Map();
        this.basePath = './';
        this.rateLimiter = new RateLimiter(10, 60000); // 10 requests per minute
        
        this.initializeEventListeners();
        this.validateInputs();
    }
    
    initializeEventListeners() {
        document.getElementById('loadTree').addEventListener('click', () => this.loadFileTree());
        document.getElementById('sendPrompt').addEventListener('click', () => this.sendToGemini());
        document.getElementById('apiKey').addEventListener('input', () => this.validateInputs());
        document.getElementById('userPrompt').addEventListener('input', () => this.validateInputs());
        
        // Load initial tree with current directory
        setTimeout(() => this.loadFileTree(), 100);
    }
    
    validateInputs() {
        const apiKey = document.getElementById('apiKey').value.trim();
        const prompt = document.getElementById('userPrompt').value.trim();
        const sendButton = document.getElementById('sendPrompt');
        
        sendButton.disabled = !apiKey || !prompt || apiKey.length < 10;
    }
    
    sanitizePath(path) {
        // Remove any path traversal attempts
        const sanitized = path.replace(/\.\./g, '').replace(/[<>:"|?*]/g, '');
        
        // Ensure path doesn't start with / or contain absolute paths
        if (sanitized.startsWith('/') || sanitized.includes(':')) {
            throw new Error('Absolute paths not allowed');
        }
        
        return sanitized;
    }
    
    async loadFileTree() {
        try {
            const pathInput = document.getElementById('basePath');
            const rawPath = pathInput.value.trim() || './';
            
            // Sanitize the base path
            this.basePath = this.sanitizePath(rawPath);
            
            const response = await fetch('/api/files', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ path: this.basePath })
            });
            
            if (!response.ok) {
                throw new Error(`Failed to load files: ${response.statusText}`);
            }
            
            const files = await response.json();
            this.renderFileTree(files);
            
        } catch (error) {
            this.showError('Error loading file tree: ' + error.message);
            // Fallback to client-side file system access if available
            this.loadClientFileTree();
        }
    }
    
    loadClientFileTree() {
        // Fallback client-side implementation
        const fileTree = document.getElementById('fileTree');
        fileTree.innerHTML = `
            <div class="tree-item folder">
                <span class="toggle">📁</span>
                <span class="name">Current Directory</span>
                <div class="tree-children">
                    <div class="tree-item file" data-path="example.txt">
                        <span class="toggle">📄</span>
                        <span class="name">example.txt</span>
                    </div>
                    <div class="tree-item file" data-path="README.md">
                        <span class="toggle">📄</span>
                        <span class="name">README.md</span>
                    </div>
                </div>
            </div>
        `;
        
        // Add click handlers for files
        fileTree.querySelectorAll('.tree-item.file').forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                this.toggleFileSelection(item);
            });
        });
    }
    
    renderFileTree(files) {
        const fileTree = document.getElementById('fileTree');
        fileTree.innerHTML = this.renderTreeNode(files, '');
        
        // Add click handlers
        fileTree.querySelectorAll('.tree-item.file').forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                this.toggleFileSelection(item);
            });
        });
        
        fileTree.querySelectorAll('.tree-item.folder').forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                this.toggleFolder(item);
            });
        });
    }
    
    renderTreeNode(node, parentPath) {
        let html = '';
        
        if (node.type === 'directory') {
            const fullPath = parentPath + node.name + '/';
            html += `
                <div class="tree-item folder" data-path="${this.escapeHtml(fullPath)}">
                    <span class="toggle">📁</span>
                    <span class="name">${this.escapeHtml(node.name)}</span>
                    <div class="tree-children">
            `;
            
            if (node.children) {
                node.children.forEach(child => {
                    html += this.renderTreeNode(child, fullPath);
                });
            }
            
            html += '</div></div>';
        } else {
            const fullPath = parentPath + node.name;
            html += `
                <div class="tree-item file" data-path="${this.escapeHtml(fullPath)}">
                    <span class="toggle">📄</span>
                    <span class="name">${this.escapeHtml(node.name)}</span>
                </div>
            `;
        }
        
        return html;
    }
    
    toggleFolder(folderItem) {
        const children = folderItem.querySelector('.tree-children');
        if (children) {
            children.style.display = children.style.display === 'none' ? 'block' : 'none';
            const toggle = folderItem.querySelector('.toggle');
            toggle.textContent = children.style.display === 'none' ? '📁' : '📂';
        }
    }
    
    async toggleFileSelection(fileItem) {
        const filePath = fileItem.dataset.path;
        
        if (this.selectedFiles.has(filePath)) {
            this.selectedFiles.delete(filePath);
            this.fileContents.delete(filePath);
            fileItem.classList.remove('selected');
        } else {
            try {
                await this.loadFileContent(filePath);
                this.selectedFiles.add(filePath);
                fileItem.classList.add('selected');
            } catch (error) {
                this.showError(`Failed to load file ${filePath}: ${error.message}`);
            }
        }
        
        this.updateSelectedFilesDisplay();
    }
    
    async loadFileContent(filePath) {
        try {
            // Sanitize file path
            const sanitizedPath = this.sanitizePath(filePath);
            
            const response = await fetch('/api/file-content', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ path: sanitizedPath })
            });
            
            if (!response.ok) {
                throw new Error(`Failed to load file content: ${response.statusText}`);
            }
            
            const content = await response.text();
            this.fileContents.set(filePath, content);
            
        } catch (error) {
            // Fallback to file input for client-side loading
            this.showFileInput(filePath);
            throw error;
        }
    }
    
    showFileInput(filePath) {
        const input = document.createElement('input');
        input.type = 'file';
        input.accept = '*/*';
        input.onchange = (e) => {
            const file = e.target.files[0];
            if (file) {
                const reader = new FileReader();
                reader.onload = (event) => {
                    this.fileContents.set(filePath, event.target.result);
                    this.selectedFiles.add(filePath);
                    this.updateSelectedFilesDisplay();
                };
                reader.readAsText(file);
            }
        };
        input.click();
    }
    
    updateSelectedFilesDisplay() {
        const container = document.getElementById('selectedFiles');
        container.innerHTML = '';
        
        this.selectedFiles.forEach(filePath => {
            const fileDiv = document.createElement('div');
            fileDiv.className = 'selected-file';
            fileDiv.innerHTML = `
                <span>${this.escapeHtml(filePath)}</span>
                <span class="remove" data-path="${this.escapeHtml(filePath)}">×</span>
            `;
            
            fileDiv.querySelector('.remove').addEventListener('click', () => {
                this.selectedFiles.delete(filePath);
                this.fileContents.delete(filePath);
                this.updateSelectedFilesDisplay();
                
                // Update tree display
                const treeItem = document.querySelector(`.tree-item.file[data-path="${filePath}"]`);
                if (treeItem) {
                    treeItem.classList.remove('selected');
                }
            });
            
            container.appendChild(fileDiv);
        });
    }
    
    async sendToGemini() {
        if (!this.rateLimiter.allowRequest()) {
            this.showError('Rate limit exceeded. Please wait before making another request.');
            return;
        }
        
        const apiKey = document.getElementById('apiKey').value.trim();
        const userPrompt = document.getElementById('userPrompt').value.trim();
        
        if (!apiKey || !userPrompt) {
            this.showError('Please provide both API key and prompt.');
            return;
        }
        
        // Show loading
        const loading = document.getElementById('loading');
        const response = document.getElementById('response');
        loading.classList.remove('hidden');
        response.innerHTML = '';
        
        try {
            // Prepare the prompt with file contents
            let fullPrompt = userPrompt;
            
            if (this.selectedFiles.size > 0) {
                fullPrompt += '\n\n--- File Contents ---\n';
                this.selectedFiles.forEach(filePath => {
                    const content = this.fileContents.get(filePath);
                    if (content) {
                        fullPrompt += `\n=== ${filePath} ===\n${content}\n`;
                    }
                });
            }
            
            // Call Gemini API
            const geminiResponse = await this.callGeminiAPI(apiKey, fullPrompt);
            
            loading.classList.add('hidden');
            response.innerHTML = this.escapeHtml(geminiResponse);
            response.classList.remove('error');
            response.classList.add('success');
            
        } catch (error) {
            loading.classList.add('hidden');
            response.innerHTML = this.escapeHtml('Error: ' + error.message);
            response.classList.remove('success');
            response.classList.add('error');
        }
    }
    
    async callGeminiAPI(apiKey, prompt) {
        const url = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent';
        
        const requestBody = {
            contents: [{
                parts: [{
                    text: prompt
                }]
            }],
            generationConfig: {
                temperature: 0.7,
                topK: 40,
                topP: 0.95,
                maxOutputTokens: 8192,
            },
            safetySettings: [
                {
                    category: "HARM_CATEGORY_HARASSMENT",
                    threshold: "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    category: "HARM_CATEGORY_HATE_SPEECH",
                    threshold: "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    category: "HARM_CATEGORY_SEXUALLY_EXPLICIT",
                    threshold: "BLOCK_MEDIUM_AND_ABOVE"
                },
                {
                    category: "HARM_CATEGORY_DANGEROUS_CONTENT",
                    threshold: "BLOCK_MEDIUM_AND_ABOVE"
                }
            ]
        };
        
        const response = await fetch(`${url}?key=${apiKey}`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
            },
            body: JSON.stringify(requestBody)
        });
        
        if (!response.ok) {
            const errorData = await response.json().catch(() => ({}));
            throw new Error(errorData.error?.message || `API request failed: ${response.status}`);
        }
        
        const data = await response.json();
        
        if (!data.candidates || data.candidates.length === 0) {
            throw new Error('No response generated from Gemini API');
        }
        
        return data.candidates[0].content.parts[0].text;
    }
    
    escapeHtml(unsafe) {
        return unsafe
            .replace(/&/g, "&amp;")
            .replace(/</g, "&lt;")
            .replace(/>/g, "&gt;")
            .replace(/"/g, "&quot;")
            .replace(/'/g, "&#039;");
    }
    
    showError(message) {
        const response = document.getElementById('response');
        response.innerHTML = this.escapeHtml(message);
        response.classList.remove('success');
        response.classList.add('error');
    }
}

class RateLimiter {
    constructor(maxRequests, timeWindow) {
        this.maxRequests = maxRequests;
        this.timeWindow = timeWindow;
        this.requests = [];
    }
    
    allowRequest() {
        const now = Date.now();
        
        // Remove old requests outside time window
        this.requests = this.requests.filter(time => now - time < this.timeWindow);
        
        // Check if we can make another request
        if (this.requests.length < this.maxRequests) {
            this.requests.push(now);
            return true;
        }
        
        return false;
    }
}

// Initialize the application
document.addEventListener('DOMContentLoaded', () => {
    new SecureGeminiApp();
});