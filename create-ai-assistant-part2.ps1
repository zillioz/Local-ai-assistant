# CREATE_AI_ASSISTANT_PART2.ps1
# Run this after CREATE_AI_ASSISTANT.ps1
# This creates the core backend files

Write-Host @"
====================================
  LOCAL AI ASSISTANT INSTALLER
  Part 2: Core Backend Files
====================================
"@ -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend")) {
    Write-Host "ERROR: Please run this script from the local-ai-assistant directory!" -ForegroundColor Red
    Write-Host "First run CREATE_AI_ASSISTANT.ps1, then run this from that directory." -ForegroundColor Yellow
    exit
}

Write-Host "`nCreating core backend files..." -ForegroundColor Yellow

# Function to create files
function Create-File {
    param($Path, $Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Created: $Path" -ForegroundColor Green
}

# Create backend/logger.py
Create-File "backend\logger.py" @'
"""
Logging configuration for the application.
Uses loguru for better formatting and features.
"""
import sys
from pathlib import Path
from loguru import logger
from backend.config import settings


def setup_logging():
    """Configure application logging."""
    # Remove default logger
    logger.remove()
    
    # Console logging with color
    logger.add(
        sys.stdout,
        format="<green>{time:YYYY-MM-DD HH:mm:ss}</green> | <level>{level: <8}</level> | <cyan>{name}</cyan>:<cyan>{function}</cyan>:<cyan>{line}</cyan> - <level>{message}</level>",
        level=settings.log_level,
        colorize=True
    )
    
    # File logging for errors
    logger.add(
        Path("logs") / "error.log",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
        level="ERROR",
        rotation="10 MB",
        retention="1 week",
        compression="zip"
    )
    
    # File logging for all logs
    logger.add(
        Path("logs") / "app.log",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {name}:{function}:{line} - {message}",
        level="DEBUG" if settings.debug else "INFO",
        rotation="50 MB",
        retention="1 week",
        compression="zip"
    )
    
    # Security audit log
    logger.add(
        Path("logs") / "security.log",
        format="{time:YYYY-MM-DD HH:mm:ss} | {level: <8} | {extra[user]} | {extra[action]} | {extra[resource]} | {message}",
        level="INFO",
        filter=lambda record: "security" in record["extra"],
        rotation="10 MB",
        retention="1 month"
    )
    
    logger.info(f"Logging configured. Level: {settings.log_level}")
    
    return logger


# Initialize logger
log = setup_logging()
'@

# Create backend/models/chat.py
Create-File "backend\models\chat.py" @'
"""
Data models for chat functionality.
Uses Pydantic for validation and serialization.
"""
from typing import Optional, List, Dict, Any, Literal
from datetime import datetime
from pydantic import BaseModel, Field, validator
from uuid import uuid4


class Message(BaseModel):
    """Individual chat message model."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    role: Literal["user", "assistant", "system", "tool"] = Field(..., description="Message sender role")
    content: str = Field(..., description="Message content")
    timestamp: datetime = Field(default_factory=datetime.now)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    @validator("content")
    def content_not_empty(cls, v):
        """Ensure message content is not empty."""
        if not v or not v.strip():
            raise ValueError("Message content cannot be empty")
        return v.strip()
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class ToolCall(BaseModel):
    """Model for tool invocation requests."""
    tool_name: str = Field(..., description="Name of the tool to invoke")
    parameters: Dict[str, Any] = Field(default_factory=dict)
    requires_confirmation: bool = Field(default=True)
    
    @validator("tool_name")
    def validate_tool_name(cls, v):
        """Validate tool name format."""
        if not v.replace("_", "").isalnum():
            raise ValueError("Tool name must be alphanumeric with underscores")
        return v.lower()


class ToolResult(BaseModel):
    """Model for tool execution results."""
    tool_name: str
    success: bool
    result: Any
    error: Optional[str] = None
    execution_time: float = Field(..., description="Execution time in seconds")
    requires_user_action: bool = False


class ChatRequest(BaseModel):
    """Request model for chat endpoint."""
    message: str = Field(..., min_length=1, max_length=10000)
    session_id: Optional[str] = None
    stream: bool = Field(default=False)
    
    @validator("message")
    def clean_message(cls, v):
        """Clean and validate message."""
        return v.strip()


class ChatResponse(BaseModel):
    """Response model for chat endpoint."""
    message: Message
    session_id: str
    tool_calls: List[ToolCall] = Field(default_factory=list)
    requires_confirmation: bool = False


class Conversation(BaseModel):
    """Model for a complete conversation."""
    id: str = Field(default_factory=lambda: str(uuid4()))
    messages: List[Message] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    metadata: Dict[str, Any] = Field(default_factory=dict)
    
    def add_message(self, message: Message):
        """Add a message to the conversation."""
        self.messages.append(message)
        self.updated_at = datetime.now()
        
        # Enforce conversation length limit
        from backend.config import settings
        if len(self.messages) > settings.max_conversation_length:
            # Keep system messages and recent messages
            system_messages = [m for m in self.messages if m.role == "system"]
            other_messages = [m for m in self.messages if m.role != "system"]
            keep_count = settings.max_conversation_length - len(system_messages) - 10
            self.messages = system_messages + other_messages[-keep_count:]
    
    def get_context(self, max_messages: int = 10) -> List[Dict[str, str]]:
        """Get conversation context for LLM."""
        recent_messages = self.messages[-max_messages:]
        return [
            {"role": msg.role, "content": msg.content}
            for msg in recent_messages
        ]
    
    class Config:
        json_encoders = {
            datetime: lambda v: v.isoformat()
        }


class SessionInfo(BaseModel):
    """Information about a chat session."""
    session_id: str
    conversation_id: str
    created_at: datetime
    last_activity: datetime
    message_count: int
    active: bool = True
'@

# Create backend/services/llm_service.py
Create-File "backend\services\llm_service.py" @'
"""
LLM Service for interacting with Ollama.
Provides a clean interface for chat completions and model management.
"""
from typing import List, Dict, Any, Optional, AsyncGenerator
import httpx
import json
from backend.config import settings
from backend.logger import log


class LLMService:
    """Service for managing LLM interactions."""
    
    def __init__(self):
        self.client = httpx.AsyncClient(timeout=60.0)
        self.base_url = settings.ollama_host
        self.default_model = settings.default_model
        
    async def initialize(self):
        """Initialize the LLM service and check connectivity."""
        try:
            # Check if Ollama is running
            response = await self.client.get(f"{self.base_url}/api/tags")
            if response.status_code == 200:
                models = response.json().get("models", [])
                log.info(f"Connected to Ollama. Available models: {[m[''name''] for m in models]}")
                
                # Check if default model is available
                model_names = [m[''name''] for m in models]
                if self.default_model not in model_names:
                    log.warning(f"Default model {self.default_model} not found. Available: {model_names}")
                    if models:
                        self.default_model = models[0][''name'']
                        log.info(f"Using {self.default_model} as default model")
                    else:
                        raise Exception("No models available in Ollama")
            else:
                raise Exception(f"Ollama returned status {response.status_code}")
        except Exception as e:
            log.error(f"Failed to connect to Ollama: {e}")
            raise
    
    async def health_check(self) -> bool:
        """Check if the LLM service is healthy."""
        try:
            response = await self.client.get(f"{self.base_url}/api/tags")
            return response.status_code == 200
        except:
            return False
    
    async def cleanup(self):
        """Cleanup resources."""
        await self.client.aclose()
    
    async def generate(
        self,
        prompt: str,
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        stream: bool = False
    ) -> AsyncGenerator[str, None]:
        """
        Generate a response from the LLM.
        
        Args:
            prompt: The input prompt
            model: Model to use (defaults to configured model)
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
            stream: Whether to stream the response
            
        Yields:
            Generated text chunks if streaming, otherwise complete response
        """
        model = model or self.default_model
        temperature = temperature or settings.temperature
        
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": stream,
            "options": {
                "temperature": temperature,
            }
        }
        
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens
        
        try:
            response = await self.client.post(
                f"{self.base_url}/api/generate",
                json=payload,
                timeout=120.0
            )
            
            if stream:
                async for line in response.aiter_lines():
                    if line:
                        data = json.loads(line)
                        if "response" in data:
                            yield data["response"]
            else:
                # Collect all chunks for non-streaming response
                full_response = ""
                async for line in response.aiter_lines():
                    if line:
                        data = json.loads(line)
                        if "response" in data:
                            full_response += data["response"]
                yield full_response
                
        except Exception as e:
            log.error(f"Error generating response: {e}")
            raise
    
    async def chat(
        self,
        messages: List[Dict[str, str]],
        model: Optional[str] = None,
        temperature: Optional[float] = None,
        max_tokens: Optional[int] = None,
        stream: bool = False,
        include_tools: bool = True
    ) -> AsyncGenerator[str, None]:
        """
        Chat completion with conversation context.
        
        Args:
            messages: List of message dicts with ''role'' and ''content''
            model: Model to use
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
            stream: Whether to stream the response
            
        Yields:
            Generated text chunks
        """
        model = model or self.default_model
        temperature = temperature or settings.temperature
        
        # Add tool information to system message if requested
        if include_tools and messages:
            # Import here to avoid circular dependency
            from backend.services.tool_manager import tool_manager
            
            # Find or create system message
            system_msg_index = None
            for i, msg in enumerate(messages):
                if msg.get("role") == "system":
                    system_msg_index = i
                    break
            
            tools_description = tool_manager.get_tools_description()
            
            if system_msg_index is not None:
                # Append to existing system message
                messages[system_msg_index]["content"] += f"\n\n{tools_description}"
            else:
                # Insert new system message at beginning
                messages.insert(0, {
                    "role": "system",
                    "content": tools_description
                })
        
        payload = {
            "model": model,
            "messages": messages,
            "stream": stream,
            "options": {
                "temperature": temperature,
            }
        }
        
        if max_tokens:
            payload["options"]["num_predict"] = max_tokens
        
        try:
            response = await self.client.post(
                f"{self.base_url}/api/chat",
                json=payload,
                timeout=120.0
            )
            
            if stream:
                async for line in response.aiter_lines():
                    if line:
                        data = json.loads(line)
                        if "message" in data and "content" in data["message"]:
                            yield data["message"]["content"]
            else:
                # Collect all chunks for non-streaming response
                full_response = ""
                async for line in response.aiter_lines():
                    if line:
                        data = json.loads(line)
                        if "message" in data and "content" in data["message"]:
                            full_response += data["message"]["content"]
                yield full_response
                
        except Exception as e:
            log.error(f"Error in chat completion: {e}")
            raise
    
    async def list_models(self) -> List[Dict[str, Any]]:
        """List available models."""
        try:
            response = await self.client.get(f"{self.base_url}/api/tags")
            if response.status_code == 200:
                return response.json().get("models", [])
            return []
        except Exception as e:
            log.error(f"Error listing models: {e}")
            return []
    
    async def pull_model(self, model_name: str) -> bool:
        """Pull a model from Ollama registry."""
        try:
            response = await self.client.post(
                f"{self.base_url}/api/pull",
                json={"name": model_name},
                timeout=None  # Model downloads can take a while
            )
            return response.status_code == 200
        except Exception as e:
            log.error(f"Error pulling model {model_name}: {e}")
            return False
'@

Write-Host @"

Part 2 files created successfully!

Next: Run CREATE_AI_ASSISTANT_PART3.ps1 for:
- Chat manager
- Tool manager  
- API endpoints
- Base tool system

"@ -ForegroundColor Green