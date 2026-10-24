# Ubuntu Node Deployment Lab

A small web service run the way a real one is operated: a Node.js app with a PostgreSQL database, behind an nginx HTTPS reverse proxy, managed by `systemd`, protected by a `ufw` firewall, backed up nightly with a tested restore, and rebuildable on a clean machine with one script.

This is a learning project, not a production deployment. The limits are listed honestly at the end.

## Environment

- Ubuntu 24.04.5 LTS on WSL2 (Windows), not a full Ubuntu Server install
- Node.js 18, nginx 1.24.0, PostgreSQL 16, ufw 0.36.2 (all from the Ubuntu archive)
- `systemd` enabled in WSL

## Architecture

```
client --HTTPS 443--> nginx --HTTP--> Node app (127.0.0.1:3000) --> PostgreSQL (127.0.0.1:5432)
         (HTTP 80 redirects to HTTPS)
```

## What is in this repo

| File | Purpose |
|---|---|
| `server.js` | Node app: records each request in PostgreSQL and returns the running visit count |
| `config/hello-app.service` | systemd unit: runs the app as a normal user, loads secrets from an env file, restarts on failure after 3 s |
| `config/hello-app.nginx.conf` | nginx: redirects HTTP to HTTPS, terminates TLS, proxies to the app |
| `config/hello-app.env.example` | Shape of the secret file. The real one lives outside the repo |
| `healthcheck.sh` | Cron job (every 5 min): requests the site over HTTPS and logs the status code |
| `hello-backup.sh` | Nightly `pg_dump` to a root-only folder, 7-day retention, with a log line |
| `setup.sh` | Rebuilds the whole server on a fresh Ubuntu 24.04 |
| `evidence.txt` | Command output from the first phase (plain HTTP, before HTTPS and the database) |
| `fresh-install-evidence.txt` | Command output from running `setup.sh` on a clean machine |

## What I built, in order

**Phase 1: basics**
1. Installed Ubuntu 24.04 on WSL2 and confirmed `systemd` was running.
2. Wrote a small Node app, ran it by hand, then turned it into a `systemd` service.
3. Tested recovery: `kill -9` on PID 12347 at 08:45:16. `systemd` logged the exit (`status=9/KILL`) and started PID 12394 at 08:45:19. The site answered again with no manual action.
4. Put nginx in front as a reverse proxy.
5. Added firewall allow rules for SSH and HTTP first, then default-deny incoming, then enabled `ufw`.
6. Added a `cron` health check that logs the HTTP status.

**Phase 2: making it more realistic**
1. **Database:** installed PostgreSQL, created a dedicated role and database, and changed the app to store every request in a `visits` table.
2. **Secrets:** the database URL lives in `/etc/hello-app.env` (mode 600, root only), loaded by the service. No password is in the repo; a `.gitignore` excludes `*.env`, keys and certificates.
3. **HTTPS:** created a self-signed certificate (CN=localhost, valid one year), configured nginx for TLS 1.2/1.3, redirected port 80 to 443, opened port 443 in `ufw`, and switched the health check to HTTPS.
4. **Backups:** a root-run `pg_dump` script, scheduled at 02:15 daily, writing compressed dumps to a folder with mode 700 and deleting dumps older than 7 days.
5. **Restore test:** took a fresh backup, restored it into a separate empty database, and compared row counts: `live=11 restored=11`. Then dropped the test database.
6. **Rebuild script:** wrote `setup.sh` (installs packages, creates the database with a random password, applies the configs, sets up TLS, firewall and cron jobs; safe to run twice).
7. **Clean-machine test:** created a second, empty Ubuntu 24.04 instance with a new user, cloned this repo and ran `setup.sh`. See below.

## Results

- Crash recovery verified (see Phase 1, step 3).
- `http://localhost` returns `301` to `https://localhost/`; HTTPS returns `200 OK`; the health check logs `status=200` over HTTPS.
- Firewall: active, default deny incoming; SSH (22), HTTP (80) and HTTPS (443) allowed.
- The visit counter increments across requests, so the app is really reading and writing PostgreSQL.
- Backup restored into a separate database with matching row counts.
- `setup.sh` rebuilt the working service on a clean machine after one bug fix (below): service `active`, site answering over HTTPS, visit count rising.

## Problems I hit and fixed

- **WSL install failed ("Not enough memory resources are available"):** the VirtualMachinePlatform Windows feature was not active yet. The install enabled it; a restart and retry fixed it.
- **Old copy still held port 3000:** an earlier hand-run app was still running. I found it with `systemctl is-active` and `ss -ltnp`, stopped it, then started the service.
- **Pasted script ran under `sh`, not `bash` (`Illegal option -o pipefail`):** pasted text had leading spaces, so `#!/bin/bash` was not at the start of the line and was ignored. I stripped the spaces and verified the first line.
- **Backup script "permission denied" when I read it:** I had set mode 750 (root only). It needed `sudo`.
- **Nightly backup line was missing from root's crontab:** I checked with `crontab -l` instead of assuming, found only the header, and added the entry.
- **Fresh-machine run gave `502 Bad Gateway`:** the journal showed `status=217/USER`. The service file had `User=ayrus15` indented by spaces from an earlier paste, so my `sed` replacement (which expected the line to start with `User=`) skipped it, and that user did not exist on the new machine. Fixed by removing the indentation in the repo and making the `sed` pattern tolerate leading spaces.
- **My own fix introduced a typo:** a doubled `-e` in the `sed` command emptied the service file. `bash -n` passes on this kind of mistake, so only re-running the script on the clean machine caught it.
- **Cloned into `C:\WINDOWS\system32` by accident** because new WSL windows can open in the Windows folder; redid it in the Linux home directory.
- **Pushed the wrong README once:** I copied a stale, unrelated `README.md` from my Downloads folder without checking it. I noticed from the odd diff size, reverted the commit, and now check file contents before committing.

## Limits and what I did not do

- Runs on WSL2, so boot behaviour and some firewall details differ from a real server. I have not tested it on a cloud VM or a bare Ubuntu Server install.
- The TLS certificate is self-signed, so browsers will warn; `curl -k` skips verification, which is fine for a lab and wrong for a real site. No Let's Encrypt because there is no public domain.
- OpenSSH is installed and allowed through the firewall, but I did not test remote SSH login or set up key-based login.
- Backups stay on the same machine. There is no off-site copy, no encryption of the dumps and no restore automation.
- No monitoring or alerting beyond the health-check log; no log rotation for that log.
- The app is minimal: no authentication and no input validation beyond what Node provides. The cron health check also adds a row every 5 minutes.
- `setup.sh` was tested once on one clean WSL2 instance, not across versions.

## How this was made

I followed these steps with guidance from an AI assistant (Claude) and ran every command myself on my own machine. The outputs in the evidence files are from my machine.