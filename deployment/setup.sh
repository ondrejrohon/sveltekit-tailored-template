#!/bin/bash

# Comprehensive setup script for slova-sveltekit deployment
# This script handles both environment configuration and server setup

# Remove strict error handling to allow for password retries
# set -e

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

# Function to execute command with sudo password retry
execute_with_sudo_retry() {
    local command="$1"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if eval "$command"; then
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                echo "⚠️  Command failed (attempt $attempt/$max_attempts). Please check your sudo password and try again."
                echo "Press Enter to retry..."
                read
                ((attempt++))
            else
                echo "❌ Command failed after $max_attempts attempts. Please check your configuration and try again."
                return 1
            fi
        fi
    done
}

# Function to prompt for password with retry
prompt_password_with_retry() {
    local prompt="$1"
    local var_name="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            echo "⚠️  Please try again (attempt $attempt/$max_attempts):"
        fi
        
        read -s -p "$prompt: " input
        echo ""
        
        if [ -n "$input" ]; then
            eval "$var_name=\"$input\""
            return 0
        else
            if [ $attempt -lt $max_attempts ]; then
                echo "❌ Password cannot be empty. Please try again."
                ((attempt++))
            else
                echo "❌ Failed to get valid password after $max_attempts attempts."
                return 1
            fi
        fi
    done
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
    
    # Handle database password with existing value support
    if [ -n "$CURRENT_DB_PASS" ]; then
        read -p "🔐 Database password [current value hidden]: " input
        if [ -z "$input" ]; then
            DB_PASS="$CURRENT_DB_PASS"
        else
            DB_PASS="$input"
        fi
    else
        # Prompt for database password with retry
        if ! prompt_password_with_retry "Database password" "DB_PASS"; then
            echo "❌ Failed to get database password. Setup cancelled."
            exit 1
        fi
    fi

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
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASS=$DB_PASS

# Security Configuration
JWT_SECRET=$JWT_SECRET
ENCRYPTION_KEY=$ENCRYPTION_KEY
EOF

    # Add all variables from .env.example (except the ones we already added)
    for var_name in "${env_vars[@]}"; do
        if [ -n "$var_name" ]; then
            # Skip variables we've already added
            case "$var_name" in
                "JWT_SECRET"|"ENCRYPTION_KEY"|"DATABASE_URL"|"DB_NAME"|"DB_USER"|"DB_PASS")
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

# Validate that all required variables are set before proceeding
required_vars=("SERVER_HOST" "SERVER_USER" "APP_NAME" "DEPLOY_PATH" "DB_NAME" "DB_USER" "DB_PASS" "APP_PORT")
missing_vars=()

for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
        missing_vars+=("$var")
    fi
done

if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "❌ Error: Missing required configuration variables!"
    echo "Missing variables:"
    for var in "${missing_vars[@]}"; do
        echo "  - $var"
    done
    echo ""
    echo "Please run the configuration phase first or check your .env.production file."
    exit 1
fi

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

# Function to perform server setup with retry
perform_server_setup() {
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if [ $attempt -gt 1 ]; then
            echo "🔄 Retrying server setup (attempt $attempt/$max_attempts)..."
            echo ""
        fi
        
        # Create a temporary script file for the remote server setup
        TEMP_SCRIPT=$(mktemp)
        cat > "$TEMP_SCRIPT" << EOF
#!/bin/bash

# Remove strict error handling for better password handling
# set -e

echo '🔧 Updating system packages...'
if ! sudo apt update && sudo apt upgrade -y; then
    echo '❌ Failed to update system packages. Please check your sudo password.'
    exit 1
fi

echo '📦 Installing required packages...'
if ! sudo apt install -y curl git nginx postgresql postgresql-contrib unzip npm; then
    echo '❌ Failed to install required packages. Please check your sudo password.'
    exit 1
fi

echo '🐰 Installing bun...'
if ! curl -fsSL https://bun.sh/install | bash; then
    echo '❌ Failed to install bun.'
    exit 1
fi
source ~/.bashrc

echo '⚡ Installing PM2...'
if ! sudo npm install -g pm2; then
    echo '❌ Failed to install PM2. Please check your sudo password.'
    exit 1
fi

echo '📁 Creating deployment directory...'
if ! sudo mkdir -p "$DEPLOY_PATH"; then
    echo '❌ Failed to create deployment directory. Please check your sudo password.'
    exit 1
fi
if ! sudo chown \$USER:\$USER "$DEPLOY_PATH"; then
    echo '❌ Failed to change ownership of deployment directory. Please check your sudo password.'
    exit 1
fi
mkdir -p "$DEPLOY_PATH/current" "$DEPLOY_PATH/previous" "$DEPLOY_PATH/deployments" "$DEPLOY_PATH/logs"

echo '🗄️ Setting up PostgreSQL...'
if ! sudo systemctl start postgresql; then
    echo '❌ Failed to start PostgreSQL. Please check your sudo password.'
    exit 1
fi
if ! sudo systemctl enable postgresql; then
    echo '❌ Failed to enable PostgreSQL. Please check your sudo password.'
    exit 1
fi

echo '🗄️ Creating database and user...'
if ! sudo -u postgres psql << PSQL_EOF
-- Create database if it doesn't exist
CREATE DATABASE $DB_NAME;

-- Create user if it doesn't exist
DO \\\$\\\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
        CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';
    ELSE
        ALTER USER $DB_USER WITH PASSWORD '$DB_PASS';
    END IF;
END
\\\$\\\$;

-- Grant all privileges on database
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Connect to the specific database to grant schema privileges
\\c $DB_NAME

-- Grant all privileges on schema
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;

-- Set default privileges for future objects
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO $DB_USER;

-- Grant CREATE privilege on database (needed for migrations)
GRANT CREATE ON DATABASE $DB_NAME TO $DB_USER;

\\q
PSQL_EOF
then
    echo '❌ Failed to create database and user. Please check your sudo password.'
    exit 1
fi

echo '⚙️ Creating PM2 ecosystem file...'
cat > "$DEPLOY_PATH/ecosystem.config.js" << PM2_EOF
module.exports = {
  apps: [{
    name: 'slova-sveltekit',
    script: 'bun',
    args: 'run preview',
    cwd: '$DEPLOY_PATH/current',
    env: {
      NODE_ENV: 'production',
      PORT: 4173,
      DATABASE_URL: 'postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME',
      DB_NAME: '$DB_NAME',
      DB_USER: '$DB_USER',
      DB_PASS: '$DB_PASS'
    },
    instances: 1,
    autorestart: true,
    watch: false,
    max_memory_restart: '1G',
    log_file: '$DEPLOY_PATH/logs/combined.log',
    out_file: '$DEPLOY_PATH/logs/out.log',
    error_file: '$DEPLOY_PATH/logs/error.log',
    log_date_format: 'YYYY-MM-DD HH:mm:ss Z'
  }]
}
PM2_EOF

echo '🔥 Setting up firewall...'
if ! sudo ufw allow ssh; then
    echo '❌ Failed to configure firewall for SSH. Please check your sudo password.'
    exit 1
fi
if ! sudo ufw allow 'Nginx Full'; then
    echo '❌ Failed to configure firewall for Nginx. Please check your sudo password.'
    exit 1
fi
if ! sudo ufw --force enable; then
    echo '❌ Failed to enable firewall. Please check your sudo password.'
    exit 1
fi

echo '✅ Server setup completed successfully!'
EOF

        # Copy the script to the remote server and execute it
        echo "📤 Uploading setup script to server..."
        if ! scp "$TEMP_SCRIPT" "$SERVER_USER@$SERVER_HOST:/tmp/server_setup.sh"; then
            echo "❌ Failed to upload setup script to server."
            rm -f "$TEMP_SCRIPT"
            if [ $attempt -lt $max_attempts ]; then
                echo "Press Enter to retry..."
                read
                ((attempt++))
                continue
            else
                return 1
            fi
        fi

        echo "🚀 Executing server setup..."
        if ! ssh -t "$SERVER_USER@$SERVER_HOST" "chmod +x /tmp/server_setup.sh && /tmp/server_setup.sh"; then
            echo "❌ Server setup failed. Please check the error messages above."
            rm -f "$TEMP_SCRIPT"
            if [ $attempt -lt $max_attempts ]; then
                echo "Press Enter to retry..."
                read
                ((attempt++))
                continue
            else
                return 1
            fi
        fi

        # Clean up temporary script
        rm -f "$TEMP_SCRIPT"
        return 0
    done
    
    return 1
}

# Perform server setup with retry
if ! perform_server_setup; then
    echo "❌ Server setup failed after multiple attempts. Please check the error messages above and try again later."
    exit 1
fi

echo ""
echo "🔍 Verifying database setup..."
echo ""

# Test database connection with retry logic
echo "Testing database connection..."
max_db_attempts=3
db_attempt=1

while [ $db_attempt -le $max_db_attempts ]; do
    if ssh -t "$SERVER_USER@$SERVER_HOST" "
        # Set environment variables to avoid URL encoding issues
        export PGPASSWORD='$DB_PASS'
        
        # Test connection with better error reporting
        if psql -h localhost -p 5432 -U '$DB_USER' -d '$DB_NAME' -c 'SELECT version();' 2>&1; then
            echo '✅ Database connection successful!'
            exit 0
        else
            echo '❌ Database connection failed!'
            echo 'Trying to diagnose the issue...'
            
            # Check if user exists
            if sudo -u postgres psql -c \"SELECT rolname FROM pg_roles WHERE rolname = '$DB_USER';\" | grep -q '$DB_USER'; then
                echo '✅ Database user exists'
            else
                echo '❌ Database user does not exist'
            fi
            
            # Check if database exists
            if sudo -u postgres psql -c \"SELECT datname FROM pg_database WHERE datname = '$DB_NAME';\" | grep -q '$DB_NAME'; then
                echo '✅ Database exists'
            else
                echo '❌ Database does not exist'
            fi
            
            # Try connecting as postgres to verify database is accessible
            if sudo -u postgres psql -d '$DB_NAME' -c 'SELECT version();' >/dev/null 2>&1; then
                echo '✅ Database is accessible as postgres user'
            else
                echo '❌ Database is not accessible even as postgres user'
            fi
            
            exit 1
        fi
    " 2>/dev/null; then
        break
    else
        if [ $db_attempt -lt $max_db_attempts ]; then
            echo "⚠️  Database connection failed (attempt $db_attempt/$max_db_attempts)."
            echo "Please check your database password and try again."
            echo "Press Enter to retry..."
            read
            ((db_attempt++))
        else
            echo "❌ Database connection failed after $max_db_attempts attempts."
            echo "Please check your database configuration and try again."
            exit 1
        fi
    fi
done

echo "Testing database permissions..."
if ! ssh -t "$SERVER_USER@$SERVER_HOST" "
    # Set environment variables to avoid URL encoding issues
    export PGPASSWORD='$DB_PASS'
    
    if psql -h localhost -p 5432 -U '$DB_USER' -d '$DB_NAME' -c 'CREATE TABLE test_permissions (id SERIAL PRIMARY KEY); DROP TABLE test_permissions;' >/dev/null 2>&1; then
        echo '✅ Database permissions verified!'
        exit 0
    else
        echo '❌ Database permissions test failed!'
        exit 1
    fi
" 2>/dev/null; then
    echo "❌ Database permissions test failed. Please check your database configuration."
    exit 1
fi

echo "✅ Database setup verification completed!"

echo ""
echo "🎉 Complete setup finished!"
echo ""
echo "📋 Summary:"
echo "✅ Environment configuration saved to .env.production"
echo "✅ Server setup completed successfully"
echo "✅ Database configured and ready"
echo ""
echo "🚀 You can now proceed with deployment using:"
echo "   deployment/deploy.sh" 