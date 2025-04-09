# scripts

various helpful scripts

## immich backup

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
