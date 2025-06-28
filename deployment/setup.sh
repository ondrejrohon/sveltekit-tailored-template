#!/bin/bash

# Comprehensive setup script for slova-sveltekit deployment
# This script handles both environment configuration and server setup

set -e

# Source default configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/deploy.defaults.sh"

echo "🚀 Slova SvelteKit Complete Setup"
echo "=================================="
echo ""

# Function to prompt for input with default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    local var_name="$3"
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        if [ -z "$input" ]; then
            input="$default"
        fi
    else
        read -p "$prompt: " input
    fi
    
    eval "$var_name=\"$input\""
}

# Function to prompt for password (hidden input)
prompt_password() {
    local prompt="$1"
    local var_name="$2"
    
    read -s -p "$prompt: " input
    echo ""
    eval "$var_name=\"$input\""
}

# 🔧 PHASE 1: Environment Configuration
echo "🔧 PHASE 1: Environment Configuration"
echo "====================================="
echo ""

# Check if .env.production already exists
if [ -f ".env.production" ]; then
    echo "📖 Found existing .env.production configuration"
    read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
    if [[ ! $RECONFIGURE =~ ^[Yy]$ ]]; then
        echo "Using existing configuration..."
        # Load existing configuration
        set -a
        source .env.production
        set +a
    else
        echo "Starting fresh configuration..."
        # Get current values as defaults
        CURRENT_SERVER_HOST=$(grep '^SERVER_HOST=' .env.production | cut -d'=' -f2)
        CURRENT_SERVER_USER=$(grep '^SERVER_USER=' .env.production | cut -d'=' -f2)
        CURRENT_APP_NAME=$(grep '^APP_NAME=' .env.production | cut -d'=' -f2)
        CURRENT_DEPLOY_PATH=$(grep '^DEPLOY_PATH=' .env.production | cut -d'=' -f2)
        CURRENT_APP_PORT=$(grep '^APP_PORT=' .env.production | cut -d'=' -f2)
        CURRENT_DB_NAME=$(grep '^DB_NAME=' .env.production | cut -d'=' -f2)
        CURRENT_DB_PASS=$(grep '^DB_PASS=' .env.production | cut -d'=' -f2)
    fi
else
    echo "📝 No existing configuration found. Starting fresh setup..."
    # Check for legacy config
    if [ -f "../deploy.config.local.sh" ]; then
        echo "📖 Found legacy configuration, using as defaults..."
        CURRENT_SERVER_HOST=$(grep '^SERVER_HOST=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_SERVER_USER=$(grep '^SERVER_USER=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_APP_NAME=$(grep '^APP_NAME=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_DEPLOY_PATH=$(grep '^DEPLOY_PATH=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_APP_PORT=$(grep '^APP_PORT=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_DB_NAME=$(grep '^DB_NAME=' ../deploy.config.local.sh | cut -d'"' -f2)
        CURRENT_DB_PASS=$(grep '^DB_PASS=' ../deploy.config.local.sh | cut -d'"' -f2)
    else
        # Use defaults from deploy.defaults.sh
        CURRENT_DEPLOY_PATH="$DEPLOY_PATH"
    fi
fi

# If we need to configure (either fresh or reconfiguring)
if [ -z "$SERVER_HOST" ] || [[ $RECONFIGURE =~ ^[Yy]$ ]]; then
    echo ""
    echo "🔧 Server Configuration"
    echo "----------------------"
    prompt_with_default "Server host (IP address)" "$CURRENT_SERVER_HOST" "SERVER_HOST"
    prompt_with_default "Server username" "$CURRENT_SERVER_USER" "SERVER_USER"
    prompt_with_default "Application name" "$CURRENT_APP_NAME" "APP_NAME"
    prompt_with_default "Deployment path" "$CURRENT_DEPLOY_PATH" "DEPLOY_PATH"

    echo ""
    echo "🌐 Application Configuration"
    echo "---------------------------"
    prompt_with_default "Application port" "$CURRENT_APP_PORT" "APP_PORT"

    echo ""
    echo "🗄️  Database Configuration"
    echo "-------------------------"
    prompt_with_default "Database name" "$CURRENT_DB_NAME" "DB_NAME"
    prompt_password "Database password" "DB_PASS"

    echo ""
    echo "🔐 Security Configuration"
    echo "------------------------"
    # Read existing values if they exist
    CURRENT_JWT_SECRET=$(grep '^JWT_SECRET=' .env.production 2>/dev/null | cut -d'=' -f2 || echo "")
    CURRENT_ENCRYPTION_KEY=$(grep '^ENCRYPTION_KEY=' .env.production 2>/dev/null | cut -d'=' -f2 || echo "")
    
    # Generate new security keys
    echo "Generating JWT secret..."
    JWT_SECRET=$(openssl rand -hex 64)
    echo "Generating encryption key..."
    ENCRYPTION_KEY=$(openssl rand --base64 16)
    
    echo "✅ Security keys generated successfully!"

    # Validate required fields
    if [ -z "$SERVER_HOST" ] || [ -z "$SERVER_USER" ] || [ -z "$APP_NAME" ] || [ -z "$DEPLOY_PATH" ] || [ -z "$DB_NAME" ] || [ -z "$DB_PASS" ] || [ -z "$APP_PORT" ]; then
        echo "❌ Error: All fields are required!"
        exit 1
    fi

    echo ""
    echo "📝 Generating .env.production file..."
    
    # Create .env.production file
    cat > .env.production << EOF
# Slova SvelteKit Production Environment
# Generated by setup.sh on $(date)

# Server Configuration
SERVER_HOST=$SERVER_HOST
SERVER_USER=$SERVER_USER
APP_NAME=$APP_NAME
DEPLOY_PATH=$DEPLOY_PATH

# Application Configuration
APP_PORT=$APP_PORT

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USER=slova_user
DB_PASS=$DB_PASS

# Security Configuration
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

    echo "✅ .env.production file created successfully!"
fi

# Show configuration summary
echo ""
echo "📋 Configuration Summary:"
echo "   Server: $SERVER_USER@$SERVER_HOST"
echo "   App: $APP_NAME (port $APP_PORT)"
echo "   Deploy path: $DEPLOY_PATH"
echo "   Database: $DB_NAME"
echo "   Security: JWT_SECRET and ENCRYPTION_KEY generated"
echo ""

# 🔧 PHASE 2: Server Setup
echo "🔧 PHASE 2: Server Setup"
echo "========================"
echo ""

read -p "Continue with server setup? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled. Configuration saved to .env.production"
    exit 0
fi

echo ""
echo "🔍 Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" "echo 'SSH connection successful'" 2>/dev/null; then
    echo "❌ Error: Cannot connect to server via SSH. Please check:"
    echo "1. Server IP address is correct"
    echo "2. SSH key is configured and has proper permissions"
    echo "3. SSH key is added to server's authorized_keys"
    echo "4. Server is accessible from your network"
    exit 1
fi

echo "✅ SSH connection successful!"
echo ""

echo "📤 Setting up remote server..."
echo ""

# Execute all setup commands in a single SSH session
ssh -t "$SERVER_USER@$SERVER_HOST" "
set -e

echo '🔧 Updating system packages...'
sudo apt update && sudo apt upgrade -y

echo '📦 Installing required packages...'
sudo apt install -y curl git nginx postgresql postgresql-contrib unzip npm

echo '🐰 Installing bun...'
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

echo '⚡ Installing PM2...'
sudo npm install -g pm2

echo '📁 Creating deployment directory...'
sudo mkdir -p '$DEPLOY_PATH'
sudo chown \$USER:\$USER '$DEPLOY_PATH'
mkdir -p '$DEPLOY_PATH/current' '$DEPLOY_PATH/previous' '$DEPLOY_PATH/deployments' '$DEPLOY_PATH/logs'

echo '🗄️ Setting up PostgreSQL...'
sudo systemctl start postgresql
sudo systemctl enable postgresql

echo '🗄️ Creating database and user...'
sudo -u postgres psql << 'EOF'
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
\q
EOF

echo '⚙️ Creating PM2 ecosystem file...'
cat > '$DEPLOY_PATH/ecosystem.config.js' << 'EOF'
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

echo '🔥 Setting up firewall...'
sudo ufw allow ssh
sudo ufw allow 'Nginx Full'
sudo ufw --force enable

echo '✅ Server setup completed successfully!'
"

echo ""
echo "🎉 Complete setup finished!"
echo ""
echo "📋 Summary:"
echo "✅ Environment configuration saved to .env.production"
echo "✅ Server setup completed successfully"
echo "✅ Database configured and ready"
echo ""
echo "🚀 You can now proceed with deployment using:"
echo "   cd deployment && ./deploy.sh" 