"""
Base classes and types for tools in the Local AI Assistant.
"""
from typing import Any, Dict

class ToolResult:
    def __init__(self, success: bool, output: Any = None, error: str = None):
        self.success = success
        self.output = output
        self.error = error

class ToolMetadata:
    def __init__(self, name: str, description: str = ""):
        self.name = name
        self.description = description

class BaseTool:
    name: str = "base"
    description: str = "Base tool class."

    def __init__(self, metadata: ToolMetadata = None):
        self.metadata = metadata or ToolMetadata(self.name, self.description)

    async def run(self, *args, **kwargs) -> ToolResult:
        raise NotImplementedError("Tool must implement the run method.")
