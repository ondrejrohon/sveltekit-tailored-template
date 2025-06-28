#!/bin/bash

# Server setup script for slova-sveltekit deployment
# This script collects configuration and sets up the remote server

set -e

echo "Server setup for slova-sveltekit deployment"
echo "==========================================="
echo ""

# Load existing configuration if available
if [ -f ".env.production" ]; then
    echo "📖 Loading configuration from .env.production..."
    echo ""
    
    # Source the .env.production file to load all variables
    set -a  # automatically export all variables
    source .env.production
    set +a  # stop automatically exporting
    
    echo "Configuration loaded:"
    echo "Server: $SERVER_USER@$SERVER_HOST"
    echo "App: $APP_NAME (port $APP_PORT)"
    echo "Deploy path: $DEPLOY_PATH"
    echo "Database: $DB_NAME"
    echo ""
else
    echo "❌ No .env.production file found."
    echo "Please run ./setup-env.sh first to create your configuration."
    exit 1
fi

# Validate required configuration
if [ -z "$SERVER_HOST" ] || [ -z "$SERVER_USER" ] || [ -z "$APP_NAME" ] || [ -z "$DEPLOY_PATH" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$APP_PORT" ]; then
    echo "❌ Missing required configuration in .env.production"
    echo "Please ensure all required variables are set:"
    echo "SERVER_HOST, SERVER_USER, APP_NAME, DEPLOY_PATH, DB_NAME, DB_USER, DB_PASS, APP_PORT"
    exit 1
fi

echo "Configuration summary:"
echo "====================="
echo "Server IP: $SERVER_HOST"
echo "SSH User: $SERVER_USER"
echo "App Name: $APP_NAME"
echo "Deploy Path: $DEPLOY_PATH"
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: [hidden]"
echo "App Port: $APP_PORT"
echo ""

read -p "Continue with server setup? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "Error: Cannot connect to server via SSH. Please check:"
    echo "1. Server IP address is correct"
    echo "2. SSH key is configured and has proper permissions"
    echo "3. SSH key is added to server's authorized_keys"
    echo "4. Server is accessible from your network"
    exit 1
fi

echo "SSH connection successful!"
echo ""

# Create a temporary file for the remote script
TEMP_SCRIPT=$(mktemp)
cat > "$TEMP_SCRIPT" << 'REMOTE_SCRIPT_EOF'
#!/bin/bash

# Server setup script for slova-sveltekit deployment
# This script runs on the remote server

set -e

echo "Setting up server for slova-sveltekit deployment..."
echo ""

# Get configuration from command line arguments
DB_NAME="$1"
DB_USER="$2"
DB_PASS="$3"
DEPLOY_PATH="$4"

if [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ] || [ -z "$DEPLOY_PATH" ]; then
    echo "Error: Missing required parameters"
    echo "Usage: $0 <db_name> <db_user> <db_pass> <deploy_path>"
    exit 1
fi

echo "Configuration received:"
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: [hidden]"
echo "Deploy path: $DEPLOY_PATH"
echo ""

echo "Starting server setup..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y curl git nginx postgresql postgresql-contrib unzip npm

# Install bun
echo "Installing bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Install PM2 globally
echo "Installing PM2..."
sudo npm install -g pm2

# Create deployment directory
echo "Creating deployment directory..."
sudo mkdir -p "$DEPLOY_PATH"
sudo chown $USER:$USER "$DEPLOY_PATH"
mkdir -p "$DEPLOY_PATH/current" "$DEPLOY_PATH/previous" "$DEPLOY_PATH/deployments" "$DEPLOY_PATH/logs"

# Setup PostgreSQL
echo "Setting up PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user using provided values
echo "Creating database and user..."
sudo -u postgres psql << EOF
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

# Create PM2 ecosystem file
echo "Creating PM2 ecosystem file..."
cat > "$DEPLOY_PATH/ecosystem.config.js" << 'EOF'
module.exports = {
  apps: [{
    name: 'slova-sveltekit',
    script: 'bun',
    args: 'run preview',
    cwd: '/app/current',
    env: {
      NODE_ENV: 'production',
      PORT: 4173
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    log_file: '/app/logs/combined.log',
    out_file: '/app/logs/out.log',
    error_file: '/app/logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
}
EOF

# Setup firewall (optional)
echo "Setting up firewall..."
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo ""
echo "Server setup completed!"
echo ""
echo "Database configuration:"
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: [hidden]"
echo ""
echo "Next steps:"
echo "1. Update nginx configuration with your domain"
echo "2. Configure SSL with Let's Encrypt (recommended)"
echo "3. Test deployment from your local machine"
echo ""
echo "Note: Save your database credentials securely!"
REMOTE_SCRIPT_EOF

echo "Uploading and executing setup script on remote server..."
echo ""

# Copy the script to the remote server and execute it with parameters
scp "$TEMP_SCRIPT" "$SERVER_USER@$SERVER_HOST:/tmp/server-setup.sh"
ssh -t "$SERVER_USER@$SERVER_HOST" "chmod +x /tmp/server-setup.sh && /tmp/server-setup.sh '$DB_NAME' '$DB_USER' '$DB_PASS' '$DEPLOY_PATH'"

# Clean up the temporary file
rm "$TEMP_SCRIPT"

echo ""
echo "Remote server setup completed!"
echo ""
echo "Server has been configured using your .env.production settings."
echo "You can now proceed with deployment using the deploy.sh script." 