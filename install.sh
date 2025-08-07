#!/bin/bash

# Installation script for sheesh

# Exit on any error
set -e

# Variables
INSTALL_DIR="$HOME/bin"
SHEESH_SCRIPT="sheesh.sh"
COMPLETION_SCRIPT="sheesh-completion.sh"
SHELL_CONFIG_BASH="$HOME/.bashrc"
SHELL_CONFIG_ZSH="$HOME/.zshrc"

echo "Starting sheesh installation..."

# 1. Check if required scripts are present
if [ ! -f "$SHEESH_SCRIPT" ] || [ ! -f "$COMPLETION_SCRIPT" ]; then
  echo "Error: Make sure '$SHEESH_SCRIPT' and '$COMPLETION_SCRIPT' are in the same directory as this installation script."
  exit 1
fi

# 2. Create installation directory if it doesn't exist
if [ ! -d "$INSTALL_DIR" ]; then
  echo "Creating directory: $INSTALL_DIR"
  mkdir -p "$INSTALL_DIR"
fi

# 3. Copy scripts to the installation directory
echo "Copying scripts to $INSTALL_DIR..."
cp "$SHEESH_SCRIPT" "$INSTALL_DIR/sheesh"
cp "$COMPLETION_SCRIPT" "$INSTALL_DIR/$COMPLETION_SCRIPT"

# 4. Make the main script executable
echo "Making sheesh script executable..."
chmod +x "$INSTALL_DIR/sheesh"

# 5. Add installation directory to PATH if not already present
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
  echo "Adding $INSTALL_DIR to your PATH."
  
  # Detect shell and update the correct config file
  if [ -n "$(echo "$SHELL" | grep "zsh")" ] && [ -f "$SHELL_CONFIG_ZSH" ]; then
    echo "Detected Zsh. Updating $SHELL_CONFIG_ZSH..."
    echo '' >> "$SHELL_CONFIG_ZSH"
    echo '# Add sheesh installation directory to PATH' >> "$SHELL_CONFIG_ZSH"
    echo "export PATH=\"$PATH:$INSTALL_DIR\"" >> "$SHELL_CONFIG_ZSH"
    SHELL_CONFIG_FILE="$SHELL_CONFIG_ZSH"
  elif [ -f "$SHELL_CONFIG_BASH" ]; then
    echo "Detected Bash. Updating $SHELL_CONFIG_BASH..."
    echo '' >> "$SHELL_CONFIG_BASH"
    echo '# Add sheesh installation directory to PATH' >> "$SHELL_CONFIG_BASH"
    echo "export PATH=\"$PATH:$INSTALL_DIR\"" >> "$SHELL_CONFIG_BASH"
    SHELL_CONFIG_FILE="$SHELL_CONFIG_BASH"
  else
    echo "Warning: Could not detect .bashrc or .zshrc. Please add '$INSTALL_DIR' to your PATH manually."
  fi
else
  echo "$INSTALL_DIR is already in your PATH."
fi

# 6. Configure shell completion
COMPLETION_SOURCE_LINE="source $INSTALL_DIR/$COMPLETION_SCRIPT"
if [ -n "$SHELL_CONFIG_FILE" ] && ! grep -qF "$COMPLETION_SOURCE_LINE" "$SHELL_CONFIG_FILE"; then
  echo "Adding sheesh completion to $SHELL_CONFIG_FILE..."
  echo '' >> "$SHELL_CONFIG_FILE"
  echo '# Source sheesh tab completion' >> "$SHELL_CONFIG_FILE"
  echo "$COMPLETION_SOURCE_LINE" >> "$SHELL_CONFIG_FILE"
else
  echo "Sheesh completion already configured or shell config file not found."
fi

echo ""
echo "--------------------------------------------------"
echo " sheesh installation complete!"
echo "--------------------------------------------------"
echo ""
echo "Please restart your shell or run the following command to apply changes:"
if [ -n "$SHELL_CONFIG_FILE" ]; then
  echo "  source $SHELL_CONFIG_FILE"
fi
echo "You can now use the 'sheesh' command globally."
echo ""
