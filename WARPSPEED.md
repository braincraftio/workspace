# WARPSPEED.md - BrainCraft.io Daily Developer Guide

Get productive in 5 minutes. Your daily command reference.

## 🚀 First Time Setup (5 minutes)

### 1. Clone and Check (1 minute)

```bash
git clone https://github.com/braincraftio/workspace.git
cd workspace
./launch-workspace --doctor
```

Doctor will tell you exactly what to fix. Follow its instructions.

### 2. Launch Workspace (30 seconds)

```bash
./launch-workspace
```

Click "Reopen in Container" when VS Code prompts.

### 3. Wait for Setup (2-3 minutes)

Watch the terminal for:


- "✅ Development environment ready!"
- "💡 Run 'mise tasks' to see available commands"

### 4. Fix Authentication (if needed)


**On your HOST machine** (not in container):

```bash
gh auth login        # Choose "Login with web browser"


gh auth setup-git    # Configure git credential helper
```


**Fix gitconfig** if you see absolute paths:

```ini
# BAD:  helper = /opt/homebrew/bin/gh auth git-credential
# GOOD: helper = !gh auth git-credential
```

### 5. Verify Success

```bash
mise doctor    # Should show all green checkmarks
```

You're ready! For architecture details, see [WORKSPACE.md](WORKSPACE.md).

## 📅 Daily Workflow

### Starting Your Day

```bash
# Launch workspace (remembers your container)
./launch-workspace

# Update everything
mise run pull         # Pull all repos
mise run doctor       # Check health

# Start development
mise run dev:all      # Start all services
# OR specific services:
mise run dev:actions  # Just GitHub Actions
mise run dev:docs     # Just documentation
```

### Before Every Commit

```bash
mise run check:before-commit    # Runs all validations
# This includes: lint:all, test:unit, security:secrets
```

### Common Development Tasks

| Task                | Command                | What it does              |
| ------------------- | ---------------------- | ------------------------- |
| See all commands    | `mise tasks`           | List everything available |
| Run specific linter | `mise run lint:python` | Lint just Python code     |
| Run specific tests  | `mise run test:unit`   | Unit tests only           |
| Check git status    | `mise run git:status`  | Status across all repos   |
| Update tools        | `mise install`         | Update all tool versions  |

### Weekly Maintenance

```bash
# Update container to latest
./launch-workspace --update

# Update all tools
mise run update

# Clean build artifacts
mise run clean
```

## 🔧 Quick Fixes

### Authentication Issues

```bash
# Can't push to GitHub?
gh auth status          # Check status
gh auth login           # Re-authenticate

# Can't pull container image?
# Get token: https://github.com/settings/tokens/new (read:packages)
export GITHUB_TOKEN='ghp_...'
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

### Performance Issues

```bash
# Container slow?
# Docker Desktop → Settings → Resources
# Recommended: 8GB RAM, 4 CPUs

# On macOS also enable:
# - Use virtualization framework
# - VirtioFS accelerated directory sharing
```

### Task/Tool Issues

```bash
# mise command not found?
mise trust --yes
mise install

# Task not found?
mise tasks              # List all available
mise tasks --verbose    # Show descriptions

# Wrong tool version?
mise doctor            # Check versions
mise install           # Reinstall
```

### Container Issues

```bash
# Container won't start?
./launch-workspace --doctor    # Run diagnostics
./launch-workspace --rebuild   # Fresh container

# Really broken?
./launch-workspace --update --rebuild   # Nuclear option
```

## 🎯 Project-Specific Commands

### Working on Actions

```bash
cd /workspace/actions
mise run dev           # Start development mode
mise run test:actions  # Test GitHub Actions
```

### Working on Docs

```bash
cd /workspace/docs
mise run serve         # Start docs server (port 1313)
```

### Multi-Repo Operations

```bash
mise run git:pull      # Update all repos
mise run git:status    # Check all statuses
mise run lint:all      # Lint everything
mise run test:all      # Test everything
```

## 💡 AI Development Tips

### For Claude/Copilot

1. **Always work from workspace root**: `/workspace`
2. **Use mise tasks**: AI understands `mise run test:all`
3. **Check available tasks**: `mise tasks --verbose`

### Common AI-Friendly Commands

```bash
# These patterns work well with AI assistants:
mise run dev:all              # Start everything
mise run check:before-commit  # Validate changes
mise run fix:formatting       # Auto-fix issues
mise run security:scan        # Security check
```

## 📋 Task Quick Reference

### Essential Tasks

| Need             | Command               | Alias         |
| ---------------- | --------------------- | ------------- |
| Setup everything | `mise run setup`      | `mise run s`  |
| Health check     | `mise run doctor`     | `mise run d`  |
| Run all lints    | `mise run lint:all`   | `mise run l`  |
| Run all tests    | `mise run test:all`   | `mise run t`  |
| Git status all   | `mise run git:status` | `mise run gs` |
| Git pull all     | `mise run git:pull`   | `mise run gp` |
| Clean artifacts  | `mise run clean`      | `mise run c`  |

### Development Tasks

```bash
mise run dev:all        # Everything
mise run dev:actions    # GitHub Actions
mise run dev:docs       # Documentation
mise run dev:obelisk    # Obelisk project
```

### Validation Tasks

```bash
mise run lint:go        # Go linting
mise run lint:python    # Python linting
mise run lint:shell     # Shell scripts
mise run lint:yaml      # YAML files
mise run test:unit      # Unit tests
mise run test:integration  # Integration tests
```

## 🚨 Emergency Commands

```bash
# Check what's broken
./launch-workspace --doctor --verbose

# Reset everything
docker system prune -af
docker volume prune -f
./launch-workspace --update --rebuild

# Backup before reset
docker cp $(docker ps -q --filter "label=devcontainer.local_folder"):/workspace/important-file ./backup/

# Manual container cleanup
docker ps -a | grep braincraftio
docker rm -f <container-id>
```

<hello@braincraft.io>

## 📚 Getting Help<hello@braincraft.io>

1. **Check doctor first**: `./launch-workspace --doctor`
2. **Read task hel<hello@braincraft.io>verbose`
3. **Architecture details**: [WORKSPACE.md](WORKSPACE.md)
4. **GitHub Discussions**: [Ask questions](https://github.com/braincraftio/workspace/discussions)
5. **Emergency**: <hello@braincraft.io>

## 🎉 Pro Tips

1. **Use task aliases**: `mise run t` instead of `mise run test:all`
2. **Tab completion**: Most shells auto-complete mise commands
3. **Parallel execution**: Many tasks run in parallel automatically
4. **Local CI**: `mise run ci:local` runs full CI pipeline
5. **Custom tasks**: Add your own in `.mise.toml`

---

**Remember**: This guide is for daily use. For understanding how things work, see
[WORKSPACE.md](WORKSPACE.md). **Philosophy**: If you need to do something more than once, there's
probably a mise task for it. Check `mise tasks`!
