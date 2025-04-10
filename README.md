# scripts

various helpful scripts

## immich backup

For alerting relies on Uptime Kuma with a Push monitor.

1. `git clone` this repo to, say `/home/youruser/.config/scripts`

### .env

1. `cp .env.example .env`
2. `edit .env` with your env data

### service

1. `cp immich-backup.service.example immich-backup.service`
2. `edit immich-backup.service` with your env data
3. `sudo ln -s /home/youruser/.config/scripts/immich-backup.service /etc/systemd/system/immich-backup.service`

### timer

1. `cp immich-backup.timer.example immich-backup.timer`
2. `edit immich-backup.timer` with your settings
3. `sudo ln -s /home/youruser/.config/scripts/immich-backup.timer /etc/systemd/system/immich-backup.timer`

### run service

1. `sudo systemctl daemon-reload`
2. `sudo systemctl enable immich-backup.timer`
3. `sudo systemctl start immich-backup.timer`

### check

- to see if the timer is active and the next run time: `systemctl list0timers`
- to see logs of the service: `journalctl -u immich-backup.service`

### restore

1. `RESTIC_PASSWORD=xxx restic -r /restic/repo restore [snapshot_id] --target /restored/location/`
2. Make sure you have a compose and .env files (they should be in Portainer backup). Make sure your username and database name in .env match with what you use below
3. Edit your compose, add a new volume `- /path/to/restored/location/database-backup/immich-database.sql:/var`. Point your `UPLOAD_LOCATION` to `/restored/location/path/to/dir/immich`.
4. Run the stack
5. `docker exec -t -u postgres immich_postgres bash -c 'PGPASSWORD="xxx" psql -U postgres -f /var/immich-database.sql'`

### TODO

1. script could be more informative
2. too many effort on internal alerting: remove all the alerts and make an external alerting script, run it as another service. It should send the error message as well.
3. if script fails it's pretty brittle
