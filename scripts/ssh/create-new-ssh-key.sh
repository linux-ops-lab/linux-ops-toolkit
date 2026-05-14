#!/bin/bash

# Script to create an SSH key pair, private and public, for the executing user

# Define variables

# Default output path for SSH keys
SSH_DIR="$HOME/.ssh"

# Default key type
SSH_KEY_TYPE="ed25519"

# Default comment for the SSH key
SSH_KEY_COMMENT="$USER@$(hostname)"

echo "_________________________________"
echo "Starting SSH key creation for user: $USER"
echo "_________________________________"
echo ""
read -p "Name of the new key: " KEY_NAME_INPUT
if [ -z "$KEY_NAME_INPUT" ]; then
    echo "Error: No key name specified. Aborting."
    exit 1
fi

KEY_NAME="id_${SSH_KEY_TYPE}_${KEY_NAME_INPUT}"

echo ""

echo "New key: $KEY_NAME"
echo "Storage location: $SSH_DIR/$KEY_NAME"

echo ""

read -p "Continue? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
    echo "Aborted by user."
    exit 2
fi

echo ""

# Check whether the SSH directory exists; create it if it does not
if [ ! -d "$SSH_DIR" ]; then
    echo "SSH directory does not exist. Creating $SSH_DIR..."
    mkdir -p "$SSH_DIR"
    chmod 700 "$SSH_DIR"
    echo "SSH directory created."
else
    echo "SSH directory already exists."
fi

# Check whether the key already exists
if [ -f "$SSH_DIR/$KEY_NAME" ]; then
    echo "Error: A key with this name already exists. Aborting."
    exit 3
fi 

# Generate SSH key
echo "Generating SSH key..."
ssh-keygen -t "$SSH_KEY_TYPE" -C "$SSH_KEY_COMMENT" -f "$SSH_DIR/$KEY_NAME" -N ""
if [ $? -ne 0 ]; then
    echo "Error: SSH key could not be generated. Aborting."
    exit 4
fi  

echo "SSH key successfully created: $SSH_DIR/$KEY_NAME"
echo "Public key: $SSH_DIR/${KEY_NAME}.pub"
echo ""
echo "_________________________________"
echo "SSH key creation completed."
echo "_________________________________"