#!/bin/bash

# Default deployment configuration values
# These values are unlikely to change and are separated from user-specific configuration

# Application Configuration
HEALTH_CHECK_URL="http://localhost:4173/api/health"
HEALTH_CHECK_TIMEOUT="30"
APP_START_TIMEOUT="10"

# Backup Configuration
KEEP_BACKUPS="2"

# SSH Options
SSH_OPTIONS="-o ConnectTimeout=10 -o BatchMode=yes"

# PM2 Configuration
PM2_SCRIPT="bun"
PM2_ARGS="run preview" 