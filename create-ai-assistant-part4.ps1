# CREATE_AI_ASSISTANT_PART4.ps1
# Run this after Part 3
# This creates the main app, APIs, and frontend

Write-Host @"
====================================
  LOCAL AI ASSISTANT INSTALLER
  Part 4: Main App & Frontend
====================================
"@ -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend")) {
    Write-Host "ERROR: Please run this script from the local-ai-assistant directory!" -ForegroundColor Red
    exit
}

Write-Host "`nCreating main application file..." -ForegroundColor Yellow

# Function to create files
function Create-File {
    param($Path, $Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Created: $Path" -ForegroundColor Green
}

# Create backend/main.py (split into parts due to size)
$mainPyPart1 = @'
"""
Main FastAPI application entry point.
Configures the API server with middleware, routes, and error handling.
"""
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from pathlib import Path
import time

from backend.config import settings
from backend.logger import log
from backend.api import chat, websocket
from backend.services.llm_service import LLMService
from backend.services.chat_manager import chat_manager
from backend.services.tool_manager import tool_manager


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan manager."""
    # Startup
    log.info(f"Starting {settings.app_name} v{settings.app_version}")
    
    # Initialize services
    try:
        llm_service = LLMService()
        await llm_service.initialize()
        app.state.llm_service = llm_service
        log.info("LLM service initialized successfully")
        
        # Start chat manager
        await chat_manager.start()
        log.info("Chat manager started successfully")
        
        # Initialize tool manager
        await tool_manager.initialize()
        app.state.tool_manager = tool_manager
        log.info("Tool manager initialized successfully")
    except Exception as e:
        log.error(f"Failed to initialize services: {e}")
        # Continue running even if services fail to initialize
    
    # Create necessary directories
    Path("logs").mkdir(exist_ok=True)
    settings.sandbox_path.mkdir(exist_ok=True)
    
    yield
    
    # Shutdown
    log.info("Shutting down application")
    await chat_manager.stop()
    if hasattr(app.state, "llm_service"):
        await app.state.llm_service.cleanup()


# Create FastAPI app
app = FastAPI(
    title=settings.app_name,
    version=settings.app_version,
    description="A privacy-focused local AI assistant with system interaction capabilities",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
'@

$mainPyPart2 = @'

@app.middleware("http")
async def add_security_headers(request: Request, call_next):
    """Add security headers to all responses."""
    start_time = time.time()
    response = await call_next(request)
    
    # Security headers
    response.headers["X-Content-Type-Options"] = "nosniff"
    response.headers["X-Frame-Options"] = "DENY"
    response.headers["X-XSS-Protection"] = "1; mode=block"
    response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    
    # Add request timing
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    
    return response


@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all HTTP requests."""
    # Skip logging for static files and health checks
    if request.url.path in ["/health", "/favicon.ico"] or request.url.path.startswith("/static"):
        return await call_next(request)
    
    start_time = time.time()
    
    # Log request
    log.info(f"Request: {request.method} {request.url.path}")
    
    # Process request
    response = await call_next(request)
    
    # Log response
    process_time = time.time() - start_time
    log.info(
        f"Response: {request.method} {request.url.path} "
        f"Status: {response.status_code} Time: {process_time:.3f}s"
    )
    
    return response


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """Global exception handler."""
    log.exception(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=500,
        content={
            "error": "Internal server error",
            "message": "An unexpected error occurred" if not settings.debug else str(exc),
            "request_id": str(time.time())
        }
    )


# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint."""
    health_status = {
        "status": "healthy",
        "version": settings.app_version,
        "services": {
            "llm": False,
            "file_system": settings.sandbox_path.exists(),
            "logging": True
        }
    }
    
    # Check LLM service
    if hasattr(app.state, "llm_service"):
        try:
            health_status["services"]["llm"] = await app.state.llm_service.health_check()
        except:
            pass
    
    # Overall health
    health_status["healthy"] = all(health_status["services"].values())
    
    return health_status
'@

$mainPyPart3 = @'

# Root endpoint
@app.get("/", response_class=HTMLResponse)
async def root():
    """Serve the main application page."""
    frontend_file = Path(__file__).parent.parent / "frontend" / "index.html"
    
    if frontend_file.exists():
        return HTMLResponse(content=frontend_file.read_text())
    else:
        # Fallback if frontend not found
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Local AI Assistant</title>
            <style>
                body {
                    font-family: Arial, sans-serif;
                    max-width: 800px;
                    margin: 0 auto;
                    padding: 20px;
                    background-color: #f5f5f5;
                }
                .container {
                    background-color: white;
                    padding: 30px;
                    border-radius: 10px;
                    box-shadow: 0 2px 4px rgba(0,0,0,0.1);
                }
                h1 { color: #333; }
                .status { 
                    padding: 10px;
                    background-color: #e8f5e9;
                    border-radius: 5px;
                    margin: 20px 0;
                }
                code {
                    background-color: #f5f5f5;
                    padding: 2px 5px;
                    border-radius: 3px;
                }
                .error {
                    background-color: #ffebee;
                    color: #c62828;
                    padding: 10px;
                    border-radius: 5px;
                    margin: 20px 0;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>🤖 Local AI Assistant</h1>
                <div class="status">
                    ✅ Backend server is running!
                </div>
                <div class="error">
                    ⚠️ Frontend files not found at expected location.
                </div>
                <p>Please ensure the frontend files are in the <code>frontend/</code> directory.</p>
                <p>API endpoints are still available:</p>
                <ul>
                    <li>Health Check: <code>GET /health</code></li>
                    <li>API Documentation: <code>GET /docs</code></li>
                    <li>WebSocket Chat: <code>WS /ws/chat</code></li>
                </ul>
            </div>
        </body>
        </html>
        """


@app.get("/static/{path:path}")
async def serve_static(path: str):
    """Serve static files with correct MIME types."""
    frontend_file = Path(__file__).parent.parent / "frontend" / path
    
    if not frontend_file.exists():
        raise HTTPException(status_code=404, detail="File not found")
    
    # Determine content type
    content_type = "text/plain"
    if path.endswith(".css"):
        content_type = "text/css"
    elif path.endswith(".js"):
        content_type = "application/javascript"
    elif path.endswith(".html"):
        content_type = "text/html"
    
    return Response(
        content=frontend_file.read_text(),
        media_type=content_type
    )


# API version endpoint
@app.get("/api/v1/info")
async def api_info():
    """Get API information."""
    return {
        "name": settings.app_name,
        "version": settings.app_version,
        "description": "Local AI Assistant API",
        "features": {
            "chat": True,
            "web_browsing": True,
            "file_system": True,
            "system_commands": settings.enable_system_commands
        },
        "models": {
            "default": settings.default_model,
            "available": ["mistral:latest", "llama2:latest", "codellama:latest"]
        }
    }


# Include routers
app.include_router(chat.router, prefix="/api/v1/chat", tags=["chat"])
app.include_router(websocket.router, prefix="/ws", tags=["websocket"])

# Serve static files (frontend)
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/static", StaticFiles(directory=str(frontend_path)), name="static")
    log.info(f"Serving frontend from {frontend_path}")


if __name__ == "__main__":
    import uvicorn
    
    log.info(f"Starting server on {settings.host}:{settings.port}")
    
    uvicorn.run(
        "backend.main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.reload,
        log_level=settings.log_level.lower()
    )
'@

# Combine and create main.py
Create-File "backend\main.py" ($mainPyPart1 + $mainPyPart2 + $mainPyPart3)

# Create frontend/index.html
Create-File "frontend\index.html" @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Local AI Assistant</title>
    <link rel="stylesheet" href="style.css">
</head>
<body>
    <div class="container">
        <header>
            <h1>🤖 Local AI Assistant</h1>
            <div class="status-bar">
                <span class="status-indicator" id="status">Disconnected</span>
                <button id="theme-toggle" class="btn-secondary" title="Toggle theme">🌙</button>
                <button id="export-chat" class="btn-secondary" title="Export conversation">💾</button>
                <button id="new-session" class="btn-secondary">New Session</button>
            </div>
        </header>

        <main>
            <div class="chat-container">
                <div class="messages" id="messages">
                    <div class="message system">
                        <div class="message-content">
                            Welcome! I''m your local AI assistant. I can help you with:
                            <ul>
                                <li>📁 Reading and writing files in the sandbox directory</li>
                                <li>🌐 Searching and browsing the web</li>
                                <li>💻 Running safe system commands (with your permission)</li>
                            </ul>
                            Just ask me anything!
                        </div>
                    </div>
                </div>

                <div class="tool-confirmation" id="tool-confirmation" style="display: none;">
                    <div class="confirmation-content">
                        <h3>⚠️ Tool Confirmation Required</h3>
                        <p>The AI wants to execute:</p>
                        <div class="tool-details" id="tool-details"></div>
                        <div class="confirmation-buttons">
                            <button class="btn-danger" onclick="confirmTool(false)">Cancel</button>
                            <button class="btn-success" onclick="confirmTool(true)">Allow</button>
                        </div>
                    </div>
                </div>

                <div class="input-container">
                    <div class="upload-area" id="upload-area">
                        <input type="file" id="file-input" style="display: none;" accept=".txt,.md,.json,.csv,.log,.py,.js,.html,.css">
                        <button class="btn-secondary" onclick="document.getElementById(''file-input'').click()">
                            📎 Upload File
                        </button>
                        <span class="upload-hint">or drag & drop files here</span>
                    </div>
                    <textarea 
                        id="message-input" 
                        placeholder="Type your message here... (Press Enter to send, Shift+Enter for new line)"
                        rows="3"
                    ></textarea>
                    <button id="send-button" class="btn-primary">Send</button>
                </div>
            </div>

            <aside class="sidebar">
                <h3>Session Info</h3>
                <div class="session-info">
                    <p>Session ID: <span id="session-id">None</span></p>
                    <p>Messages: <span id="message-count">0</span></p>
                </div>

                <h3>Available Tools</h3>
                <div class="tools-list" id="tools-list">
                    <div class="loading">Loading...</div>
                </div>

                <h3>Recent Activity</h3>
                <div class="activity-log" id="activity-log">
                    <p class="text-muted">No activity yet</p>
                </div>
            </aside>
        </main>
    </div>

    <script src="app.js"></script>
</body>
</html>
'@

Write-Host @"

Part 4 files created successfully!

Next: Run CREATE_AI_ASSISTANT_PART5.ps1 for:
- API endpoints (chat.py, websocket.py)
- Frontend CSS and JavaScript
- File system tools

"@ -ForegroundColor Green