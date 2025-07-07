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
