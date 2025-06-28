#!/bin/bash

# Deployment script for slova-sveltekit
# Usage: ./deploy.sh [environment]

set -e  # Exit on any error

# Configuration overrides
ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOCAL_BUILD_DIR="deployment-package"
LOG_FILE="deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

# Load configuration from .env.production
load_configuration() {
    # Load default values first
    if [ -f "deploy.defaults.sh" ]; then
        source deploy.defaults.sh
    else
        error "Default configuration file deploy.defaults.sh not found"
    fi
    
    if [ -f "../.env.production" ]; then
        # Source the .env.production file
        set -a  # automatically export all variables
        source ../.env.production
        set +a  # stop automatically exporting
        log "Configuration loaded from .env.production"
    elif [ -f "deploy.config.local.sh" ]; then
        # Fallback to local config for backward compatibility
        source deploy.config.local.sh
        warning "Using deploy.config.local.sh (deprecated). Please run ./setup-env.sh to create .env.production"
    else
        error "No configuration found. Please run ./setup-env.sh to create .env.production"
    fi
    
    # Set deployment name after loading config
    DEPLOYMENT_NAME="${APP_NAME}_${TIMESTAMP}"
    
    # Update HEALTH_CHECK_URL with the actual APP_PORT
    HEALTH_CHECK_URL="http://localhost:${APP_PORT}/api/health"
}

# Check if server is reachable
check_server() {
    log "Checking server connectivity..."
    if ! ssh $SSH_OPTIONS "$SERVER_USER@$SERVER_HOST" "echo 'Server is reachable'" >/dev/null 2>&1; then
        error "Cannot connect to server $SERVER_HOST"
    fi
    success "Server is reachable"
}

# Check local git status
check_git_status() {
    log "Checking git status..."
    if [ -n "$(git status --porcelain)" ]; then
        warning "Working directory is not clean. Consider committing changes first."
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Deployment cancelled"
        fi
    fi
    success "Git status OK"
}

# Build locally
build_app() {
    log "Building application locally..."
    
    # Check if bun is installed
    if ! command -v bun &> /dev/null; then
        error "bun is not installed. Please install bun first."
    fi
    
    # Install dependencies
    log "Installing dependencies..."
    bun install
    
    # # Run tests
    # log "Running tests..."
    # if ! bun run test; then
    #     error "Tests failed. Deployment cancelled."
    # fi
    
    # Build the application
    log "Building application..."
    if ! bun run build; then
        error "Build failed. Deployment cancelled."
    fi
    
    success "Application built successfully"
}

# Create deployment package
create_package() {
    log "Creating deployment package..."
    
    # Create deployment directory
    mkdir -p "$LOCAL_BUILD_DIR"
    
    # Copy built files
    cp -r build/* "$LOCAL_BUILD_DIR/"
    
    # Copy package.json and other necessary files
    cp package.json "$LOCAL_BUILD_DIR/"
    cp bun.lock "$LOCAL_BUILD_DIR/"
    cp svelte.config.js "$LOCAL_BUILD_DIR/"
    cp drizzle.config.ts "$LOCAL_BUILD_DIR/"
    cp -r drizzle "$LOCAL_BUILD_DIR/"
    
    # Copy environment file if it exists
    if [ -f ".env.$ENVIRONMENT" ]; then
        cp ".env.$ENVIRONMENT" "$LOCAL_BUILD_DIR/.env"
    else
        warning "No .env.$ENVIRONMENT file found. Make sure environment variables are set on server."
    fi
    
    # Create tar.gz package
    tar -czf "${DEPLOYMENT_NAME}.tar.gz" -C "$LOCAL_BUILD_DIR" .
    
    success "Deployment package created: ${DEPLOYMENT_NAME}.tar.gz"
}

# Backup current version on server
backup_current() {
    log "Backing up current version on server..."
    
    ssh "$SERVER_USER@$SERVER_HOST" "DEPLOY_PATH=$DEPLOY_PATH; if [ -d \"\$DEPLOY_PATH/current\" ]; then mkdir -p \"\$DEPLOY_PATH/previous\"; rm -rf \"\$DEPLOY_PATH/previous\"; mv \"\$DEPLOY_PATH/current\" \"\$DEPLOY_PATH/previous\"; echo 'Previous version backed up'; else echo 'No current version found'; fi"
    
    success "Current version backed up"
}

# Upload new version to server
upload_package() {
    log "Uploading deployment package to server..."
    
    scp "${DEPLOYMENT_NAME}.tar.gz" "$SERVER_USER@$SERVER_HOST:$DEPLOY_PATH/"
    
    success "Package uploaded to server"
}

# Deploy on server
deploy_on_server() {
    log "Deploying on server..."
    
    # Create a temporary script for the remote server
    cat > /tmp/deploy_remote.sh << 'REMOTE_SCRIPT'
#!/bin/bash
set -e

DEPLOY_PATH="$1"
DEPLOYMENT_NAME="$2"
APP_NAME="$3"
PM2_SCRIPT="$4"
PM2_ARGS="$5"
HEALTH_CHECK_TIMEOUT="$6"
HEALTH_CHECK_URL="$7"
APP_START_TIMEOUT="$8"
KEEP_BACKUPS="$9"

# Ensure bun is available in PATH
export PATH="$HOME/.bun/bin:$PATH"
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
if [ -f ~/.profile ]; then
    source ~/.profile
fi

# Check if bun is available
if ! command -v bun &> /dev/null; then
    echo "Error: bun is not available. Please ensure bun is installed on the server."
    exit 1
fi

cd "$DEPLOY_PATH"

# Create current directory
mkdir -p current

# Extract new version
tar -xzf "${DEPLOYMENT_NAME}.tar.gz" -C current/

# Install dependencies
cd current
bun install

# Run database migrations
echo "Running database migrations..."
if bun run db:migrate; then
    echo "Migrations completed successfully"
else
    echo "Migration failed, rolling back..."
    cd ..
    rm -rf current
    mv previous current
    exit 1
fi

# Restart PM2 process
echo "Restarting PM2 process..."
pm2 restart "$APP_NAME" || pm2 start "$PM2_SCRIPT" --name "$APP_NAME" -- "$PM2_ARGS"

# Wait for app to start
echo "Waiting for application to start..."
sleep "$APP_START_TIMEOUT"

# Health checks
echo "Running health checks..."

# Check if PM2 process is running
if ! pm2 list | grep -q "$APP_NAME.*online"; then
    echo "PM2 process is not running, rolling back..."
    cd ..
    rm -rf current
    mv previous current
    pm2 restart "$APP_NAME"
    exit 1
fi

# Check health endpoint
if curl -f --max-time "$HEALTH_CHECK_TIMEOUT" "$HEALTH_CHECK_URL" >/dev/null 2>&1; then
    echo "Health check passed"
else
    echo "Health check failed, rolling back..."
    cd ..
    rm -rf current
    mv previous current
    pm2 restart "$APP_NAME"
    exit 1
fi

# Cleanup old backups
if [ -d "deployments" ]; then
    cd deployments
    ls -t | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
    cd ..
fi

echo "Deployment completed successfully"
REMOTE_SCRIPT

    # Upload and execute the remote script
    scp /tmp/deploy_remote.sh "$SERVER_USER@$SERVER_HOST:/tmp/"
    ssh "$SERVER_USER@$SERVER_HOST" "chmod +x /tmp/deploy_remote.sh && /tmp/deploy_remote.sh \"$DEPLOY_PATH\" \"$DEPLOYMENT_NAME\" \"$APP_NAME\" \"$PM2_SCRIPT\" \"$PM2_ARGS\" \"$HEALTH_CHECK_TIMEOUT\" \"$HEALTH_CHECK_URL\" \"$APP_START_TIMEOUT\" \"$KEEP_BACKUPS\""
    
    # Clean up local temp file
    rm -f /tmp/deploy_remote.sh
    
    success "Deployment completed on server"
}

# Cleanup
cleanup() {
    log "Cleaning up local files..."
    rm -rf "$LOCAL_BUILD_DIR"
    rm -f "${DEPLOYMENT_NAME}.tar.gz"
    success "Cleanup completed"
}

# Main deployment function
main() {
    load_configuration
    
    log "Starting deployment to $ENVIRONMENT environment..."
    log "Server: $SERVER_USER@$SERVER_HOST"
    log "App: $APP_NAME"
    
    check_server
    check_git_status
    build_app
    create_package
    backup_current
    upload_package
    deploy_on_server
    cleanup
    
    success "Deployment completed successfully!"
}

# Run main function
main "$@" 
