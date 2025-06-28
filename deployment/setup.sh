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

# Function to read .env.example and extract variable names
read_env_example() {
    if [ -f ".env.example" ]; then
        # Extract variable names from .env.example (lines that contain = but not comments)
        grep -E '^[A-Z_]+=' .env.example | cut -d'=' -f1
    else
        echo "Error: .env.example file not found!"
        exit 1
    fi
}

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
        # Get current values as defaults for deployment variables
        CURRENT_SERVER_HOST=$(grep '^SERVER_HOST=' .env.production | cut -d'=' -f2)
        CURRENT_SERVER_USER=$(grep '^SERVER_USER=' .env.production | cut -d'=' -f2)
        CURRENT_APP_NAME=$(grep '^APP_NAME=' .env.production | cut -d'=' -f2)
        CURRENT_DEPLOY_PATH=$(grep '^DEPLOY_PATH=' .env.production | cut -d'=' -f2)
        CURRENT_APP_PORT=$(grep '^APP_PORT=' .env.production | cut -d'=' -f2)
        CURRENT_DB_NAME=$(grep '^DB_NAME=' .env.production | cut -d'=' -f2)
        CURRENT_DB_USER=$(grep '^DB_USER=' .env.production | cut -d'=' -f2)
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
        CURRENT_DB_USER=$(grep '^DB_USER=' ../deploy.config.local.sh | cut -d'"' -f2)
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
    prompt_with_default "Database user" "$CURRENT_DB_USER" "DB_USER"
    prompt_password "Database password" "DB_PASS"

    echo ""
    echo "🔐 Security Configuration"
    echo "------------------------"
    # Generate new security keys
    echo "Generating JWT secret..."
    JWT_SECRET=$(openssl rand -hex 64)
    echo "Generating encryption key..."
    ENCRYPTION_KEY=$(openssl rand --base64 16)
    
    echo "✅ Security keys generated successfully!"

    echo ""
    echo "📋 Environment Variables from .env.example"
    echo "------------------------------------------"
    
    # Read all variables from .env.example into an array
    env_vars=()
    while IFS= read -r var_name; do
        if [ -n "$var_name" ]; then
            env_vars+=("$var_name")
        fi
    done < <(read_env_example)
    
    # Process each variable
    for var_name in "${env_vars[@]}"; do
        # Skip auto-generated variables
        case "$var_name" in
            "JWT_SECRET"|"ENCRYPTION_KEY"|"DATABASE_URL")
                continue
                ;;
        esac
        
        # Get current value from .env.production if it exists
        current_value=""
        if [ -f ".env.production" ]; then
            current_value=$(grep "^${var_name}=" .env.production | cut -d'=' -f2- || echo "")
        fi
        
        # Create user-friendly prompt descriptions
        case "$var_name" in
            "ORIGIN")
                prompt_desc="Public origin URL (e.g., http://localhost:5173 for dev, https://yourdomain.com for prod)"
                ;;
            "ANTHROPIC_API_KEY")
                prompt_desc="Anthropic API key for AI features (get from https://console.anthropic.com/)"
                ;;
            "GOOGLE_CLIENT_ID")
                prompt_desc="Google OAuth Client ID (get from https://console.cloud.google.com/apis/credentials)"
                ;;
            "GOOGLE_CLIENT_SECRET")
                prompt_desc="Google OAuth Client Secret (get from https://console.cloud.google.com/apis/credentials)"
                ;;
            "MAILERSEND_TOKEN")
                prompt_desc="MailerSend API token for email functionality (get from https://www.mailersend.com/app/api-keys)"
                ;;
            *)
                prompt_desc="$var_name"
                ;;
        esac
        
        # Determine if this should be a password prompt
        case "$var_name" in
            *"SECRET"*|*"KEY"*|*"TOKEN"*|*"PASSWORD"*)
                if [ -n "$current_value" ]; then
                    read -p "🔐 $prompt_desc [current value hidden]: " input
                    if [ -z "$input" ]; then
                        input="$current_value"
                    fi
                else
                    read -s -p "🔐 $prompt_desc: " input
                    echo ""
                fi
                ;;
            *)
                if [ -n "$current_value" ]; then
                    read -p "🌐 $prompt_desc [$current_value]: " input
                    if [ -z "$input" ]; then
                        input="$current_value"
                    fi
                else
                    read -p "🌐 $prompt_desc: " input
                fi
                ;;
        esac
        
        # Store the variable with the actual input value
        eval "${var_name}=\"${input}\""
    done

    # Validate required fields
    required_vars=("SERVER_HOST" "SERVER_USER" "APP_NAME" "DEPLOY_PATH" "DB_NAME" "DB_USER" "DB_PASS" "APP_PORT")
    missing_vars=()
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done
    
    if [ ${#missing_vars[@]} -gt 0 ]; then
        echo "❌ Error: All required fields must be filled!"
        echo "Missing required fields:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi

    # Construct DATABASE_URL from the database variables we collected
    DATABASE_URL="postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}"

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
DATABASE_URL=$DATABASE_URL

# Security Configuration
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

    # Add all variables from .env.example (except the ones we already added)
    for var_name in "${env_vars[@]}"; do
        if [ -n "$var_name" ]; then
            # Skip variables we've already added
            case "$var_name" in
                "JWT_SECRET"|"ENCRYPTION_KEY"|"DATABASE_URL")
                    continue
                    ;;
            esac
            
            # Add the variable to .env.production
            var_value="${!var_name}"
            if [ -n "$var_value" ]; then
                echo "$var_name=$var_value" >> .env.production
            else
                echo "Warning: $var_name is empty, adding empty value"
                echo "$var_name=" >> .env.production
            fi
        fi
    done

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