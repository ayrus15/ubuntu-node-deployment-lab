#!/bin/bash
set -euo pipefail
dir=/var/backups/hello-app
mkdir -p "$dir"
ts=$(date +%F_%H%M)
runuser -u postgres -- pg_dump hello_db | gzip > "$dir/hello_db_$ts.sql.gz"
find "$dir" -name 'hello_db_*.sql.gz' -mtime +7 -delete
echo "$(date -Is) backup ok hello_db_$ts.sql.gz" >> /var/log/hello-backup.log
