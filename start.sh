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
