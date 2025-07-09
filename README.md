# BrainCraft.io Workspace

A development environment for multi-repository projects, built around VSCode Workspaces on DevContainers and Mise dependency management, environment configuration, and task orchestration.

## Overview

The BrainCraft.io Workspace provides a meta-repository that orchestrates multiple independent Git repositories through a unified development environment. It delivers consistent tooling, automated workflows, and seamless integration between local development, CI/CD pipelines, and AI-assisted coding.

## Features

- **One-Command Setup**: Launch a fully configured development environment with `./launch-workspace`or use it even easier with CodeSpaces built into GitHub!
- **Multi-Repository Management**: Orchestrate multiple repos without submodules
- **Consistent Tooling**: All developers use identical tool versions via mise
- **Performance Optimized**: Persistent volumes and caching for near-native speed
- **AI-First Design**: Optimized for GitHub Copilot, Claude, and other AI assistants
- **Security by Default**: Pre-commit hooks, secret scanning, and secure container practices

## Quick Start

### Prerequisites (Local Development)

- Docker Desktop 4.x+ or Docker Engine 20.x+
- [Visual Studio Code](https://code.visualstudio.com/Download)
- GitHub CLI authenticated (`gh auth login`)

### Getting Started

```bash
# Clone the workspace
git clone https://github.com/braincraftio/workspace.git
cd workspace

# Launch the development environment
./launch-workspace --doctor && ./launch-workspace

# When VS Code opens with the container, click "Open Workspace" when prompted
# This loads the multi-root workspace with all repositories
```

### First Time Setup (Inside Container)

```bash
# Pull all child repositories
mise run git:pull

# Verify environment
mise run doctor
```

## Repository Structure

```text
workspace/                   # This meta-repository
├── actions/                 # GitHub Actions workflows (cloned)
├── containers/              # Container definitions (cloned)
├── dot-github/              # Organization templates (cloned as .github)
├── style-system/            # Multi-brand style system (cloned)
├── .config/                 # Workspace configuration
│   ├── mise/                # Task system and libraries
│   └── bin/                 # Custom tools
├── dot-github/              # Workspace-specific workflows
├── .mise.toml               # Task orchestration
└── launch-workspace         # Container launcher script
```

## Core Commands

### Daily Workflow

```bash
mise run git:pull    # Update all repositories
mise run format      # Format all code
mise run lint        # Run all linters
mise run test        # Run all tests
mise run pre-commit  # Pre-commit validation
```

### Git Operations

```bash
mise run git:status          # Status across all repos
mise run git:branch          # List all branches
mise run git log --oneline   # Any git command
```

### Task Discovery

```bash
mise tasks           # List all available tasks
mise tasks --hidden  # Include hidden tasks
mise run task-list   # Pretty formatted list
mise run tl python   # Filter tasks by domain
```

## Development Workflow

1. **Launch**: `./launch-workspace` starts or resumes your container
2. **Code**: Make changes across any repository
3. **Validate**: `mise run pre-commit` ensures quality
4. **Commit**: Standard git workflow per repository
5. **Cross-repo**: Use `mise run git <command>` for multi-repo operations

## Task System

The workspace uses mise for task orchestration with hierarchical naming:

```
<action>:<domain>:<detail>
```

Examples:
- `lint:python:style` - Python style checking
- `format:javascript` - JavaScript formatting
- `validate:security` - Security validation

### Common Task Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `lint:*` | Code quality checks | `mise run lint:python` |
| `format:*` | Code formatting | `mise run format:go` |
| `test:*` | Test execution | `mise run test:unit` |
| `validate:*` | Validation checks | `mise run validate:schemas` |
| `security:*` | Security scanning | `mise run security:secrets` |

## Tool Management

All tools are managed via mise and defined in `.config/mise/conf.d/00-tools.toml`:

- **Languages**: Go 1.24+, Node 24+, Python 3.13+, Rust stable
- **Linters**: ESLint, Ruff, golangci-lint, ShellCheck
- **Formatters**: Biome, shfmt, gofumpt
- **Security**: detect-secrets, bandit, semgrep

## Contributing

### Adding a New Repository

1. Create the repository on GitHub
2. Update `.github/config/workspace.json` to add repository metadata
3. Update `braincraft.code-workspace` to include the new folder
4. Run `mise run git:clone` to clone it

### Creating Tasks

Add tasks to `.mise.toml` following the naming convention:

```toml
[tasks."domain:action"]
description = "Clear description of what this does"
run = "command to execute"
```

### Code Standards

- Pre-commit hooks enforce quality standards
- All code must pass linting and formatting checks
- Security scanning prevents credential leaks
- Follow language-specific style guides

## Performance

The workspace is optimized for speed:

- **Persistent Volumes**: Tool caches survive container rebuilds
- **Parallel Execution**: Tasks can run concurrently
- **Smart Caching**: Docker BuildKit and mise caching

## Security

- **Container Security**: Non-root user, minimal privileges
- **Secret Management**: Environment-based, no hardcoded secrets
- **Dependency Scanning**: Automated vulnerability detection
- **Pre-commit Hooks**: Prevent accidental secret commits

## Troubleshooting

### Common Issues

```bash
# Container won't start
./launch-workspace --doctor           # Run diagnostics
./launch-workspace --rebuild          # Force rebuild
./launch-workspace --update --rebuild # Update and rebuild

# Authentication issues
gh auth status                 # Check GitHub auth
gh auth login                  # Re-authenticate
gh auth switch <username>      # Switch user if needed

# Performance problems
# Docker Desktop → Settings → Resources
# Allocate 8GB RAM, 4 CPUs minimum
```

### Getting Help

- **Quick Reference**: [WARPSPEED.md](WARPSPEED.md)
- **Architecture Details**: [WORKSPACE.md](WORKSPACE.md)
- **Issues**: [GitHub Issues](https://github.com/braincraftio/workspace/issues)
- **Discussions**: [GitHub Discussions](https://github.com/braincraftio/workspace/discussions)

## License

Copyright 2024-2025 BrainCraft Innovations, LLC. Licensed under Apache 2.0.

See [LICENSE](LICENSE) for details.

## Acknowledgments

Built with:
- [mise](https://mise.jdx.dev) - Polyglot tool version manager
- [VS Code DevContainers](https://code.visualstudio.com/docs/devcontainers/containers) - Development containers
- [GitHub Actions](https://github.com/features/actions) - CI/CD automation

---

**Ready to start?** → [Quick Start](#quick-start)
**Need speed?** → [WARPSPEED.md](WARPSPEED.md)
**Want details?** → [WORKSPACE.md](WORKSPACE.md)