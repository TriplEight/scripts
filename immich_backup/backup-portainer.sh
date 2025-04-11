#!/usr/bin/env bash

# backup-portainer.sh

# heres my obfuscated chron task for backing up portainer daily. 
# I have a second task thats nearly identical that backups to a rclone directory for my google drive: 
curl -k -X POST https://truenas:31015/api/backup \
    -H 'X-API-Key:#PORTAINER API KEY' \
    -H 'Content-Type: application/json; charset=utf-8' \
    -d '{ "#PORTAINER PASSWORD": "" }' \
    --output /mnt/chungusprime/main/Backups/Portainer/portainersnapshot-$(date +%Y%m%d%H%M%S).tar.gz
