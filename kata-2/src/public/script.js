class LLMFilePrompter {
    constructor() {
        this.fileTree = [];
        this.selectedFiles = [];
        this.isSubmitting = false;
        this.expandedFolders = new Set();
        
        this.initializeElements();
        this.attachEventListeners();
        this.loadFiles();
        this.updateModelOptions();
    }
    
    initializeElements() {
        this.fileList = document.getElementById('file-list');
        this.selectedFilesContainer = document.getElementById('selected-files');
        this.promptTextarea = document.getElementById('prompt');
        this.submitBtn = document.getElementById('submit-btn');
        this.clearBtn = document.getElementById('clear-btn');
        this.responseDiv = document.getElementById('response');
        this.providerSelect = document.getElementById('provider');
        this.modelSelect = document.getElementById('model');
        this.apiKeyInput = document.getElementById('api-key');
    }
    
    attachEventListeners() {
        this.submitBtn.addEventListener('click', () => this.submitPrompt());
        this.clearBtn.addEventListener('click', () => this.clearResponse());
        this.promptTextarea.addEventListener('input', () => this.updateSubmitButton());
        this.apiKeyInput.addEventListener('input', () => this.updateSubmitButton());
        this.providerSelect.addEventListener('change', () => this.updateModelOptions());
        
        // Handle Enter key in prompt (Ctrl+Enter to submit)
        this.promptTextarea.addEventListener('keydown', (e) => {
            if (e.ctrlKey && e.key === 'Enter') {
                this.submitPrompt();
            }
        });
    }
    
    updateModelOptions() {
        const provider = this.providerSelect.value;
        this.modelSelect.innerHTML = '';
        
        const models = {
            openai: [
                { value: 'gpt-3.5-turbo', label: 'GPT-3.5 Turbo' },
                { value: 'gpt-4', label: 'GPT-4' },
                { value: 'gpt-4-turbo', label: 'GPT-4 Turbo' },
                { value: 'gpt-4o', label: 'GPT-4o' }
            ],
            gemini: [
                { value: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro' },
                { value: 'gemini-2.5-pro', label: 'Gemini 2.5 Pro' }
            ]
        };
        
        models[provider].forEach(model => {
            const option = document.createElement('option');
            option.value = model.value;
            option.textContent = model.label;
            this.modelSelect.appendChild(option);
        });
    }
    
    async loadFiles() {
        try {
            const response = await fetch('/api/files');
            if (!response.ok) throw new Error('Failed to load files');
            
            this.fileTree = await response.json();
            this.renderTreeView();
        } catch (error) {
            this.fileList.innerHTML = `<div class="error">Error loading files: ${error.message}</div>`;
        }
    }
    
    renderTreeView() {
        if (this.fileTree.length === 0) {
            this.fileList.innerHTML = '<div class="empty-state">No files found</div>';
            return;
        }
        
        this.fileList.innerHTML = this.renderTreeNodes(this.fileTree);
    }
    
    renderTreeNodes(nodes) {
        return nodes.map(node => this.renderTreeNode(node)).join('');
    }
    
    renderTreeNode(node) {
        const isFolder = node.type === 'folder';
        const isExpanded = this.expandedFolders.has(node.path);
        const isSelected = this.selectedFiles.some(f => f.path === node.path);
        
        let html = `<div class="tree-item">`;
        
        if (isFolder) {
            html += `
                <div class="tree-node ${isSelected ? 'selected' : ''}" data-path="${node.path}">
                    <span class="tree-toggle ${isExpanded ? 'expanded' : 'collapsed'}" onclick="app.toggleFolder('${node.path}', event)"></span>
                    <span class="tree-icon folder"></span>
                    <span class="tree-label" onclick="app.toggleFileSelection('${node.path}', event)">${node.name}</span>
                </div>
            `;
            
            if (node.children && node.children.length > 0) {
                html += `<div class="tree-children ${isExpanded ? '' : 'hidden'}">`;
                html += this.renderTreeNodes(node.children);
                html += `</div>`;
            }
        } else {
            html += `
                <div class="tree-node ${isSelected ? 'selected' : ''}" data-path="${node.path}">
                    <span class="tree-toggle leaf"></span>
                    <span class="tree-icon file"></span>
                    <span class="tree-label" onclick="app.toggleFileSelection('${node.path}', event)">${node.name}</span>
                    <span class="tree-size">${this.formatFileSize(node.size)}</span>
                </div>
            `;
        }
        
        html += `</div>`;
        return html;
    }
    
    renderSelectedFiles() {
        if (this.selectedFiles.length === 0) {
            this.selectedFilesContainer.innerHTML = '<div class="empty-state">No files selected</div>';
            return;
        }
        
        this.selectedFilesContainer.innerHTML = this.selectedFiles.map(file => `
            <div class="file-item selected" data-path="${file.path}" onclick="app.removeFile('${file.path}')">
                <div class="file-name">${file.name}</div>
                <div class="file-path">${file.path}</div>
                <div class="file-size">${this.formatFileSize(file.size)}</div>
            </div>
        `).join('');
    }
    
    toggleFolder(folderPath, event) {
        event.stopPropagation();
        
        if (this.expandedFolders.has(folderPath)) {
            this.expandedFolders.delete(folderPath);
        } else {
            this.expandedFolders.add(folderPath);
        }
        
        this.renderTreeView();
    }
    
    toggleFileSelection(filePath, event) {
        event.stopPropagation();
        
        const file = this.findFileByPath(filePath);
        if (!file || file.type === 'folder') return;
        
        const existingIndex = this.selectedFiles.findIndex(f => f.path === filePath);
        
        if (existingIndex >= 0) {
            this.selectedFiles.splice(existingIndex, 1);
        } else {
            this.selectedFiles.push(file);
        }
        
        this.renderSelectedFiles();
        this.renderTreeView();
    }
    
    findFileByPath(filePath) {
        const searchNodes = (nodes) => {
            for (const node of nodes) {
                if (node.path === filePath) {
                    return node;
                }
                if (node.children) {
                    const found = searchNodes(node.children);
                    if (found) return found;
                }
            }
            return null;
        };
        
        return searchNodes(this.fileTree);
    }
    
    removeFile(filePath) {
        const index = this.selectedFiles.findIndex(f => f.path === filePath);
        if (index >= 0) {
            this.selectedFiles.splice(index, 1);
            this.renderSelectedFiles();
            this.renderTreeView();
        }
    }
    
    updateSubmitButton() {
        const hasPrompt = this.promptTextarea.value.trim().length > 0;
        const hasApiKey = this.apiKeyInput.value.trim().length > 0;
        const canSubmit = hasPrompt && hasApiKey && !this.isSubmitting;
        
        this.submitBtn.disabled = !canSubmit;
    }
    
    async submitPrompt() {
        if (this.isSubmitting) return;
        
        const prompt = this.promptTextarea.value.trim();
        const apiKey = this.apiKeyInput.value.trim();
        const provider = this.providerSelect.value;
        const model = this.modelSelect.value;
        
        if (!prompt || !apiKey) return;
        
        this.isSubmitting = true;
        this.submitBtn.disabled = true;
        this.submitBtn.textContent = 'Submitting...';
        this.responseDiv.textContent = '';
        this.responseDiv.classList.add('streaming');
        
        try {
            const response = await fetch('/api/chat', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    prompt,
                    files: this.selectedFiles,
                    provider,
                    model,
                    apiKey
                })
            });
            
            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error || 'Request failed');
            }
            
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let responseText = '';
            
            while (true) {
                const { value, done } = await reader.read();
                if (done) break;
                
                const chunk = decoder.decode(value);
                responseText += chunk;
                this.responseDiv.textContent = responseText;
            }
            
        } catch (error) {
            this.responseDiv.textContent = `Error: ${error.message}`;
            this.responseDiv.classList.add('error');
        } finally {
            this.isSubmitting = false;
            this.submitBtn.disabled = false;
            this.submitBtn.textContent = 'Submit';
            this.responseDiv.classList.remove('streaming');
            this.updateSubmitButton();
        }
    }
    
    clearResponse() {
        this.responseDiv.textContent = '';
        this.responseDiv.classList.remove('error');
    }
    
    formatFileSize(bytes) {
        if (bytes === 0) return '0 B';
        const k = 1024;
        const sizes = ['B', 'KB', 'MB', 'GB'];
        const i = Math.floor(Math.log(bytes) / Math.log(k));
        return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
    }
}

// Initialize the application
window.addEventListener('DOMContentLoaded', () => {
    window.app = new LLMFilePrompter();
});