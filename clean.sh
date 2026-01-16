#!/bin/sh

# Ask for confirmation
printf "Are you sure you want to clean all data for this project? [y/N]: "
read -r confirm

case "$confirm" in
    [yY][eE][sS]|[yY])
        echo "🧹 Cleaning environment..."
        # Remove containers, networks, and volumes associated with this project ONLY
        docker compose down --volumes --remove-orphans

        # Remove local folders and files
        echo "🗑️ Removing local files and directories..."
        rm -rf html wordpress
        rm -rf config/ssl/*
        rm -rf config/secrets/*
        
        echo "✅ Clean up completed."
        ;;
    *)
        echo "Operation aborted."
        exit 0
        ;;
esac