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
