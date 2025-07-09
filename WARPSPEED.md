# WARPSPEED

Lightning-fast onboarding and daily workflow guide for the BrainCraft.io workspace.

## 🚀 Zero to Productive (5 minutes)

### Prerequisites Check (30 seconds)

```bash
# Required: Docker, VS Code, GitHub CLI
docker --version && code --version && gh --version || echo "❌ Missing tools"
```

### Launch Sequence (4 minutes)

```bash
# 1. Clone and enter
git clone https://github.com/braincraftio/workspace.git && cd workspace

# 2. Pre-flight check
./launch-workspace --doctor

# 3. Launch
./launch-workspace

# 4. When VS Code opens: "Reopen in Container"
```

### First-Time Setup (Inside Container)

```bash
# Clone all repositories
mise run git:clone

# Install everything
mise run install

# Verify
mise run doctor
```

## 🎯 Essential Commands

### Daily Drivers

| What             | Command               | Alias         |
| ---------------- | --------------------- | ------------- |
| Update all repos | `mise run git:pull`   | `mise run gp` |
| Check everything | `mise run doctor`     | `mise run d`  |
| Pre-commit check | `mise run pre-commit` | `mise run pc` |
| Format code      | `mise run format`     | `mise run f`  |
| Lint code        | `mise run lint`       | `mise run l`  |
| Run tests        | `mise run test`       | `mise run t`  |

### Git Across All Repos

```bash
mise run git status       # Status everywhere
mise run git branch       # All branches
mise run git "log -1"     # Latest commits
mise run exec <command>   # Any command
```

## 🔧 Quick Fixes

### Can't Push to GitHub?

```bash
# On HOST machine (not container)
gh auth login
gh auth setup-git
```

### Container Problems?

```bash
# Rebuild everything
./launch-workspace --update --rebuild

# Nuclear reset
docker system prune -af && docker volume prune -f
```

### Missing Tools?

```bash
mise trust --yes && mise install
```

## 📦 Repository Map

- **workspace/** - This meta-repository
- **actions/** - GitHub Actions workflows
- **containers/** - Container definitions
- **dot-github/** - Organization templates (.github)
- **style-system/** - Multi-brand styles

## 🏃 Speed Run Commands

### Morning Routine

```bash
./launch-workspace        # Resume work
mise run gp              # Pull updates
mise run doctor          # Health check
```

### Before Committing

```bash
mise run pc              # Pre-commit checks
mise run validate        # Full validation
```

### End of Day

```bash
mise run clean           # Clean artifacts
exit                     # Leave container
```

## 🎨 Working on Specific Projects

### Style System

```bash
cd style-system
mise run demo            # http://localhost:8080
```

### Actions

```bash
cd actions
mise run test            # Test workflows
```

### Containers

```bash
cd containers
mise run build           # Build images
```

## 🚨 Emergency Procedures

### Authentication Reset

```bash
# GitHub CLI (on host)
gh auth logout && gh auth login

# Docker Registry
docker logout ghcr.io
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

### Performance Boost

```bash
# Docker Desktop → Settings → Resources
# Set: 8GB RAM, 4 CPUs, VirtioFS enabled
```

### List Everything

```bash
mise tasks               # All available tasks
mise tasks --verbose     # With descriptions
mise run task-list       # Pretty formatted list
```

## 🤖 AI Assistant Tips

1. Always work from `/workspace`
2. Use `mise run` commands - AI understands them
3. Check `mise tasks` for available operations
4. Reference files with `path:line` format

## 🎯 Task Domains

### Code Quality

- `lint` - Check code style
- `format` - Fix code style
- `validate` - Verify integrity

### Development

- `build` - Build projects
- `test` - Run tests
- `dev` - Start dev servers

### Security

- `security` - Security scans
- `security:secrets` - Secret detection
- `validate:security` - Full validation

### Git Operations

- `git` - Any git command
- `git:status` - Multi-repo status
- `git:pull` - Update all

## 💡 Power User Tricks

```bash
# Run any command across all repos
mise run exec "npm test"

# Parallel execution
MISE_EXPERIMENTAL=1 mise run build

# Check specific domain
mise run lint:python
mise run test:unit
mise run validate:links

# Quick task search
mise tasks | grep docker
```

## 📝 Remember

- **One command philosophy**: If you do it twice, there's a mise task
- **Check doctor first**: Most issues are caught by health checks
- **Use aliases**: Save keystrokes with short aliases
- **Stay in workspace**: All paths are relative to `/workspace`

---

**Need details?** → [WORKSPACE.md](WORKSPACE.md) **Got stuck?** → `./launch-workspace --doctor`
**Questions?** → [GitHub Discussions](https://github.com/braincraftio/workspace/discussions)
