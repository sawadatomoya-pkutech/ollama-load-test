#!/bin/bash

set -a
source .env
set +a

# --- Configuration ---
OLLAMA_START_SCRIPT=./start-ollama.sh
BASE_PORT=${OLLAMA_PORT}

# --- Input Validation ---
if [ "$#" -ne 1 ]; then
    echo "ERROR: Please provide exactly one number as an argument."
    echo "Usage: $0 <number_of_servers>"
    exit 1
fi

if ! [ $1 -gt 0 ]; then
    echo "ERROR: Argument must be an integer greater than 0."
    echo "Usage: $0 <number_of_servers>"
    exit 1
fi

NUM_SERVERS=$1
UPPER_LIMIT=$(( NUM_SERVERS - 1 ))

echo "Preparing to launch ${NUM_SERVERS} Ollama server(s)."
echo "------------------------------------------------------------------"


# --- Main Loop ---
for (( i=0; i<=$UPPER_LIMIT; i++ ))
do
    PORT=$(( BASE_PORT + i ))
    SESSION_NAME="${OLLAMA_TMUX_SESSION_PREFIX}${PORT}"

    # Check if a tmux session with this name already exists to avoid errors.
    if tmux has-session -t=${SESSION_NAME} 2>/dev/null; then
        echo "⚠️  SKIPPING: A tmux session named '${SESSION_NAME}' already exists."
        continue
    fi

    COMMAND="${OLLAMA_START_SCRIPT} --port ${PORT}; exec $SHELL"

    echo "▶️  Launching instance #$((i + 1)) of ${NUM_SERVERS}..."
    echo "   ↳ Session Name: ${SESSION_NAME}"
    echo "   ↳ Port:         ${PORT}"

    # Create a new detached (-d) tmux session with the specified name (-s) and command.
    tmux new -d -s "${SESSION_NAME}" "${COMMAND}"
done

echo "------------------------------------------------------------------"
echo "✅ Script finished. All requested servers have been launched."
