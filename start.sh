#!/bin/bash

# FastAPI Backend Startup Script for Ubuntu
# This script activates conda environment, installs dependencies, and starts the FastAPI service in background

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
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/fastapi.log"
PID_FILE="$LOG_DIR/fastapi.pid"
LOG_MAX_SIZE="10M"  # Maximum log file size before rotation
LOG_MAX_FILES="5"   # Maximum number of log files to keep

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

# Function to rotate logs
rotate_logs() {
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt 10485760 ]; then
        log_message "INFO" "Rotating log file (size exceeds $LOG_MAX_SIZE)"

        # Rotate existing log files
        for i in $(seq $((LOG_MAX_FILES - 1)) -1 1); do
            if [ -f "$LOG_FILE.$i" ]; then
                mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))"
            fi
        done

        # Move current log to .1
        mv "$LOG_FILE" "$LOG_FILE.1"

        # Remove old log files beyond limit
        if [ -f "$LOG_FILE.$((LOG_MAX_FILES + 1))" ]; then
            rm "$LOG_FILE.$((LOG_MAX_FILES + 1))"
        fi
    fi
}

# Function to check if process is already running
check_existing_process() {
    if [ -f "$PID_FILE" ]; then
        local existing_pid=$(cat "$PID_FILE")
        if kill -0 "$existing_pid" 2>/dev/null; then
            print_message "$YELLOW" "FastAPI service is already running with PID: $existing_pid"
            print_message "$YELLOW" "Use './stop_backend.sh' to stop it first"
            exit 1
        else
            print_message "$YELLOW" "Removing stale PID file"
            rm -f "$PID_FILE"
        fi
    fi
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

# Function to create conda environment if it doesn't exist
create_conda_env() {
    print_message "$YELLOW" "Checking conda environment: $CONDA_ENV_NAME"
    log_message "INFO" "Checking conda environment: $CONDA_ENV_NAME"

    if ! conda env list | grep -q "$CONDA_ENV_NAME"; then
        print_message "$YELLOW" "Creating conda environment: $CONDA_ENV_NAME"
        log_message "INFO" "Creating conda environment: $CONDA_ENV_NAME"
        conda create -n "$CONDA_ENV_NAME" python=3.9 -y >> "$LOG_FILE" 2>&1
        print_message "$GREEN" "✓ Environment $CONDA_ENV_NAME created"
        log_message "INFO" "Conda environment created successfully"
    else
        print_message "$GREEN" "✓ Environment $CONDA_ENV_NAME already exists"
        log_message "INFO" "Conda environment already exists"
    fi
}

# Function to activate conda environment
activate_conda_env() {
    print_message "$YELLOW" "Activating conda environment: $CONDA_ENV_NAME"
    log_message "INFO" "Activating conda environment: $CONDA_ENV_NAME"
    eval "$(conda shell.bash hook)"
    conda activate "$CONDA_ENV_NAME"
    print_message "$GREEN" "✓ Environment activated"
    log_message "INFO" "Conda environment activated"
}

# Function to install dependencies
install_dependencies() {
    print_message "$YELLOW" "Installing dependencies from requirements.txt"
    log_message "INFO" "Starting dependency installation"

    if [ -f "requirements.txt" ]; then
        # Check if requirements.txt is readable (not corrupted encoding)
        if ! head -1 requirements.txt >/dev/null 2>&1; then
            print_message "$RED" "Error: requirements.txt has encoding issues and cannot be read"
            log_message "ERROR" "requirements.txt encoding issues"
            exit 1
        fi

        # Upgrade pip first
        print_message "$BLUE" "Upgrading pip..."
        log_message "INFO" "Upgrading pip"
        pip install --upgrade pip >> "$LOG_FILE" 2>&1

        # Install dependencies with error handling
        print_message "$BLUE" "Installing dependencies..."
        log_message "INFO" "Installing dependencies from requirements.txt"
        if pip install -r requirements.txt >> "$LOG_FILE" 2>&1; then
            print_message "$GREEN" "✓ Dependencies installed successfully"
            log_message "INFO" "Dependencies installed successfully"
        else
            print_message "$RED" "Error: Failed to install dependencies"
            log_message "ERROR" "Failed to install dependencies"
            print_message "$RED" "Check $LOG_FILE for detailed error information"
            exit 1
        fi
    else
        print_message "$RED" "Warning: requirements.txt not found"
        log_message "WARNING" "requirements.txt not found"
        print_message "$YELLOW" "Continuing without installing dependencies..."
    fi
}

# Function to verify dependencies are installed
verify_dependencies() {
    print_message "$YELLOW" "Verifying critical dependencies..."
    log_message "INFO" "Verifying critical dependencies"

    local critical_deps=("fastapi" "uvicorn" "pydantic")
    local missing_deps=()

    for dep in "${critical_deps[@]}"; do
        if ! python -c "import $dep" 2>/dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_message "$RED" "Error: Missing critical dependencies: ${missing_deps[*]}"
        log_message "ERROR" "Missing dependencies: ${missing_deps[*]}"
        print_message "$YELLOW" "Please install dependencies first with: pip install -r requirements.txt"
        exit 1
    fi

    print_message "$GREEN" "✓ All critical dependencies verified"
    log_message "INFO" "All critical dependencies verified"
}

# Function to check if main Python file exists
check_main_file() {
    if [ ! -f "$PYTHON_FILE" ]; then
        print_message "$RED" "Error: Main Python file '$PYTHON_FILE' not found"
        log_message "ERROR" "Main file $PYTHON_FILE not found"
        exit 1
    fi
    print_message "$GREEN" "✓ Main file $PYTHON_FILE found"
    log_message "INFO" "Main file $PYTHON_FILE verified"
}

# Function to test import of main application
test_imports() {
    print_message "$YELLOW" "Testing application imports..."
    log_message "INFO" "Testing application imports"

    # Extract module name without .py extension
    local module_name="${PYTHON_FILE%.*}"

    if python -c "from $module_name import app; print('✓ Main application imported successfully')" >> "$LOG_FILE" 2>&1; then
        print_message "$GREEN" "✓ Application imports test passed"
        log_message "INFO" "Application imports test passed"
    else
        print_message "$RED" "Error: Failed to import main application"
        log_message "ERROR" "Failed to import main application"
        print_message "$YELLOW" "Attempting to debug import issue..."

        # Try to show more detailed error information
        python -c "
try:
    from $module_name import app
    print('✓ Import successful')
except ImportError as e:
    print(f'ImportError: {e}')
except Exception as e:
    print(f'Other error: {e}')
" >> "$LOG_FILE" 2>&1 || true

        print_message "$RED" "Check $LOG_FILE for detailed error information"
        print_message "$YELLOW" "Please check if all dependencies are installed and the application structure is correct"
        exit 1
    fi
}

# Function to start FastAPI service in background
start_fastapi_background() {
    print_message "$YELLOW" "Starting FastAPI service in background..."
    log_message "INFO" "Starting FastAPI service"

    # Rotate logs if needed
    rotate_logs

    # Set PYTHONPATH to ensure proper module resolution
    export PYTHONPATH="${PYTHONPATH}:$(pwd)"

    # Start the FastAPI application in background
    print_message "$BLUE" "Server will be available at: http://$HOST:$PORT"
    print_message "$BLUE" "API docs will be available at: http://$HOST:$PORT/docs"
    print_message "$BLUE" "Logs are being saved to: $LOG_FILE"
    print_message "$GREEN" "Use './stop_backend.sh' to stop the service"
    print_message "$GREEN" "Use 'tail -f $LOG_FILE' to monitor logs in real-time"

    log_message "INFO" "Starting FastAPI on http://$HOST:$PORT"
    log_message "INFO" "API docs available at http://$HOST:$PORT/docs"

    # Start uvicorn in background and capture PID
    nohup python -m uvicorn "${PYTHON_FILE%.*}:app" \
        --host "$HOST" \
        --port "$PORT" \
        --reload \
        --log-level info \
        >> "$LOG_FILE" 2>&1 &

    local uvicorn_pid=$!
    echo "$uvicorn_pid" > "$PID_FILE"

    # Wait a moment to check if the service started successfully
    sleep 2

    if kill -0 "$uvicorn_pid" 2>/dev/null; then
        print_message "$GREEN" "✓ FastAPI service started successfully with PID: $uvicorn_pid"
        log_message "INFO" "FastAPI service started successfully with PID: $uvicorn_pid"

        # Test if the service is responding
        sleep 3
        if curl -s "http://$HOST:$PORT/docs" >/dev/null 2>&1; then
            print_message "$GREEN" "✓ Service is responding to requests"
            log_message "INFO" "Service is responding to requests"
        else
            print_message "$YELLOW" "⚠ Service started but not yet responding (still warming up)"
            log_message "WARNING" "Service started but not yet responding"
        fi
    else
        print_message "$RED" "✗ Failed to start FastAPI service"
        log_message "ERROR" "Failed to start FastAPI service"
        print_message "$RED" "Check $LOG_FILE for detailed error information"
        rm -f "$PID_FILE"
        exit 1
    fi
}

# Function to show service status
show_status() {
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
}

# Function to handle command line arguments
handle_arguments() {
    case "${1:-}" in
        "status")
            show_status
            exit 0
            ;;
        "logs")
            if [ -f "$LOG_FILE" ]; then
                print_message "$BLUE" "Showing last 50 lines of log file:"
                tail -50 "$LOG_FILE"
            else
                print_message "$YELLOW" "No log file found"
            fi
            exit 0
            ;;
        "tail")
            if [ -f "$LOG_FILE" ]; then
                print_message "$BLUE" "Monitoring log file (Ctrl+C to exit):"
                tail -f "$LOG_FILE"
            else
                print_message "$YELLOW" "No log file found"
            fi
            exit 0
            ;;
        "help"|"-h"|"--help")
            print_message "$BLUE" "FastAPI Backend Management Script"
            echo
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  start    Start the FastAPI service (default)"
            echo "  status   Show service status"
            echo "  logs     Show last 50 lines of log file"
            echo "  tail     Monitor log file in real-time"
            echo "  help     Show this help message"
            echo
            echo "Examples:"
            echo "  $0              # Start the service"
            echo "  $0 status       # Check status"
            echo "  $0 logs         # View logs"
            echo "  $0 tail         # Follow logs"
            exit 0
            ;;
        "")
            # Default behavior - start the service
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
    print_message "$BLUE" "=== FastAPI Backend Startup Script ==="
    log_message "INFO" "=== FastAPI Backend Startup Script Started ==="

    # Handle command line arguments
    handle_arguments "$@"

    # Check if service is already running
    check_existing_process

    print_message "$BLUE" "Starting FastAPI backend setup..."

    # Run all setup functions
    check_conda
    init_conda
    create_conda_env
    activate_conda_env
    install_dependencies
    verify_dependencies
    check_main_file
    test_imports

    print_message "$GREEN" "=== Setup completed successfully! ==="
    log_message "INFO" "Setup completed successfully"

    # Start the FastAPI service in background
    start_fastapi_background

    print_message "$GREEN" "=== Script completed ==="
    log_message "INFO" "=== FastAPI Backend Startup Script Completed ==="
}

# Handle script interruption
trap 'print_message "$YELLOW" "Script interrupted by user"; log_message "WARNING" "Script interrupted by user"; exit 0' INT

# Run main function
main "$@"