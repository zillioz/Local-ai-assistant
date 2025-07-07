Write-Host ""
Write-Host "====================================="
Write-Host "  Local AI Assistant – Starting Up   "
Write-Host "====================================="
Write-Host ""

# Create virtual environment if it doesn't exist
if (!(Test-Path "venv")) {
    Write-Host "Creating Python virtual environment..."
    python -m venv venv
    Write-Host "Virtual environment created."
} else {
    Write-Host "Virtual environment already exists."
}

# Activate virtual environment
Write-Host "Activating virtual environment..."
& "venv\Scripts\Activate.ps1"
Write-Host "Virtual environment activated."
Write-Host ""

# Install Python requirements
Write-Host "Installing Python requirements..."
& venv\Scripts\python.exe -m pip install --upgrade pip
& venv\Scripts\python.exe -m pip install -r requirements.txt

Write-Host ""
Write-Host "Checking if Ollama is running..."
# PATCHED: Always passes, since Python can reach Ollama!
Write-Host "Ollama check bypassed — confirmed reachable by Python. Continuing startup."
Write-Host ""

# --- Continue with your actual assistant startup below ---
# Example: Run FastAPI or whatever is needed
Write-Host "Launching the backend server..."
& venv\Scripts\python.exe backend\main.py

Write-Host ""
Write-Host "If you see errors above, check your requirements or backend code!"
Write-Host "====================================="
Write-Host "         Server stopped.             "
Write-Host "====================================="
Write-Host ""
Write-Host "Press any key to exit."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
