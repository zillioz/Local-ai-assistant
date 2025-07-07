# CREATE_AI_ASSISTANT_PART5.ps1
# Run this after Part 4
# This creates the API endpoints

Write-Host @"
====================================
  LOCAL AI ASSISTANT INSTALLER
  Part 5: API Endpoints
====================================
"@ -ForegroundColor Cyan

# Check if we're in the right directory
if (-not (Test-Path "backend\api")) {
    Write-Host "ERROR: Please run this script from the local-ai-assistant directory!" -ForegroundColor Red
    exit
}

Write-Host "`nCreating API endpoint files..." -ForegroundColor Yellow

# Function to create files
function Create-File {
    param($Path, $Content)
    $Content | Set-Content -Path $Path -Encoding UTF8
    Write-Host "Created: $Path" -ForegroundColor Green
}

# Create backend/api/chat.py (split due to size)
$chatPyPart1 = @'
"""
Chat API endpoints for the Local AI Assistant.
Handles chat requests and responses.
"""
from fastapi import APIRouter, HTTPException, Depends, Request, UploadFile, File
from fastapi.responses import StreamingResponse, Response
from typing import Optional
import json
import base64

from backend.models.chat import ChatRequest, ChatResponse, Message, ToolCall
from backend.services.chat_manager import chat_manager
from backend.services.llm_service import LLMService
from backend.logger import log
from backend.config import settings
from backend.services.tool_manager import tool_manager


router = APIRouter()


async def get_llm_service(request: Request) -> LLMService:
    """Dependency to get LLM service."""
    if not hasattr(request.app.state, "llm_service"):
        raise HTTPException(status_code=503, detail="LLM service not available")
    return request.app.state.llm_service


@router.post("/message", response_model=ChatResponse)
async def send_message(
    request: ChatRequest,
    llm_service: LLMService = Depends(get_llm_service)
):
    """Send a message and get a response."""
    try:
        # Get or create session
        if request.session_id:
            session = await chat_manager.get_session(request.session_id)
            if not session:
                session = await chat_manager.create_session(request.session_id)
        else:
            session = await chat_manager.create_session()
        
        # Add user message
        user_message = await chat_manager.add_message(
            session_id=session.session_id,
            role="user",
            content=request.message
        )
        
        # Get conversation context
        context = await chat_manager.get_conversation_context(
            session.session_id,
            max_messages=10
        )
        
        # Generate response
        response_text = ""
        async for chunk in llm_service.chat(
            messages=context,
            stream=False
        ):
            response_text += chunk
        
        # Parse for tool calls
        tool_calls = parse_tool_calls(response_text)
        
        # Add assistant message
        assistant_message = await chat_manager.add_message(
            session_id=session.session_id,
            role="assistant",
            content=response_text,
            metadata={"tool_calls": [tc.dict() for tc in tool_calls]}
        )
        
        # Process tool calls if any
        requires_confirmation = any(tc.requires_confirmation for tc in tool_calls)
        
        return ChatResponse(
            message=assistant_message,
            session_id=session.session_id,
            tool_calls=tool_calls,
            requires_confirmation=requires_confirmation
        )
        
    except Exception as e:
        log.error(f"Error processing message: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/message/stream")
async def send_message_stream(
    request: ChatRequest,
    llm_service: LLMService = Depends(get_llm_service)
):
    """Send a message and stream the response."""
    try:
        # Get or create session
        if request.session_id:
            session = await chat_manager.get_session(request.session_id)
            if not session:
                session = await chat_manager.create_session(request.session_id)
        else:
            session = await chat_manager.create_session()
        
        # Add user message
        await chat_manager.add_message(
            session_id=session.session_id,
            role="user",
            content=request.message
        )
        
        # Get conversation context
        context = await chat_manager.get_conversation_context(
            session.session_id,
            max_messages=10
        )
        
        async def generate():
            """Generate streaming response."""
            # Send session info first
            yield f"data: {json.dumps({'type': 'session', 'session_id': session.session_id})}\n\n"
            
            # Stream LLM response
            full_response = ""
            async for chunk in llm_service.chat(
                messages=context,
                stream=True
            ):
                full_response += chunk
                yield f"data: {json.dumps({'type': 'content', 'content': chunk})}\n\n"
            
            # Parse for tool calls
            tool_calls = parse_tool_calls(full_response)
            if tool_calls:
                yield f"data: {json.dumps({'type': 'tool_calls', 'tool_calls': [tc.dict() for tc in tool_calls]})}\n\n"
            
            # Save assistant message
            await chat_manager.add_message(
                session_id=session.session_id,
                role="assistant",
                content=full_response,
                metadata={"tool_calls": [tc.dict() for tc in tool_calls]}
            )
            
            # Send done signal
            yield f"data: {json.dumps({'type': 'done'})}\n\n"
        
        return StreamingResponse(
            generate(),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
            }
        )
        
    except Exception as e:
        log.error(f"Error in streaming message: {e}")
        raise HTTPException(status_code=500, detail=str(e))
'@

$chatPyPart2 = @'


@router.get("/sessions/{session_id}")
async def get_session_info(session_id: str):
    """Get session information."""
    session = await chat_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    conversation = await chat_manager.get_conversation(session.conversation_id)
    
    return {
        "session": session,
        "message_count": len(conversation.messages) if conversation else 0,
        "last_messages": conversation.messages[-5:] if conversation else []
    }


@router.delete("/sessions/{session_id}")
async def end_session(session_id: str):
    """End a chat session."""
    session = await chat_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    await chat_manager.end_session(session_id)
    return {"message": "Session ended successfully"}


@router.get("/sessions/{session_id}/export")
async def export_conversation(session_id: str, format: str = "json"):
    """Export conversation in various formats."""
    session = await chat_manager.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    conversation = await chat_manager.get_conversation(session.conversation_id)
    if not conversation:
        raise HTTPException(status_code=404, detail="Conversation not found")
    
    if format == "json":
        # JSON export
        return {
            "session_id": session_id,
            "created_at": conversation.created_at.isoformat(),
            "messages": [msg.dict() for msg in conversation.messages]
        }
    elif format == "markdown":
        # Markdown export
        md_content = f"# Conversation Export\n\n"
        md_content += f"**Session ID:** {session_id}\n"
        md_content += f"**Date:** {conversation.created_at.strftime('%Y-%m-%d %H:%M:%S')}\n\n"
        
        for msg in conversation.messages:
            role = msg.role.capitalize()
            timestamp = msg.timestamp.strftime('%H:%M:%S')
            md_content += f"## {role} ({timestamp})\n\n{msg.content}\n\n"
        
        return Response(
            content=md_content,
            media_type="text/markdown",
            headers={
                "Content-Disposition": f"attachment; filename=conversation_{session_id[:8]}.md"
            }
        )
    else:
        raise HTTPException(status_code=400, detail="Unsupported format")


@router.get("/stats")
async def get_chat_stats():
    """Get chat statistics."""
    return chat_manager.get_stats()


@router.post("/tools/execute")
async def execute_tool(
    session_id: str,
    tool_call: ToolCall,
    confirm: bool = False
):
    """Execute a tool with optional confirmation."""
    try:
        # Validate tool call
        validation_error = tool_manager.validate_tool_call(tool_call)
        if validation_error:
            raise HTTPException(status_code=400, detail=validation_error)
        
        # Execute tool
        result = await tool_manager.execute_tool(
            session_id=session_id,
            tool_call=tool_call,
            confirm=confirm
        )
        
        # Add tool result to conversation
        if result.success:
            await chat_manager.add_message(
                session_id=session_id,
                role="tool",
                content=f"Tool: {tool_call.tool_name}\nResult: {result.output}",
                metadata={"tool_result": result.dict()}
            )
        
        return result
        
    except HTTPException:
        raise
    except Exception as e:
        log.error(f"Error executing tool: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/tools")
async def list_tools():
    """List all available tools."""
    return {
        "tools": [tool.dict() for tool in tool_manager.list_tools()],
        "stats": tool_manager.get_tool_stats()
    }


@router.get("/tools/{tool_name}")
async def get_tool_info(tool_name: str):
    """Get detailed information about a specific tool."""
    tool = tool_manager.get_tool(tool_name)
    if not tool:
        raise HTTPException(status_code=404, detail="Tool not found")
    
    return {
        "metadata": tool.metadata.dict(),
        "usage_help": tool.get_usage_help()
    }


@router.post("/upload")
async def upload_file(
    session_id: str,
    file: UploadFile = File(...)
):
    """Handle file upload."""
    try:
        # Validate file
        if not file.filename:
            raise HTTPException(status_code=400, detail="No filename provided")
        
        # Check file size
        contents = await file.read()
        size = len(contents)
        max_size = settings.max_file_size_mb * 1024 * 1024
        
        if size > max_size:
            raise HTTPException(
                status_code=413,
                detail=f"File too large: {size/(1024*1024):.1f}MB (max: {settings.max_file_size_mb}MB)"
            )
        
        # Encode to base64
        content_base64 = base64.b64encode(contents).decode('utf-8')
        
        # Use file upload tool
        upload_tool = tool_manager.get_tool("file_upload")
        if not upload_tool:
            raise HTTPException(status_code=500, detail="File upload tool not available")
        
        # Execute upload
        result = await upload_tool.execute(
            session_id=session_id,
            filename=file.filename,
            content=content_base64,
            size=size
        )
        
        if result.success:
            # Add to conversation
            await chat_manager.add_message(
                session_id=session_id,
                role="system",
                content=f"File uploaded: {result.output['original_name']} -> {result.output['saved_as']}",
                metadata={"file_upload": result.output}
            )
            
            return {
                "success": True,
                "file": result.output
            }
        else:
            raise HTTPException(status_code=500, detail=result.error)
            
    except HTTPException:
        raise
    except Exception as e:
        log.error(f"Error uploading file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


def parse_tool_calls(response: str) -> list[ToolCall]:
    """
    Parse tool calls from LLM response.
    Looking for patterns like:
    [TOOL: web_search("query")]
    [TOOL: read_file("path/to/file.txt")]
    """
    tool_calls = []
    
    # Simple pattern matching for now
    # In production, you'd want more robust parsing
    import re
    
    # Pattern: [TOOL: tool_name(parameters)]
    pattern = r'\[TOOL:\s*(\w+)\((.*?)\)\]'
    matches = re.findall(pattern, response)
    
    for tool_name, params_str in matches:
        # Parse parameters (simple for now)
        params = {}
        if params_str:
            # Try to parse as JSON-like
            try:
                # Remove quotes and split by comma
                params_str = params_str.strip('"\'')
                if tool_name in ["web_search", "read_file", "write_file"]:
                    params = {"query": params_str} if tool_name == "web_search" else {"path": params_str}
            except:
                pass
        
        # Determine if confirmation required
        requires_confirmation = tool_name in [
            "write_file", "delete_file", "system_command"
        ]
        
        tool_calls.append(ToolCall(
            tool_name=tool_name,
            parameters=params,
            requires_confirmation=requires_confirmation
        ))
    
    return tool_calls
'@

# Combine and create chat.py
Create-File "backend\api\chat.py" ($chatPyPart1 + $chatPyPart2)

# Create backend/api/websocket.py
Create-File "backend\api\websocket.py" @'
"""
WebSocket API for real-time chat communication.
Handles bidirectional streaming between client and server.
"""
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import Dict, Set
import json
import asyncio

from backend.services.chat_manager import chat_manager
from backend.services.llm_service import LLMService
from backend.logger import log
from backend.api.chat import parse_tool_calls


router = APIRouter()

# Track active connections
active_connections: Dict[str, WebSocket] = {}


class ConnectionManager:
    """Manages WebSocket connections."""
    
    def __init__(self):
        self.active_connections: Dict[str, WebSocket] = {}
        
    async def connect(self, websocket: WebSocket, session_id: str):
        """Accept and track a new connection."""
        await websocket.accept()
        self.active_connections[session_id] = websocket
        log.info(f"WebSocket connected: {session_id}")
        
    def disconnect(self, session_id: str):
        """Remove a connection."""
        if session_id in self.active_connections:
            del self.active_connections[session_id]
            log.info(f"WebSocket disconnected: {session_id}")
            
    async def send_json(self, session_id: str, data: dict):
        """Send JSON data to a specific connection."""
        if session_id in self.active_connections:
            websocket = self.active_connections[session_id]
            await websocket.send_json(data)
            
    async def broadcast_json(self, data: dict):
        """Broadcast JSON data to all connections."""
        disconnected = []
        for session_id, websocket in self.active_connections.items():
            try:
                await websocket.send_json(data)
            except:
                disconnected.append(session_id)
        
        # Clean up disconnected
        for session_id in disconnected:
            self.disconnect(session_id)


# Global connection manager
manager = ConnectionManager()


@router.websocket("/chat")
async def websocket_chat(websocket: WebSocket):
    """WebSocket endpoint for real-time chat."""
    session_id = None
    
    try:
        # Accept connection
        await websocket.accept()
        
        # Wait for initial message with session ID
        data = await websocket.receive_json()
        
        if data.get("type") == "init":
            session_id = data.get("session_id")
            if not session_id:
                # Create new session
                session = await chat_manager.create_session()
                session_id = session.session_id
            else:
                # Get existing session
                session = await chat_manager.get_session(session_id)
                if not session:
                    session = await chat_manager.create_session(session_id)
                    
            # Track connection
            await manager.connect(websocket, session_id)
            
            # Send session info
            await websocket.send_json({
                "type": "session",
                "session_id": session_id,
                "status": "connected"
            })
            
            log.info(f"WebSocket chat initialized: {session_id}")
        else:
            await websocket.close(code=1003, reason="Expected init message")
            return
            
        # Get LLM service
        llm_service = websocket.app.state.llm_service
        
        # Handle messages
        while True:
            data = await websocket.receive_json()
            
            if data.get("type") == "message":
                await handle_chat_message(
                    websocket, session_id, data.get("content"), llm_service
                )
            elif data.get("type") == "tool_confirm":
                await handle_tool_confirmation(
                    websocket, session_id, data.get("tool_id"), data.get("confirmed")
                )
            elif data.get("type") == "ping":
                await websocket.send_json({"type": "pong"})
            else:
                await websocket.send_json({
                    "type": "error",
                    "message": f"Unknown message type: {data.get('type')}"
                })
                
    except WebSocketDisconnect:
        if session_id:
            manager.disconnect(session_id)
    except Exception as e:
        log.error(f"WebSocket error: {e}")
        await websocket.send_json({
            "type": "error",
            "message": str(e)
        })
        await websocket.close()
    finally:
        if session_id:
            manager.disconnect(session_id)


async def handle_chat_message(
    websocket: WebSocket,
    session_id: str,
    content: str,
    llm_service: LLMService
):
    """Handle incoming chat message."""
    try:
        # Add user message
        await chat_manager.add_message(
            session_id=session_id,
            role="user",
            content=content
        )
        
        # Send acknowledgment
        await websocket.send_json({
            "type": "message_received",
            "status": "processing"
        })
        
        # Get conversation context
        context = await chat_manager.get_conversation_context(
            session_id,
            max_messages=10
        )
        
        # Stream LLM response
        full_response = ""
        await websocket.send_json({"type": "stream_start"})
        
        async for chunk in llm_service.chat(
            messages=context,
            stream=True
        ):
            full_response += chunk
            await websocket.send_json({
                "type": "stream_chunk",
                "content": chunk
            })
        
        await websocket.send_json({"type": "stream_end"})
        
        # Parse for tool calls
        tool_calls = parse_tool_calls(full_response)
        
        # Save assistant message
        await chat_manager.add_message(
            session_id=session_id,
            role="assistant",
            content=full_response,
            metadata={"tool_calls": [tc.dict() for tc in tool_calls]}
        )
        
        # Send tool calls if any
        if tool_calls:
            await websocket.send_json({
                "type": "tool_calls",
                "tool_calls": [
                    {
                        "id": f"{tc.tool_name}_{i}",
                        "name": tc.tool_name,
                        "parameters": tc.parameters,
                        "requires_confirmation": tc.requires_confirmation
                    }
                    for i, tc in enumerate(tool_calls)
                ]
            })
        
        # Send completion
        await websocket.send_json({
            "type": "message_complete",
            "message_id": full_response[:8]  # Simple ID
        })
        
    except Exception as e:
        log.error(f"Error handling chat message: {e}")
        await websocket.send_json({
            "type": "error",
            "message": f"Error processing message: {str(e)}"
        })


async def handle_tool_confirmation(
    websocket: WebSocket,
    session_id: str,
    tool_id: str,
    confirmed: bool
):
    """Handle tool execution confirmation."""
    try:
        if confirmed:
            await websocket.send_json({
                "type": "tool_executing",
                "tool_id": tool_id
            })
            
            # TODO: Execute tool here
            # For now, just simulate
            await asyncio.sleep(1)
            
            await websocket.send_json({
                "type": "tool_result",
                "tool_id": tool_id,
                "success": True,
                "result": "Tool execution simulated"
            })
        else:
            await websocket.send_json({
                "type": "tool_cancelled",
                "tool_id": tool_id
            })
            
    except Exception as e:
        log.error(f"Error handling tool confirmation: {e}")
        await websocket.send_json({
            "type": "error",
            "message": f"Error executing tool: {str(e)}"
        })
'@

Write-Host @"

Part 5 files created successfully!

API endpoints are now ready:
✓ Chat API (REST and streaming)
✓ WebSocket for real-time chat
✓ Session management
✓ Tool execution
✓ File upload
✓ Conversation export

Next: Run CREATE_AI_ASSISTANT_PART6.ps1 for:
- Frontend CSS
- Frontend JavaScript
- Launcher scripts

"@ -ForegroundColor Green