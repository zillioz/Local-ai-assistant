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


# @router.websocket("/chat")
# async def websocket_chat(websocket: WebSocket):
#     """WebSocket endpoint for real-time chat."""
#     session_id = None
    
#     try:
#         # Accept connection
#         await websocket.accept()
        
#         # Wait for initial message with session ID
#         data = await websocket.receive_json()
        
#         if data.get("type") == "init":
#             session_id = data.get("session_id")
#             if not session_id:
#                 # Create new session
#                 session = await chat_manager.create_session()
#                 session_id = session.session_id
#             else:
#                 # Get existing session
#                 session = await chat_manager.get_session(session_id)
#                 if not session:
#                     session = await chat_manager.create_session(session_id)
                    
#             # Track connection
#             await manager.connect(websocket, session_id)
            
#             # Send session info
#             await websocket.send_json({
#                 "type": "session",
#                 "session_id": session_id,
#                 "status": "connected"
#             })
            
#             log.info(f"WebSocket chat initialized: {session_id}")
#         else:
#             await websocket.close(code=1003, reason="Expected init message")
#             return
            
#         # Get LLM service
#         llm_service = websocket.app.state.llm_service
        
#         # Handle messages
#         while True:
#             data = await websocket.receive_json()
            
#             if data.get("type") == "message":
#                 await handle_chat_message(
#                     websocket, session_id, data.get("content"), llm_service
#                 )
#             elif data.get("type") == "tool_confirm":
#                 await handle_tool_confirmation(
#                     websocket, session_id, data.get("tool_id"), data.get("confirmed")
#                 )
#             elif data.get("type") == "ping":
#                 await websocket.send_json({"type": "pong"})
#             else:
#                 await websocket.send_json({
#                     "type": "error",
#                     "message": f"Unknown message type: {data.get('type')}"
#                 })
                
#     except WebSocketDisconnect:
#         if session_id:
#             manager.disconnect(session_id)
#     except Exception as e:
#         log.error(f"WebSocket error: {e}")
#         await websocket.send_json({
#             "type": "error",
#             "message": str(e)
#         })
#         await websocket.close()
#     finally:
#         if session_id:
#             manager.disconnect(session_id)


# async def handle_chat_message(
#     websocket: WebSocket,
#     session_id: str,
#     content: str,
#     llm_service: LLMService
# ):
#     """Handle incoming chat message."""
#     try:
#         # Add user message
#         await chat_manager.add_message(
#             session_id=session_id,
#             role="user",
#             content=content
#         )
        
#         # Send acknowledgment
#         await websocket.send_json({
#             "type": "message_received",
#             "status": "processing"
#         })
        
#         # Get conversation context
#         context = await chat_manager.get_conversation_context(
#             session_id,
#             max_messages=10
#         )
        
#         # Stream LLM response
#         full_response = ""
#         await websocket.send_json({"type": "stream_start"})
        
#         async for chunk in llm_service.chat(
#             messages=context,
#             stream=True
#         ):
#             full_response += chunk
#             await websocket.send_json({
#                 "type": "stream_chunk",
#                 "content": chunk
#             })
        
#         await websocket.send_json({"type": "stream_end"})
        
#         # Parse for tool calls
#         tool_calls = parse_tool_calls(full_response)
        
#         # Save assistant message
#         await chat_manager.add_message(
#             session_id=session_id,
#             role="assistant",
#             content=full_response,
#             metadata={"tool_calls": [tc.dict() for tc in tool_calls]}
#         )
        
#         # Send tool calls if any
#         if tool_calls:
#             await websocket.send_json({
#                 "type": "tool_calls",
#                 "tool_calls": [
#                     {
#                         "id": f"{tc.tool_name}_{i}",
#                         "name": tc.tool_name,
#                         "parameters": tc.parameters,
#                         "requires_confirmation": tc.requires_confirmation
#                     }
#                     for i, tc in enumerate(tool_calls)
#                 ]
#             })
        
#         # Send completion
#         await websocket.send_json({
#             "type": "message_complete",
#             "message_id": full_response[:8]  # Simple ID
#         })
        
#     except Exception as e:
#         log.error(f"Error handling chat message: {e}")
#         await websocket.send_json({
#             "type": "error",
#             "message": f"Error processing message: {str(e)}"
#         })


# async def handle_tool_confirmation(
#     websocket: WebSocket,
#     session_id: str,
#     tool_id: str,
#     confirmed: bool
# ):
#     """Handle tool execution confirmation."""
#     try:
#         if confirmed:
#             await websocket.send_json({
#                 "type": "tool_executing",
#                 "tool_id": tool_id
#             })
            
#             # TODO: Execute tool here
#             # For now, just simulate
#             await asyncio.sleep(1)
            
#             await websocket.send_json({
#                 "type": "tool_result",
#                 "tool_id": tool_id,
#                 "success": True,
#                 "result": "Tool execution simulated"
#             })
#         else:
#             await websocket.send_json({
#                 "type": "tool_cancelled",
#                 "tool_id": tool_id
#             })
            
#     except Exception as e:
#         log.error(f"Error handling tool confirmation: {e}")
#         await websocket.send_json({
#             "type": "error",
#             "message": f"Error executing tool: {str(e)}"
#         })
