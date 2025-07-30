# Sveltekit Tailored Template

Start your own project by cloning this repository. It reuses code from lib folder of https://github.com/ondrejrohon/sveltekit-tailored.

## Setup
1. Clone this repo or use scaffold.sh from https://github.com/ondrejrohon/sveltekit-tailored/blob/main/scaffold.sh
2. generate envs:
  JWT_SECRET by running: `openssl rand -base64 32`
  ENCRYPTION_KEY: `openssl rand -base64 16`
  DATABASE_URL: (based on your db)
3. create project on GCP, allow google sign in
4. create project on coolify (app + db)
5. setup domain on cloudflare
6. make sure that db port is not taken
7. verify that it sends emails

## Connect to DB
- setup SSH connection to server
- find docker postgres container id: `docker ps`
- find ip address of docker postgres container:  `docker inspect CONTAINER_ID | grep IPAddress`
- use IP as host/socket

## Lucia Auth
https://lucia-auth.com/
https://github.com/lucia-auth/example-sveltekit-email-password-2fa/tree/main

all lucia auth files are based on commit:
https://github.com/lucia-auth/example-sveltekit-email-password-2fa/tree/7f9f22d48fb058e4085a11c52528e781c4bc70df
