// Modular, modern chat UI logic for Local AI Assistant (ES6 modules)
// All DOM queries are guarded and match index.html
import { initChat, appendMessage } from './modules/chat.js';
import { loadTheme, toggleTheme } from './modules/theme.js';
import { saveMessage, loadChatHistory, clearChatHistory, exportChatHistory } from './modules/session.js';
import { startVoiceInput, speakLastAssistantMessage } from './modules/voice.js';
import { initFileUpload } from './modules/fileupload.js';

// --- DOM Elements ---
const chatHistory = document.getElementById('chat-history');
const chatForm = document.getElementById('chat-form');
const chatInput = document.getElementById('chat-input');
const sendBtn = document.getElementById('send-btn');
const exportBtn = document.getElementById('export-btn');
const exportMenu = document.getElementById('export-menu');
const exportMdBtn = document.getElementById('export-md');
const exportJsonBtn = document.getElementById('export-json');
const themeToggle = document.getElementById('theme-toggle');
const voiceInputBtn = document.getElementById('voice-input-btn');
const voiceOutputBtn = document.getElementById('voice-output-btn');
const clearSessionBtn = document.getElementById('clear-session-btn');
const apiUrl = 'http://localhost:8000/api/v1/chat/message';

// --- Main App Initialization ---
init();

/**
 * Main app initializer: loads theme, restores chat, binds all events
 */
function init() {
    loadTheme(themeToggle);
    restoreSession();
    if (chatInput) chatInput.focus();
    if (chatForm && chatInput && sendBtn && chatHistory) {
        initChat({
            chatHistory,
            chatForm,
            chatInput,
            sendBtn,
            apiUrl,
            onMessage: (role, content) => saveMessage(role, content),
            onError: showErrorOverlay
        });
    }
    if (themeToggle) themeToggle.addEventListener('click', () => toggleTheme(themeToggle));
    if (exportBtn && exportMenu) {
        exportBtn.addEventListener('click', () => {
            exportMenu.hidden = !exportMenu.hidden;
            exportBtn.setAttribute('aria-expanded', String(!exportMenu.hidden));
        });
        document.addEventListener('click', (e) => {
            if (!exportMenu.hidden && !exportBtn.contains(e.target) && !exportMenu.contains(e.target)) {
                exportMenu.hidden = true;
                exportBtn.setAttribute('aria-expanded', 'false');
            }
        });
    }
    if (exportMdBtn) exportMdBtn.addEventListener('click', () => exportConversation('markdown'));
    if (exportJsonBtn) exportJsonBtn.addEventListener('click', () => exportConversation('json'));
    if (voiceInputBtn && chatInput) {
        if ('webkitSpeechRecognition' in window || 'SpeechRecognition' in window) {
            voiceInputBtn.disabled = false;
            voiceInputBtn.title = 'Voice input (mic)';
            voiceInputBtn.addEventListener('click', () => startVoiceInput(chatInput, null, (err) => appendMessage(chatHistory, 'system', '⚠️ Voice input error: ' + (err.error || err.message || 'Unknown error'))));
        } else {
            voiceInputBtn.disabled = true;
            voiceInputBtn.title = 'Voice input not supported in this browser';
        }
    }
    if (voiceOutputBtn && chatHistory) {
        if ('speechSynthesis' in window) {
            voiceOutputBtn.disabled = false;
            voiceOutputBtn.title = 'Read last assistant message aloud';
            voiceOutputBtn.addEventListener('click', () => speakLastAssistantMessage(chatHistory));
        } else {
            voiceOutputBtn.disabled = true;
            voiceOutputBtn.title = 'Voice output not supported in this browser';
        }
    }
    if (clearSessionBtn) {
        clearSessionBtn.addEventListener('click', () => {
            clearChatHistory();
            if (chatHistory) chatHistory.innerHTML = '';
            restoreSession();
        });
    }
    if (chatForm) initFileUpload(chatForm);
}

/**
 * Restore chat history from storage and render each message
 */
function restoreSession() {
    try {
        const messages = loadChatHistory();
        if (chatHistory) chatHistory.innerHTML = '';
        messages.forEach(msg => appendMessage(chatHistory, msg.role, msg.content));
    } catch (err) {
        appendMessage(chatHistory, 'system', '⚠️ Error restoring chat history: ' + (err.message || 'Unknown error'));
    }
}

/**
 * Export chat history as Markdown or JSON
 */
function exportConversation(format) {
    try {
        const data = exportChatHistory(format);
        const blob = new Blob([data], { type: format === 'json' ? 'application/json' : 'text/markdown' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `chat-history.${format === 'json' ? 'json' : 'md'}`;
        document.body.appendChild(a);
        a.click();
        setTimeout(() => {
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }, 100);
    } catch (err) {
        showErrorOverlay(err);
    }
}

/**
 * Show error overlay for fetch or critical errors
 */
function showErrorOverlay(err) {
    let overlay = document.getElementById('error-overlay');
    if (!overlay) {
        overlay = document.createElement('div');
        overlay.id = 'error-overlay';
        overlay.className = 'error-overlay';
        overlay.tabIndex = 0;
        overlay.setAttribute('role', 'alert');
        overlay.innerHTML = `<div class="error-content"><strong>Error:</strong> <span id="error-message"></span><button id="close-error-btn" aria-label="Close error">✖</button></div>`;
        document.body.appendChild(overlay);
    }
    document.getElementById('error-message').textContent = err.message || String(err);
    overlay.style.display = 'block';
    const closeBtn = document.getElementById('close-error-btn');
    if (closeBtn) closeBtn.onclick = () => { overlay.style.display = 'none'; };
    overlay.focus();
}
