#!/bin/bash

set -a
source .env
set +a

# Kills all tmux sessions that start with a specific prefix.

PREFIX=${OLLAMA_TMUX_SESSION_PREFIX}

echo "🔎 Searching for tmux sessions with prefix '$PREFIX'..."
echo "------------------------------------------------------------------"

# Find tmux sessions that starts with the prefix.
SESSIONS=() # Initialize an empty array
while IFS= read -r line; do
    SESSIONS+=("$line")
done < <(tmux list-sessions -F '#S' 2>/dev/null | grep "^$PREFIX" || true)

if [ ${#SESSIONS[@]} -eq 0 ]; then
    echo "✅ No running tmux sessions found with the prefix '$PREFIX'."
    exit 0
fi

# List the sessions that will be killed.
echo "🔥 The following sessions will be killed:"
printf ' - %s\n' "${SESSIONS[@]}"
echo

# Loop through the array and kill each session.
for session_name in "${SESSIONS[@]}"; do
    tmux kill-session -t "$session_name"
    echo "   ↳ Killed session: $session_name"
done

echo "------------------------------------------------------------------"
echo "✅ All matching sessions terminated."
