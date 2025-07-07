// modules/theme.js
/**
 * Theme switching and persistence for Local AI Assistant
 * Exports: loadTheme, toggleTheme
 */

const THEME_KEY = 'ai-assistant-theme';

/**
 * Load theme from storage or system preference and apply to document
 * @param {HTMLElement} themeToggle - Theme toggle button (optional, for icon update)
 */
export function loadTheme(themeToggle) {
    let theme = 'light';
    try {
        theme = localStorage.getItem(THEME_KEY) || (window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light');
    } catch {}
    document.body.setAttribute('data-theme', theme);
    if (themeToggle) themeToggle.textContent = theme === 'dark' ? '☀️' : '🌙';
}

/**
 * Toggle dark/light theme and persist selection
 * @param {HTMLElement} themeToggle - Theme toggle button (optional, for icon update)
 */
export function toggleTheme(themeToggle) {
    const current = document.body.getAttribute('data-theme');
    const next = current === 'dark' ? 'light' : 'dark';
    document.body.setAttribute('data-theme', next);
    if (themeToggle) themeToggle.textContent = next === 'dark' ? '☀️' : '🌙';
    try {
        localStorage.setItem(THEME_KEY, next);
    } catch {}
}
