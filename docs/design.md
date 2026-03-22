# Dockaroo — Design Document

## What Is It

Dockaroo is a lightweight Docker container manager for deploying pre-built images across multiple hosts over SSH. It uses `docker run` directly (not Compose, not Swarm) with support for host networking — making it compatible with Tailscale and other VPN/overlay networks.

## Why It Exists

Kamal 2 doesn't support `network_mode: host`. If your infrastructure uses Tailscale for inter-host communication (Redis, PostgreSQL, Beanstalkd on Tailscale IPs), Docker bridge-networked containers can't reach those services. Compose supports host networking but has no multi-host orchestration. Dockaroo fills that gap.

## Design Principles

1. **Solve real problems, not hypothetical ones** — built for managing a handful of hosts running Docker containers, not for orchestrating thousands of pods.
2. **Direct docker commands** — no Compose, no Swarm. Just `docker run` over SSH. Simple to understand, simple to debug.
3. **Host networking first-class** — `network_mode: host` is the default, not an afterthought.
4. **Per-project configuration** — `.dockaroo.yml` lives in the project root. Different projects, different configs.
5. **TUI interface** — interactive terminal UI for status, logs, and management. Not just a CLI that dumps text.

## What It Does

- Manage hosts (add/remove, set SSH user, verify docker group membership)
- Deploy pre-built images to specific hosts
- Start/stop/restart containers across hosts
- Scale services with replicas
- View container status across all hosts in a single view
- Tail logs from any container
- Verify host prerequisites (Docker installed, user in docker group, registry access)

## What It Does NOT Do

- Build images (use `docker build` / `docker buildx` / your existing build script)
- Push images to registries (use `docker push` / your build script)
- Manage Docker networks, volumes, or other infrastructure
- Service discovery or load balancing
- Zero-downtime deploys (see below)
- Replace Kubernetes, Nomad, or any serious orchestrator

## Zero-Downtime Deploys — Explicitly Out of Scope (For Now)

Kamal achieves zero-downtime deploys by controlling kamal-proxy — it boots the new container, health checks it, then switches the proxy to route traffic before stopping the old one. This only works because Kamal owns the reverse proxy.

Dockaroo does not manage proxies and makes no assumptions about what sits in front of your containers. Implementing zero-downtime would require either:
- Controlling a proxy (adds complexity and coupling)
- Assuming a specific load balancer setup

For the target use case (background workers, queue processors, schedulers), brief downtime during deploys is acceptable — jobs wait in the queue for a few seconds while containers restart.

**Planned: rolling deploys for replicated services.** For services with `replicas > 1`, dockaroo will deploy one replica at a time, waiting for each to be running before moving to the next. This provides near-zero-downtime for replicated workers without any proxy involvement.
