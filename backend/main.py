"""
Main FastAPI application entry point.
Configures the API server with middleware, routes, and error handling.
"""
from fastapi import FastAPI, Request, Response, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.staticfiles import StaticFiles
from contextlib import asynccontextmanager
from pathlib import Path
import time

from backend.config import settings
from backend.logger import log
from backend.api import chat  # , websocket
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


# Include routers
app.include_router(chat.router, prefix="/api/v1/chat", tags=["chat"])
# app.include_router(websocket.router, prefix="/ws", tags=["websocket"])  # Disabled WebSocket routes

# Serve all frontend files at root using StaticFiles (html=True)
frontend_path = Path(__file__).parent.parent / "frontend"
if frontend_path.exists():
    app.mount("/", StaticFiles(directory=str(frontend_path), html=True), name="frontend")
    log.info(f"Serving frontend from {frontend_path} at root URL")


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
