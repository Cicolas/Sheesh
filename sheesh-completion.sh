_sheesh_completions() {
    local cur_word prev_word
    # COMP_WORDS is an array of the words in the current command line.
    # COMP_CWORD is the index of the current word in COMP_WORDS.
    cur_word="${COMP_WORDS[COMP_CWORD]}"
    prev_word="${COMP_WORDS[COMP_CWORD-1]}"

    local config_file="$HOME/.sheesh"
    # Define the main commands your script accepts
    local main_commands="add connect c list ls remove rm edit help"

    # Scenario 1: Completing the main command itself
    # This happens when COMP_CWORD is 1 (i.e., we are completing the word right after "sheesh" or "sheesh.sh")
    if [[ ${COMP_CWORD} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "${main_commands}" -- "$cur_word") )
        return 0
    fi

    # Scenario 2: Completing arguments for specific commands (like aliases)
    # This happens when COMP_CWORD is 2 (i.e., we are completing the word after a main command)
    if [[ ${COMP_CWORD} -eq 2 ]]; then
        case "$prev_word" in
            connect|c|remove|rm|edit)
                # These commands expect an alias as their argument.
                # We'll read aliases from your config file.
                if [ -f "$config_file" ]; then
                    local alias_list
                    # Use awk to extract the first field (alias) from each line.
                    # 'NF > 0' ensures we only process non-empty lines.
                    # Errors from awk (e.g., if file is empty/malformed) are suppressed.
                    mapfile -t alias_list < <(awk -F: 'NF > 0 {print $1}' "$config_file" 2>/dev/null)

                    if [[ ${#alias_list[@]} -gt 0 ]]; then
                        COMPREPLY=( $(compgen -W "${alias_list[*]}" -- "$cur_word") )
                    else
                        COMPREPLY=() # No aliases found
                    fi
                    return 0
                else
                    COMPREPLY=() # Config file doesn't exist
                    return 0
                fi
                ;;
            *)
                # For other main commands (like 'add', 'list'),
                # we don't have specific second-level completions defined here.
                COMPREPLY=()
                ;;
        esac
    fi

    # Default to no completions if none of the above scenarios match.
    COMPREPLY=()
    return 0
}

# Register the completion function for your script.
# Adjust these lines based on how you typically invoke your script.

# If 'sheesh.sh' is in your PATH or you call it directly by filename:
complete -F _sheesh_completions sheesh.sh

# If you have an alias or a symlink named 'sheesh' in your PATH:
complete -F _sheesh_completions sheesh

# If you often call it as './sheesh.sh' from its directory:
complete -F _sheesh_completions ./sheesh.sh

# If you consistently call it by its full path, you might add:
# complete -F _sheesh_completions /home/nicolas/prog/sheesh/sheesh.sh
