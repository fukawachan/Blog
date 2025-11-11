#!/bin/bash

# FastAPI Backend Stop Script for Ubuntu
# This script stops the FastAPI backend service gracefully

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CONDA_ENV_NAME="blog"  # Must match the environment name in start_backend.sh
HOST="0.0.0.0"
PORT="8000"
PYTHON_FILE="main.py"   # Must match the main file name in start_backend.sh

echo -e "${BLUE}=== FastAPI Backend Stop Script ===${NC}"
echo

# Function to check if conda is installed
check_conda() {
    if ! command -v conda &> /dev/null; then
        echo -e "${RED}Error: conda is not installed or not in PATH${NC}"
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

# Function to find and kill FastAPI processes
stop_fastapi_processes() {
    echo -e "${YELLOW}Searching for FastAPI processes...${NC}"

    local found_processes=false

    # Method 1: Find processes by port (most reliable)
    echo -e "${BLUE}Checking processes using port $PORT...${NC}"
    local pid_by_port=$(lsof -ti:$PORT 2>/dev/null || true)

    if [ ! -z "$pid_by_port" ]; then
        echo -e "${YELLOW}Found process(es) using port $PORT: $pid_by_port${NC}"
        for pid in $pid_by_port; do
            local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
            echo -e "${BLUE}Process info: $process_info${NC}"

            echo -e "${YELLOW}Attempting graceful shutdown for PID $pid...${NC}"
            kill -TERM $pid 2>/dev/null || true

            # Wait for graceful shutdown
            local count=0
            while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
                echo -e "${BLUE}Waiting for process $pid to stop... (${count}/10)${NC}"
                sleep 1
                count=$((count + 1))
            done

            # Force kill if still running
            if kill -0 $pid 2>/dev/null; then
                echo -e "${YELLOW}Force killing process $pid...${NC}"
                kill -KILL $pid 2>/dev/null || true
                sleep 1
            fi

            if ! kill -0 $pid 2>/dev/null; then
                echo -e "${GREEN}✓ Process $pid stopped successfully${NC}"
                found_processes=true
            else
                echo -e "${RED}✗ Failed to stop process $pid${NC}"
            fi
        done
    fi

    # Method 2: Find uvicorn processes
    echo -e "${BLUE}Checking for uvicorn processes...${NC}"
    local uvicorn_pids=$(pgrep -f "uvicorn.*$PYTHON_FILE" 2>/dev/null || true)

    if [ ! -z "$uvicorn_pids" ]; then
        echo -e "${YELLOW}Found uvicorn processes: $uvicorn_pids${NC}"
        for pid in $uvicorn_pids; do
            # Skip if already killed by port method
            if kill -0 $pid 2>/dev/null; then
                local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
                echo -e "${BLUE}Process info: $process_info${NC}"

                echo -e "${YELLOW}Stopping uvicorn process $pid...${NC}"
                kill -TERM $pid 2>/dev/null || true

                # Wait for graceful shutdown
                local count=0
                while kill -0 $pid 2>/dev/null && [ $count -lt 5 ]; do
                    sleep 1
                    count=$((count + 1))
                done

                # Force kill if still running
                if kill -0 $pid 2>/dev/null; then
                    kill -KILL $pid 2>/dev/null || true
                fi

                if ! kill -0 $pid 2>/dev/null; then
                    echo -e "${GREEN}✓ Uvicorn process $pid stopped${NC}"
                    found_processes=true
                fi
            fi
        done
    fi

    # Method 3: Find Python processes running the specific file
    echo -e "${BLUE}Checking for Python processes running $PYTHON_FILE...${NC}"
    local python_pids=$(pgrep -f "python.*$PYTHON_FILE" 2>/dev/null || true)

    if [ ! -z "$python_pids" ]; then
        echo -e "${YELLOW}Found Python processes: $python_pids${NC}"
        for pid in $python_pids; do
            # Skip if already killed
            if kill -0 $pid 2>/dev/null; then
                local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
                echo -e "${BLUE}Process info: $process_info${NC}"

                # Check if it's actually our FastAPI app
                if echo "$process_info" | grep -q "uvicorn\|fastapi\|$PORT"; then
                    echo -e "${YELLOW}Stopping Python process $pid...${NC}"
                    kill -TERM $pid 2>/dev/null || true

                    # Wait for graceful shutdown
                    local count=0
                    while kill -0 $pid 2>/dev/null && [ $count -lt 5 ]; do
                        sleep 1
                        count=$((count + 1))
                    done

                    # Force kill if still running
                    if kill -0 $pid 2>/dev/null; then
                        kill -KILL $pid 2>/dev/null || true
                    fi

                    if ! kill -0 $pid 2>/dev/null; then
                        echo -e "${GREEN}✓ Python process $pid stopped${NC}"
                        found_processes=true
                    fi
                else
                    echo -e "${BLUE}Skipping process $pid (not a FastAPI process)${NC}"
                fi
            fi
        done
    fi

    if [ "$found_processes" = true ]; then
        echo -e "${GREEN}✓ FastAPI processes stopped${NC}"
    else
        echo -e "${YELLOW}No running FastAPI processes found${NC}"
    fi
}

# Function to verify port is released
verify_port_released() {
    echo -e "${YELLOW}Verifying port $PORT is released...${NC}"
    sleep 2

    local pid_check=$(lsof -ti:$PORT 2>/dev/null || true)
    if [ -z "$pid_check" ]; then
        echo -e "${GREEN}✓ Port $PORT is now free${NC}"
    else
        echo -e "${RED}⚠ Port $PORT is still in use by process: $pid_check${NC}"
        echo -e "${YELLOW}You may need to manually kill this process${NC}"
    fi
}

# Function to clean up any temporary files
cleanup() {
    echo -e "${YELLOW}Cleaning up temporary files...${NC}"

    # Remove common temporary files that might be left behind
    local temp_files=(
        "*.pyc"
        "__pycache__/"
        ".pytest_cache/"
        "*.log"
        "*.tmp"
    )

    for pattern in "${temp_files[@]}"; do
        if ls $pattern 1> /dev/null 2>&1; then
            echo -e "${BLUE}Removing: $pattern${NC}"
            rm -rf $pattern 2>/dev/null || true
        fi
    done

    echo -e "${GREEN}✓ Cleanup completed${NC}"
}

# Function to show final status
show_status() {
    echo
    echo -e "${BLUE}=== Final Status ===${NC}"

    # Check if port is still in use
    local port_status=$(lsof -ti:$PORT 2>/dev/null || echo "Free")
    if [ "$port_status" = "Free" ]; then
        echo -e "${GREEN}✓ Port $PORT: Available${NC}"
    else
        echo -e "${RED}✗ Port $PORT: In use by PID $port_status${NC}"
    fi

    # Check for remaining processes
    local remaining_processes=$(pgrep -f "uvicorn.*$PYTHON_FILE\|python.*$PYTHON_FILE" 2>/dev/null || echo "None")
    if [ "$remaining_processes" = "None" ]; then
        echo -e "${GREEN}✓ FastAPI processes: None running${NC}"
    else
        echo -e "${YELLOW}⚠ FastAPI processes: $remaining_processes${NC}"
    fi

    echo
    echo -e "${GREEN}=== Stop script completed ===${NC}"
}

# Main execution
main() {
    echo -e "${BLUE}Stopping FastAPI backend service...${NC}"
    echo

    # Run all stop functions
    check_conda
    init_conda
    stop_fastapi_processes
    verify_port_released
    cleanup
    show_status
}

# Handle script interruption
trap 'echo -e "\n${YELLOW}Script interrupted by user${NC}"; exit 0' INT

# Run main function
main "$@"