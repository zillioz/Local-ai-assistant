// modules/voice.js
/**
 * Voice input/output logic for Local AI Assistant
 * Exports: startVoiceInput, speakLastAssistantMessage
 */

export function startVoiceInput(chatInput, onResult, onError) {
    const SpeechRecognition = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!SpeechRecognition || !chatInput) {
        if (onError) onError(new Error('Speech recognition not supported'));
        return;
    }
    const recognition = new SpeechRecognition();
    recognition.lang = 'en-US';
    recognition.interimResults = false;
    recognition.maxAlternatives = 1;
    recognition.onresult = (event) => {
        const transcript = event.results[0][0].transcript;
        chatInput.value = transcript;
        chatInput.focus();
        if (onResult) onResult(transcript);
    };
    recognition.onerror = (event) => {
        if (onError) onError(event);
    };
    recognition.start();
}

export function speakLastAssistantMessage(chatHistory) {
    if (!('speechSynthesis' in window) || !chatHistory) return;
    const msgs = Array.from(chatHistory.querySelectorAll('.message.assistant .message-content'));
    if (!msgs.length) return;
    const lastMsg = msgs[msgs.length - 1].innerText;
    const utter = new window.SpeechSynthesisUtterance(lastMsg);
    utter.lang = 'en-US';
    window.speechSynthesis.speak(utter);
}
