#!/bin/bash

# Navigate to the working directory
if [ -d "$HOME/video-rag" ]; then
    cd $HOME/video-rag
else
    cd $HOME/work/video-rag
fi

# Ensure log directory exists
mkdir -p ~/.cache/log/

# Add Poetry to PATH
export PATH="$HOME/.local/bin:$PATH"

# Export an environment variable to indicate running in a script environment
export RUNNING_IN_SCRIPT=1

# Set environment variables for log file paths
export ST_LOG_FILE_PATH=~/.cache/log/video_rag_streamlit.log
export API_LOG_FILE_PATH=~/.cache/log/video_rag_uvicorn.log

# Function to check if a service is running
check_service() {
    local service_name="$1"
    if systemctl is-active --quiet "$service_name"; then
        echo "$(date): $service_name is already running"
        return 0
    else
        echo "$(date): $service_name is not running"
        return 1
    fi
}

# Function to start a service
start_service() {
    local service_name="$1"
    echo "$(date): Starting $service_name..."
    if sudo systemctl start "$service_name"; then
        echo "$(date): $service_name started successfully"
        return 0
    else
        echo "$(date): Failed to start $service_name"
        return 1
    fi
}

# Function to check if Ollama is responding
check_ollama_api() {
    echo "$(date): Checking Ollama API..."
    if curl -s http://localhost:11434/api/tags >/dev/null 2>&1; then
        echo "$(date): Ollama API is responding"
        return 0
    else
        echo "$(date): Ollama API is not responding"
        return 1
    fi
}

echo "$(date): Starting required services for Video-RAG..."

# 1. Start Ollama service
if ! check_service ollama; then
    start_service ollama
    # Wait a bit for Ollama to fully start
    sleep 3
fi

# Check if Ollama API is responding
if ! check_ollama_api; then
    echo "$(date): Waiting for Ollama to be ready..."
    sleep 5
    if ! check_ollama_api; then
        echo "$(date): Warning: Ollama API may not be ready. Continuing anyway..."
    fi
fi

# 2. Start Docker service (if installed)
if command -v docker >/dev/null 2>&1; then
    # Check if Docker is available (snap version doesn't use systemd service)
    if docker ps >/dev/null 2>&1; then
        echo "$(date): Docker is already running"
    else
        echo "$(date): Docker is not responding, checking if it's a snap installation..."
        # For snap installations, Docker should start automatically
        # Wait a moment and check again
        sleep 2
        if ! docker ps >/dev/null 2>&1; then
            echo "$(date): Warning: Docker is not responding. You may need to restart it manually."
        else
            echo "$(date): Docker is now responding"
        fi
    fi
    
    # Start Docker Compose services if docker directory exists
    if [ -d "./docker" ]; then
        echo "$(date): Starting Docker Compose services..."
        cd ./docker
        if docker compose ps >/dev/null 2>&1; then
            echo "$(date): Docker Compose services are already running"
        else
            if docker compose up -d; then
                echo "$(date): Docker Compose services started successfully"
            else
                echo "$(date): Warning: Failed to start Docker Compose services"
            fi
        fi
        cd ..
    fi
else
    echo "$(date): Docker not found, skipping Docker services"
fi

# Function to kill processes matching a pattern
kill_processes() {
  local pattern="$1"
  ps aux | grep "$pattern" | grep -v grep | awk '{print $2}' | xargs -r kill -9
}

# Stop the running instances if any
echo "$(date): Stopping running video-rag instances..."
kill_processes "python -m streamlit run web/front.py"
kill_processes "uvicorn api.main:app --host 0.0.0.0 --port 12001"

# Wait for a few seconds to ensure the processes have stopped
sleep 5

# Run poetry install and append the output to the log file
echo "$(date): Running poetry install..."
poetry install >> ~/.cache/log/poetry_install.log 2>&1

# Check if poetry install was successful
if [ $? -eq 0 ]; then
  echo "$(date): Starting video-rag applications..."
  # Start the processes in the background and append all output to log files
  nohup poetry run python -m streamlit run web/front.py --server.port 8501 >> "$ST_LOG_FILE_PATH" 2>&1 < /dev/null &
  nohup poetry run uvicorn api.main:app --host 0.0.0.0 --port 12001 >> "$API_LOG_FILE_PATH" 2>&1 < /dev/null &
  echo "$(date): Video-RAG applications started."
  echo "$(date): Frontend (Streamlit) running on http://localhost:8501"
  echo "$(date): Backend (FastAPI) running on http://localhost:12001"
else
  echo "$(date): Poetry install failed. Check ~/.cache/log/poetry_install.log for details."
fi
