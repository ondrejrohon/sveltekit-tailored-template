#!/bin/bash

# Remote server setup script for slova-sveltekit deployment
# This script runs the server setup on a remote server

set -e

echo "Remote server setup for slova-sveltekit deployment"
echo "=================================================="
echo ""

# Interactive configuration for remote server
echo "Please provide the following server configuration:"
read -p "Server IP address: " SERVER_IP

if [ -z "$SERVER_IP" ]; then
    echo "Error: Server IP address cannot be empty!"
    exit 1
fi

read -p "SSH username (default: root): " SSH_USER
SSH_USER=${SSH_USER:-root}

echo ""
echo "Configuration summary:"
echo "Server IP: $SERVER_IP"
echo "SSH User: $SSH_USER"
echo "SSH Key: Using default SSH key configuration"
echo ""

read -p "Continue with this configuration? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

echo ""
echo "Testing SSH connection..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SSH_USER@$SERVER_IP" "echo 'SSH connection successful'" 2>/dev/null; then
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

# Interactive configuration
echo "Please provide the following database configuration:"
read -p "Database name (default: slova_production): " DB_NAME
DB_NAME=${DB_NAME:-slova_production}

read -p "Database user (default: slova_user): " DB_USER
DB_USER=${DB_USER:-slova_user}

read -s -p "Database password: " DB_PASS
echo ""
read -s -p "Confirm database password: " DB_PASS_CONFIRM
echo ""

if [ "$DB_PASS" != "$DB_PASS_CONFIRM" ]; then
    echo "Error: Passwords do not match!"
    exit 1
fi

if [ -z "$DB_PASS" ]; then
    echo "Error: Database password cannot be empty!"
    exit 1
fi

echo ""
echo "Configuration summary:"
echo "Database name: $DB_NAME"
echo "Database user: $DB_USER"
echo "Database password: [hidden]"
echo ""

read -p "Continue with this configuration? (y/N): " CONFIRM
if [[ ! $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Setup cancelled."
    exit 0
fi

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
sudo mkdir -p /app
sudo chown $USER:$USER /app
mkdir -p /app/current /app/previous /app/deployments /app/logs

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
cat > /app/ecosystem.config.js << 'EOF'
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
echo "3. Create .env.production file with your production settings"
echo "4. Test deployment from your local machine"
echo ""
echo "Note: Save your database credentials securely!"
REMOTE_SCRIPT_EOF

echo "Uploading and executing setup script on remote server..."
echo ""

# Copy the script to the remote server and execute it
scp "$TEMP_SCRIPT" "$SSH_USER@$SERVER_IP:/tmp/server-setup.sh"
ssh -t "$SSH_USER@$SERVER_IP" "chmod +x /tmp/server-setup.sh && /tmp/server-setup.sh"

# Clean up the temporary file
rm "$TEMP_SCRIPT"

echo ""
echo "Remote server setup completed!"
echo ""
echo "You can now proceed with deployment using the deploy.sh script." 