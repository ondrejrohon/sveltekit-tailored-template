# Deployment

This directory contains deployment scripts and configuration for the Slova SvelteKit application.

## Quick Setup

To set up your deployment configuration and server in one go:

```bash
cd deployment
./setup.sh
```

This comprehensive script will:
- **Phase 1**: Configure your environment (server details, database, etc.)
- **Phase 2**: Set up the remote server (install packages, configure database, etc.)
- Use existing values as defaults when available
- Generate `.env.production` with your configuration
- Set up the complete server environment

## Files

- `setup.sh` - **Main setup script** (handles both configuration and server setup)
- `deploy.sh` - Main deployment script (uses `.env.production` + `deploy.defaults.sh`)
- `deploy.defaults.sh` - Default configuration values (timeouts, SSH options, PM2 settings)
- `deploy.config.local.sh` - **Legacy** (deprecated, use `.env.production`)

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

1. Run `./setup.sh` to configure your environment and set up the server
2. Ensure your SSH key is set up for the target server
3. Run `./deploy.sh` to deploy your application

## Migration from Old Scripts

If you have existing configuration:
- **`deploy.config.local.sh`**: `setup.sh` will automatically use these values as defaults

## Setup Process

The `setup.sh` script provides a clear, emoji-marked process:

### 🔧 Phase 1: Environment Configuration
- Loads existing configuration or prompts for new values
- Creates `.env.production` with your settings
- Validates all required fields

### 🔧 Phase 2: Server Setup
- Tests SSH connectivity
- Updates system packages
- Installs required software (bun, PM2, PostgreSQL, nginx)
- Configures database and deployment directories
- Sets up firewall and PM2 ecosystem

Each step is clearly marked with emojis for easy log reading during long setup processes.

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