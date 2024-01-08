#!/bin/bash

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

init () {
# Get User Email Address
    while [[ ! $USER_EMAIL =~ ^.+@.+\..+$ ]] || [[ $USER_EMAIL == '' ]]
    do
        read -e -p "Enter Your Email [$(printf "${RED}REQUIRED${NC}")]: " USER_EMAIL
        
        if ! [[ $USER_EMAIL =~ ^.+@.+\..+$ ]]; then 
            printf "[${RED}ERROR${NC}] Write a correct email address\n"
        fi
    done

# Get User Domain Name
    while [[ ! $USER_DOMAIN =~ ^.*\..*$ ]] || [[ $USER_DOMAIN == '' ]]
    do
        read -e -p "Enter Your Domain [$(printf "${RED}REQUIRED${NC}")]: " USER_DOMAIN
        
        if ! [[ $USER_DOMAIN =~ ^.*\..*$ ]]; then 
            printf "[${RED}ERROR${NC}] Write a correct domain name\n"
        fi
    done

    if dig +short ns $USER_DOMAIN | grep -q ns.cloudflare.com; then 
        printf "[${YELLOW}WARNING${NC}] Cloudflare NS-servers found. IP checks will be skipped\n"
    else
        PUBLIC_IP_ADDRESS=$(dig +short myip.opendns.com @resolver1.opendns.com)

        printf "Your public IP address: ${GREEN}${PUBLIC_IP_ADDRESS}${NC}\n"

        if [[ $(dig +short a "wiki.$USER_DOMAIN") = $PUBLIC_IP_ADDRESS ]]; then
            printf "[${GREEN}SUCCESS${NC}] Check IP wiki.${USER_DOMAIN}\n"
        else
            printf "[${RED}ERROR${NC}] Check IP wiki.${USER_DOMAIN}\n"
        fi

        if [[ $(dig +short a "kk.$USER_DOMAIN") = $PUBLIC_IP_ADDRESS ]]; then
            printf "[${GREEN}SUCCESS${NC}] Check IP kk.${USER_DOMAIN}\n"
        else
            printf "[${RED}ERROR${NC}] Check IP kk.${USER_DOMAIN}\n"
        fi

        if [[ $(dig +short a "minio.$USER_DOMAIN") = $PUBLIC_IP_ADDRESS ]]; then
            printf "[${GREEN}SUCCESS${NC}] Check IP minio.${USER_DOMAIN}\n"
        else
            printf "[${RED}ERROR${NC}] Check IP minio.${USER_DOMAIN}\n"
        fi

        if [[ $(dig +short a "minio-admin.$USER_DOMAIN") = $PUBLIC_IP_ADDRESS ]]; then
            printf "[${GREEN}SUCCESS${NC}] Check IP minio-admin.${USER_DOMAIN}\n"
        else
            printf "[${RED}ERROR${NC}] Check IP minio-admin.${USER_DOMAIN}\n"
        fi
    fi

    read -e -p "Enter Keycloak Admin Username: " -i "admin" KEYCLOAK_ADMIN_USERNAME
    read -e -p "Enter Keycloak Realm for Outline: " -i "outline" KEYCLOAK_REALM_NAME
    KEYCLOAK_ADMIN_PASSWORD=$(pass_gen 16)
    KEYCLOAK_CLIENT_SECRET=$(pass_gen 32)

    read -e -p "Enter MiniO Root Username: " -i "admin" MINIO_ROOT_USERNAME
    MINIO_ROOT_PASSWORD=$(pass_gen 16)
    read -e -p "Enter MiniO Bucket for Outline Name: " -i "outline" MINIO_BUCKET_NAME
    read -e -p "Enter MiniO Bucket for Outline Username: " -i "outline" MINIO_BUCKET_USERNAME
    MINIO_BUCKET_PASSWORD=$(pass_gen 16)

    read -e -p "Enter Outline Database User: " -i "outline" POSTGRES_OUTLINE_USERNAME
    read -e -p "Enter Outline Database: " -i "outline" POSTGRES_OUTLINE_DB_NAME
    POSTGRES_OUTLINE_PASSWORD=$(pass_gen 16)

    tee .env <<EOF  > /dev/null
# –––––––––––––––– NOT OUTLINE ENVS ––––––––––––––––
USER_DOMAIN=$USER_DOMAIN
USER_EMAIL=$USER_EMAIL
KEYCLOAK_DOMAIN=kk.\${USER_DOMAIN}
MINIO_DOMAIN=minio.\${USER_DOMAIN}
MINIO_ADMIN_DOMAIN=minio.\${USER_DOMAIN}
OUTLINE_DOMAIN=wiki.\${USER_DOMAIN}

# POSTGRES
POSTGRES_OUTLINE_USERNAME=$POSTGRES_OUTLINE_USERNAME
POSTGRES_OUTLINE_DB_NAME=$POSTGRES_OUTLINE_DB_NAME
POSTGRES_OUTLINE_PASSWORD=$POSTGRES_OUTLINE_PASSWORD

# MINIO
MINIO_ROOT_USERNAME=$MINIO_ROOT_USERNAME
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
MINIO_BUCKET_NAME=$MINIO_BUCKET_NAME
MINIO_BUCKET_USERNAME=$MINIO_BUCKET_USERNAME
MINIO_BUCKET_PASSWORD=$MINIO_BUCKET_PASSWORD

# KEYCLOAK
KEYCLOAK_REALM_NAME=$KEYCLOAK_REALM_NAME
KEYCLOAK_CLIENT_SECRET=$KEYCLOAK_CLIENT_SECRET
# –––––––––––––––– REQUIRED ––––––––––––––––

# Generate a hex-encoded 32-byte random key. You should use \`openssl rand -hex 32\`
# in your terminal to generate a random value.
SECRET_KEY=`hash_gen`

# Generate a unique random key. The format is not important but you could still use
# \`openssl rand -hex 32\` in your terminal to produce this.
UTILS_SECRET=`hash_gen`

# For production point these at your databases, in development the default
# should work out of the box.
DATABASE_URL=postgres://\${POSTGRES_OUTLINE_USERNAME}:\${POSTGRES_OUTLINE_PASSWORD}@postgres:5432/\${POSTGRES_OUTLINE_DB_NAME}
DATABASE_URL_TEST=postgres://\${POSTGRES_OUTLINE_USERNAME}:\${POSTGRES_OUTLINE_PASSWORD}@postgres:5432/\${POSTGRES_OUTLINE_DB_NAME}-test
DATABASE_CONNECTION_POOL_MIN=
DATABASE_CONNECTION_POOL_MAX=
# Uncomment this to disable SSL for connecting to Postgres
PGSSLMODE=disable
REDIS_URL=redis://redis:6379

# URL should point to the fully qualified, publicly accessible URL. If using a
# proxy the port in URL and PORT may be different.
URL=https://wiki.\${USER_DOMAIN}
PORT=3000

# See [documentation](docs/SERVICES.md) on running a separate collaboration
# server, for normal operation this does not need to be set.
COLLABORATION_URL=

# To support uploading of images for avatars and document attachments an
# s3-compatible storage must be provided. AWS S3 is recommended for redundency
# however if you want to keep all file storage local an alternative such as
# minio (https://github.com/minio/minio) can be used.

# A more detailed guide on setting up S3 is available here:
# => https://wiki.generaloutline.com/share/125de1cc-9ff6-424b-8415-0d58c809a40f
#
AWS_ACCESS_KEY_ID=\${MINIO_BUCKET_USERNAME}
AWS_SECRET_ACCESS_KEY=\${MINIO_BUCKET_PASSWORD}
AWS_REGION=us-east-1
AWS_S3_ACCELERATE_URL=
AWS_S3_UPLOAD_BUCKET_URL=https://minio.\${USER_DOMAIN}
AWS_S3_UPLOAD_BUCKET_NAME=\${MINIO_BUCKET_NAME}
FILE_STORAGE_UPLOAD_MAX_SIZE=26214400
AWS_S3_FORCE_PATH_STYLE=true
AWS_S3_ACL=private

# –––––––––––––– AUTHENTICATION ––––––––––––––

# Third party signin credentials, at least ONE OF EITHER Google, Slack,
# or Microsoft is required for a working installation or you'll have no sign-in
# options.

# To configure Slack auth, you'll need to create an Application at
# => https://api.slack.com/apps
#
# When configuring the Client ID, add a redirect URL under "OAuth & Permissions":
# https://<URL>/auth/slack.callback
SLACK_KEY=
SLACK_SECRET=

# To configure Google auth, you'll need to create an OAuth Client ID at
# => https://console.cloud.google.com/apis/credentials
#
# When configuring the Client ID, add an Authorized redirect URI:
# https://<URL>/auth/google.callback
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# To configure Microsoft/Azure auth, you'll need to create an OAuth Client. See
# the guide for details on setting up your Azure App:
# => https://wiki.generaloutline.com/share/dfa77e56-d4d2-4b51-8ff8-84ea6608faa4
AZURE_CLIENT_ID=
AZURE_CLIENT_SECRET=
AZURE_RESOURCE_APP_ID=

# To configure generic OIDC auth, you'll need some kind of identity provider.
# See documentation for whichever IdP you use to acquire the following info:
# Redirect URI is https://<URL>/auth/oidc.callback
OIDC_CLIENT_ID=outline
OIDC_CLIENT_SECRET=\${KEYCLOAK_CLIENT_SECRET}
OIDC_AUTH_URI=https://kk.\${USER_DOMAIN}/auth/realms/\${KEYCLOAK_REALM_NAME}/protocol/openid-connect/auth
OIDC_TOKEN_URI=https://kk.\${USER_DOMAIN}/auth/realms/\${KEYCLOAK_REALM_NAME}/protocol/openid-connect/token
OIDC_USERINFO_URI=https://kk.\${USER_DOMAIN}/auth/realms/\${KEYCLOAK_REALM_NAME}/protocol/openid-connect/userinfo

# Specify which claims to derive user information from
# Supports any valid JSON path with the JWT payload
OIDC_USERNAME_CLAIM=email

# Display name for OIDC authentication
OIDC_DISPLAY_NAME=Keycloak

# Space separated auth scopes.
OIDC_SCOPES=openid profile email

# –––––––––––––––– OPTIONAL ––––––––––––––––

# Base64 encoded private key and certificate for HTTPS termination. This is only
# required if you do not use an external reverse proxy. See documentation:
# https://wiki.generaloutline.com/share/1c922644-40d8-41fe-98f9-df2b67239d45
SSL_KEY=
SSL_CERT=

# If using a Cloudfront/Cloudflare distribution or similar it can be set below.
# This will cause paths to javascript, stylesheets, and images to be updated to
# the hostname defined in CDN_URL. In your CDN configuration the origin server
# should be set to the same as URL.
CDN_URL=

# Auto-redirect to https in production. The default is true but you may set to
# false if you can be sure that SSL is terminated at an external loadbalancer.
FORCE_HTTPS=true

# Have the installation check for updates by sending anonymized statistics to
# the maintainers
ENABLE_UPDATES=true

# How many processes should be spawned. As a reasonable rule divide your servers
# available memory by 512 for a rough estimate
WEB_CONCURRENCY=1

# Override the maxium size of document imports, could be required if you have
# especially large Word documents with embedded imagery
MAXIMUM_IMPORT_SIZE=5120000

# You can remove this line if your reverse proxy already logs incoming http
# requests and this ends up being duplicative
DEBUG=http

# Comma separated list of domains to be allowed to signin to the wiki. If not
# set, all domains are allowed by default when using Google OAuth to signin
ALLOWED_DOMAINS=

# For a complete Slack integration with search and posting to channels the
# following configs are also needed, some more details
# => https://wiki.generaloutline.com/share/be25efd1-b3ef-4450-b8e5-c4a4fc11e02a
#
SLACK_VERIFICATION_TOKEN=
SLACK_APP_ID=
SLACK_MESSAGE_ACTIONS=

# Optionally enable google analytics to track pageviews in the knowledge base
GOOGLE_ANALYTICS_ID=

# Optionally enable Sentry (sentry.io) to track errors and performance
SENTRY_DSN=

# To support sending outgoing transactional emails such as "document updated" or
# "you've been invited" you'll need to provide authentication for an SMTP server
SMTP_HOST=
SMTP_PORT=
SMTP_USERNAME=
SMTP_PASSWORD=
SMTP_FROM_EMAIL=
SMTP_REPLY_EMAIL=
SMTP_TLS_CIPHERS=
SMTP_SECURE=true

# Custom logo that displays on the authentication screen, scaled to height: 60px
# TEAM_LOGO=https://example.com/images/logo.png

# The default interface language. See translate.getoutline.com for a list of
# available language codes and their rough percentage translated.
DEFAULT_LANGUAGE=en_US
EOF
}

pass_gen () {
    local len="${1:-32}"
    echo $(tr -dc A-Za-z0-9 </dev/urandom | head -c $len)
}

hash_gen () {
    local len="${1:-32}"
    echo $(openssl rand -hex $len)
}

init