#!/bin/bash

# Deployment script for slova-sveltekit
# Usage: ./deploy.sh [environment]

set -e  # Exit on any error

# Load configuration
if [ -f "deploy.config.local.sh" ]; then
    source deploy.config.local.sh
else
    source deploy.config.sh
fi

# Configuration overrides
ENVIRONMENT=${1:-production}
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_NAME="${APP_NAME}_${TIMESTAMP}"
LOCAL_BUILD_DIR="build"
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
    
    # Run tests
    log "Running tests..."
    if ! bun run test; then
        error "Tests failed. Deployment cancelled."
    fi
    
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
    
    ssh "$SERVER_USER@$SERVER_HOST" << EOF
        if [ -d "$DEPLOY_PATH/current" ]; then
            mkdir -p "$DEPLOY_PATH/previous"
            rm -rf "$DEPLOY_PATH/previous"
            mv "$DEPLOY_PATH/current" "$DEPLOY_PATH/previous"
            echo "Previous version backed up"
        else
            echo "No current version found"
        fi
    EOF
    
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
    
    ssh "$SERVER_USER@$SERVER_HOST" << EOF
        set -e
        
        cd $DEPLOY_PATH
        
        # Create current directory
        mkdir -p current
        
        # Extract new version
        tar -xzf "${DEPLOYMENT_NAME}.tar.gz" -C current/
        
        # Install dependencies
        cd current
        bun install --production
        
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
        pm2 restart $APP_NAME || pm2 start $PM2_SCRIPT --name $APP_NAME -- $PM2_ARGS
        
        # Wait for app to start
        echo "Waiting for application to start..."
        sleep $APP_START_TIMEOUT
        
        # Health checks
        echo "Running health checks..."
        
        # Check if PM2 process is running
        if ! pm2 list | grep -q "$APP_NAME.*online"; then
            echo "PM2 process is not running, rolling back..."
            cd ..
            rm -rf current
            mv previous current
            pm2 restart $APP_NAME
            exit 1
        fi
        
        # Check health endpoint
        if curl -f --max-time $HEALTH_CHECK_TIMEOUT $HEALTH_CHECK_URL >/dev/null 2>&1; then
            echo "Health check passed"
        else
            echo "Health check failed, rolling back..."
            cd ..
            rm -rf current
            mv previous current
            pm2 restart $APP_NAME
            exit 1
        fi
        
        # Cleanup old backups
        if [ -d "deployments" ]; then
            cd deployments
            ls -t | tail -n +$((KEEP_BACKUPS + 1)) | xargs -r rm -f
            cd ..
        fi
        
        echo "Deployment completed successfully"
    EOF
    
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