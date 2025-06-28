#!/bin/bash

# Server setup script for slova-sveltekit deployment
# Run this on your Hetzner server

set -e

echo "Setting up server for slova-sveltekit deployment..."

# Update system
echo "Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install required packages
echo "Installing required packages..."
sudo apt install -y curl git nginx postgresql postgresql-contrib

# Install bun
echo "Installing bun..."
curl -fsSL https://bun.sh/install | bash
source ~/.bashrc

# Install PM2 globally
echo "Installing PM2..."
npm install -g pm2

# Create deployment directory
echo "Creating deployment directory..."
sudo mkdir -p /app
sudo chown $USER:$USER /app
mkdir -p /app/current /app/previous /app/deployments /app/logs

# Setup PostgreSQL
echo "Setting up PostgreSQL..."
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Create database and user (adjust as needed)
echo "Creating database and user..."
sudo -u postgres psql << EOF
CREATE DATABASE slova_production;
CREATE USER slova_user WITH PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE slova_production TO slova_user;
\q
EOF

# Configure nginx
echo "Configuring nginx..."
sudo cp nginx.conf.template /etc/nginx/sites-available/slova-sveltekit
sudo ln -sf /etc/nginx/sites-available/slova-sveltekit /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
sudo nginx -t

# Start nginx
sudo systemctl restart nginx
sudo systemctl enable nginx

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

echo "Server setup completed!"
echo ""
echo "Next steps:"
echo "1. Update nginx configuration with your domain"
echo "2. Configure SSL with Let's Encrypt (recommended)"
echo "3. Update database password in PostgreSQL"
echo "4. Create .env.production file with your production settings"
echo "5. Test deployment from your local machine" 