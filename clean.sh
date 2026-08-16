#!/bin/sh

# Ask for confirmation
printf "This will permanently delete ALL data for this project.\nType ALLDATADELETE to confirm: "
read -r confirm

case "$confirm" in
    ALLDATADELETE)
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