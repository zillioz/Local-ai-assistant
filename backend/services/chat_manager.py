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
