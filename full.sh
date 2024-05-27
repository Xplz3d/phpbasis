#!/bin/bash

# Variables
KEY_VAULT_NAME="kvsqldump"  # Replace with your Key Vault name 

# Define an array of database configurations
declare -A DATABASES
DATABASES=(
    ["db1"]="hostname1 username1 secretname1"
    ["db2"]="hostname2 username2 secretname2"
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
    USERNAME="${CONFIG[1]}"
    SECRET_NAME="${CONFIG[2]}"

    # Accessing the secret from Key Vault
    SECRET_VALUE=$(curl -s -H "Authorization: Bearer ${ACCESS_TOKEN}" "https://${KEY_VAULT_NAME}.vault.azure.net/secrets/${SECRET_NAME}?api-version=7.3" | jq -r '.value')

    # Check if the secret retrieval was successful
    if [ -z "$SECRET_VALUE" ]; then
        echo "Failed to get secret value for ${DB} from Key Vault"
        continue
    fi

    # Output the secret value (for demonstration purposes, remove or secure this in production)
    echo "The value of the secret '${SECRET_NAME}' for database '${DB}' is retrieved successfully."

    # Dump the MySQL database
    DUMP_FILE_NAME="/mnt/sqldumps/${DB}_database_dump.sql"
    mysqldump --host="$HOSTNAME" --user="$USERNAME" --password="$SECRET_VALUE" --databases "$DB" --no-tablespaces --set-gtid-purged=OFF --skip-lock-tables > "$DUMP_FILE_NAME"

    # Check if the mysqldump was successful
    if [ $? -ne 0 ]; then
        echo "mysqldump failed for ${DB}"
        continue
    fi

    echo "Database dump for ${DB} completed successfully and saved to $DUMP_FILE_NAME"
done

