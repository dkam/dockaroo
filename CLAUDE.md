# CLAUDE.md

## Project Overview

Dockaroo is a lightweight Docker container manager for deploying pre-built images across multiple hosts over SSH. It uses `docker run` directly (not Compose, not Swarm) with first-class support for host networking — making it compatible with Tailscale and other VPN/overlay networks.

The CLI command is `dockaroo`. It's distributed as a Ruby gem.

## Documentation

Read these first — they contain the full design, config format, commands, and architecture:

- `docs/design.md` — goals, principles, scope, and explicit non-goals
- `docs/configuration.md` — `.dockaroo.yml` format and full reference
- `docs/commands.md` — TUI mode and all CLI commands
- `docs/architecture.md` — components, docker command generation, deploy strategy
- `docs/roadmap.md` — phased implementation plan (Phase 0–7)

## Tech Stack

- **Ruby** (>= 3.2.0)
- **charm-ruby** (https://charm-ruby.dev) — Ruby bindings for the Charm TUI ecosystem:
  - **bubbletea** — TUI framework using the Elm Architecture (Model-View-Update)
  - **lipgloss** — terminal styling (borders, colors, padding, layout)
  - **bubbles** — pre-built TUI components (table, list, spinner, progress, etc.)
- **SSH** — all remote operations via SSH to target hosts, running docker commands

## Architecture Pattern — Model-View-Update (MVU)

Bubbletea uses the Elm Architecture:
1. **Model** — app state as a data structure
2. **View** — function that renders the model to the screen
3. **Update** — function that takes a message (keypress, event) and returns a new model

The framework runs the loop: User input → Message → Update → new Model → View → Screen

## Key Concepts

- **Project**: defined by a `.dockaroo.yml` in the project root
- **Host**: a remote machine reachable via SSH with Docker installed
- **Service**: a container definition (image, command, env, volumes, etc.)
- **Replica**: multiple identical containers of the same service
- **Defaults**: shared config inherited by all services, overridable per-service

## Container Naming

`{project}-{service}-{replica}` — e.g. `booko-grabber-1`, `booko-scheduler`

Single-replica services omit the number suffix.

## Development Commands

```bash
bundle install
bundle exec rake test
bundle exec dockaroo
```

## Design Principles

1. Solve real problems, not hypothetical ones
2. Direct docker commands over SSH — no Compose, no Swarm
3. Host networking is first-class
4. Per-project configuration via `.dockaroo.yml`
5. TUI interface for interactive use, CLI for scripting
6. Zero-downtime deploys are explicitly NOT a goal (see docs/design.md)
