// modules/chat.js
/**
 * Chat UI and logic module for Local AI Assistant
 * Exports: initChat, appendMessage
 */

export function initChat({ chatHistory, chatForm, chatInput, sendBtn, apiUrl, onMessage, onError }) {
    if (!chatForm || !chatInput || !sendBtn || !chatHistory) return;
    chatForm.addEventListener('submit', async (e) => {
        e.preventDefault();
        const userMsg = chatInput.value.trim();
        if (!userMsg) return;
        appendMessage(chatHistory, 'user', userMsg);
        chatInput.value = '';
        chatInput.focus();
        appendMessage(chatHistory, 'system', 'Sending...');
        sendBtn.disabled = true;
        try {
            const res = await fetch(apiUrl, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ message: userMsg })
            });
            removeLastSystemMessage(chatHistory);
            if (!res.ok) throw new Error(`Error: ${res.status}`);
            const data = await res.json();
            appendMessage(chatHistory, 'assistant', data.message.content);
            if (onMessage) onMessage('assistant', data.message.content);
        } catch (err) {
            removeLastSystemMessage(chatHistory);
            appendMessage(chatHistory, 'system', '⚠️ Error: ' + (err.message || 'Unknown error'));
            if (onError) onError(err);
        } finally {
            sendBtn.disabled = false;
            chatInput.focus();
        }
    });
}

export function appendMessage(chatHistory, role, content) {
    if (!chatHistory) return;
    const msgDiv = document.createElement('div');
    const toolBlockMatch = content.trim().match(/^[\[]tool:(.*?)\](.*)$/i);
    if (toolBlockMatch) {
        msgDiv.className = 'message tool fade-in';
        const toolName = toolBlockMatch[1].trim();
        const toolDetails = toolBlockMatch[2].trim();
        msgDiv.innerHTML = `
            <div class="tool-block">
                <div class="tool-block-header">🛠️ TOOL: <span class="tool-block-name">${toolName || 'Unknown'}</span></div>
                <div class="tool-block-body">${toolDetails ? escapeHtml(toolDetails) : ''}</div>
            </div>
        `;
        chatHistory.appendChild(msgDiv);
        setTimeout(() => msgDiv.classList.remove('fade-in'), 300);
        scrollToBottom(chatHistory);
    } else if (role === 'assistant') {
        msgDiv.className = `message assistant fade-in`;
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        msgDiv.appendChild(contentDiv);
        chatHistory.appendChild(msgDiv);
        let i = 0;
        function typeChar() {
            if (i <= content.length) {
                contentDiv.innerText = content.slice(0, i);
                scrollToBottom(chatHistory);
                i++;
                setTimeout(typeChar, 12 + Math.random() * 30);
            } else {
                setTimeout(() => msgDiv.classList.remove('fade-in'), 300);
            }
        }
        typeChar();
    } else {
        msgDiv.className = `message ${role} fade-in`;
        const contentDiv = document.createElement('div');
        contentDiv.className = 'message-content';
        contentDiv.innerText = content;
        msgDiv.appendChild(contentDiv);
        chatHistory.appendChild(msgDiv);
        setTimeout(() => msgDiv.classList.remove('fade-in'), 300);
        scrollToBottom(chatHistory);
    }
}

function removeLastSystemMessage(chatHistory) {
    if (!chatHistory) return;
    const sysMsg = chatHistory.querySelector('.message.system:last-child');
    if (sysMsg) sysMsg.remove();
}

function scrollToBottom(chatHistory) {
    if (chatHistory) chatHistory.scrollTop = chatHistory.scrollHeight;
}

function escapeHtml(str) {
    return str.replace(/[&<>"']/g, function(tag) {
        const charsToReplace = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        };
        return charsToReplace[tag] || tag;
    });
}
