# Ubuntu Node Deployment Lab

A small, hands-on exercise in running and operating a web service on Ubuntu 24.04 LTS: a Node.js app managed by `systemd`, served through an `nginx` reverse proxy, protected by a `ufw` firewall, and monitored by a `cron` health check.

Built to learn the basics of operating a Linux service. It is a learning project, not a production deployment.

## Environment

- Ubuntu 24.04.5 LTS (noble) on WSL2 (Windows), not a full Ubuntu Server install
- Node.js 18 (from the Ubuntu archive), nginx 1.24.0, ufw 0.36.2
- `systemd` enabled in WSL

## What I built

| Piece | What it does | File |
|---|---|---|
| Node app | Tiny HTTP server on `127.0.0.1:3000` that returns the hostname and time | `server.js` |
| systemd service | Starts the app at boot, runs it as a normal user, restarts it on failure after 3 s | `config/hello-app.service` |
| nginx reverse proxy | Accepts requests on port 80 and forwards them to the app | `config/hello-app.nginx.conf` |
| ufw firewall | Denies incoming traffic by default; allows only SSH (22) and HTTP (80) | see `evidence.txt` |
| cron health check | Every 5 minutes, requests the site through nginx and logs the HTTP status | `healthcheck.sh` |

## Steps (summary)

1. Installed Ubuntu 24.04 on WSL2 and confirmed `systemd` was running.
2. Updated packages and installed `nginx`, `ufw`, `openssh-server`, `curl`, `git`, `nodejs`.
3. Wrote the app and ran it by hand to confirm it worked (and that it stops when the terminal closes).
4. Created `hello-app.service`, then `daemon-reload` and `enable --now`.
5. Tested recovery: killed the process with `kill -9` and confirmed `systemd` restarted it.
6. Replaced the default nginx site with a reverse-proxy config, checked it with `nginx -t`, then reloaded.
7. Added firewall allow rules for SSH and HTTP first, then set default-deny incoming and enabled `ufw`.
8. Wrote a health-check script and scheduled it with `cron`.

## Results

- **Crash recovery:** `kill -9` on PID 12347 at 08:45:16; `systemd` logged the exit (`status=9/KILL`) and started a new process, PID 12394, at 08:45:19. The site answered again with no manual action.
- **Reverse proxy:** `curl -I http://localhost` returns `HTTP/1.1 200 OK` with `Server: nginx/1.24.0 (Ubuntu)`.
- **Firewall:** active, default deny incoming; only 22/tcp and 80/tcp allowed (IPv4 and IPv6).
- **Health check:** the cron job ran every minute while testing (log lines one minute apart, all `status=200`), then I changed the schedule to every 5 minutes.

Full command output is in [`evidence.txt`](evidence.txt).

## Problems I hit and fixed

- **WSL install failed with "Not enough memory resources are available":** a required Windows feature (VirtualMachinePlatform) was not active yet. It was enabled by the install, and a restart plus a retry fixed it.
- **App kept the port after I thought I had stopped it:** an earlier hand-run copy was still holding port 3000. I checked with `systemctl is-active` and `ss -ltnp`, stopped it, then started the service cleanly.
- **A pasted multi-line command never finished:** the closing `EOF` of a heredoc was indented, so the shell kept waiting. I cancelled and wrote the file with `nano` instead.
- **Typos that cost time:** `systemct1` (digit 1) for `systemctl`, `crontab -1` for `crontab -l`, and `--no pager` for `--no-pager`.

## Limits and what I did not do

- Ran on WSL2, so boot behaviour and some firewall details differ from a real server.
- OpenSSH server is installed and allowed through the firewall, but I did not test remote SSH login or set up key-based login.
- No HTTPS/TLS, no log rotation for `health.log`, and no monitoring or alerting beyond the log file.
- The app is a minimal example, with no database or authentication.

## How this was made

I followed these steps with guidance from an AI assistant (Claude), and ran every command myself on my own machine. The outputs in `evidence.txt` are from my machine.
