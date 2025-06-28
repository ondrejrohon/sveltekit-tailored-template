# Deployment

This directory contains deployment scripts and configuration for the Slova SvelteKit application.

## Quick Setup

To set up your deployment configuration interactively:

```bash
cd deployment
./setup-env.sh
```

This script will:
- Prompt for server host, username, app name, deploy path, app port, database name, and password
- Use existing values from `deploy.config.local.sh` as defaults (if available)
- Generate a `.env.production` file with your configuration
- Keep sensitive information secure (password input is hidden)

## Files

- `setup-env.sh` - Interactive configuration setup script
- `deploy.sh` - Main deployment script (uses `.env.production` + `deploy.defaults.sh`)
- `server-setup.sh` - Initial server setup script
- `deploy.defaults.sh` - Default configuration values (timeouts, SSH options, PM2 settings)
- `deploy.config.local.sh` - Legacy local configuration (deprecated, use `.env.production`)

## Configuration

The deployment uses a two-tier configuration system:

### User Configuration (`.env.production`)
- **Server**: SSH connection details
- **Application**: Port settings
- **Database**: PostgreSQL connection details

### Default Configuration (`deploy.defaults.sh`)
- **Timeouts**: Health check and app start timeouts
- **SSH Options**: Connection settings
- **PM2**: Process management settings
- **Backup**: Number of backups to keep

These defaults are unlikely to change and are separated from user-specific settings.

## Security

- `.env.production` contains sensitive information and is automatically ignored by git
- Database passwords are stored securely
- SSH keys are used for server authentication

## Usage

1. Run `./setup-env.sh` to configure your environment
2. Ensure your SSH key is set up for the target server
3. Run `./deploy.sh` to deploy your application

## Migration from deploy.config.local.sh

If you have an existing `deploy.config.local.sh` file:
1. Run `./setup-env.sh` to create `.env.production` with your current values
2. The deployment script will automatically use `.env.production` and show a deprecation warning for the old file
3. You can safely delete `deploy.config.local.sh` after confirming everything works

## Usage

### 1. Initial Setup (Run once)

Run the server setup script to configure your deployment:

```bash
cd deployment
./server-setup.sh
```

This script will:
- Ask for server IP, username, app name, and deployment path
- Ask for database name, user, and password
- Ask for application configuration (port, timeouts, etc.)
- Test SSH connectivity
- Set up the remote server with all required software
- Create a PostgreSQL database and user
- Save all configuration to `deploy.config.local.sh`

### 2. Deployment

After the initial setup, you can deploy your application:

```bash
cd deployment
./deploy.sh [environment]
```

The deployment script will:
- Build the application locally
- Run tests
- Create a deployment package with database configuration
- Upload to the server
- Run database migrations
- Restart the application
- Perform health checks
- Rollback on failure

## Configuration

The `deploy.config.local.sh` file contains all your deployment configuration:

- Server connection details
- Database credentials
- Application settings
- Timeouts and backup settings

**Important**: Keep this file secure as it contains sensitive information like database passwords.

## Requirements

### Local Machine
- SSH key configured for server access
- bun installed
- git repository with your application

### Server
- Ubuntu/Debian-based system
- SSH access with sudo privileges
- The server setup script will install all required software

## Troubleshooting

### SSH Connection Issues
- Ensure your SSH key is added to the server's `~/.ssh/authorized_keys`
- Check that the server IP and username are correct
- Verify SSH key permissions (should be 600)

### Database Issues
- Check that PostgreSQL is running: `sudo systemctl status postgresql`
- Verify database credentials in the configuration file
- Check database connection from the application

### Application Issues
- Check PM2 logs: `pm2 logs slova-sveltekit`
- Verify the application is running: `pm2 list`
- Check nginx configuration if using a reverse proxy

## Security Notes

- The `deploy.config.local.sh` file contains sensitive information
- Keep it out of version control (add to .gitignore)
- Use strong database passwords
- Consider using environment variables for sensitive data in production 