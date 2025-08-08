
# Ollama load test

Scripts for load testing Ollama.

## Usage

- Install `tmux` and `uv`.

- Setup python env via `uv`.

```sh
uv sync
```

- Edit `.env`

|variable|description|
|-|-|
|`OLLAMA_ENDPOINT`|The Ollama endpoint. You must include `{port}` which will be replace to the targt port in `main.py`|
|`OLLAMA_PORT`|This can be any integer number. This value will be used to startup ollama servers on the next step and also in the `main.py` to access the endpoint.|
|`OLLAMA_TMUX_SESSION_PREFIX`|The prefix used to create tmux sessions.  The session name will be set as `${OLLAMA_TMUX_SESSION_PREFIX}${PORT}`, where `${PORT}` equals `OLLAMA_PORT + session index`. Make sure you set a prefix that does not conflict with any existing tmux sessions.|

- Start (multiple) ollama server(s) using tmux session(s).

```sh
./start-servers.sh 5
```

- Run long jobs.

```sh
uv run main.py -t 5
```

- Stop all servers

```sh
./stop-servers.sh
```

---

- If you want to test ollama's parallel access control.

    1. Edit the `./start-ollama.sh`'s `DEFAULT_NUM_PARALLEL` to some number
    2. Edit the `main.py`'s `multiport` argument to False.
    3. Start servers with 1 as number of servers.
    4. Run long jobs.

- Currently combining the two is not supported.

## Author

Tomoya Sawada
