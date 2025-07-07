// File upload logic for Local AI Assistant (ES6 module)
// Handles file input, drag-and-drop, preview, and upload events

/**
 * Initialize file upload UI and logic
 * @param {HTMLElement} chatForm - The chat form element
 */
export function initFileUpload(chatForm) {
    const chatFormParent = chatForm ? chatForm.parentNode : null;
    if (chatFormParent && !document.getElementById('upload-area')) {
        const uploadArea = document.createElement('div');
        uploadArea.id = 'upload-area';
        uploadArea.className = 'upload-area';
        uploadArea.tabIndex = 0;
        uploadArea.setAttribute('role', 'region');
        uploadArea.setAttribute('aria-label', 'File upload area');
        uploadArea.innerHTML = `
            <label for="file-input" class="upload-label">📎 <span>Attach file</span></label>
            <input type="file" id="file-input" class="visually-hidden" multiple accept=".txt,.csv,.json,.md,.py,.js" aria-label="Choose files to upload" />
            <div id="file-preview" class="file-preview" aria-live="polite"></div>
        `;
        chatFormParent.insertBefore(uploadArea, chatForm);
    }
    const fileInput = document.getElementById('file-input');
    const filePreview = document.getElementById('file-preview');
    const uploadArea = document.getElementById('upload-area');

    if (uploadArea && fileInput && filePreview) {
        uploadArea.addEventListener('keydown', (e) => {
            if (e.key === 'Enter' || e.key === ' ') {
                fileInput.click();
                e.preventDefault();
            }
        });
        uploadArea.addEventListener('dragover', (e) => {
            e.preventDefault();
            uploadArea.classList.add('drag-over');
        });
        uploadArea.addEventListener('dragleave', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('drag-over');
        });
        uploadArea.addEventListener('drop', (e) => {
            e.preventDefault();
            uploadArea.classList.remove('drag-over');
            if (e.dataTransfer.files.length) {
                fileInput.files = e.dataTransfer.files;
                handleFilePreview(fileInput, filePreview);
                uploadFiles(e.dataTransfer.files);
            }
        });
        fileInput.addEventListener('change', () => {
            handleFilePreview(fileInput, filePreview);
            uploadFiles(fileInput.files);
        });
    }
}

/**
 * Show file preview in the UI
 */
function handleFilePreview(fileInput, filePreview) {
    if (!fileInput || !filePreview) return;
    filePreview.innerHTML = '';
    Array.from(fileInput.files).forEach(file => {
        const div = document.createElement('div');
        div.className = 'file-item';
        div.textContent = `${file.name} (${Math.round(file.size/1024)} KB)`;
        filePreview.appendChild(div);
    });
}

/**
 * Upload files to the backend (stub, implement as needed)
 */
function uploadFiles(files) {
    // TODO: Implement actual upload logic (e.g., POST to /api/v1/upload)
    // For now, just log files
    if (!files || !files.length) return;
    console.log('Uploading files:', files);
}
