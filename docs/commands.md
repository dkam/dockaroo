# Dockaroo — Commands

## Global Options

```bash
dockaroo -c PATH    # Use a specific config file (default: .dockaroo.yml)
```

## TUI Mode

```bash
dockaroo
```

Launches the interactive TUI. From here you can:
- View status of all containers across all hosts
- Deploy/redeploy services
- Start/stop/restart individual containers or services
- Tail logs from any container
- Add/remove hosts

## CLI Commands

For scripting and quick operations:

### Status

```bash
# Show all containers across all hosts
dockaroo status

# Show containers on a specific host
dockaroo status grabber02

# Show a specific service
dockaroo status --service grabber
```

Output:
```
HOST        SERVICE      REPLICA  STATUS    IMAGE TAG   UPTIME
grabber01   grabber      1        running   462dd14     2h 15m
grabber01   grabber      2        running   462dd14     2h 15m
grabber01   grabber      3        running   462dd14     2h 15m
grabber01   grabber      4        running   462dd14     2h 15m
grabber01   amazon       -        running   462dd14     2h 15m
grabber02   grabber      1        running   462dd14     5m
grabber02   grabber      2        running   462dd14     5m
grabber02   grabber      3        running   462dd14     5m
grabber02   grabber      4        running   462dd14     5m
grabber02   active_job   -        running   462dd14     5m
grabber02   scheduler    -        running   462dd14     5m
grabber02   amazon       -        exited    462dd14     -
```

### Deploy

```bash
# Deploy latest tag to all hosts
dockaroo deploy

# Deploy specific tag
dockaroo deploy --tag 462dd14

# Deploy to a specific host only
dockaroo deploy grabber02

# Deploy a specific service only
dockaroo deploy --service grabber

# Deploy without pulling (image already on host)
dockaroo deploy --skip-pull
```

Deploy workflow:
1. `docker login` to registry on each host
2. `docker pull` the image on each host
3. For each service on each host:
   a. Stop the old container(s)
   b. Remove the old container(s)
   c. Start new container(s) with updated image

### Logs

```bash
# Tail logs from a service on a host
dockaroo logs grabber02 amazon

# Tail logs with follow
dockaroo logs -f grabber02 amazon

# Tail a specific replica
dockaroo logs grabber02 grabber 3

# Last N lines
dockaroo logs -n 200 grabber02 scheduler
```

### Service Management

```bash
# Stop a service on all its hosts
dockaroo stop grabber

# Stop a service on a specific host
dockaroo stop grabber --host grabber02

# Start a stopped service
dockaroo start grabber

# Restart a service (stop + start)
dockaroo restart grabber

# Scale replicas (updates config and applies)
dockaroo scale grabber 6
```

### Host Management

```bash
# Check host prerequisites
dockaroo check grabber02

# Output:
# grabber02:
#   SSH connection: OK
#   Docker installed: OK (27.5.1)
#   User in docker group: OK
#   Registry login: OK
#   Disk space: 45GB free

# Add a host
dockaroo host add grabber03 --user booko

# Remove a host
dockaroo host remove grabber03
```

### Init

```bash
# Generate a .dockaroo.yml in current directory
dockaroo init
```
