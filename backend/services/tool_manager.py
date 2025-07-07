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
