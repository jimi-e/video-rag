#!/bin/bash
# Video-RAG System Environment Setup Script
# chmod +x ~/work/video-rag/system_setup.sh

# Enable strict error handling
set -e  # Exit immediately if a command exits with a non-zero status
set -u  # Treat unset variables as an error
set -o pipefail  # Return exit status of the last command in the pipe that failed

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create log directory
LOG_DIR="$HOME/.cache/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/video_rag_setup.log"

# Initialize log file
echo "=== Video-RAG Setup Started at $(date) ===" | tee "$LOG_FILE"

# Function to run command with output to both terminal and log
run_cmd() {
    local cmd="$1"
    local description="$2"
    
    echo -e "${BLUE}[INFO] Running: $description${NC}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}[CMD] $cmd${NC}" | tee -a "$LOG_FILE"
    
    if eval "$cmd" 2>&1 | tee -a "$LOG_FILE"; then
        echo -e "${GREEN}[SUCCESS] $description completed${NC}" | tee -a "$LOG_FILE"
        return 0
    else
        echo -e "${RED}[ERROR] $description failed${NC}" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Logging functions
log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo -e "${GREEN}$message${NC}" | tee -a "$LOG_FILE"
}

error() {
    local message="[ERROR] $1"
    echo -e "${RED}$message${NC}" | tee -a "$LOG_FILE"
}

warning() {
    local message="[WARNING] $1"
    echo -e "${YELLOW}$message${NC}" | tee -a "$LOG_FILE"
}

info() {
    local message="[INFO] $1"
    echo -e "${BLUE}$message${NC}" | tee -a "$LOG_FILE"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        error "Setup failed. Check log file: $LOG_FILE"
        info "You can retry the setup by running this script again"
    fi
}

# Set trap for cleanup on exit
trap cleanup EXIT

log "Starting Video-RAG system environment setup..."
log "Log file: $LOG_FILE"

# Check if running on Ubuntu/Debian
if ! command_exists apt-get; then
    error "This script is designed for Ubuntu/Debian systems with apt package manager"
    exit 1
fi

# Update system packages
log "Updating system packages..."
run_cmd "sudo apt-get update -y" "System package list update"
run_cmd "sudo apt-get upgrade -y" "System package upgrade"

# Install update manager and perform release upgrade
log "Installing update manager..."
run_cmd "sudo apt install update-manager-core -y" "Update manager installation"

info "Performing distribution release upgrade (this may take a long time)..."
if ! run_cmd "sudo do-release-upgrade -f DistUpgradeViewNonInteractive" "Distribution release upgrade"; then
    warning "Release upgrade failed or no new release available, continuing..."
fi

# Install build tools
log "Installing build tools..."
run_cmd "sudo apt install lld -y" "LLD linker installation"

# Install package management tools
log "Installing package management tools..."
run_cmd "sudo apt-get install -y aptitude" "Aptitude installation"

# Install FFmpeg for video processing
log "Installing FFmpeg for video processing..."
run_cmd "sudo aptitude install -y ffmpeg" "FFmpeg installation"

# Verify FFmpeg installation
if command_exists ffmpeg; then
    log "FFmpeg version: $(ffmpeg -version | head -n1)"
else
    error "FFmpeg installation verification failed"
    exit 1
fi

# Install Poetry for Python dependency management
log "Installing Poetry..."
if command_exists poetry; then
    log "Poetry is already installed: $(poetry --version)"
else
    if run_cmd "curl -sSL https://install.python-poetry.org | POETRY_VERSION=1.8.3 python3 -" "Poetry installation"; then
        # Add Poetry to PATH for current session
        export PATH="$HOME/.local/bin:$PATH"
        
        # Verify Poetry installation
        if command_exists poetry; then
            log "Poetry installed successfully: $(poetry --version)"
        else
            error "Poetry installation verification failed"
            exit 1
        fi
    else
        error "Poetry installation failed"
        exit 1
    fi
fi

# Install Python development packages
log "Installing Python development packages..."
run_cmd "sudo apt-get install -y python3-dev python3-pip python3-setuptools python3-wheel portaudio19-dev" "Python development packages installation"

# Verify Python installation
log "Python version: $(python3 --version)"
log "Pip version: $(pip3 --version)"

# Install Ollama for AI model support
log "Installing Ollama..."
if command_exists ollama; then
    log "Ollama is already installed"
else
    if run_cmd "curl -fsSL https://ollama.com/install.sh | sh" "Ollama installation"; then
        log "Ollama installed successfully"
    else
        error "Ollama installation failed"
        exit 1
    fi
fi

# Pull required AI model
log "Pulling Qwen3:7b model (this may take a while)..."
run_cmd "ollama pull qwen3:7b" "Qwen3:7b model download"

# Install Docker Compose
log "Installing Docker Compose..."
if command_exists docker-compose; then
    log "Docker Compose is already installed: $(docker-compose --version)"
else
    if run_cmd "sudo curl -SL https://github.com/docker/compose/releases/download/v2.29.6/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose" "Docker Compose download"; then
        run_cmd "sudo chmod +x /usr/local/bin/docker-compose" "Setting Docker Compose permissions"
        run_cmd "sudo ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose" "Creating Docker Compose symlink"
        
        # Verify Docker Compose installation
        if command_exists docker-compose; then
            log "Docker Compose installed successfully: $(docker-compose --version)"
        else
            error "Docker Compose installation verification failed"
            exit 1
        fi
    else
        error "Docker Compose installation failed"
        exit 1
    fi
fi

# Setup Docker environment
log "Setting up Docker environment..."
if [ -d "docker" ]; then
    cd docker
    
    if [ ! -f ".env" ]; then
        if [ -f ".env.example" ]; then
            cp .env.example .env
            log "Created .env file from .env.example"
        else
            error ".env.example file not found in docker directory"
            exit 1
        fi
    else
        log ".env file already exists"
    fi
    
    # Start Docker services
    log "Starting Docker services..."
    run_cmd "docker-compose up -d" "Docker services startup"
    
    cd ..
else
    warning "Docker directory not found, skipping Docker setup"
fi

# Final verification
log "Performing final verification..."

# Check all required commands
required_commands=("python3" "pip3" "poetry" "ffmpeg" "ollama" "docker-compose")
for cmd in "${required_commands[@]}"; do
    if command_exists "$cmd"; then
        log "✓ $cmd is available"
    else
        error "✗ $cmd is not available"
        exit 1
    fi
done

log "=== Video-RAG System Setup Completed Successfully! ==="
log "All required components have been installed and configured."
log ""
log "Next steps:"
log "1. Restart your terminal or run: source ~/.bashrc"
log "2. Navigate to your video-rag project directory"
log "3. Run: poetry install"
log "4. Run: ./start.sh"
log ""
log "Log file saved to: $LOG_FILE"