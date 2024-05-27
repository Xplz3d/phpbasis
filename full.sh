#!/bin/bash

# Variables
KEY_VAULT_NAME="kvsqldump"  # Replace with your Key Vault name 

# Define an array of database configurations
declare -A DATABASES
DATABASES=(
    ["db1"]="hostname1 mysqluser mysqlpwd"
    ["db2"]="hostname2 username_secretname2 password_secretname2"
    # Add more databases as needed
)

# Fetching access token for the managed identity
ACCESS_TOKEN=$(curl -s -H "Metadata:true" "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net" | jq -r '.access_token')

# Check if the access token retrieval was successful
if [ -z "$ACCESS_TOKEN" ]; then
    echo "Failed to get access token from managed identity"
    exit 1
fi

# Loop through each database configuration
for DB in "${!DATABASES[@]}"; do
    IFS=' ' read -r -a CONFIG <<< "${DATABASES[$DB]}"
    HOSTNAME="${CONFIG[0]}"
    USERNAME_SECRET_NAME="${CONFIG[1]}"
    PASSWORD_SECRET_NAME="${CONFIG[2]}"

    # Accessing the username secret from Key Vault
    USERNAME=$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${USERNAME_SECRET_NAME}?api-version=7.3" | jq -r '.value')

    # Check if the username retrieval was successful
    if [ -z "$USERNAME" ]; then
        echo "Failed to get username for ${DB} from Key Vault"
        continue
    fi

    # Accessing the password secret from Key Vault
    PASSWORD=$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${PASSWORD_SECRET_NAME}?api-version=7.3" | jq -r '.value')

    # Check if the password retrieval was successful
    if [ -z "$PASSWORD" ]; then
        echo "Failed to get password for ${DB} from Key Vault"
        continue
    fi

    # Output the secret values (for demonstration purposes, remove or secure this in production)
    echo "The username and password for database '${DB}' are retrieved successfully."

    # Generate the dump file name with timestamp
    TIMESTAMP=$(date -u '+%Y%m%d%H%M%S')
    DUMP_FILE_NAME="/mnt/sqldumps/${DB}_database_dump_${TIMESTAMP}.sql"

    # Dump the MySQL database
    mysqldump --host="$HOSTNAME" --user="$USERNAME" --password="$PASSWORD" --databases "$DB" --no-tablespaces --set-gtid-purged=OFF --skip-lock-tables > "$DUMP_FILE_NAME"

    # Check if the mysqldump was successful
    if [ $? -ne 0 ]; then
        echo "mysqldump failed for ${DB}"
        continue
    fi

    echo "Database dump for ${DB} completed successfully and saved to $DUMP_FILE_NAME"
done
