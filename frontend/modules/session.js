/**
 * Session storage logic for Local AI Assistant
 * Exports: saveMessage, loadChatHistory, clearChatHistory, exportChatHistory
 */

const STORAGE_KEY = 'ai-assistant-chat-history-v1';

/**
 * Save a message to chat history in localStorage.
 * @param {string} role - 'user' | 'assistant'
 * @param {string} content
 */
export function saveMessage(role, content) {
    if (!['user', 'assistant'].includes(role)) return;
    try {
        const history = loadChatHistory();
        history.push({ role, content });
        localStorage.setItem(STORAGE_KEY, JSON.stringify(history));
    } catch (err) {
        console.error('Error saving message:', err);
    }
}

/**
 * Load chat history from localStorage.
 * @returns {Array<{role: string, content: string}>}
 */
export function loadChatHistory() {
    try {
        const raw = localStorage.getItem(STORAGE_KEY);
        if (!raw) return [];
        const parsed = JSON.parse(raw);
        if (!Array.isArray(parsed)) return [];
        return parsed.filter(msg => msg && (msg.role === 'user' || msg.role === 'assistant') && typeof msg.content === 'string');
    } catch (err) {
        console.error('Error loading chat history:', err);
        return [];
    }
}

/**
 * Clear chat history from localStorage.
 */
export function clearChatHistory() {
    try {
        localStorage.removeItem(STORAGE_KEY);
    } catch (err) {
        console.error('Error clearing chat history:', err);
    }
}

/**
 * Export chat history as Markdown or JSON.
 * @param {'markdown'|'json'} format
 * @returns {string}
 */
export function exportChatHistory(format = 'markdown') {
    const history = loadChatHistory();
    if (format === 'json') {
        return JSON.stringify(history, null, 2);
    }
    // Markdown export
    return history.map(msg => `**${msg.role.toUpperCase()}:**\n${msg.content}\n`).join('\n');
}
