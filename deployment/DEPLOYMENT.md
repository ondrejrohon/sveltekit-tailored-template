# Deployment Guide

This guide explains how to deploy the slova-sveltekit application to your Hetzner server.

## Prerequisites

### Local Machine
- `bun` installed
- SSH access to your server
- SSH key configured for passwordless access

### Server
- Ubuntu with nginx, postgres, and pm2
- `bun` installed on server
- `/app` directory created with proper permissions

## Setup

### 1. Configure Deployment

Copy the configuration template and customize it for your environment:

```bash
cp deploy.config.sh deploy.config.local.sh
```

Edit `deploy.config.local.sh` with your server details:

```bash
SERVER_HOST="your-server-ip"
SERVER_USER="your-username"
DB_NAME="your-database-name"
```

### 2. Environment Variables

Create environment-specific files:

```bash
# Development
cp .env.example .env.development

# Production  
cp .env.example .env.production
```

Update the production environment file with your production values:
- Database connection string
- API keys (Anthropic, OAuth, etc.)
- JWT secrets
- Email service configuration

### 3. Server Setup

On your server, create the deployment directory:

```bash
sudo mkdir -p /app
sudo chown $USER:$USER /app
```

Install bun on the server:

```bash
curl -fsSL https://bun.sh/install | bash
```

### 4. PM2 Setup

Create a PM2 ecosystem file on the server (`/app/ecosystem.config.js`):

```javascript
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
    max_memory_restart: '1G'
  }]
}
```

## Usage

### Deploy to Production

```bash
./deploy.sh production
```

### Deploy to Staging (if configured)

```bash
./deploy.sh staging
```

## What the Script Does

1. **Pre-deployment Checks**
   - Verifies server connectivity
   - Checks git status (warns if working directory is dirty)
   - Ensures bun is installed locally

2. **Local Build**
   - Installs dependencies with `bun install`
   - Runs tests with `bun run test`
   - Builds the application with `bun run build`
   - Creates a timestamped deployment package

3. **Server Deployment**
   - Backs up current version to `/app/previous/`
   - Uploads new version to server
   - Extracts deployment package to `/app/current/`
   - Installs production dependencies
   - Runs database migrations
   - Restarts PM2 process

4. **Health Checks**
   - Verifies PM2 process is running
   - Tests application health endpoint
   - Rolls back if health checks fail

5. **Cleanup**
   - Removes local build artifacts
   - Logs deployment results

## Rollback

If deployment fails, the script automatically rolls back to the previous version.

To manually rollback:

```bash
ssh your-username@your-server-ip
cd /app
rm -rf current
mv previous current
pm2 restart slova-sveltekit
```

## Monitoring

### Logs
- Deployment logs: `deploy.log` (local)
- Application logs: `pm2 logs slova-sveltekit` (server)
- PM2 status: `pm2 status`

### Health Check Endpoint

The script expects a health check endpoint at `/api/health`. Make sure your application implements this endpoint to verify:
- Database connectivity
- Application status

## Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   - Verify server IP and username
   - Ensure SSH key is configured
   - Check firewall settings

2. **Build Failed**
   - Check for TypeScript errors
   - Verify all dependencies are installed
   - Check environment variables

3. **Migration Failed**
   - Check database connectivity
   - Verify database credentials
   - Review migration files

4. **Health Check Failed**
   - Check if application started correctly
   - Verify port configuration
   - Check application logs

### Debug Mode

To run with more verbose output:

```bash
bash -x deploy.sh
```

## Security Notes

- Never commit `.env.production` to version control
- Use strong passwords and API keys
- Keep your server updated
- Monitor logs for suspicious activity
- Use HTTPS in production (configure nginx)

## Next Steps

Consider implementing:
- Automated backups
- CI/CD integration
- Monitoring and alerting
- SSL/TLS configuration
- Load balancing 