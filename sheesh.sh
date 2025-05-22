#!/bin/bash


set -euo pipefail

# ANSI Color Codes
RESET='\033[0m'
BOLD='\033[1m'

# Regular Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bright/Light Colors (often Bold + Regular Color)
LIGHT_GREEN='\033[1;32m'
LIGHT_BLUE='\033[1;34m'
LIGHT_YELLOW='\033[1;33m'
LIGHT_CYAN='\033[1;36m'

# Configuration file path
CONFIG_FILE="$HOME/.ssh_manager_connections"

# Ensure config file exists
touch "$CONFIG_FILE"

# Function to display usage
usage() {
    echo -e "${BOLD}Usage:${RESET} $(basename "$0") ${LIGHT_BLUE}<command>${RESET} [arguments]"
    echo -e "${BOLD}Commands:${RESET}"
    echo -e "  ${LIGHT_GREEN}add${RESET} ${LIGHT_BLUE}<alias>${RESET} ${LIGHT_BLUE}<ssh_connection_details_or_full_command>${RESET}"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}add${RESET} myserver user@example.com"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}add${RESET} anotherserver user@example.com -p 2222 -i ~/.ssh/id_rsa"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}add${RESET} jump 'ssh -J user@jumphost user@targetserver'"
    echo -e "  ${LIGHT_GREEN}connect${RESET} ${LIGHT_BLUE}<alias>${RESET} (or ${LIGHT_GREEN}c${RESET} ${LIGHT_BLUE}<alias>${RESET})"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}connect${RESET} myserver"
    echo -e "  ${LIGHT_GREEN}list${RESET} (or ${LIGHT_GREEN}ls${RESET})"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}list${RESET}"
    echo -e "  ${LIGHT_GREEN}remove${RESET} ${LIGHT_BLUE}<alias>${RESET} (or ${LIGHT_GREEN}rm${RESET} ${LIGHT_BLUE}<alias>${RESET})"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}remove${RESET} myserver"
    echo -e "  ${LIGHT_GREEN}edit${RESET} ${LIGHT_BLUE}<alias>${RESET} ${LIGHT_BLUE}<new_ssh_connection_details_or_full_command>${RESET}"
    echo -e "      Example: $(basename "$0") ${LIGHT_GREEN}edit${RESET} myserver user@newserver.com -p 2223"
    echo -e "  ${LIGHT_GREEN}help, -h, --help${RESET}"
    echo -e "      Displays this help message."
}

# Function to check if an alias exists
alias_exists() {
    local alias_name="$1"
    # awk: -F: sets colon as delimiter.
    #      -v search="$alias_name" passes shell var to awk var.
    #      '$1 == search { exit 0 }' if first field matches, exit with 0 (found).
    #      'END { exit 1 }' if loop finishes, exit with 1 (not found).
    if awk -F: -v search="$alias_name" '$1 == search { exit 0 } END { exit 1 }' "$CONFIG_FILE"; then
        return 0 # Exists
    else
        return 1 # Does not exist
    fi
}

# Function to add a new connection
add_connection() {
    local alias_name="$1"
    shift
    local connection_details="$*"

    if [ -z "$alias_name" ] || [ -z "$connection_details" ]; then
        echo "Error: Alias and connection details are required for 'add'." >&2
        usage
        exit 1
    fi

    if alias_exists "$alias_name"; then
        echo "Error: Alias '$alias_name' already exists. Use 'edit' to modify or 'remove' first." >&2
        exit 1
    fi

    echo "${alias_name}:${connection_details}" >> "$CONFIG_FILE"
    echo "Connection '$alias_name' added."
}

# Function to list saved connections
list_connections() {
    if [ ! -s "$CONFIG_FILE" ]; then
        echo -e "${YELLOW}No connections saved yet.${RESET}"
        return
    fi
    echo -e "${BOLD}Saved connections:${RESET}"
    # Read line by line to correctly handle connection details that might contain colons
    while IFS= read -r line; do
        local alias_name="${line%%:*}"      # Everything before the first colon
        local connection_info="${line#*:}"  # Everything after the first colon

        local display_host
        local display_details

        if [[ "$connection_info" == "ssh "* ]]; then
            # It's a full SSH command string
            display_host="(Full SSH Cmd)"
            display_details="$connection_info"
        else
            # Standard connection: [user@]host [options]
            if [[ "$connection_info" == *" "* ]]; then # Check if there are options after the host
                display_host="${connection_info%% *}"  # Part before the first space
                display_details="${connection_info#* }" # Part after the first space
            else
                display_host="$connection_info" # No spaces, so the whole string is the host
                display_details=""              # No additional details
            fi
        fi
        # Format: Alias (Yellow) -> Host (Cyan) | Details (White/Default)
        # Ensuring truncation for alignment: .<width>s
        # Using -e with printf is not standard for variable expansion, but echo -e is used above.
        # For printf, the escape sequences are interpreted directly if they are part of the format string.
        # shellcheck disable=SC2059 # We are intentionally using variables in printf format string for colors
        printf "${LIGHT_YELLOW}%-15.15s${RESET} ${WHITE}->${RESET} ${LIGHT_CYAN}%-25.25s${RESET} ${WHITE}|${RESET} ${WHITE}%-30.30s${RESET}\n" "$alias_name" "$display_host" "$display_details"
    done < "$CONFIG_FILE"
}

# Function to connect to a saved alias
connect_to_alias() {
    local alias_name="$1"
    if [ -z "$alias_name" ]; then
        echo "Error: Alias is required for 'connect'." >&2
        usage
        exit 1
    fi

    local connection_details
    # awk: Find line where $1 is alias, remove "alias:" part, print rest, then exit.
    connection_details=$(awk -F':' -v alias="$alias_name" '$1 == alias {sub($1":", ""); print; exit}' "$CONFIG_FILE")

    if [ -z "$connection_details" ]; then
        echo "Error: Alias '$alias_name' not found." >&2
        list_connections
        exit 1
    fi

    echo "Connecting to '$alias_name'..."
    # If the stored string starts with "ssh ", execute it as a full command.
    # This allows storing complex commands like those with port forwarding or jump hosts.
    if [[ "$connection_details" == "ssh "* ]]; then
        echo "Executing as full command: $connection_details"
        eval "$connection_details"
    else
        # Otherwise, assume it's arguments for the ssh command (e.g., user@host -p 2222).
        echo "Executing: ssh $connection_details"
        # shellcheck disable=SC2086 # We want word splitting for $connection_details here
        ssh $connection_details
    fi
}

# Function to remove a connection
remove_connection() {
    local alias_name="$1"
    if [ -z "$alias_name" ]; then
        echo "Error: Alias is required for 'remove'." >&2
        usage
        exit 1
    fi

    if ! alias_exists "$alias_name"; then
        echo "Error: Alias '$alias_name' not found." >&2
        exit 1
    fi

    # awk: Print lines where the first field does not match the alias to remove.
    # This output overwrites a temporary file, which then replaces the original.
    awk -F: -v alias_to_remove="$alias_name" '$1 != alias_to_remove' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp" && mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "Connection '$alias_name' removed."
}

# Function to edit an existing connection
edit_connection() {
    local alias_name="$1"
    shift
    local new_connection_details="$*"

    if [ -z "$alias_name" ] || [ -z "$new_connection_details" ]; then
        echo "Error: Alias and new connection details are required for 'edit'." >&2
        usage
        exit 1
    fi

    if ! alias_exists "$alias_name"; then
        echo "Error: Alias '$alias_name' not found. Use 'add' to create it." >&2
        exit 1
    fi

    # Remove old entry by filtering it out, then append the new/updated entry.
    awk -F: -v alias_to_edit="$alias_name" '$1 != alias_to_edit' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    echo "${alias_name}:${new_connection_details}" >> "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo "Connection '$alias_name' updated."
}


# Main script logic
if [ "$#" -eq 0 ]; then
    usage
    exit 0 # It's not an error to call with no args if we show list & help
fi

COMMAND="$1"
shift # Remove command from argument list

case "$COMMAND" in
    add)
        add_connection "$@"
        ;;
    connect|c)
        connect_to_alias "$@"
        ;;
    list|ls)
        list_connections
        ;;
    remove|rm)
        remove_connection "$@"
        ;;
    edit)
        edit_connection "$@"
        ;;
    help|-h|--help)
        usage
        ;;
    *)
        echo "Error: Unknown command '$COMMAND'" >&2
        usage
        exit 1
        ;;
esac

exit 0