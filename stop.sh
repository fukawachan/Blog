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

# Configuration (must match start.sh)
CONDA_ENV_NAME="blog"  # Must match the environment name in start.sh
HOST="0.0.0.0"
PORT="8000"
PYTHON_FILE="main.py"   # Must match the main file name in start.sh
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/fastapi.log"
PID_FILE="$LOG_DIR/fastapi.pid"

# Create log directory if it doesn't exist
mkdir -p "$LOG_DIR"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Colored output function for console
print_message() {
    local color="$1"
    local message="$2"
    echo -e "${color}$message${NC}"
}

# Function to check if conda is installed
check_conda() {
    if ! command -v conda &> /dev/null; then
        print_message "$RED" "Error: conda is not installed or not in PATH"
        log_message "ERROR" "Conda not found"
        exit 1
    fi
    print_message "$GREEN" "✓ Conda found"
    log_message "INFO" "Conda installation verified"
}

# Function to initialize conda for bash
init_conda() {
    print_message "$YELLOW" "Initializing conda..."
    log_message "INFO" "Initializing conda environment"

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
                print_message "$GREEN" "✓ Conda initialized from $conda_path"
                log_message "INFO" "Conda initialized from $conda_path"
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

# Function to stop service using PID file
stop_service_by_pid() {
    local stopped_processes=false

    if [ -f "$PID_FILE" ]; then
        local service_pid=$(cat "$PID_FILE")
        print_message "$YELLOW" "Found service PID file with PID: $service_pid"
        log_message "INFO" "Found service PID: $service_pid"

        if kill -0 "$service_pid" 2>/dev/null; then
            print_message "$YELLOW" "Attempting graceful shutdown for PID $service_pid..."
            log_message "INFO" "Attempting graceful shutdown for PID $service_pid"

            # Send TERM signal for graceful shutdown
            kill -TERM "$service_pid" 2>/dev/null || true

            # Wait for graceful shutdown
            local count=0
            while kill -0 "$service_pid" 2>/dev/null && [ $count -lt 10 ]; do
                print_message "$BLUE" "Waiting for service to stop... (${count}/10)"
                sleep 1
                count=$((count + 1))
            done

            # Check if process stopped
            if ! kill -0 "$service_pid" 2>/dev/null; then
                print_message "$GREEN" "✓ Service stopped gracefully"
                log_message "INFO" "Service stopped gracefully"
                stopped_processes=true
            else
                print_message "$YELLOW" "Force killing service PID $service_pid..."
                log_message "WARNING" "Force killing service PID $service_pid"
                kill -KILL "$service_pid" 2>/dev/null || true
                sleep 1

                if ! kill -0 "$service_pid" 2>/dev/null; then
                    print_message "$GREEN" "✓ Service force killed"
                    log_message "INFO" "Service force killed"
                    stopped_processes=true
                else
                    print_message "$RED" "✗ Failed to stop service PID $service_pid"
                    log_message "ERROR" "Failed to stop service PID $service_pid"
                fi
            fi
        else
            print_message "$YELLOW" "Service PID $service_pid is not running (stale PID file)"
            log_message "WARNING" "Found stale PID file for PID $service_pid"
        fi

        # Remove PID file
        rm -f "$PID_FILE"
        print_message "$BLUE" "PID file removed"
        log_message "INFO" "PID file removed"
    else
        print_message "$YELLOW" "No PID file found - service may not be running with this script"
        log_message "WARNING" "No PID file found"
    fi

    return $([ "$stopped_processes" = true ] && echo 0 || echo 1)
}

# Function to find and kill FastAPI processes (fallback method)
stop_fastapi_processes() {
    print_message "$YELLOW" "Searching for FastAPI processes..."
    log_message "INFO" "Searching for FastAPI processes"

    local found_processes=false

    # Method 1: Find processes by port (most reliable)
    print_message "$BLUE" "Checking processes using port $PORT..."
    log_message "INFO" "Checking processes using port $PORT"

    local pid_by_port=$(lsof -ti:$PORT 2>/dev/null || true)

    if [ ! -z "$pid_by_port" ]; then
        print_message "$YELLOW" "Found process(es) using port $PORT: $pid_by_port"
        log_message "INFO" "Found process(es) using port $PORT: $pid_by_port"

        for pid in $pid_by_port; do
            local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
            print_message "$BLUE" "Process info: $process_info"
            log_message "INFO" "Process info: $process_info"

            print_message "$YELLOW" "Attempting graceful shutdown for PID $pid..."
            log_message "INFO" "Attempting graceful shutdown for PID $pid"

            kill -TERM $pid 2>/dev/null || true

            # Wait for graceful shutdown
            local count=0
            while kill -0 $pid 2>/dev/null && [ $count -lt 10 ]; do
                print_message "$BLUE" "Waiting for process $pid to stop... (${count}/10)"
                sleep 1
                count=$((count + 1))
            done

            # Force kill if still running
            if kill -0 $pid 2>/dev/null; then
                print_message "$YELLOW" "Force killing process $pid..."
                log_message "WARNING" "Force killing process $pid"
                kill -KILL $pid 2>/dev/null || true
                sleep 1
            fi

            if ! kill -0 $pid 2>/dev/null; then
                print_message "$GREEN" "✓ Process $pid stopped successfully"
                log_message "INFO" "Process $pid stopped successfully"
                found_processes=true
            else
                print_message "$RED" "✗ Failed to stop process $pid"
                log_message "ERROR" "Failed to stop process $pid"
            fi
        done
    fi

    # Method 2: Find uvicorn processes
    print_message "$BLUE" "Checking for uvicorn processes..."
    log_message "INFO" "Checking for uvicorn processes"

    local uvicorn_pids=$(pgrep -f "uvicorn.*$PYTHON_FILE" 2>/dev/null || true)

    if [ ! -z "$uvicorn_pids" ]; then
        print_message "$YELLOW" "Found uvicorn processes: $uvicorn_pids"
        log_message "INFO" "Found uvicorn processes: $uvicorn_pids"

        for pid in $uvicorn_pids; do
            # Skip if already killed by port method
            if kill -0 $pid 2>/dev/null; then
                local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
                print_message "$BLUE" "Process info: $process_info"
                log_message "INFO" "Process info: $process_info"

                print_message "$YELLOW" "Stopping uvicorn process $pid..."
                log_message "INFO" "Stopping uvicorn process $pid"
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
                    print_message "$GREEN" "✓ Uvicorn process $pid stopped"
                    log_message "INFO" "Uvicorn process $pid stopped"
                    found_processes=true
                fi
            fi
        done
    fi

    # Method 3: Find Python processes running the specific file
    print_message "$BLUE" "Checking for Python processes running $PYTHON_FILE..."
    log_message "INFO" "Checking for Python processes running $PYTHON_FILE"

    local python_pids=$(pgrep -f "python.*$PYTHON_FILE" 2>/dev/null || true)

    if [ ! -z "$python_pids" ]; then
        print_message "$YELLOW" "Found Python processes: $python_pids"
        log_message "INFO" "Found Python processes: $python_pids"

        for pid in $python_pids; do
            # Skip if already killed
            if kill -0 $pid 2>/dev/null; then
                local process_info=$(ps -p $pid -o pid,ppid,cmd --no-headers 2>/dev/null || echo "Process $pid not found")
                print_message "$BLUE" "Process info: $process_info"
                log_message "INFO" "Process info: $process_info"

                # Check if it's actually our FastAPI app
                if echo "$process_info" | grep -q "uvicorn\|fastapi\|$PORT"; then
                    print_message "$YELLOW" "Stopping Python process $pid..."
                    log_message "INFO" "Stopping Python process $pid"
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
                        print_message "$GREEN" "✓ Python process $pid stopped"
                        log_message "INFO" "Python process $pid stopped"
                        found_processes=true
                    fi
                else
                    print_message "$BLUE" "Skipping process $pid (not a FastAPI process)"
                    log_message "INFO" "Skipping process $pid (not a FastAPI process)"
                fi
            fi
        done
    fi

    if [ "$found_processes" = true ]; then
        print_message "$GREEN" "✓ FastAPI processes stopped"
        log_message "INFO" "FastAPI processes stopped"
    else
        print_message "$YELLOW" "No running FastAPI processes found"
        log_message "WARNING" "No running FastAPI processes found"
    fi
}

# Function to verify port is released
verify_port_released() {
    print_message "$YELLOW" "Verifying port $PORT is released..."
    log_message "INFO" "Verifying port $PORT is released"
    sleep 2

    local pid_check=$(lsof -ti:$PORT 2>/dev/null || true)
    if [ -z "$pid_check" ]; then
        print_message "$GREEN" "✓ Port $PORT is now free"
        log_message "INFO" "Port $PORT is now free"
    else
        print_message "$RED" "⚠ Port $PORT is still in use by process: $pid_check"
        log_message "WARNING" "Port $PORT is still in use by process: $pid_check"
        print_message "$YELLOW" "You may need to manually kill this process"
    fi
}

# Function to clean up any temporary files
cleanup() {
    print_message "$YELLOW" "Cleaning up temporary files..."
    log_message "INFO" "Cleaning up temporary files"

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
            print_message "$BLUE" "Removing: $pattern"
            log_message "INFO" "Removing: $pattern"
            rm -rf $pattern 2>/dev/null || true
        fi
    done

    print_message "$GREEN" "✓ Cleanup completed"
    log_message "INFO" "Cleanup completed"
}

# Function to show final status
show_status() {
    print_message "$BLUE" "=== Final Status ==="
    log_message "INFO" "=== Final Status ==="

    # Check if port is still in use
    local port_status=$(lsof -ti:$PORT 2>/dev/null || echo "Free")
    if [ "$port_status" = "Free" ]; then
        print_message "$GREEN" "✓ Port $PORT: Available"
        log_message "INFO" "Port $PORT: Available"
    else
        print_message "$RED" "✗ Port $PORT: In use by PID $port_status"
        log_message "WARNING" "Port $PORT: In use by PID $port_status"
    fi

    # Check for remaining processes
    local remaining_processes=$(pgrep -f "uvicorn.*$PYTHON_FILE\|python.*$PYTHON_FILE" 2>/dev/null || echo "None")
    if [ "$remaining_processes" = "None" ]; then
        print_message "$GREEN" "✓ FastAPI processes: None running"
        log_message "INFO" "FastAPI processes: None running"
    else
        print_message "$YELLOW" "⚠ FastAPI processes: $remaining_processes"
        log_message "WARNING" "FastAPI processes: $remaining_processes"
    fi

    # Check PID file
    if [ -f "$PID_FILE" ]; then
        print_message "$YELLOW" "⚠ PID file still exists: $PID_FILE"
        log_message "WARNING" "PID file still exists: $PID_FILE"
    else
        print_message "$GREEN" "✓ PID file: Clean"
        log_message "INFO" "PID file: Clean"
    fi

    echo
    print_message "$GREEN" "=== Stop script completed ==="
    log_message "INFO" "=== FastAPI Backend Stop Script Completed ==="
}

# Function to handle command line arguments
handle_arguments() {
    case "${1:-}" in
        "force")
            print_message "$YELLOW" "Force mode: Skipping graceful shutdown"
            log_message "WARNING" "Force mode enabled"
            return 0
            ;;
        "status")
            print_message "$BLUE" "=== Service Status ==="
            if [ -f "$PID_FILE" ]; then
                local pid=$(cat "$PID_FILE")
                if kill -0 "$pid" 2>/dev/null; then
                    print_message "$GREEN" "✓ FastAPI service is RUNNING (PID: $pid)"
                    print_message "$BLUE" "📁 Log file: $LOG_FILE"
                    print_message "$BLUE" "🌐 Service URL: http://$HOST:$PORT"
                    print_message "$BLUE" "📚 API docs: http://$HOST:$PORT/docs"
                else
                    print_message "$RED" "✗ Service is NOT running (stale PID file)"
                    rm -f "$PID_FILE"
                fi
            else
                print_message "$YELLOW" "⚠ Service is NOT running"
            fi
            exit 0
            ;;
        "help"|"-h"|"--help")
            print_message "$BLUE" "FastAPI Backend Stop Script"
            echo
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  stop     Stop the FastAPI service (default)"
            echo "  force    Force stop without graceful shutdown"
            echo "  status   Show service status"
            echo "  help     Show this help message"
            echo
            echo "Examples:"
            echo "  $0              # Stop the service gracefully"
            echo "  $0 force        # Force stop the service"
            echo "  $0 status       # Check status"
            exit 0
            ;;
        "")
            # Default behavior - stop the service
            return 0
            ;;
        *)
            print_message "$RED" "Unknown command: $1"
            print_message "$YELLOW" "Use '$0 help' for available commands"
            exit 1
            ;;
    esac
}

# Main execution
main() {
    print_message "$BLUE" "=== FastAPI Backend Stop Script ==="
    log_message "INFO" "=== FastAPI Backend Stop Script Started ==="

    # Handle command line arguments
    handle_arguments "$@"

    # Try to stop service using PID file first
    if stop_service_by_pid; then
        # Service stopped by PID file
        echo
    else
        # Fallback to process searching
        print_message "$YELLOW" "PID file method failed or no PID file found, trying process search..."
        stop_fastapi_processes
    fi

    # Verify and cleanup
    verify_port_released
    cleanup
    show_status
}

# Handle script interruption
trap 'print_message "$YELLOW" "Script interrupted by user"; log_message "WARNING" "Script interrupted by user"; exit 0' INT

# Run main function
main "$@"