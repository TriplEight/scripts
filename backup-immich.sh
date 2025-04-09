#!/usr/bin/env bash

# backup-immich.sh

set -euo pipefail

###################################################################
# Adjust these variables to match your environment
###################################################################

# shellcheck source=.env
source .env

export RESTIC_REPOSITORY
export RESTIC_PASSWORD

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
    [ -z "${RESTIC_PASSWORD}" ] || \
    [ -z "${ALERTING_URL}" ]; then
    echo "Required variables are not set in .env file. Please check the file."
    exit 1
fi

###################################################################
# Alerting
###################################################################

# Usage:
#   send_kuma_push_failure "<COMMAND_OUTPUT>"
#
# Example:
#   if ! some_command 2>&1; then
#       cmd_output="$(some_command 2>&1)"
#       send_kuma_push_failure "$cmd_output"
#   fi

send_kuma_push_failure() {
  local cmd_output="$1"

  local msg="Immich backup failed. Output: ${cmd_output}"

  # with the message in the "msg" query parameter:
  curl -fsS -m 10 --retry 5 "${ALERTING_URL}?status=down&msg=${msg}&ping="
}

###################################################################
# Checks
###################################################################

# check if restic is installed
if ! command -v restic &> /dev/null
then
    send_kuma_push_failure "Restic not found"
    echo "Restic could not be found. Please install it first."
    exit 1
fi

# check if restic repository is reachable
restic -r "${RESTIC_REPOSITORY}" cat config >/dev/null 2>&1
if [ $? -eq 10 ]; then
  send_kuma_push_failure "Restic repository does not exist"
  echo "Repository does not exist"
  exit 1
fi

# check if docker is installed
if ! command -v docker &> /dev/null
then
    send_kuma_push_failure "Docker not found"
    echo "Docker could not be found. Please install it first."
    exit 1
fi

# check if immich stack is running
if docker inspect "${POSTGRES_CONTAINER}" > /dev/null 2>&1; then
    if docker inspect -f '{{.State.Running}}' "${POSTGRES_CONTAINER}" | grep -q "true"; then
        echo "==> ${POSTGRES_CONTAINER} container exists and is running."
    else
        send_kuma_push_failure "${POSTGRES_CONTAINER} container is stopped"
        echo "==> ${POSTGRES_CONTAINER} container exists but is stopped. Please start it first."
        exit 1
    fi
else
    send_kuma_push_failure "${POSTGRES_CONTAINER} container does not exist"
    echo "Container does not exist"
    exit 1
fi

# check if httpie is installed
if ! command -v http &> /dev/null
then
    send_kuma_push_failure "httpie not found"
    echo "httpie could not be found. Please install it first."
    exit 1
fi

# check if jq is installed
if ! command -v jq &> /dev/null
then
    send_kuma_push_failure "jq not found"
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
DB_DATABASE_NAME=$(echo "${STACKS}" | jq -r '.[] | select(.Name=="immich") | .Env[] | select(.name=="DB_DATABASE_NAME") | .value')
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
docker exec -t -u postgres "${POSTGRES_CONTAINER}"  \
  bash -c 'PGPASSWORD="${DB_PASSWORD}" \
    pg_dumpall --clean \
               --if-exists \
               --username="${DB_USERNAME}" \
               --database="${DB_DATABASE_NAME}"' \
    > "${DB_DUMP_PATH}"
echo "==> Successfully created database dump at ${DB_DUMP_PATH}"
du -sh "${DB_DUMP_PATH}"

###################################################################
# Step 2: Run restic backup (database dump + photos)
###################################################################
echo "==> Starting Restic backup..."

# Back up both the database dump file and the photo directory
restic backup \
  --exclude encoded-video \
  --exclude thumbs \
  --exclude backups \
  --tag "$(date +'%Y%m%d_%H%M%S')" \
  --tag restic_cli \
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

echo "==> Updating Uptime Kuma status..."
curl -fsS -m 10 --retry 5 "${ALERTING_URL}?status=up&msg=Backup+Completed&ping="

echo "==> Backup complete."
