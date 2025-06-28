#!/bin/bash

# Deployment configuration for slova-sveltekit
# Copy this file to deploy.config.local.sh and customize for your environment

# Server configuration
SERVER_HOST="your-server-ip"        # Your Hetzner server IP
SERVER_USER="your-username"         # SSH username
APP_NAME="slova-sveltekit"          # PM2 app name
DEPLOY_PATH="/app"                  # Deployment path on server

# Application configuration
APP_PORT="4173"                     # SvelteKit preview port
HEALTH_CHECK_URL="http://localhost:4173/api/health"

# Database configuration
DB_HOST="localhost"                 # Database host
DB_PORT="5432"                      # Database port
DB_NAME="your-database-name"        # Database name

# Timeouts
HEALTH_CHECK_TIMEOUT="30"           # Health check timeout in seconds
APP_START_TIMEOUT="10"              # Time to wait for app to start

# Backup configuration
KEEP_BACKUPS="5"                    # Number of backups to keep

# SSH options
SSH_OPTIONS="-o ConnectTimeout=10 -o BatchMode=yes"

# PM2 configuration
PM2_SCRIPT="bun"
PM2_ARGS="run preview" 
