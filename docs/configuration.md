# Dockaroo — Configuration

## Config File

Dockaroo uses a `.dockaroo.yml` file in the project root.

```yaml
# .dockaroo.yml
project: booko

defaults:
  image: reg.tbdb.info/booko:latest
  remote_dir: ~/booko-services
  network: host
  restart: on-failure
  environment:
    MALLOC_ARENA_MAX: "2"
    RUBY_YJIT_ENABLE: "1"
    BOOKO_LOG_STDOUT: "1"
  volumes:
    - ./log:/rails/log
  logging:
    max_size: 50m
    max_file: 5

hosts:
  web01:
    user: booko
  grabber01:
    user: booko
  grabber02:
    user: booko

services:
  web:
    cmd: bundle exec puma -C config/puma_docker.rb
    hosts: [web01]

  grabber:
    cmd: bundle exec bin/booko -W -i1
    hosts: [grabber01, grabber02]
    replicas: 4

  scheduler:
    cmd: bundle exec ruby bin/scheduler
    hosts: [grabber02]

  caddy:
    image: caddy:2-alpine
    hosts: [web01]
    network: bridge
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./conf:/etc/caddy
      - caddy_data:/data

  anubis:
    image: ghcr.io/techarohq/anubis:latest
    hosts: [web01]
    network: host
```

## Configuration Reference

### Top-level

| Key | Required | Description |
|---|---|---|
| `project` | yes | Project name, used as container name prefix |

### Defaults

The `defaults` block sets values inherited by all services. Any service can override these.

| Key | Description |
|---|---|
| `image` | Default Docker image for services that don't specify their own |
| `remote_dir` | Working directory on the remote host for `docker run` (default: `~`). Relative volume paths resolve from here. |
| `network` | Docker network mode (`host`, `bridge`, or a named network) |
| `restart` | Restart policy (`no`, `on-failure`, `unless-stopped`, `always`) |
| `environment` | Key-value environment variables (non-secret) |
| `volumes` | Volume mounts |
| `logging.max_size` | Max log file size |
| `logging.max_file` | Max number of log files |

### Hosts

Each host entry specifies connection details.

| Key | Required | Description |
|---|---|---|
| `user` | no | SSH user (default: current user) |
| `port` | no | SSH port (default: 22) |

### Services

Each service defines what to run and where. Services inherit from `defaults` and can override any field.

| Key | Required | Description |
|---|---|---|
| `image` | no | Docker image (overrides `defaults.image`). Required if no default image set. |
| `cmd` | no | Command to run in the container (omit to use image's default CMD) |
| `hosts` | yes | List of hosts to deploy this service to |
| `replicas` | no | Number of identical containers per host (default: 1) |
| `network` | no | Override default network mode |
| `restart` | no | Override default restart policy |
| `environment` | no | Additional/override environment variables |
| `volumes` | no | Additional/override volume mounts |
| `remote_dir` | no | Override default remote working directory |
| `ports` | no | Port mappings (e.g. `"80:80"`, `"127.0.0.1:8080:8080"`) |
| `logging` | no | Override default logging settings |

### Image Resolution

Each service gets its image from the first available source:
1. `services.{service}.image` — explicit per-service image
2. `defaults.image` — shared default

When deploying with `--tag`, the tag override only applies to services using the default image. Services with their own explicit image are deployed as-is.

## Container Naming

Containers are named: `{project}-{service}-{replica}`

Examples:
- `booko-grabber-1`, `booko-grabber-2`, `booko-grabber-3`, `booko-grabber-4`
- `booko-scheduler`
- `booko-caddy`

Services with `replicas: 1` (or no replicas key) omit the number suffix.

## Secrets

Secrets (database URLs, API keys, passwords) are stored locally in `.dockaroo/secrets` files and uploaded to each host at deploy time. These files use dotenv format and should be added to `.gitignore`.

### File structure

```
.dockaroo/secrets              # shared across all hosts
.dockaroo/secrets.grabber01    # host-specific overrides (optional)
.dockaroo/secrets.grabber02    # host-specific overrides (optional)
```

### Example

```bash
# .dockaroo/secrets — shared base
DATABASE_URL=postgres://user:password@db:5432/myapp
REDIS_URL=redis://redis.tailscale:6379
SECRET_KEY_BASE=abc123...

# .dockaroo/secrets.grabber01 — overrides for grabber01
DATABASE_URL=postgres://user:password@db:5433/myapp?prepared_statements=false
```

### Merge order

At deploy time, environment variables are merged in this order (later values override earlier):

1. `.dockaroo/secrets` — base secrets
2. `.dockaroo/secrets.{host}` — host-specific secret overrides
3. `defaults.environment` — non-secret defaults from `.dockaroo.yml`
4. `services.{service}.environment` — non-secret per-service values

The merged secrets file is uploaded to each host (mode 0600) and passed to Docker via `--env-file`. Non-secret `environment` values from the YAML config are passed as `--env` flags.

### What goes where

| Type | Where | Example |
|---|---|---|
| Passwords, tokens, connection strings | `.dockaroo/secrets` | `DATABASE_URL`, `API_KEY` |
| Host-specific secret overrides | `.dockaroo/secrets.{host}` | Different `DATABASE_URL` per host |
| Non-secret config | `environment` in `.dockaroo.yml` | `MALLOC_ARENA_MAX`, `RAILS_ENV` |

## Auto-injected Environment Variables

Dockaroo injects these automatically into every container:

| Variable | Description |
|---|---|
| `DOCKAROO_PROJECT` | Project name |
| `DOCKAROO_SERVICE` | Service name |
| `DOCKAROO_HOST` | Host the container is running on |
| `DOCKAROO_INSTANCE` | Replica instance number (1-based), only for replicated services |

## Registry Authentication

Dockaroo runs `docker login` on each host before pulling. It automatically detects which registries are needed from the service images. Credentials come from:

1. Environment variables: `DOCKAROO_REGISTRY_USERNAME` and `DOCKAROO_REGISTRY_PASSWORD`
2. `.dockaroo/secrets` (set `DOCKAROO_REGISTRY_USERNAME` and `DOCKAROO_REGISTRY_PASSWORD`)
3. Interactive prompt

Docker Hub images (e.g. `caddy:2-alpine`) don't require registry login.
