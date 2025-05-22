# sheesh - An SSH Connection Manager

`sheesh` is a command-line tool designed to simplify managing and connecting to multiple SSH servers. It allows you to save SSH connection details with memorable aliases and quickly reconnect.

## Genesis & Purpose

This iteration of `sheesh` was primarily developed as an exercise to explore and test the "vibe coding" and iterative development capabilities of Gemini Code Assist. The goal was to see how an AI could help build a functional command-line utility.

**Disclaimer:** This tool was created for experimental and personal use purposes.

## Installation

1.  **Get the Scripts**:
    You'll need `sheesh.sh` (the main script) and `sheesh-completion.sh` (for bash tab completion). You can place them in a directory like `~/bin` to use it globally.

2.  **Make `sheesh.sh` Executable**:
    ```bash
    chmod +x /path/to/your/sheesh.sh
    ```

## Configuration

`sheesh` stores its connection configurations in a plain text file located at `~/.sheesh`. Each line in this file represents a connection in the format:

`alias_name:ssh_connection_details_or_full_command`

**Examples:**
```
myserver:user@example.com
devbox:developer@192.168.1.100 -p 2222 -i ~/.ssh/dev_key
jump_prod:ssh -J user@jumphost.example.com admin@production.internal
```

The script will automatically create this file if it doesn't exist when you first use a command like `add`.

## How to Use

Invoke the script followed by a command and its arguments:

```bash
sheesh <command> [arguments...]
```

### Core Commands

*   **`help` (or `-h`, `--help`)**: Displays the help message with all available commands.
    ```bash
    sheesh help
    ```

*   **`add <alias> <connection_details>`**: Adds a new SSH connection.
    *   `<alias>`: A short, memorable name for your connection.
    *   `<connection_details>`: Can be simple like `user@host` or a full SSH command string like `'ssh -p 2222 user@host -i ~/.ssh/mykey'`. If your details contain spaces, quote them.
    ```bash
    sheesh add webserver user@mywebserver.com
    sheesh add devdb 'ssh -L 5433:localhost:5432 devuser@db.internal -i ~/.ssh/dev_id'
    ```

*   **`list` (or `ls`)**: Lists all saved SSH connections with their aliases and details.
    ```bash
    sheesh list
    ```

*   **`connect <alias>` (or `c <alias>`)**: Connects to the SSH server associated with the given alias.
    ```bash
    sheesh connect webserver
    sheesh c devdb
    ```

*   **`remove <alias>` (or `rm <alias>`)**: Removes a saved SSH connection.
    ```bash
    sheesh remove oldserver
    ```

*   **`edit <alias> <new_connection_details>`**: Modifies the details of an existing SSH connection.
    ```bash
    sheesh edit webserver newuser@mywebserver.com -p 2200
    ```

### Tab Completion

`sheesh` supports bash tab completion for commands and aliases.

1.  **Install Completion Script**:
    Run the built-in command to help install the completion script:
    ```bash
    sheesh completions
    ```
    This command will attempt to add a line to your `~/.bashrc` to source the `sheesh-completion.sh` script (which should be in the same directory as `sheesh.sh`).

Once enabled, you can type `sheesh c` then press `TAB` to see a list of your saved aliases, or `sheesh ` then `TAB` to see available commands.
