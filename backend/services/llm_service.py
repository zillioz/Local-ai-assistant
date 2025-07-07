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
                model_names = [m['name'] for m in models]
                log.info(f"Connected to Ollama. Available models: {model_names}")
                # Normalize model name (strip :latest if needed)
                if self.default_model not in model_names:
                    # Try fallback: strip :latest if present
                    fallback = self.default_model.split(":")[0]
                    if fallback in model_names:
                        self.default_model = fallback
                        log.warning(f"Default model not found, falling back to '{fallback}'")
                    elif models:
                        self.default_model = models[0]['name']
                        log.warning(f"Default model not found, using '{self.default_model}' instead")
                    else:
                        raise Exception("No models available in Ollama")
                log.info(f"Using model: {self.default_model}")
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
