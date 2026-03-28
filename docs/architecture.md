# Dockaroo — Architecture

## Overview

```
dockaroo (local machine)
    |
    |-- SSH --> grabber01 --> docker run ...
    |-- SSH --> grabber02 --> docker run ...
    |-- SSH --> web01     --> docker run ...
```

Dockaroo runs on your local machine. It reads `.dockaroo.yml`, SSHs to each host, and executes Docker commands. There is no agent or daemon installed on the remote hosts.

## Components

### Config Parser
Reads `.dockaroo.yml`, merges defaults into services, validates configuration.

### SSH Executor
Manages SSH connections to hosts. Runs docker commands remotely. Handles connection pooling for performance (multiple commands to the same host reuse the connection).

### Container Manager
Translates service definitions into `docker run` commands. Handles:
- Container naming (`{project}-{service}-{replica}`)
- Building the full `docker run` argument list (network, restart, env, volumes, logging, etc.)
- Start/stop/restart/remove operations
- Status queries via `docker ps` and `docker inspect`

### Registry Manager
Handles `docker login` and `docker pull` on remote hosts.

### TUI
Interactive terminal interface built with a Ruby TUI library. Displays:
- Host/service/container status grid
- Log viewer
- Deploy progress

## Docker Command Generation

A service definition like:

```yaml
defaults:
  network: host
  restart: on-failure
  environment:
    MALLOC_ARENA_MAX: "2"
  volumes:
    - ./log:/rails/log
  logging:
    max_size: 50m
    max_file: 5

services:
  grabber:
    cmd: bundle exec bin/booko -W
    replicas: 4
```

Generates (for replica 2 on grabber02):

```bash
cd ~/booko-services && docker run \
  --detach \
  --name booko-grabber-2 \
  --network host \
  --restart on-failure \
  --env-file /home/booko/.dockaroo/env \
  --env MALLOC_ARENA_MAX=2 \
  --env DOCKAROO_PROJECT=booko \
  --env DOCKAROO_SERVICE=grabber \
  --env DOCKAROO_HOST=grabber02 \
  --env DOCKAROO_INSTANCE=2 \
  --volume ./log:/rails/log \
  --log-driver json-file \
  --log-opt max-size=50m \
  --log-opt max-file=5 \
  git.booko.info/booko/booko:latest \
  bundle exec bin/booko -W
```

The `cd` prefix sets the working directory so that relative volume paths (like `./log`) resolve from `remote_dir` (configured in defaults or per-service, defaults to `~`).

The `--env-file` points to a secrets file uploaded to each host at deploy time (see Deploy Strategy). The path is resolved from `$HOME` on the remote host. Non-secret `environment` values from `.dockaroo.yml` are passed as individual `--env` flags.

## Deploy Strategy

Dockaroo uses a simple stop-then-start strategy per service:

1. Resolve `$HOME` on the remote host
2. Upload merged secrets file to host (`$HOME/.dockaroo/env`, mode 0600)
3. `docker login` + `docker pull` the image on each host
4. Create `remote_dir` on host (`mkdir -p`)
5. For each service on each host, for each replica:
   a. `docker stop {container}` (with timeout for graceful shutdown)
   b. `docker rm {container}`
   c. `cd {remote_dir} && docker run ...` with new image

This means brief downtime per container during deploys. For worker processes pulling from a queue, this is acceptable — jobs wait in the queue for a few seconds while the container restarts. Other replicas (if any) continue processing throughout.

Zero-downtime deploys are explicitly out of scope — see design.md for rationale. **Rolling deploys** (one replica at a time) are planned as a future enhancement for replicated services.

## Host Prerequisites

Dockaroo checks these before deploying:

1. **SSH access** — can connect with configured user
2. **Docker installed** — `docker --version` succeeds
3. **Docker group** — user is in `docker` group (or is root)
4. **Registry access** — `docker login` succeeds
5. **Disk space** — warn if low (images can be large)

The `dockaroo check` command runs all these checks and reports results.
