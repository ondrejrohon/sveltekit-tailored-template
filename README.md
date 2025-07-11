# Sveltekit Repo

all the nice stuff that I like to use for web dev

## Setup
1. Clone this repo
2. edit package.json project name
3. generate envs:
  JWT_SECRET by running: `openssl rand -base64 32`
  ENCRYPTION_KEY: `openssl rand -base64 32`
3. create project on GCP, allow google sign in, send emails

## Lucia Auth
https://lucia-auth.com/
https://github.com/lucia-auth/example-sveltekit-email-password-2fa/tree/main

all lucia auth files are based on commit:
https://github.com/lucia-auth/example-sveltekit-email-password-2fa/tree/7f9f22d48fb058e4085a11c52528e781c4bc70df
