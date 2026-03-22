# Dockaroo

Lightweight Docker container manager for deploying pre-built images across multiple hosts over SSH.

Dockaroo uses `docker run` directly — no Compose, no Swarm — with first-class support for host networking, making it compatible with Tailscale and other VPN/overlay networks.

## How It Works

```
dockaroo (local machine)
    |
    |-- SSH --> host01 --> docker run ...
    |-- SSH --> host02 --> docker run ...
    |-- SSH --> host03 --> docker run ...
```

Dockaroo runs on your local machine. It reads `.dockaroo.yml`, SSHs to each host, and executes Docker commands. No agent or daemon is installed on the remote hosts.

## Installation

```bash
gem install dockaroo
```

Requires Ruby >= 3.2.0.

## Quick Start

Generate a config file in your project root:

```bash
dockaroo init
```

Edit `.dockaroo.yml` to define your hosts and services, then deploy:

```bash
dockaroo deploy --tag abc123
```

## Configuration

Dockaroo uses a `.dockaroo.yml` file in the project root:

```yaml
project: myapp
registry: registry.example.com
image: myapp/myapp
tag: latest

defaults:
  network: host
  restart: on-failure
  env_file: .env
  environment:
    MALLOC_ARENA_MAX: "2"
  volumes:
    - ./log:/app/log
  logging:
    max_size: 50m
    max_file: 5

hosts:
  worker01:
    user: deploy
  worker02:
    user: deploy

services:
  worker:
    cmd: bundle exec bin/worker
    hosts: [worker01, worker02]
    replicas: 4

  scheduler:
    cmd: bundle exec bin/scheduler
    hosts: [worker01]
```

The `defaults` block sets values inherited by all services. Any service can override these.

See [docs/configuration.md](docs/configuration.md) for the full reference.

## Usage

### TUI Mode

```bash
dockaroo
```

Launches an interactive terminal UI where you can view status, deploy, manage containers, and tail logs.

### CLI Commands

```bash
# Show container status across all hosts
dockaroo status

# Deploy to all hosts (or a specific host/service)
dockaroo deploy
dockaroo deploy --tag abc123
dockaroo deploy --service worker
dockaroo deploy worker02

# Start/stop/restart services
dockaroo stop worker
dockaroo start worker
dockaroo restart worker

# Tail logs
dockaroo logs worker01 scheduler
dockaroo logs -f worker01 worker 2

# Scale replicas
dockaroo scale worker 6

# Check host prerequisites
dockaroo check worker01

# Manage hosts
dockaroo host add worker03 --user deploy
dockaroo host remove worker03
```

See [docs/commands.md](docs/commands.md) for full command reference.

## Container Naming

Containers are named `{project}-{service}-{replica}`:

- `myapp-worker-1`, `myapp-worker-2`, `myapp-worker-3`
- `myapp-scheduler` (single-replica services omit the number)

## Registry Authentication

Dockaroo runs `docker login` on each host before pulling. Credentials come from:

1. Environment variables: `DOCKAROO_REGISTRY_USERNAME` and `DOCKAROO_REGISTRY_PASSWORD`
2. Config file
3. Interactive prompt

## What Dockaroo Does NOT Do

- Build or push images — use your existing build pipeline
- Manage Docker networks, volumes, or infrastructure
- Service discovery or load balancing
- Zero-downtime deploys (see [docs/design.md](docs/design.md) for rationale)
- Replace Kubernetes, Nomad, or any serious orchestrator

Dockaroo is built for managing a handful of hosts running Docker containers, not for orchestrating thousands of pods.

## Documentation

- [Design](docs/design.md) — goals, principles, and scope
- [Configuration](docs/configuration.md) — `.dockaroo.yml` format and reference
- [Commands](docs/commands.md) — TUI and CLI command reference
- [Architecture](docs/architecture.md) — components and deploy strategy
- [Roadmap](docs/roadmap.md) — phased implementation plan

## Development

```bash
bundle install
bundle exec rake test
bundle exec dockaroo
```

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
