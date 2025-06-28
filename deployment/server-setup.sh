#!/bin/bash

# Server setup script for slova-sveltekit deployment
# Run this on your Hetzner server

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

# TODO: Configure nginx
# # Configure nginx
# echo "Configuring nginx..."
# sudo cp nginx.conf.template /etc/nginx/sites-available/slova-sveltekit
# sudo ln -sf /etc/nginx/sites-available/slova-sveltekit /etc/nginx/sites-enabled/
# sudo rm -f /etc/nginx/sites-enabled/default

# # Test nginx configuration
# sudo nginx -t

# # Start nginx
# sudo systemctl restart nginx
# sudo systemctl enable nginx

# Create PM2 ecosystem file
echo "Creating PM2 ecosystem file..."
cat > /app/ecosystem.config.js << EOF
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