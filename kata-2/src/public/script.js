class LLMFilePrompter {
    constructor() {
        this.files = [];
        this.selectedFiles = [];
        this.isSubmitting = false;
        
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
            
            this.files = await response.json();
            this.renderFileList();
        } catch (error) {
            this.fileList.innerHTML = `<div class="error">Error loading files: ${error.message}</div>`;
        }
    }
    
    renderFileList() {
        if (this.files.length === 0) {
            this.fileList.innerHTML = '<div class="empty-state">No files found</div>';
            return;
        }
        
        this.fileList.innerHTML = this.files.map(file => `
            <div class="file-item" data-path="${file.path}" onclick="app.toggleFile('${file.path}')">
                <div class="file-name">${file.name}</div>
                <div class="file-path">${file.path}</div>
                <div class="file-size">${this.formatFileSize(file.size)}</div>
            </div>
        `).join('');
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
    
    toggleFile(filePath) {
        const file = this.files.find(f => f.path === filePath);
        if (!file) return;
        
        const existingIndex = this.selectedFiles.findIndex(f => f.path === filePath);
        
        if (existingIndex >= 0) {
            this.selectedFiles.splice(existingIndex, 1);
        } else {
            this.selectedFiles.push(file);
        }
        
        this.renderSelectedFiles();
        this.updateFileListHighlights();
    }
    
    removeFile(filePath) {
        const index = this.selectedFiles.findIndex(f => f.path === filePath);
        if (index >= 0) {
            this.selectedFiles.splice(index, 1);
            this.renderSelectedFiles();
            this.updateFileListHighlights();
        }
    }
    
    updateFileListHighlights() {
        const fileItems = this.fileList.querySelectorAll('.file-item');
        fileItems.forEach(item => {
            const path = item.dataset.path;
            const isSelected = this.selectedFiles.some(f => f.path === path);
            item.classList.toggle('selected', isSelected);
        });
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