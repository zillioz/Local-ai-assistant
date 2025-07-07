"""
Configuration management for the Local AI Assistant.
Loads settings from environment variables with validation.
"""
from typing import List, Optional
from pathlib import Path
from pydantic_settings import BaseSettings
from pydantic import Field, validator
import os


class Settings(BaseSettings):
    """Application settings with environment variable support."""
    
    # Application
    app_name: str = Field(default="Local AI Assistant", env="APP_NAME")
    app_version: str = Field(default="0.1.0", env="APP_VERSION")
    debug: bool = Field(default=False, env="DEBUG")
    log_level: str = Field(default="INFO", env="LOG_LEVEL")
    
    # Server
    host: str = Field(default="127.0.0.1", env="HOST")
    port: int = Field(default=8000, env="PORT")
    reload: bool = Field(default=False, env="RELOAD")
    
    # Security
    secret_key: str = Field(..., env="SECRET_KEY")
    cors_origins: Optional[str] = Field(
        default="http://localhost:8000,http://127.0.0.1:8000",
        env="CORS_ORIGINS"
    )
    
    # LLM Configuration
    ollama_host: str = Field(default="http://localhost:11434", env="OLLAMA_HOST")
    default_model: str = Field(default="mistral:latest", env="DEFAULT_MODEL")
    max_tokens: int = Field(default=2048, env="MAX_TOKENS")
    temperature: float = Field(default=0.7, env="TEMPERATURE")
    
    # File System Tool
    sandbox_path: Path = Field(default=Path("./sandbox"), env="SANDBOX_PATH")
    max_file_size_mb: int = Field(default=10, env="MAX_FILE_SIZE_MB")
    allowed_file_extensions: Optional[str] = Field(
        default=".txt,.md,.json,.csv,.log,.py,.js,.html,.css",
        env="ALLOWED_FILE_EXTENSIONS"
    )
    
    # Web Browser Tool
    browser_driver: str = Field(default="edge", env="BROWSER_DRIVER")
    browser_headless: bool = Field(default=True, env="BROWSER_HEADLESS")
    browser_timeout: int = Field(default=30, env="BROWSER_TIMEOUT")
    
    # System Commands Tool
    enable_system_commands: bool = Field(default=False, env="ENABLE_SYSTEM_COMMANDS")
    command_timeout: int = Field(default=30, env="COMMAND_TIMEOUT")
    allowed_commands: Optional[str] = Field(
        default="dir,ls,echo,cat,type,find,grep",
        env="ALLOWED_COMMANDS"
    )
    
    # Rate Limiting
    rate_limit_requests: int = Field(default=100, env="RATE_LIMIT_REQUESTS")
    rate_limit_window: int = Field(default=3600, env="RATE_LIMIT_WINDOW")
    
    # Session Management
    session_timeout_minutes: int = Field(default=60, env="SESSION_TIMEOUT_MINUTES")
    max_conversation_length: int = Field(default=100, env="MAX_CONVERSATION_LENGTH")
    
    @property
    def cors_origins_list(self) -> list:
        v = self.cors_origins
        if v is None or v == "":
            return ["http://localhost:8000", "http://127.0.0.1:8000"]
        v = v.strip()
        if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        if v.startswith("[") and v.endswith("]"):
            import json
            try:
                return json.loads(v)
            except Exception:
                pass
        return [origin.strip() for origin in v.split(",") if origin.strip()]
    
    @property
    def allowed_file_extensions_list(self) -> list:
        v = self.allowed_file_extensions
        if v is None or v == "":
            return [".txt", ".md", ".json", ".csv", ".log", ".py", ".js", ".html", ".css"]
        v = v.strip()
        if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        if v.startswith("[") and v.endswith("]"):
            import json
            try:
                return json.loads(v)
            except Exception:
                pass
        return [ext.strip() for ext in v.split(",") if ext.strip()]
    
    @property
    def allowed_commands_list(self) -> list:
        v = self.allowed_commands
        if v is None or v == "":
            return ["dir", "ls", "echo", "cat", "type", "find", "grep"]
        v = v.strip()
        if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
            v = v[1:-1]
        if v.startswith("[") and v.endswith("]"):
            import json
            try:
                return json.loads(v)
            except Exception:
                pass
        return [cmd.strip() for cmd in v.split(",") if cmd.strip()]
    
    @validator("sandbox_path")
    def ensure_sandbox_exists(cls, v):
        """Ensure sandbox directory exists."""
        v = Path(v)
        v.mkdir(parents=True, exist_ok=True)
        return v.absolute()
    
    @validator("secret_key")
    def validate_secret_key(cls, v):
        """Ensure secret key is secure."""
        if v == "your-secret-key-here-change-this":
            raise ValueError(
                "Please change the SECRET_KEY in your .env file! "
                "Generate one with: python -c \"import secrets; print(secrets.token_urlsafe(32))\""
            )
        if len(v) < 32:
            raise ValueError("SECRET_KEY must be at least 32 characters long")
        return v
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False


# Create global settings instance
settings = Settings()

# Create necessary directories
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)
