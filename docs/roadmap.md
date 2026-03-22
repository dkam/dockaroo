# Dockaroo — Implementation Roadmap

## Phases Overview

| Phase | Name | Key Deliverable | Depends On |
|-------|------|----------------|------------|
| 0 | Foundation | `dockaroo --version` runs, CLI routing works | — |
| 1a | SSH + Config + CLI Hosts | SSH executor, config parsing (hosts), `dockaroo host add/remove/list/test` | Phase 0 |
| 1b | TUI Shell | Interactive TUI with host list, add/edit host forms, SSH test from TUI | Phase 1a |
| 2 | Configuration (services) | Full `.dockaroo.yml` parsing (services, defaults), `dockaroo init` | Phase 1a |
| 3 | Host Checks | `dockaroo check` verifies prerequisites | Phases 1a, 2 |
| 4 | Registry | `docker login` + `docker pull` on remote hosts | Phases 1a, 2 |
| 5 | Container Management | `docker run`, status, start/stop/restart | Phases 2, 4 |
| 6 | Deploy Workflow | Full `dockaroo deploy` pipeline | Phase 5 |
| 7 | Logs, Scaling | Remaining commands, feature parity | Phase 6 |

---

## Phase 0: Foundation

**Goal**: Establish the executable, CLI argument routing, and module skeleton so `bundle exec dockaroo` runs without error.

**Deliverable**: `dockaroo --version` prints the version. `dockaroo` with no args launches TUI (placeholder). Unknown commands print usage help.

**Files**:
- `lib/dockaroo/cli.rb` — CLI dispatcher. Parse ARGV, route to subcommands or launch TUI.
- `lib/dockaroo/errors.rb` — Error hierarchy (`ConfigError`, `SSHError`, `DockerError`).

**Tests**:
- `test/test_cli.rb` — CLI dispatching, `--version`, unknown command handling.

---

## Phase 1a: SSH + Config + CLI Host Management

**Goal**: Build the SSH executor, minimal config parsing (hosts section), and CLI host management commands. All testable without a TUI.

**Deliverable**: `dockaroo host add/remove/list/test` works. Config persists to `.dockaroo.yml`. SSH connections verified via `dockaroo host test`.

**Files**:
- `lib/dockaroo/config.rb` — YAML parser for hosts section. Load, save (round-trips preserving unknown keys), add/remove/update/find hosts.
- `lib/dockaroo/config/host.rb` — Host data class: `name`, `user`, `port`.
- `lib/dockaroo/ssh_executor.rb` — Wraps `net-ssh`. `SSHExecutor.new(host:, user:, port:)` with `#run(cmd)` returning `SSHResult`. `SSHResult = Data.define(:stdout, :stderr, :exit_status)`.
- `lib/dockaroo/commands/host.rb` — CLI handler for `host add/remove/list/test`.

**Tests**:
- `test/test_config.rb` — Load, add/remove/update hosts, save round-trip, validation.
- `test/test_ssh_executor.rb` — Mock `Net::SSH`, test command execution and error handling.
- `test/commands/test_host.rb` — CLI host commands against temp config files.

---

## Phase 1b: TUI Shell

**Goal**: Interactive TUI built with charm-ruby (bubbletea/lipgloss/bubbles). Shows hosts, lets you add/edit them, test SSH connections.

**Deliverable**: `dockaroo` (no args) launches a full-screen TUI with host list, add/edit host forms, and SSH connectivity testing.

**Files**:
- `lib/dockaroo/tui/app.rb` — Main bubbletea MVU app. Manages screen state, routes input to current screen.
- `lib/dockaroo/tui/screens/hosts.rb` — Host table (Bubbles::Table). Keys: `a` add, `e` edit, `d` delete, `t` test SSH, `q` quit.
- `lib/dockaroo/tui/screens/host_form.rb` — Add/edit host form with TextInput fields for hostname and user.

**Tests**:
- `test/tui/test_app.rb` — Test MVU model transitions: given model + message, assert new model state.

---

## Phase 2: Configuration (services)

**Goal**: Extend config parsing to handle the full `.dockaroo.yml` — services, defaults merging, validation. Add `dockaroo init`.

**Deliverable**: `dockaroo init` generates a template config. Services parsed with defaults merged. TUI and CLI read full config.

**Files**:
- `lib/dockaroo/config/service.rb` — Data class: `name`, `cmd`, `hosts`, `replicas`, `network`, `restart`, `env_file`, `environment`, `volumes`, `logging`.
- `lib/dockaroo/commands/init.rb` — Generates template `.dockaroo.yml`.
- `lib/dockaroo/config.rb` — Extended with `#services`, `#defaults`, defaults-into-services merging, validation.

**Tests**:
- `test/test_config.rb` — Extended: parse services, assert defaults merge, validate required fields.
- `test/commands/test_init.rb` — Assert init creates file with expected structure.
- `test/fixtures/valid_config.yml`, `test/fixtures/missing_project.yml`, `test/fixtures/no_services.yml`

---

## Phase 3: Host Checks

**Goal**: Implement `dockaroo check`. SSH to each host and verify prerequisites. Display in CLI and TUI.

**Deliverable**: `dockaroo check [host]` outputs check results (SSH, Docker installed, docker group, disk space).

**Files**:
- `lib/dockaroo/host_checker.rb` — Prerequisite checks via SSH: `#check_docker_installed` (runs `docker --version`), `#check_docker_group` (runs `id -nG`), `#check_disk_space` (runs `df`). Each returns status + detail.
- `lib/dockaroo/commands/check.rb` — CLI handler, formats output.
- `lib/dockaroo/tui/screens/check.rb` — TUI check results screen.

**Tests**:
- `test/test_host_checker.rb` — Mock SSH responses for each check scenario.

---

## Phase 4: Registry

**Goal**: Handle `docker login` and `docker pull` on remote hosts.

**Deliverable**: Registry login works via env vars, config, or interactive prompt. Images can be pulled to remote hosts. `dockaroo check` also verifies registry access.

**Files**:
- `lib/dockaroo/registry_manager.rb` — `docker login` and `docker pull` over SSH. Credential resolution: env vars → config → prompt.
- `lib/dockaroo/credentials.rb` — Credential resolution logic.

**Tests**:
- `test/test_registry_manager.rb` — Mock SSH, test login command generation.
- `test/test_credentials.rb` — Test env var lookup, config lookup, fallback order.

---

## Phase 5: Container Management

**Goal**: Core container lifecycle. Translate service definitions into `docker run` commands. Start/stop/restart/status.

**Deliverable**: `dockaroo status` shows containers across hosts. `dockaroo stop/start/restart <service>` works. TUI shows live container grid.

**Files**:
- `lib/dockaroo/container_manager.rb` — Generates `docker run` commands from service definitions (following `docs/architecture.md` spec). Methods: `#run_command`, `#start`, `#stop`, `#restart`, `#remove`, `#status`.
- `lib/dockaroo/container_status.rb` — Parses `docker ps --format '{{json .}}'` output.
- `lib/dockaroo/commands/status.rb` — CLI handler for `dockaroo status [host] [--service]`.
- `lib/dockaroo/commands/start.rb`, `stop.rb`, `restart.rb` — CLI handlers.
- `lib/dockaroo/tui/screens/status.rb` — Container status grid (HOST / SERVICE / REPLICA / STATUS / IMAGE TAG / UPTIME).

**Key detail**: Container naming follows `{project}-{service}-{replica}` (no suffix for `replicas: 1`). Filter `docker ps` by name prefix to show only dockaroo-managed containers.

**Tests**:
- `test/test_container_manager.rb` — Assert generated `docker run` commands match the example in `docs/architecture.md`.
- `test/test_container_status.rb` — Parse sample `docker ps` JSON.

---

## Phase 6: Deploy Workflow

**Goal**: Full deploy pipeline: login → pull → stop old → remove old → run new → verify.

**Deliverable**: `dockaroo deploy [host] [--tag TAG] [--service SVC] [--skip-pull]` works. TUI shows deploy progress with spinners.

**Files**:
- `lib/dockaroo/deployer.rb` — Orchestrates deploy: for each host, login, pull, then per service: stop → remove → start → verify. Accepts host/service/tag filters. Reports progress via callbacks.
- `lib/dockaroo/commands/deploy.rb` — CLI handler.
- `lib/dockaroo/tui/screens/deploy.rb` — Deploy progress screen (pending/pulling/stopping/starting/done/failed per host+service).

**Strategy**: Stop-then-start per replica (sequential). Rolling deploys (one replica at a time) noted as future enhancement.

**Tests**:
- `test/test_deployer.rb` — Mock SSH, assert exact command sequence (login, pull, stop, rm, run, verify).

---

## Phase 7: Logs, Scaling

**Goal**: Complete remaining commands for full feature parity with `docs/commands.md`.

**Deliverable**: All CLI commands implemented. TUI can tail logs. `dockaroo scale` adjusts replicas.

**Files**:
- `lib/dockaroo/commands/logs.rb` — Runs `docker logs [-f] [--tail N]` on remote host. Follow mode streams output.
- `lib/dockaroo/tui/screens/logs.rb` — Scrollable log viewer with follow mode toggle.
- `lib/dockaroo/commands/scale.rb` — Update replica count, start/stop containers to match.

**Note**: Streaming logs requires `SSHExecutor#exec_streaming(cmd, &block)` that yields output chunks instead of buffering.

**Tests**:
- `test/commands/test_logs.rb` — Assert correct `docker logs` command construction.
- `test/commands/test_scale.rb` — Test scale up (new containers) and scale down (remove excess).

---

## Directory Structure (at completion)

```
lib/
  dockaroo.rb
  dockaroo/
    version.rb
    errors.rb
    cli.rb
    config.rb
    config/
      host.rb
      service.rb
    ssh_executor.rb
    ssh_result.rb
    host_checker.rb
    registry_manager.rb
    credentials.rb
    container_manager.rb
    container_status.rb
    deployer.rb
    commands/
      init.rb
      check.rb
      status.rb
      deploy.rb
      start.rb
      stop.rb
      restart.rb
      logs.rb
      scale.rb
      host.rb
    tui/
      app.rb
      messages.rb
      screens/
        hosts.rb
        status.rb
        check.rb
        deploy.rb
        logs.rb
test/
  test_helper.rb
  test_cli.rb
  test_config.rb
  test_ssh_executor.rb
  test_host_checker.rb
  test_registry_manager.rb
  test_credentials.rb
  test_container_manager.rb
  test_container_status.rb
  test_deployer.rb
  commands/
    test_init.rb
    test_check.rb
    test_status.rb
    test_deploy.rb
    test_logs.rb
    test_scale.rb
    test_host.rb
  tui/
    test_app.rb
  fixtures/
    valid_config.yml
    missing_project.yml
    no_services.yml
```
