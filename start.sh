#!/bin/bash

# FastAPI Backend Startup Script for Ubuntu
# This script activates conda environment, installs dependencies, and starts the FastAPI service

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONDA_ENV_NAME="blog"  # Change this to your conda environment name
PYTHON_FILE="main.py"       # Change this to your main FastAPI file name
HOST="0.0.0.0"
PORT="8000"

echo -e "${BLUE}=== FastAPI Backend Startup Script ===${NC}"
echo

# Function to check if conda is installed
check_conda() {
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Error: conda is not installed or not in PATH${NC}"
        echo "Please install Anaconda or Miniconda first"
        exit 1
    fi
    echo -e "${GREEN}✓ Conda found${NC}"
}

# Function to initialize conda for bash
init_conda() {
    echo -e "${YELLOW}Initializing conda...${NC}"

    # Try to find conda installation
    if [ -z "$CONDA_DEFAULT_ENV" ]; then
        # Common conda paths
        CONDA_PATHS=(
            "$HOME/anaconda3/etc/profile.d/conda.sh"
            "$HOME/miniconda3/etc/profile.d/conda.sh"
            "/opt/conda/etc/profile.d/conda.sh"
            "/usr/local/anaconda3/etc/profile.d/conda.sh"
            "/usr/local/miniconda3/etc/profile.d/conda.sh"
        )

        for conda_path in "${CONDA_PATHS[@]}"; do
            if [ -f "$conda_path" ]; then
                source "$conda_path"
                echo -e "${GREEN}✓ Conda initialized from $conda_path${NC}"
                break
            fi
        done

        # If still not found, try conda init
        if [ -z "$CONDA_DEFAULT_ENV" ]; then
            conda init bash 2>/dev/null || true
            source ~/.bashrc 2>/dev/null || true
        fi
    fi
}

# Function to create conda environment if it doesn't exist
create_conda_env() {
    echo -e "${YELLOW}Checking conda environment: $CONDA_ENV_NAME${NC}"

    if ! conda env list | grep -q "$CONDA_ENV_NAME"; then
        echo -e "${YELLOW}Creating conda environment: $CONDA_ENV_NAME${NC}"
        conda create -n "$CONDA_ENV_NAME" python=3.9 -y
        echo -e "${GREEN}✓ Environment $CONDA_ENV_NAME created${NC}"
    else
        echo -e "${GREEN}✓ Environment $CONDA_ENV_NAME already exists${NC}"
    fi
}

# Function to activate conda environment
activate_conda_env() {
    echo -e "${YELLOW}Activating conda environment: $CONDA_ENV_NAME${NC}"
    eval "$(conda shell.bash hook)"
    conda activate "$CONDA_ENV_NAME"
    echo -e "${GREEN}✓ Environment activated${NC}"
}

# Function to install dependencies
install_dependencies() {
    echo -e "${YELLOW}Installing dependencies from requirements.txt${NC}"

    if [ -f "requirements.txt" ]; then
        # Check if requirements.txt is readable (not corrupted encoding)
        if ! head -1 requirements.txt >/dev/null 2>&1; then
            echo -e "${RED}Error: requirements.txt has encoding issues and cannot be read${NC}"
            echo "Please fix the encoding of requirements.txt file"
            exit 1
        fi

        # Upgrade pip first
        echo -e "${BLUE}Upgrading pip...${NC}"
        pip install --upgrade pip

        # Install dependencies with error handling
        echo -e "${BLUE}Installing dependencies...${NC}"
        if pip install -r requirements.txt; then
            echo -e "${GREEN}✓ Dependencies installed successfully${NC}"
        else
            echo -e "${RED}Error: Failed to install dependencies${NC}"
            echo "Please check your internet connection and requirements.txt file"
            exit 1
        fi
    else
        echo -e "${RED}Warning: requirements.txt not found${NC}"
        echo "Continuing without installing dependencies..."
    fi
}

# Function to check if main Python file exists
check_main_file() {
    if [ ! -f "$PYTHON_FILE" ]; then
        echo -e "${RED}Error: Main Python file '$PYTHON_FILE' not found${NC}"
        echo "Please make sure your FastAPI application file exists"
        exit 1
    fi
    echo -e "${GREEN}✓ Main file $PYTHON_FILE found${NC}"
}

# Function to start FastAPI service
start_fastapi() {
    echo -e "${YELLOW}Starting FastAPI service...${NC}"
    echo -e "${BLUE}Server will be available at: http://$HOST:$PORT${NC}"
    echo -e "${BLUE}API docs will be available at: http://$HOST:$PORT/docs${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop the server${NC}"
    echo

    # Start the FastAPI application
    python -m uvicorn "$PYTHON_FILE:app" --host "$HOST" --port "$PORT" --reload
}

# Main execution
main() {
    echo -e "${BLUE}Starting FastAPI backend setup...${NC}"
    echo

    # Run all setup functions
    check_conda
    init_conda
    create_conda_env
    activate_conda_env
    install_dependencies
    check_main_file

    echo
    echo -e "${GREEN}=== Setup completed successfully! ===${NC}"
    echo

    # Start the FastAPI service
    start_fastapi
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; exit 0' INT

# Run main function
main "$@"