#!/usr/bin/env bash

# backup-immich.sh

set -euo pipefail

###################################################################
# Adjust these variables to match your environment
###################################################################

# shellcheck source=.env
source .env

# check if .env file exists
if [ ! -f .env ]; then
    echo ".env file not found. Please create one with the required variables."
    exit 1
fi
# check if required variables are set
if  [ -z "${PORTAINER_URL}" ] || \
    [ -z "${PORTAINER_USERNAME}" ] || \
    [ -z "${PORTAINER_PASSWORD}" ] || \
    [ -z "${POSTGRES_CONTAINER}" ] || \
    [ -z "${RESTIC_REPOSITORY}" ] || \
    [ -z "${RESTIC_PASSWORD}" ] ; then
    echo "Required variables are not set in .env file. Please check the file."
    exit 1
fi

# check if restic repository is reachable
if ! restic -r "${RESTIC_REPOSITORY}" init &> /dev/null; then
    echo "Restic repository is not reachable. Please check the repository URL and credentials."
    exit 1
fi

# check if docker is installed
if ! command -v docker &> /dev/null
then
    echo "Docker could not be found. Please install it first."
    exit 1
fi

# check if immich stack is running
if ! docker ps | grep -q "${POSTGRES_CONTAINER}"; then
    echo "Immich stack is not running. Please check the stack."
    exit 1
fi

# check if restic is installed
if ! command -v restic &> /dev/null
then
    echo "Restic could not be found. Please install it first."
    exit 1
fi

# check if httpie is installed
if ! command -v http &> /dev/null
then
    echo "httpie could not be found. Please install it first."
    exit 1
fi

# check if jq is installed
if ! command -v jq &> /dev/null
then
    echo "jq could not be found. Please install it first."
    exit 1
fi

###################################################################
# Prepare the environment
###################################################################

### query local portainer instance api for immich stack data
# get the jwt token
JWT_TOKEN=$(http --verify=no POST "${PORTAINER_URL}"/api/auth Username="$PORTAINER_USERNAME" Password="$PORTAINER_PASSWORD" | jq -r '.jwt')
# get stacks data
STACKS=$(http --verify=no GET "${PORTAINER_URL}"/api/stacks "Authorization: Bearer $JWT_TOKEN")
# get the stack data for immich
# DB_DATABASE_NAME=$(echo ${STACKS} | jq -r '.[] | select(.Name=="immich") | .Env[] | select(.name=="DB_DATABASE_NAME") | .value')
DB_USERNAME=$(echo "${STACKS}" | jq -r '.[] | select(.Name=="immich") | .Env[] | select(.name=="DB_USERNAME") | .value')
DB_PASSWORD=$(echo "${STACKS}" | jq -r '.[] | select(.Name=="immich") | .Env[] | select(.name=="DB_PASSWORD") | .value')
UPLOAD_LOCATION=$(echo "${STACKS}" | jq -r '.[] | select(.Name=="immich") | .Env[] | select(.name=="UPLOAD_LOCATION") | .value')

# Directory to store the temporary database dump
# backup script assumes it's within UPLOAD_LOCATION
DB_DUMP_DIR="${UPLOAD_LOCATION}/database-backup"
DB_DUMP_PATH="${DB_DUMP_DIR}/immich-database.sql"

# Create the backup directory if it doesn’t exist
mkdir -p "${DB_DUMP_DIR}"

###################################################################
# Step 1: Dump the Postgres database
###################################################################
# Backup Immich database
echo "==> Dumping Postgres database..."
docker exec -t "${POSTGRES_CONTAINER}" \
  pg_dumpall --clean \
            --if-exists \
            --username="${DB_USERNAME}" \
            --password="${DB_PASSWORD}" \
  > "${DB_DUMP_PATH}"

echo "==> Successfully created database dump at ${DB_DUMP_PATH}"

###################################################################
# Step 2: Run restic backup (database dump + photos)
###################################################################
echo "==> Starting Restic backup..."

# Initialize the repository if it hasn't been done yet (safe to run repeatedly)
restic init || true

# Back up both the database dump file and the photo directory
restic backup \
  --exclude encoded-video \
  --exclude thumbs \
  --exclude backups \
  --tag immich-backup \
  --tag "$(date +'%Y%m%d_%H%M%S')" \
  "${UPLOAD_LOCATION}"

echo "==> Restic backup complete."

###################################################################
# Step 3: Prune old backups
###################################################################
# Adjust retention as desired. For example:
#   --keep-daily 7   Keep 7 daily snapshots
#   --keep-weekly 4  Keep 4 weekly snapshots
#   --keep-monthly 6 Keep 6 monthly snapshots
echo "==> Forgetting old snapshots and pruning..."
restic forget \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 6 \
  --prune

echo "==> Pruning complete."

###################################################################
# Optional: Clean up local DB dumps older than X days
###################################################################
# find "${DB_DUMP_DIR}" -name "immich_db_*.sql" -type f -mtime +7 -exec rm {} \;

echo "==> All done!"
