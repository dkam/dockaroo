# Dockaroo — Future Features

Ideas that are out of scope for the current implementation but worth revisiting later.

## Service `extends`

Allow a service to inherit from another service definition, with per-field overrides:

```yaml
services:
  grabber:
    cmd: bundle exec bin/booko -W -i1
    hosts: [grabber01, grabber02]
    replicas: 4

  grabber-au:
    extends: grabber
    cmd: bundle exec bin/booko -W -i1 --region au
    hosts: [grabber01]
    replicas: 2
```

Same merge semantics as `defaults` → service, but service → service. Useful when you have many variants of the same service and want parent changes to cascade.

**Why deferred:** Simple duplication (copy + edit) covers the immediate need without inheritance chain complexity.

## Drift Detection (`dockaroo diff`)

Compare running container state against local `.dockaroo.yml` config and highlight differences. SSH into each host, run `docker inspect` on managed containers, and diff against what dockaroo would generate from the current config.

Detectable drift includes:
- Image tag changed (e.g. someone pulled a newer tag manually)
- Environment variables added, removed, or changed
- Volume mounts or port mappings differ
- Containers running that aren't in config (orphans)
- Containers in config that aren't running (missing)
- Network mode, restart policy, or other docker run flags changed

This is the `terraform plan` equivalent — "here's what would change if you deployed now."

```
$ dockaroo diff grabber01
  booko-grabber-1:
    image: registry.example.com/booko:abc123 → registry.example.com/booko:def456
    env REDIS_URL: changed
  booko-scheduler: not running (expected from config)
  unknown container "manual-debug": running but not in config
```

**Design decision:** `dockaroo deploy` remains authoritative — local config always wins. Drift detection is a pre-deploy diagnostic, not a sync mechanism. If remote changes are intentional, update the config first.

**Why deferred:** Requires a stable deploy workflow first. The diff logic depends on having a reliable "what would dockaroo generate" function to compare against.

## Remote Import (`dockaroo import`)

Scan a remote host's running containers and generate a `.dockaroo.yml` that matches the current state. Useful for adopting existing deployments into dockaroo management without recreating config from scratch.

```
$ dockaroo import grabber01 --project booko
Scanning grabber01...
Found 5 containers:
  booko-grabber-1    registry.example.com/booko:def456
  booko-grabber-2    registry.example.com/booko:def456
  booko-scheduler    registry.example.com/booko:def456
  redis              redis:7-alpine
  unrelated-thing    nginx:latest

Generated .dockaroo.yml (excluded 1 unrelated container)
```

Implementation approach:
- `docker ps --format json` gives container names, images, ports, volumes, network mode, restart policy
- `docker inspect` fills in env vars and other runtime config
- Containers following the `{project}-{service}-{replica}` naming convention can be automatically grouped into services
- Non-matching containers are listed for the user to include/exclude
- Multi-host import by running against multiple hosts

**Why deferred:** Onboarding feature — most valuable once the core deploy/manage workflow is solid. Also needs heuristics for grouping non-dockaroo containers into services, which benefits from real-world usage patterns to guide the design.

## Host Bootstrap (`dockaroo bootstrap`)

Install Docker and configure the user on remote hosts, following Kamal's approach:

1. Check if Docker is already installed (`docker -v`) — skip if so
2. Check for root or passwordless sudo
3. Install via Docker's official convenience script: `curl -fsSL https://get.docker.com | sh`
4. Add user to docker group: `sudo -n usermod -aG docker $USER`
5. Refresh session

The `get.docker.com` script handles distro detection (apt/yum/dnf/etc.) internally, so dockaroo doesn't need to.

Requires either root access or passwordless sudo — prompting for a password over SSH is impractical and bad practice. If the user lacks privileges, fail with a clear message pointing to Docker's manual install docs.

The existing `HostChecker` already detects missing Docker and docker group membership, so bootstrap would be the natural next step: "Docker isn't installed — run `dockaroo bootstrap` to set it up."

**Why deferred:** Most users will already have Docker installed. The host checker provides adequate feedback for now, and users can install Docker themselves following standard docs.
