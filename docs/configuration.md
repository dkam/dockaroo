# Dockaroo — Configuration

## Config File

Dockaroo uses a `.dockaroo.yml` file in the project root.

```yaml
# .dockaroo.yml
project: booko
registry: git.booko.info
image: booko/booko
tag: latest              # default tag, can be overridden at deploy time

defaults:
  network: host
  restart: on-failure
  env_file: .env
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
  grabber01:
    user: booko
  grabber02:
    user: booko

services:
  grabber:
    cmd: bundle exec bin/booko -W
    hosts: [grabber01, grabber02]
    replicas: 4

  active_job:
    cmd: bundle exec bin/active_job_worker
    hosts: [grabber02]

  scheduler:
    cmd: bundle exec ruby bin/scheduler
    hosts: [grabber02]

  amazon:
    cmd: bundle exec bin/amazon
    hosts: [grabber01, grabber02]
```

## Configuration Reference

### Top-level

| Key | Required | Description |
|---|---|---|
| `project` | yes | Project name, used as container name prefix |
| `registry` | yes | Docker registry server |
| `image` | yes | Image name (without registry prefix) |
| `tag` | no | Default image tag (default: `latest`) |

### Defaults

The `defaults` block sets values inherited by all services. Any service can override these.

| Key | Description |
|---|---|
| `network` | Docker network mode (`host`, `bridge`, or a named network) |
| `restart` | Restart policy (`no`, `on-failure`, `unless-stopped`, `always`) |
| `env_file` | Path to env file on the remote host |
| `environment` | Key-value environment variables |
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

Each service defines what to run and where.

| Key | Required | Description |
|---|---|---|
| `cmd` | yes | Command to run in the container |
| `hosts` | yes | List of hosts to deploy this service to |
| `replicas` | no | Number of identical containers per host (default: 1) |
| `network` | no | Override default network mode |
| `restart` | no | Override default restart policy |
| `env_file` | no | Override default env file |
| `environment` | no | Additional/override environment variables |
| `volumes` | no | Additional/override volume mounts |

## Container Naming

Containers are named: `{project}-{service}-{replica}`

Examples:
- `booko-grabber-1`, `booko-grabber-2`, `booko-grabber-3`, `booko-grabber-4`
- `booko-active_job`
- `booko-scheduler`
- `booko-amazon`

Services with `replicas: 1` (or no replicas key) omit the number suffix.

## Environment Variables

Dockaroo injects these automatically:

| Variable | Description |
|---|---|
| `DOCKAROO_PROJECT` | Project name |
| `DOCKAROO_SERVICE` | Service name |
| `DOCKAROO_HOST` | Host the container is running on |
| `DOCKAROO_INSTANCE` | Replica instance number (1-based), only for replicated services |

## Registry Authentication

Dockaroo runs `docker login` on each host before pulling. Credentials come from:

1. Environment variables: `DOCKAROO_REGISTRY_USERNAME` and `DOCKAROO_REGISTRY_PASSWORD`
2. Config file (not recommended for secrets)
3. Interactive prompt
