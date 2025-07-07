# CREATE_AI_ASSISTANT_PART6.ps1
# Run this after Part 5
# This creates the frontend CSS and JavaScript

Write-Host @"
====================================
  LOCAL AI ASSISTANT INSTALLER
  Part 6: Frontend CSS & JavaScript
====================================
"@ -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "frontend")) {
    Write-Host "ERROR: Please run this script from the local-ai-assistant directory!" -ForegroundColor Red
    exit
}

Write-Host "`nCreating frontend files..." -ForegroundColor Yellow

# Function to create files
function Create-File {
    param($Path, $Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Created: $Path" -ForegroundColor Green
}

# Create frontend/style.css (split into parts due to size)
$cssPart1 = @'
/* Global Styles */
:root {
    --primary-color: #2563eb;
    --secondary-color: #64748b;
    --success-color: #22c55e;
    --danger-color: #ef4444;
    --warning-color: #f59e0b;
    --bg-color: #f8fafc;
    --surface-color: #ffffff;
    --text-color: #1e293b;
    --text-muted: #64748b;
    --border-color: #e2e8f0;
    --shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
    --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

/* Dark Mode */
[data-theme="dark"] {
    --primary-color: #3b82f6;
    --secondary-color: #64748b;
    --success-color: #22c55e;
    --danger-color: #ef4444;
    --warning-color: #f59e0b;
    --bg-color: #0f172a;
    --surface-color: #1e293b;
    --text-color: #f1f5f9;
    --text-muted: #94a3b8;
    --border-color: #334155;
    --shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.3), 0 1px 2px 0 rgba(0, 0, 0, 0.2);
    --shadow-lg: 0 10px 15px -3px rgba(0, 0, 0, 0.3), 0 4px 6px -2px rgba(0, 0, 0, 0.2);
}

[data-theme="dark"] .message.system .message-content {
    background-color: #1e3a5f;
    border-color: #2563eb;
    color: #93c5fd;
}

[data-theme="dark"] .message.assistant .message-content {
    background-color: #334155;
    color: var(--text-color);
}

[data-theme="dark"] .message.tool .message-content {
    background-color: #422006;
    border-color: #92400e;
    color: #fde68a;
}

[data-theme="dark"] .tool-item {
    background-color: #1e293b;
}

[data-theme="dark"] pre {
    background-color: #1e293b !important;
}

[data-theme="dark"] code {
    background-color: #334155 !important;
}

* {
    box-sizing: border-box;
    margin: 0;
    padding: 0;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
    background-color: var(--bg-color);
    color: var(--text-color);
    line-height: 1.6;
}

/* Container */
.container {
    max-width: 1400px;
    margin: 0 auto;
    padding: 1rem;
    height: 100vh;
    display: flex;
    flex-direction: column;
}

/* Header */
header {
    background-color: var(--surface-color);
    padding: 1rem 1.5rem;
    border-radius: 0.5rem;
    box-shadow: var(--shadow);
    margin-bottom: 1rem;
    display: flex;
    justify-content: space-between;
    align-items: center;
}

header h1 {
    font-size: 1.5rem;
    font-weight: 700;
}

.status-bar {
    display: flex;
    align-items: center;
    gap: 1rem;
}

.status-indicator {
    padding: 0.375rem 0.75rem;
    border-radius: 9999px;
    font-size: 0.875rem;
    font-weight: 500;
    background-color: var(--secondary-color);
    color: white;
}

.status-indicator.connected {
    background-color: var(--success-color);
}

/* Main Layout */
main {
    display: grid;
    grid-template-columns: 1fr 320px;
    gap: 1rem;
    flex: 1;
    overflow: hidden;
}

/* Chat Container */
.chat-container {
    background-color: var(--surface-color);
    border-radius: 0.5rem;
    box-shadow: var(--shadow);
    display: flex;
    flex-direction: column;
    overflow: hidden;
}

/* Messages */
.messages {
    flex: 1;
    overflow-y: auto;
    padding: 1.5rem;
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.message {
    display: flex;
    gap: 0.75rem;
    animation: fadeIn 0.3s ease-out;
}

@keyframes fadeIn {
    from {
        opacity: 0;
        transform: translateY(10px);
    }
    to {
        opacity: 1;
        transform: translateY(0);
    }
}

.message.user {
    flex-direction: row-reverse;
}

.message-content {
    max-width: 70%;
    padding: 0.75rem 1rem;
    border-radius: 0.5rem;
    word-wrap: break-word;
}

.message.system .message-content {
    background-color: #f0f9ff;
    border: 1px solid #bae6fd;
    color: #0369a1;
    max-width: 100%;
}

.message.user .message-content {
    background-color: var(--primary-color);
    color: white;
}

.message.assistant .message-content {
    background-color: #f3f4f6;
    color: var(--text-color);
}

.message.tool .message-content {
    background-color: #fef3c7;
    border: 1px solid #fde68a;
    color: #92400e;
    font-family: 'Consolas', 'Monaco', monospace;
    font-size: 0.875rem;
}

.message-content ul {
    margin: 0.5rem 0;
    padding-left: 1.5rem;
}
'@

$cssPart2 = @'

/* Tool Confirmation */
.tool-confirmation {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background-color: var(--surface-color);
    border-radius: 0.5rem;
    box-shadow: var(--shadow-lg);
    padding: 1.5rem;
    z-index: 100;
    max-width: 500px;
    width: 90%;
}

.confirmation-content h3 {
    margin-bottom: 0.75rem;
    color: var(--warning-color);
}

.tool-details {
    background-color: #f3f4f6;
    padding: 0.75rem;
    border-radius: 0.375rem;
    margin: 1rem 0;
    font-family: monospace;
    font-size: 0.875rem;
}

.confirmation-buttons {
    display: flex;
    gap: 0.75rem;
    justify-content: flex-end;
}

/* Input Container */
.input-container {
    display: flex;
    gap: 0.75rem;
    padding: 1rem;
    border-top: 1px solid var(--border-color);
    flex-wrap: wrap;
}

.upload-area {
    display: flex;
    align-items: center;
    gap: 0.5rem;
    width: 100%;
    padding: 0.5rem;
    border: 2px dashed var(--border-color);
    border-radius: 0.375rem;
    transition: all 0.2s;
}

.upload-area.drag-over {
    border-color: var(--primary-color);
    background-color: #eff6ff;
}

.upload-hint {
    color: var(--text-muted);
    font-size: 0.875rem;
}

#message-input {
    flex: 1;
    padding: 0.625rem;
    border: 1px solid var(--border-color);
    border-radius: 0.375rem;
    resize: none;
    font-family: inherit;
    font-size: 0.9375rem;
    outline: none;
    transition: border-color 0.2s;
    min-width: 300px;
}

#message-input:focus {
    border-color: var(--primary-color);
}

/* Buttons */
.btn-primary,
.btn-secondary,
.btn-success,
.btn-danger {
    padding: 0.625rem 1.25rem;
    border: none;
    border-radius: 0.375rem;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.2s;
    font-size: 0.9375rem;
}

.btn-primary {
    background-color: var(--primary-color);
    color: white;
}

.btn-primary:hover {
    background-color: #1d4ed8;
}

.btn-secondary {
    background-color: var(--secondary-color);
    color: white;
}

.btn-secondary:hover {
    background-color: #475569;
}

.btn-success {
    background-color: var(--success-color);
    color: white;
}

.btn-success:hover {
    background-color: #16a34a;
}

.btn-danger {
    background-color: var(--danger-color);
    color: white;
}

.btn-danger:hover {
    background-color: #dc2626;
}

/* Sidebar */
.sidebar {
    display: flex;
    flex-direction: column;
    gap: 1rem;
}

.sidebar > div {
    background-color: var(--surface-color);
    padding: 1rem;
    border-radius: 0.5rem;
    box-shadow: var(--shadow);
}

.sidebar h3 {
    font-size: 0.875rem;
    font-weight: 600;
    text-transform: uppercase;
    color: var(--text-muted);
    margin-bottom: 0.75rem;
}

.session-info p {
    font-size: 0.875rem;
    margin-bottom: 0.25rem;
}

.session-info span {
    font-weight: 500;
    color: var(--primary-color);
}

/* Tools List */
.tools-list {
    max-height: 300px;
    overflow-y: auto;
}

.tool-item {
    padding: 0.5rem;
    border-radius: 0.25rem;
    margin-bottom: 0.5rem;
    font-size: 0.875rem;
    background-color: #f8fafc;
}

.tool-item .tool-name {
    font-weight: 500;
    color: var(--primary-color);
}

.tool-item .tool-category {
    font-size: 0.75rem;
    color: var(--text-muted);
}

/* Activity Log */
.activity-log {
    max-height: 200px;
    overflow-y: auto;
    font-size: 0.875rem;
}

.activity-item {
    padding: 0.375rem 0;
    border-bottom: 1px solid var(--border-color);
}

.activity-item:last-child {
    border-bottom: none;
}

.activity-time {
    font-size: 0.75rem;
    color: var(--text-muted);
}

/* Utilities */
.text-muted {
    color: var(--text-muted);
}

.loading {
    text-align: center;
    color: var(--text-muted);
    padding: 1rem;
}

/* Responsive */
@media (max-width: 768px) {
    main {
        grid-template-columns: 1fr;
    }
    
    .sidebar {
        display: none;
    }
    
    header {
        flex-direction: column;
        gap: 1rem;
    }
    
    .message-content {
        max-width: 85%;
    }
}
'@

# Combine and create style.css
Create-File "frontend\style.css" ($cssPart1 + $cssPart2)

# Create frontend/app.js (split into parts)
$jsPart1 = @'
// Global variables
let ws = null;
let sessionId = null;
let messageCount = 0;
let pendingToolCalls = new Map();

// API Configuration
const API_BASE = 'http://localhost:8000';
const WS_BASE = 'ws://localhost:8000';

// Initialize application
document.addEventListener('DOMContentLoaded', () => {
    initializeApp();
});

function initializeApp() {
    // Set up event listeners
    document.getElementById('send-button').addEventListener('click', sendMessage);
    document.getElementById('message-input').addEventListener('keydown', handleInputKeydown);
    document.getElementById('new-session').addEventListener('click', createNewSession);
    document.getElementById('theme-toggle').addEventListener('click', toggleTheme);
    document.getElementById('export-chat').addEventListener('click', exportConversation);
    
    // File upload
    document.getElementById('file-input').addEventListener('change', handleFileSelect);
    setupDragAndDrop();
    
    // Load theme preference
    loadTheme();
    
    // Connect WebSocket
    connectWebSocket();
    
    // Load tools
    loadTools();
}

// WebSocket Management
function connectWebSocket() {
    updateStatus('Connecting...');
    
    ws = new WebSocket(`${WS_BASE}/ws/chat`);
    
    ws.onopen = () => {
        console.log('WebSocket connected');
        updateStatus('Connected', true);
        
        // Initialize session
        ws.send(JSON.stringify({
            type: 'init',
            session_id: sessionId
        }));
    };
    
    ws.onmessage = (event) => {
        const data = JSON.parse(event.data);
        handleWebSocketMessage(data);
    };
    
    ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        updateStatus('Error');
    };
    
    ws.onclose = () => {
        console.log('WebSocket disconnected');
        updateStatus('Disconnected');
        
        // Attempt to reconnect after 3 seconds
        setTimeout(() => {
            if (ws.readyState === WebSocket.CLOSED) {
                connectWebSocket();
            }
        }, 3000);
    };
}

function handleWebSocketMessage(data) {
    switch (data.type) {
        case 'session':
            sessionId = data.session_id;
            document.getElementById('session-id').textContent = sessionId.substring(0, 8) + '...';
            break;
            
        case 'message_received':
            // Message acknowledged
            break;
            
        case 'stream_start':
            addAssistantMessage('', true);
            break;
            
        case 'stream_chunk':
            appendToLastMessage(data.content);
            break;
            
        case 'stream_end':
            finalizeLastMessage();
            break;
            
        case 'tool_calls':
            handleToolCalls(data.tool_calls);
            break;
            
        case 'message_complete':
            messageCount++;
            updateMessageCount();
            break;
            
        case 'error':
            addSystemMessage(`Error: ${data.message}`, 'error');
            break;
    }
}

// Message Handling
function sendMessage() {
    const input = document.getElementById('message-input');
    const message = input.value.trim();
    
    if (!message) return;
    
    if (!ws || ws.readyState !== WebSocket.OPEN) {
        addSystemMessage('Not connected to server. Please wait...', 'error');
        return;
    }
    
    // Add user message to chat
    addUserMessage(message);
    
    // Send via WebSocket
    ws.send(JSON.stringify({
        type: 'message',
        content: message
    }));
    
    // Clear input
    input.value = '';
    input.style.height = 'auto';
    
    // Log activity
    addActivity('Sent message');
}

function handleInputKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
        event.preventDefault();
        sendMessage();
    }
}
'@

$jsPart2 = @'

// UI Message Functions
function addUserMessage(content) {
    const messagesDiv = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message user';
    messageDiv.innerHTML = `
        <div class="message-content">${escapeHtml(content)}</div>
    `;
    messagesDiv.appendChild(messageDiv);
    scrollToBottom();
}

function addAssistantMessage(content, streaming = false) {
    const messagesDiv = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message assistant';
    messageDiv.innerHTML = `
        <div class="message-content">${streaming ? '<span class="streaming-content"></span>' : formatMessage(content)}</div>
    `;
    messagesDiv.appendChild(messageDiv);
    scrollToBottom();
}

function addSystemMessage(content, type = 'info') {
    const messagesDiv = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message system';
    messageDiv.innerHTML = `
        <div class="message-content">${escapeHtml(content)}</div>
    `;
    messagesDiv.appendChild(messageDiv);
    scrollToBottom();
}

function addToolMessage(content) {
    const messagesDiv = document.getElementById('messages');
    const messageDiv = document.createElement('div');
    messageDiv.className = 'message tool';
    messageDiv.innerHTML = `
        <div class="message-content">${escapeHtml(content)}</div>
    `;
    messagesDiv.appendChild(messageDiv);
    scrollToBottom();
}

function appendToLastMessage(content) {
    const messages = document.getElementsByClassName('streaming-content');
    if (messages.length > 0) {
        const lastMessage = messages[messages.length - 1];
        lastMessage.textContent += content;
        scrollToBottom();
    }
}

function finalizeLastMessage() {
    const messages = document.getElementsByClassName('streaming-content');
    if (messages.length > 0) {
        const lastMessage = messages[messages.length - 1];
        const content = lastMessage.textContent;
        lastMessage.parentElement.innerHTML = formatMessage(content);
    }
}

// Tool Handling
function handleToolCalls(toolCalls) {
    toolCalls.forEach(tool => {
        pendingToolCalls.set(tool.id, tool);
        
        if (tool.requires_confirmation) {
            showToolConfirmation(tool);
        } else {
            // Auto-execute safe tools
            executeToolCall(tool.id, true);
        }
        
        // Log tool call
        addActivity(`Tool: ${tool.name}`);
    });
}

function showToolConfirmation(tool) {
    const confirmDiv = document.getElementById('tool-confirmation');
    const detailsDiv = document.getElementById('tool-details');
    
    detailsDiv.innerHTML = `
        <strong>Tool:</strong> ${tool.name}<br>
        <strong>Parameters:</strong> ${JSON.stringify(tool.parameters, null, 2)}
    `;
    
    confirmDiv.style.display = 'block';
    confirmDiv.dataset.toolId = tool.id;
}

function confirmTool(confirmed) {
    const confirmDiv = document.getElementById('tool-confirmation');
    const toolId = confirmDiv.dataset.toolId;
    
    confirmDiv.style.display = 'none';
    
    if (ws && ws.readyState === WebSocket.OPEN) {
        ws.send(JSON.stringify({
            type: 'tool_confirm',
            tool_id: toolId,
            confirmed: confirmed
        }));
    }
    
    if (confirmed) {
        addToolMessage(`Executing tool: ${pendingToolCalls.get(toolId).name}`);
    } else {
        addToolMessage(`Cancelled tool: ${pendingToolCalls.get(toolId).name}`);
    }
    
    pendingToolCalls.delete(toolId);
}

// Tools Loading
async function loadTools() {
    try {
        const response = await fetch(`${API_BASE}/api/v1/chat/tools`);
        const data = await response.json();
        
        displayTools(data.tools);
    } catch (error) {
        console.error('Error loading tools:', error);
    }
}

function displayTools(tools) {
    const toolsList = document.getElementById('tools-list');
    toolsList.innerHTML = '';
    
    tools.forEach(tool => {
        const toolDiv = document.createElement('div');
        toolDiv.className = 'tool-item';
        toolDiv.innerHTML = `
            <div class="tool-name">${tool.name}</div>
            <div class="tool-category">${tool.category} • Level ${tool.danger_level}/5</div>
        `;
        toolsList.appendChild(toolDiv);
    });
}

// Activity Logging
function addActivity(action) {
    const activityLog = document.getElementById('activity-log');
    const time = new Date().toLocaleTimeString();
    
    const activityDiv = document.createElement('div');
    activityDiv.className = 'activity-item';
    activityDiv.innerHTML = `
        <div class="activity-time">${time}</div>
        <div>${action}</div>
    `;
    
    // Remove "no activity" message if present
    const noActivity = activityLog.querySelector('.text-muted');
    if (noActivity) {
        noActivity.remove();
    }
    
    activityLog.insertBefore(activityDiv, activityLog.firstChild);
    
    // Keep only last 10 activities
    while (activityLog.children.length > 10) {
        activityLog.removeChild(activityLog.lastChild);
    }
}
'@

$jsPart3 = @'

// Session Management
function createNewSession() {
    if (confirm('Start a new session? Current conversation will be lost.')) {
        sessionId = null;
        messageCount = 0;
        
        // Clear messages
        const messagesDiv = document.getElementById('messages');
        messagesDiv.innerHTML = `
            <div class="message system">
                <div class="message-content">
                    New session started. How can I help you today?
                </div>
            </div>
        `;
        
        // Reconnect WebSocket
        if (ws) {
            ws.close();
        }
        connectWebSocket();
        
        updateMessageCount();
        addActivity('New session started');
    }
}

// Utility Functions
function updateStatus(status, connected = false) {
    const statusElement = document.getElementById('status');
    statusElement.textContent = status;
    statusElement.className = `status-indicator ${connected ? 'connected' : ''}`;
}

function updateMessageCount() {
    document.getElementById('message-count').textContent = messageCount;
}

function scrollToBottom() {
    const messagesDiv = document.getElementById('messages');
    messagesDiv.scrollTop = messagesDiv.scrollHeight;
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function formatMessage(text) {
    // Basic formatting for better display
    let formatted = escapeHtml(text)
        .replace(/\n/g, '<br>')
        .replace(/\[TOOL: (.*?)\]/g, '<span style="color: #f59e0b; font-weight: 500;">[TOOL: $1]</span>');
    
    // Format code blocks
    formatted = formatted.replace(/```(\w+)?\n([\s\S]*?)```/g, (match, lang, code) => {
        return `<pre style="background: #f3f4f6; padding: 0.5rem; border-radius: 0.25rem; overflow-x: auto;"><code>${code.trim()}</code></pre>`;
    });
    
    // Format inline code
    formatted = formatted.replace(/`([^`]+)`/g, '<code style="background: #f3f4f6; padding: 0.125rem 0.25rem; border-radius: 0.125rem;">$1</code>');
    
    // Format bold
    formatted = formatted.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    
    // Format italic
    formatted = formatted.replace(/\*(.*?)\*/g, '<em>$1</em>');
    
    // Format links
    formatted = formatted.replace(/\[([^\]]+)\]\(([^)]+)\)/g, '<a href="$2" target="_blank" style="color: #2563eb;">$1</a>');
    
    return formatted;
}

// Auto-resize textarea
document.getElementById('message-input').addEventListener('input', function() {
    this.style.height = 'auto';
    this.style.height = Math.min(this.scrollHeight, 150) + 'px';
});

// Theme Management
function loadTheme() {
    const savedTheme = localStorage.getItem('theme') || 'light';
    document.documentElement.setAttribute('data-theme', savedTheme);
    updateThemeButton(savedTheme);
}

function toggleTheme() {
    const currentTheme = document.documentElement.getAttribute('data-theme');
    const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
    
    document.documentElement.setAttribute('data-theme', newTheme);
    localStorage.setItem('theme', newTheme);
    updateThemeButton(newTheme);
    
    addActivity(`Theme changed to ${newTheme}`);
}

function updateThemeButton(theme) {
    const button = document.getElementById('theme-toggle');
    button.textContent = theme === 'dark' ? '☀️' : '🌙';
    button.title = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
}

// Export Conversation
async function exportConversation() {
    if (!sessionId) {
        alert('No active session to export');
        return;
    }
    
    try {
        // Ask for format
        const format = confirm('Export as Markdown? (Cancel for JSON)') ? 'markdown' : 'json';
        
        const response = await fetch(
            `${API_BASE}/api/v1/chat/sessions/${sessionId}/export?format=${format}`
        );
        
        if (response.ok) {
            const blob = await response.blob();
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = `conversation_${sessionId.substring(0, 8)}.${format === 'markdown' ? 'md' : 'json'}`;
            document.body.appendChild(a);
            a.click();
            window.URL.revokeObjectURL(url);
            document.body.removeChild(a);
            
            addActivity('Conversation exported');
        } else {
            alert('Failed to export conversation');
        }
    } catch (error) {
        console.error('Export error:', error);
        alert('Error exporting conversation');
    }
}
'@

$jsPart4 = @'

// File Upload Functions
function setupDragAndDrop() {
    const uploadArea = document.getElementById('upload-area');
    const messagesArea = document.getElementById('messages');
    
    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
        uploadArea.addEventListener(eventName, preventDefaults, false);
        messagesArea.addEventListener(eventName, preventDefaults, false);
        document.body.addEventListener(eventName, preventDefaults, false);
    });
    
    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
        uploadArea.addEventListener(eventName, highlight, false);
    });
    
    ['dragleave', 'drop'].forEach(eventName => {
        uploadArea.addEventListener(eventName, unhighlight, false);
    });
    
    // Handle dropped files
    uploadArea.addEventListener('drop', handleDrop, false);
    messagesArea.addEventListener('drop', handleDrop, false);
}

function preventDefaults(e) {
    e.preventDefault();
    e.stopPropagation();
}

function highlight(e) {
    document.getElementById('upload-area').classList.add('drag-over');
}

function unhighlight(e) {
    document.getElementById('upload-area').classList.remove('drag-over');
}

function handleDrop(e) {
    const dt = e.dataTransfer;
    const files = dt.files;
    
    handleFiles(files);
}

function handleFileSelect(e) {
    const files = e.target.files;
    handleFiles(files);
}

async function handleFiles(files) {
    for (let file of files) {
        await uploadFile(file);
    }
}

async function uploadFile(file) {
    // Check file size
    const maxSize = 10 * 1024 * 1024; // 10MB
    if (file.size > maxSize) {
        addSystemMessage(`File ${file.name} is too large (max 10MB)`, 'error');
        return;
    }
    
    // Check file type
    const allowedTypes = ['.txt', '.md', '.json', '.csv', '.log', '.py', '.js', '.html', '.css'];
    const fileExt = '.' + file.name.split('.').pop().toLowerCase();
    if (!allowedTypes.includes(fileExt)) {
        addSystemMessage(`File type ${fileExt} not allowed`, 'error');
        return;
    }
    
    // Show upload message
    addSystemMessage(`Uploading ${file.name}...`, 'info');
    
    // Create form data
    const formData = new FormData();
    formData.append('file', file);
    formData.append('session_id', sessionId || 'default');
    
    try {
        const response = await fetch(`${API_BASE}/api/v1/chat/upload`, {
            method: 'POST',
            body: formData
        });
        
        const result = await response.json();
        
        if (response.ok && result.success) {
            addSystemMessage(
                `✅ File uploaded: ${result.file.original_name} → ${result.file.saved_as}`,
                'success'
            );
            addActivity(`Uploaded ${file.name}`);
            
            // Optionally, send a message about the upload
            const input = document.getElementById('message-input');
            input.value = `I've uploaded a file: ${result.file.original_name}. Can you check it?`;
            input.focus();
        } else {
            addSystemMessage(`Failed to upload ${file.name}: ${result.detail || 'Unknown error'}`, 'error');
        }
    } catch (error) {
        console.error('Upload error:', error);
        addSystemMessage(`Failed to upload ${file.name}: ${error.message}`, 'error');
    }
    
    // Reset file input
    document.getElementById('file-input').value = '';
}
'@

# Combine and create app.js
Create-File "frontend\app.js" ($jsPart1 + $jsPart2 + $jsPart3 + $jsPart4)

# Create launcher scripts
Write-Host "`nCreating launcher scripts..." -ForegroundColor Yellow

# Create start_assistant.ps1
Create-File "start_assistant.ps1" @'
# Local AI Assistant Launcher Script

Write-Host "====================================" -ForegroundColor Cyan
Write-Host "   Local AI Assistant Launcher" -ForegroundColor Cyan
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

# Check if virtual environment exists
if (-not (Test-Path "venv\Scripts\Activate.ps1")) {
    Write-Host "Creating virtual environment..." -ForegroundColor Yellow
    python -m venv venv
    Write-Host "Virtual environment created." -ForegroundColor Green
    Write-Host ""
}

# Activate virtual environment
Write-Host "Activating virtual environment..." -ForegroundColor Yellow
& "venv\Scripts\Activate.ps1"

# Check if dependencies are installed
$fastapi = pip show fastapi 2>$null
if (-not $fastapi) {
    Write-Host "Installing dependencies..." -ForegroundColor Yellow
    pip install -r requirements.txt
    Write-Host "Dependencies installed." -ForegroundColor Green
    Write-Host ""
}

# Check if Ollama is running
try {
    $response = Invoke-WebRequest -Uri "http://localhost:11434/api/tags" -UseBasicParsing -ErrorAction Stop
    Write-Host "✓ Ollama is running" -ForegroundColor Green
} catch {
    Write-Host "WARNING: Ollama doesn't seem to be running!" -ForegroundColor Red
    Write-Host "Please start Ollama first or the AI features won't work." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press any key to continue anyway..." -ForegroundColor Yellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# Create .env from example if it doesn't exist
if (-not (Test-Path ".env")) {
    if (Test-Path ".env.example") {
        Write-Host "Creating .env file from template..." -ForegroundColor Yellow
        Copy-Item ".env.example" ".env"
        Write-Host "Please edit .env file with your settings!" -ForegroundColor Yellow
        Write-Host ""
    }
}

# Start the assistant
Write-Host "Starting Local AI Assistant..." -ForegroundColor Green
Write-Host ""
Write-Host "The application will be available at:" -ForegroundColor Cyan
Write-Host "  http://localhost:8000" -ForegroundColor White
Write-Host ""
Write-Host "Press Ctrl+C to stop the server." -ForegroundColor Yellow
Write-Host "====================================" -ForegroundColor Cyan
Write-Host ""

Set-Location backend
python main.py
'@

# Create start_assistant.bat
Create-File "start_assistant.bat" @'
@echo off
echo ====================================
echo   Local AI Assistant Launcher
echo ====================================
echo.

REM Check if virtual environment exists
if not exist "venv\Scripts\activate.bat" (
    echo Creating virtual environment...
    python -m venv venv
    echo Virtual environment created.
    echo.
)

REM Activate virtual environment
echo Activating virtual environment...
call venv\Scripts\activate.bat

REM Check if dependencies are installed
pip show fastapi >nul 2>&1
if errorlevel 1 (
    echo Installing dependencies...
    pip install -r requirements.txt
    echo Dependencies installed.
    echo.
)

REM Check if Ollama is running
curl -s http://localhost:11434/api/tags >nul 2>&1
if errorlevel 1 (
    echo WARNING: Ollama doesn't seem to be running!
    echo Please start Ollama first or the AI features won't work.
    echo.
    pause
)

REM Create .env from example if it doesn't exist
if not exist ".env" (
    if exist ".env.example" (
        echo Creating .env file from template...
        copy .env.example .env
        echo Please edit .env file with your settings!
        echo.
    )
)

REM Start the assistant
echo Starting Local AI Assistant...
echo.
echo The application will be available at:
echo   http://localhost:8000
echo.
echo Press Ctrl+C to stop the server.
echo ====================================
echo.

cd backend
python main.py
'@

Write-Host @"

Part 6 files created successfully!

Frontend is now complete:
✓ CSS with dark mode support
✓ JavaScript with all functionality
✓ File upload with drag & drop
✓ WebSocket real-time chat
✓ Theme toggle
✓ Export functionality
✓ Launcher scripts

Next: Run CREATE_AI_ASSISTANT_PART7.ps1 for:
- All tool implementations
- Test scripts
- Final documentation

"@ -ForegroundColor Green