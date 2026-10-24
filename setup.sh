#!/bin/bash
# Rebuilds the hello-app server on a fresh Ubuntu 24.04 (tested on WSL2).
# Run as a normal user with sudo rights, from inside the cloned repo:  bash setup.sh
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$HOME/hello-app"
ENV_FILE=/etc/hello-app.env

if [ "$(id -u)" -eq 0 ]; then echo "Run as a normal user, not root."; exit 1; fi

echo "==> Installing packages"
sudo apt-get update -y
sudo apt-get install -y nginx ufw nodejs npm postgresql curl openssl cron openssh-server

echo "==> Installing the app into $APP_DIR"
mkdir -p "$APP_DIR"
cp "$REPO_DIR"/server.js "$REPO_DIR"/healthcheck.sh "$REPO_DIR"/package.json "$REPO_DIR"/package-lock.json "$APP_DIR"/
sed -i "s#/home/ayrus15#$HOME#g" "$APP_DIR/healthcheck.sh"
chmod +x "$APP_DIR/healthcheck.sh"
(cd "$APP_DIR" && npm install --omit=dev)

echo "==> Setting up PostgreSQL"
if ! sudo test -f "$ENV_FILE"; then
DB_PASS="$(openssl rand -hex 16)"
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='hello_app'" | grep -q 1; then
sudo -u postgres psql -c "CREATE USER hello_app WITH PASSWORD '$DB_PASS';"
else
sudo -u postgres psql -c "ALTER USER hello_app WITH PASSWORD '$DB_PASS';"
fi
echo "DATABASE_URL=postgresql://hello_app:${DB_PASS}@127.0.0.1:5432/hello_db" | sudo tee "$ENV_FILE" > /dev/null
sudo chmod 600 "$ENV_FILE"
fi
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='hello_db'" | grep -q 1; then
sudo -u postgres createdb -O hello_app hello_db
fi
sudo -u postgres psql -d hello_db -c "SET ROLE hello_app; CREATE TABLE IF NOT EXISTS visits (id serial PRIMARY KEY, visited_at timestamptz DEFAULT now(), path text);"

echo "==> Installing the systemd service"
sed -e "s#/home/ayrus15#$HOME#g" -e "s#^[[:space:]]*User=.*#User=$USER#" "$REPO_DIR/config/hello-app.service" | sudo tee /etc/systemd/system/hello-app.service > /dev/null
sudo systemctl daemon-reload
sudo systemctl enable hello-app
sudo systemctl restart hello-app

echo "==> TLS certificate (self-signed)"
if [ ! -f /etc/ssl/certs/hello-app.crt ]; then
sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/hello-app.key -out /etc/ssl/certs/hello-app.crt -subj "/CN=localhost"
fi

echo "==> Configuring nginx"
sudo cp "$REPO_DIR/config/hello-app.nginx.conf" /etc/nginx/sites-available/hello-app
sudo ln -sf /etc/nginx/sites-available/hello-app /etc/nginx/sites-enabled/hello-app
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

echo "==> Firewall"
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx HTTP'
sudo ufw allow 'Nginx HTTPS'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw --force enable

echo "==> Backups and health check"
sudo install -m 750 "$REPO_DIR/hello-backup.sh" /usr/local/bin/hello-backup.sh
(sudo crontab -l 2>/dev/null | grep -v hello-backup || true; echo '15 2 * * * /usr/local/bin/hello-backup.sh') | sudo crontab -
(crontab -l 2>/dev/null | grep -v healthcheck || true; echo "*/5 * * * * $APP_DIR/healthcheck.sh") | crontab -

echo "==> Checking"
sleep 3
systemctl is-active hello-app nginx postgresql
curl -sk https://localhost
echo "Done."
