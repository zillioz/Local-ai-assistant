# CREATE_AI_ASSISTANT_PART3.ps1
# Run this after Part 2
# This creates service and API files

Write-Host @"
====================================
  LOCAL AI ASSISTANT INSTALLER
  Part 3: Services and APIs
====================================
"@ -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend\services")) {
    Write-Host "ERROR: Please run this script from the local-ai-assistant directory!" -ForegroundColor Red
    exit
}

Write-Host "`nCreating service files..." -ForegroundColor Yellow

# Function to create files
function Create-File {
    param($Path, $Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Created: $Path" -ForegroundColor Green
}

# Create backend/services/chat_manager.py
Create-File "backend\services\chat_manager.py" @'
"""
Chat Manager Service for handling conversations and sessions.
Manages conversation state, history, and context.
"""
from typing import Dict, Optional, List
from datetime import datetime, timedelta
from uuid import uuid4
import asyncio

from backend.models.chat import (
    Message, Conversation, SessionInfo, 
    ChatRequest, ChatResponse, ToolCall
)
from backend.config import settings
from backend.logger import log


class ChatManager:
    """Manages chat sessions and conversations."""
    
    def __init__(self):
        # In-memory storage (could be replaced with Redis/DB later)
        self.sessions: Dict[str, SessionInfo] = {}
        self.conversations: Dict[str, Conversation] = {}
        self._cleanup_task = None
        
    async def start(self):
        """Start the chat manager and background tasks."""
        # Start session cleanup task
        self._cleanup_task = asyncio.create_task(self._cleanup_sessions())
        log.info("Chat manager started")
        
    async def stop(self):
        """Stop the chat manager."""
        if self._cleanup_task:
            self._cleanup_task.cancel()
            try:
                await self._cleanup_task
            except asyncio.CancelledError:
                pass
        log.info("Chat manager stopped")
    
    async def _cleanup_sessions(self):
        """Background task to clean up expired sessions."""
        while True:
            try:
                await asyncio.sleep(300)  # Check every 5 minutes
                
                now = datetime.now()
                timeout = timedelta(minutes=settings.session_timeout_minutes)
                
                # Find expired sessions
                expired = []
                for session_id, session in self.sessions.items():
                    if now - session.last_activity > timeout:
                        expired.append(session_id)
                
                # Remove expired sessions
                for session_id in expired:
                    await self.end_session(session_id)
                    log.info(f"Cleaned up expired session: {session_id}")
                    
            except asyncio.CancelledError:
                break
            except Exception as e:
                log.error(f"Error in session cleanup: {e}")
    
    async def create_session(self, session_id: Optional[str] = None) -> SessionInfo:
        """Create a new chat session."""
        session_id = session_id or str(uuid4())
        conversation_id = str(uuid4())
        
        # Create conversation
        conversation = Conversation(id=conversation_id)
        
        # Add system message
        system_message = Message(
            role="system",
            content=(
                "You are a helpful AI assistant with access to various tools. "
                "You can browse the web, read and write files, and execute system commands. "
                "Always ask for confirmation before performing potentially dangerous operations."
            )
        )
        conversation.add_message(system_message)
        
        # Store conversation
        self.conversations[conversation_id] = conversation
        
        # Create session
        session = SessionInfo(
            session_id=session_id,
            conversation_id=conversation_id,
            created_at=datetime.now(),
            last_activity=datetime.now(),
            message_count=0
        )
        
        # Store session
        self.sessions[session_id] = session
        
        log.info(f"Created new session: {session_id}")
        return session
    
    async def get_session(self, session_id: str) -> Optional[SessionInfo]:
        """Get session by ID."""
        session = self.sessions.get(session_id)
        if session:
            # Update last activity
            session.last_activity = datetime.now()
        return session
    
    async def end_session(self, session_id: str):
        """End a chat session."""
        session = self.sessions.get(session_id)
        if session:
            # Mark as inactive
            session.active = False
            
            # Remove from active sessions
            del self.sessions[session_id]
            
            # Optionally save conversation to disk
            # await self._save_conversation(session.conversation_id)
            
            log.info(f"Ended session: {session_id}")
    
    async def get_conversation(self, conversation_id: str) -> Optional[Conversation]:
        """Get conversation by ID."""
        return self.conversations.get(conversation_id)
    
    async def add_message(
        self, 
        session_id: str, 
        role: str, 
        content: str,
        metadata: Optional[Dict] = None
    ) -> Message:
        """Add a message to a conversation."""
        session = await self.get_session(session_id)
        if not session:
            raise ValueError(f"Session not found: {session_id}")
        
        conversation = await self.get_conversation(session.conversation_id)
        if not conversation:
            raise ValueError(f"Conversation not found: {session.conversation_id}")
        
        # Create message
        message = Message(
            role=role,
            content=content,
            metadata=metadata or {}
        )
        
        # Add to conversation
        conversation.add_message(message)
        
        # Update session
        session.message_count += 1
        session.last_activity = datetime.now()
        
        # Log for security audit
        log.bind(
            security=True,
            user=session_id,
            action="message_added",
            resource=f"conversation:{session.conversation_id}"
        ).info(f"Message added: role={role}, length={len(content)}")
        
        return message
    
    async def get_conversation_context(
        self, 
        session_id: str,
        max_messages: int = 10
    ) -> List[Dict[str, str]]:
        """Get conversation context for LLM."""
        session = await self.get_session(session_id)
        if not session:
            return []
        
        conversation = await self.get_conversation(session.conversation_id)
        if not conversation:
            return []
        
        return conversation.get_context(max_messages)
    
    async def process_tool_calls(
        self,
        session_id: str,
        tool_calls: List[ToolCall]
    ) -> List[Dict]:
        """Process tool calls from LLM response."""
        results = []
        
        for tool_call in tool_calls:
            # Log tool call for security
            log.bind(
                security=True,
                user=session_id,
                action="tool_call",
                resource=tool_call.tool_name
            ).info(f"Tool call requested: {tool_call.tool_name}")
            
            # Check if confirmation required
            if tool_call.requires_confirmation:
                results.append({
                    "tool": tool_call.tool_name,
                    "status": "requires_confirmation",
                    "parameters": tool_call.parameters
                })
            else:
                # Auto-execute safe tools
                # This will be implemented when we add tools
                results.append({
                    "tool": tool_call.tool_name,
                    "status": "not_implemented",
                    "parameters": tool_call.parameters
                })
        
        return results
    
    def get_stats(self) -> Dict:
        """Get chat manager statistics."""
        return {
            "active_sessions": len(self.sessions),
            "total_conversations": len(self.conversations),
            "total_messages": sum(
                conv.messages.__len__() 
                for conv in self.conversations.values()
            )
        }


# Global chat manager instance
chat_manager = ChatManager()
'@

# Create backend/services/tool_manager.py
Create-File "backend\services\tool_manager.py" @'
"""
Tool Manager for orchestrating tool discovery, registration, and execution.
Handles tool lifecycle and provides a unified interface for tool usage.
"""
from typing import Dict, List, Optional, Any, Type
import importlib
import inspect
from pathlib import Path

from backend.services.tools.base_tool import BaseTool, ToolResult, ToolMetadata
from backend.models.chat import ToolCall
from backend.logger import log
from backend.config import settings


class ToolManager:
    """Manages all available tools and their execution."""
    
    def __init__(self):
        self.tools: Dict[str, BaseTool] = {}
        self._initialized = False
        
    async def initialize(self):
        """Initialize the tool manager and discover tools."""
        if self._initialized:
            return
            
        log.info("Initializing tool manager...")
        
        # Auto-discover tools
        await self._discover_tools()
        
        self._initialized = True
        log.info(f"Tool manager initialized with {len(self.tools)} tools")
        
    async def _discover_tools(self):
        """Auto-discover and register tools from the tools directory."""
        tools_dir = Path(__file__).parent / "tools"
        
        for file_path in tools_dir.glob("*.py"):
            if file_path.name.startswith("_") or file_path.name == "base_tool.py":
                continue
                
            module_name = f"backend.services.tools.{file_path.stem}"
            
            try:
                # Import module
                module = importlib.import_module(module_name)
                
                # Find tool classes
                for name, obj in inspect.getmembers(module):
                    if (inspect.isclass(obj) and 
                        issubclass(obj, BaseTool) and 
                        obj != BaseTool):
                        # Instantiate and register tool
                        tool_instance = obj()
                        self.register_tool(tool_instance)
                        
            except Exception as e:
                log.error(f"Error loading tool from {module_name}: {e}")
    
    def register_tool(self, tool: BaseTool):
        """Register a tool instance."""
        tool_name = tool.metadata.name
        
        if tool_name in self.tools:
            log.warning(f"Tool {tool_name} already registered, overwriting")
            
        self.tools[tool_name] = tool
        log.info(f"Registered tool: {tool_name}")
        
    def unregister_tool(self, tool_name: str):
        """Unregister a tool."""
        if tool_name in self.tools:
            del self.tools[tool_name]
            log.info(f"Unregistered tool: {tool_name}")
    
    def get_tool(self, tool_name: str) -> Optional[BaseTool]:
        """Get a tool by name."""
        return self.tools.get(tool_name)
    
    def list_tools(self) -> List[ToolMetadata]:
        """List all available tools."""
        return [tool.metadata for tool in self.tools.values()]
    
    def get_tools_by_category(self, category: str) -> List[ToolMetadata]:
        """Get tools by category."""
        return [
            tool.metadata 
            for tool in self.tools.values() 
            if tool.metadata.category == category
        ]
    
    async def execute_tool(
        self, 
        session_id: str,
        tool_call: ToolCall,
        confirm: bool = False
    ) -> ToolResult:
        """
        Execute a tool based on a tool call.
        
        Args:
            session_id: Session ID for tracking
            tool_call: Tool call details
            confirm: Whether user confirmed execution (for dangerous tools)
        """
        tool = self.get_tool(tool_call.tool_name)
        
        if not tool:
            return ToolResult(
                success=False,
                output=None,
                error=f"Tool not found: {tool_call.tool_name}",
                execution_time=0
            )
        
        # Check confirmation requirement
        if tool.metadata.requires_confirmation and not confirm:
            return ToolResult(
                success=False,
                output=None,
                error="Tool requires user confirmation",
                execution_time=0,
                metadata={"requires_confirmation": True}
            )
        
        # Check if tool is enabled
        if not self._is_tool_enabled(tool):
            return ToolResult(
                success=False,
                output=None,
                error=f"Tool {tool_call.tool_name} is disabled",
                execution_time=0
            )
        
        # Execute tool
        return await tool.execute(session_id, **tool_call.parameters)
    
    def _is_tool_enabled(self, tool: BaseTool) -> bool:
        """Check if a tool is enabled based on configuration."""
        # System commands have special config
        if tool.metadata.category == "system" and tool.metadata.name == "system_command":
            return settings.enable_system_commands
        
        # Other tools are enabled by default
        # Can add more granular control here
        return True
    
    def get_tools_description(self) -> str:
        """Get a description of all available tools for the LLM."""
        description = "Available tools:\n\n"
        
        for category in ["file_system", "web", "system", "utility"]:
            category_tools = self.get_tools_by_category(category)
            if category_tools:
                description += f"{category.upper()} TOOLS:\n"
                
                for tool_meta in category_tools:
                    params = ", ".join(
                        f"{p.name}: {p.type}" 
                        for p in tool_meta.parameters
                    )
                    description += f"- {tool_meta.name}({params}): {tool_meta.description}\n"
                    
                    if tool_meta.examples:
                        description += f"  Example: {tool_meta.examples[0]}\n"
                        
                description += "\n"
        
        description += """
To use a tool, respond with:
[TOOL: tool_name(parameter1, parameter2)]

For example:
[TOOL: web_search("Python tutorials")]
[TOOL: read_file("notes.txt")]
"""
        
        return description
    
    def validate_tool_call(self, tool_call: ToolCall) -> Optional[str]:
        """Validate a tool call before execution."""
        tool = self.get_tool(tool_call.tool_name)
        
        if not tool:
            return f"Unknown tool: {tool_call.tool_name}"
        
        # Use tool''s validation
        return tool._validate_parameters(tool_call.parameters)
    
    def get_tool_stats(self) -> Dict[str, Any]:
        """Get statistics about tool usage."""
        stats = {
            "total_tools": len(self.tools),
            "tools_by_category": {},
            "tools_by_danger_level": {},
            "enabled_tools": 0
        }
        
        for tool in self.tools.values():
            # By category
            category = tool.metadata.category
            stats["tools_by_category"][category] = stats["tools_by_category"].get(category, 0) + 1
            
            # By danger level
            danger = str(tool.metadata.danger_level)
            stats["tools_by_danger_level"][danger] = stats["tools_by_danger_level"].get(danger, 0) + 1
            
            # Enabled count
            if self._is_tool_enabled(tool):
                stats["enabled_tools"] += 1
        
        return stats


# Global tool manager instance
tool_manager = ToolManager()
'@