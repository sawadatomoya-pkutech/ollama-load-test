#!/bin/bash

# ==============================================================================
# Ollama Server Control Script
#
# Description:
#   A helper script to start the Ollama server with custom environment
#   variables set via command-line flags.
#
# Usage:
#   ./start_ollama.sh [options]
#
# Options:
#   -h --host       Set the server's IP address
#   -P --port       Set the server's port
#   -m --model-dir  Set the Ollama models directory
#   -k --keep-alive Set keep-alive duration for models
#   -p --parallel   Set max number of parallel requests
#   -l --load       Set max number of concurrently loaded models
#   -f --flash      Enable Flash Attention
#   -d --debug      Enable debug mode
#   --help          Show this help message
#
# ==============================================================================

set -e # Exit immediately if a command exits with a non-zero status.
set -o pipefail # The return value of a pipeline is the status of the last command to exit.


# --- Default Values ---
DEFAULT_HOST="127.0.0.1"
DEFAULT_PORT="11434"
DEFAULT_MODELS_DIR="${HOME}/.ollama/models"
DEFAULT_KEEP_ALIVE="1h"
DEFAULT_NUM_PARALLEL="1"
DEFAULT_MAX_LOADED_MODELS="2"

# Internal variables to hold settings from flags
HOST_SETTING=""
PORT_SETTING=""
OLLAMA_NUM_PARALLEL=""
OLLAMA_MAX_LOADED_MODELS=""
OLLAMA_DEBUG="0"
OLLAMA_FLASH_ATTENTION="0"

# --- Function to Display Help ---
show_help() {
    echo "Ollama Server Control Script"
    echo "----------------------------"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -h --host       Set the server's IP address (Default: ${DEFAULT_HOST})"
    echo "  -P --port       Set the server's port (Default: ${DEFAULT_PORT})"
    echo "  -m --model-dir  Set the Ollama models directory (Default: ${DEFAULT_MODELS_DIR})"
    echo "  -k --keep-alive Set keep-alive duration for models (Default: ${DEFAULT_KEEP_ALIVE})"
    echo "  -p --parallel   Set max number of parallel requests. (Default: ${DEFAULT_NUM_PARALLEL})"
    echo "  -l --load       Set max number of concurrently loaded models. (Default: ${DEFAULT_MAX_LOADED_MODELS})"
    echo "  -f --flash      Enable Flash Attention."
    echo "  -d --debug      Enable debug mode."
    echo "  --help          Show this help message."
    echo ""
    echo "Example: $0 -h 0.0.0.0 -k 30m -f"
}

# --- Parse Command-Line Arguments ---

# Handle long options like --help first
for arg in "$@"; do
  shift
  case "$arg" in
    "--help")
      show_help
      exit 0
      ;;
    *)
      set -- "$@" "$arg"
      ;;
  esac
done

# Then, parse short options with getopts
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--host)
            # Check if an argument was provided for this option
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            HOST_SETTING="$2"
            shift 2 # Consume option and argument
            ;;
        -P|--port)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            PORT_SETTING="$2"
            shift 2 # Consume option and argument
            ;;
        -m|--model-dir)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            OLLAMA_MODELS="$2"
            shift 2 # Consume option and argument
            ;;
        -k|--keep-alive)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            OLLAMA_KEEP_ALIVE="$2"
            shift 2 # Consume option and argument
            ;;
        -p|--parallel)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            OLLAMA_NUM_PARALLEL="$2"
            shift 2 # Consume option and argument
            ;;
        -l|--load)
            if [ -z "$2" ] || [[ "$2" == -* ]]; then
                echo "Error: Option -$1 requires an argument." 1>&2
                exit 1
            fi
            OLLAMA_MAX_LOADED_MODELS="$2"
            shift 2 # Consume option and argument
            ;;
        -f|--flash)
            OLLAMA_FLASH_ATTENTION="1"
            shift # Consume option
            ;;
        -d|--debug)
            OLLAMA_DEBUG="1"
            shift # Consume option
            ;;
        --)
            # End of options marker
            shift
            break
            ;;
        -*)
            echo "Invalid Option: $1" 1>&2
            show_help
            exit 1
            ;;
        *)
            # No more options, break the loop
            break
            ;;
    esac
done

# Assign defaults if variables are still empty
HOST_SETTING=${HOST_SETTING:-$DEFAULT_HOST}
PORT_SETTING=${PORT_SETTING:-$DEFAULT_PORT}
OLLAMA_MODELS=${OLLAMA_MODELS:-$DEFAULT_MODELS_DIR}
OLLAMA_KEEP_ALIVE=${OLLAMA_KEEP_ALIVE:-$DEFAULT_KEEP_ALIVE}
OLLAMA_NUM_PARALLEL=${OLLAMA_NUM_PARALLEL:-$DEFAULT_NUM_PARALLEL}
OLLAMA_MAX_LOADED_MODELS=${OLLAMA_MAX_LOADED_MODELS:-$DEFAULT_MAX_LOADED_MODELS}

# --- Pre-run Checks ---
# Check if the ollama command exists
if ! command -v ollama &> /dev/null; then
    echo "Error: 'ollama' command not found."
    echo "Please make sure Ollama is installed and in your system's PATH."
    exit 1
fi

# Create the models directory if it doesn't exist
mkdir -p "$OLLAMA_MODELS"

# --- Set and Export Environment Variables ---
# Combine host and port into the single OLLAMA_HOST variable
export OLLAMA_HOST="${HOST_SETTING}:${PORT_SETTING}"
export OLLAMA_MODELS
export OLLAMA_KEEP_ALIVE
export OLLAMA_DEBUG
export OLLAMA_NUM_PARALLEL
export OLLAMA_MAX_LOADED_MODELS

# Only export flash attention if it's enabled
if [[ "$OLLAMA_FLASH_ATTENTION" == "1" ]]; then
    export OLLAMA_FLASH_ATTENTION
fi

# --- Display Configuration and Start Server ---
echo "--- Starting Ollama Server ---"
echo "Configuration:"
echo "  OLLAMA_HOST             : ${OLLAMA_HOST}"
echo "  OLLAMA_MODELS           : ${OLLAMA_MODELS}"
echo "  OLLAMA_KEEP_ALIVE       : ${OLLAMA_KEEP_ALIVE}"
echo "  OLLAMA_NUM_PARALLEL     : ${OLLAMA_NUM_PARALLEL}"
echo "  OLLAMA_MAX_LOADED_MODELS: ${OLLAMA_MAX_LOADED_MODELS}"
if [[ "$OLLAMA_FLASH_ATTENTION" == "1" ]]; then
    echo "  OLLAMA_FLASH_ATTENTION   : Enabled"
fi
if [[ "$OLLAMA_DEBUG" == "1" ]]; then
    echo "  OLLAMA_DEBUG            : Enabled"
fi
echo "--------------------------------"
echo "To stop the server, press Ctrl+C."
echo ""

# Execute the ollama server
ollama serve
