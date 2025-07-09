# MCP (Model Context Protocol) Configuration Guide

## Overview

This repository is configured with Model Context Protocol (MCP) servers to enhance AI assistant

capabilities across multiple tools:

- Claude Desktop
- VS Code with Continue/Copilot
- Gemini
- Other MCP-compatible tools

## Configured MCP Servers

We haGitHubCP servers configured: GitHub

1. **GitHub** - Persistent memory storage across conversations
2. **sequential-thinking** - Step-by-step problem solving
3. **GitHub** - GitHub API integration
4. **fetch** - Web content fetching
5. **git** - Local git repository operations
6. **playwright** - Browser automation and web scraping
7. **perplexity** - Perplexity AI search integration
8. **deepwiki** - GitHub repository documentation access

## Environment Setup

### 1. Copy Environment Template

```bash
cp .env.example .env
```

### 2. Configure Required Environment Variables

Edit `.env` and add your API keys:

```bash
# GitHub Integration (Required for github server)
# Create a personal access token at https://github.com/settings/tokens
# Required scopes: repo, read:org, read:user
GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx  # pragma: allowlist secret

# Perplexity API (Required for perplexity server)
# Get your API key from https://www.perplexity.ai/settings/api
PERPLEXITY_API_KEY=pplx-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

**Note:** The `.env` file is gitignored. Never commit real API keys.

## Installation

### Prerequisites

This project uses `mise` for tool management. All MCP servers are automatically installed when you
run:

````bash
# Install mise if you haven't already
curl https://mise.run | sh


# Trust and install all toolsGitHub
mise trust

mise installGitHub

```GitHub

This will install:

- Node.js packages via npm (memory, sequential-thinking, GitHub, playwright, perplexity)
- Python packages via pipx (mcp-server-fetch, mcp-server-git)

### Manual Installation (if needed)

```bash
# NPM-based servers
npm install -g \
  @modelcontextprotocol/server-memory \
  @modelcontextprotocol/server-sequential-thinking \
  @modelcontextprotocol/server-github \
  @playwright/mcp@latest \
  server-perplexity-ask

# Python-based servers (via pipx)
pipx install mcp-server-fetch
pipx install mcp-server-git
````

## Configuration Files

### MCP Server Configurations

All MCP configurations are unified across tools with identical server setups:

- **`.mcp.json`** - Primary MCP configuration
- **`.vscode/mcp.json`** - VS Code MCP configuration
- **`.claude/settings.json`** - Claude-specific settings and permissions
- **`.gemini/settings.json`** - Gemini MCP configuration

### Configuration Structure

```json
{
  "mcpServers": {
    "memory": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-memory"],
      "env": {}
    },
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "${GITHUB_PERSONAL_ACCESS_TOKEN:-${GITHUB_TOKEN:-${GH_TOKEN}}}"
      }
    },
    "fetch": {
      "type": "stdio",
      "command": "mcp-server-fetch",
      "args": [],
      "env": {}
    },
    "deepwiki": {
      "type": "http",
      "url": "https://mcp.deepwiki.com/mcp"
    }
    // ... other servers
  }
}
```

### Claude-Specific Configuration

`.claude/settings.json` includes additional permission settings:

```json
{
  "permissions": {
    "allow": ["Bash(ls:*)", "mcp__playwright__browser_navigate", "mcp__perplexity__perplexity_ask"],
    "deny": []
  },
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": [
    "memory",
    "sequential-thinking",
    "github",
    "fetch",

    "git",
    "playwright",
    "perplexity",

    "deepwiki"
  ]
}
```

## Usage Examples

### Memory Server

```bash

# Store information

> Store this note: "Project uses mise for tool management"
> Remember that the main branch is protected


# Recall information

> What notes do I have stored?

> What did I store about the project?
```

### Sequential Thinking

```bash
> Think through how to implement a new feature step by step
> Break down this complex problem into smaller parts
```

### GitHub Server

```bash
> List my recent GitHub repositories
> Show open issues in owner/repo
> Create a new issue in owner/repo

```

### Git Server

```bash

> Show current git status
> List recent commits


> Show changes in the working directory
```

### Fetch Server

```bash
> Fetch content from https://example.com

> Get the documentation from https://docs.example.com/api
```

### Playwright Server

```bash

> Navigate to https://example.com and take a screenshot
> Extract all links from https://example.com

> Fill out the contact form on https://example.com
```

### Perplexity Server

```bash
> Ask Perplexity: What are the latest developments in AI coding assistants?
> Search for recent news about MCP protocol
```

### DeepWiki Server

```bash
> Get documentation for facebook/react
> Explain the architecture of microsoft/vscode
```

## Troubleshooting

### Verify Installation

```bash
# Check if mise installed the tools
mise list

# Verify individual tools
which mcp-server-fetch
which mcp-server-git
npm list -g @modelcontextprotocol/server-memory


```

### Common Issues

1. **"Command not found" errors**

   ```bash
   # Ensure mise shims are in PATH
   eval "$(mise activate bash)"  # or zsh

   # Or add to your shell profile
   echo 'eval "$(mise activate bash)"' >> ~/.bashrc

   ```

2. **Environment variables not loaded**

   ```bash
   # Check if .env exists
   ls -la .env

   # Manually export for testing
   export $(cat .env | xargs)
   ```

3. **Permission denied errors**
   - Ensure API tokens have correct permissions
   - GitHub token needs: repo, read:org, read:user
   - Check Claude permissions in `.claude/settings.json`

4. **Server startup failures**

   ```bash
   # Test servers individually
   npx -y @modelcontextprotocol/server-memory --version
   mcp-server-fetch --help

   mcp-server-git --help
   ```

### Debug Mode

For Claude Desktop:

```bash
# Run with debug output
claude --debug

# Check MCP server status
claude mcp list
```

## Security Best Practices

1. **Never commit `.env` files** - Already in `.gitignore`
2. **Use minimal token permissions** - Only grant what's needed
3. **Rotate API keys regularly** - Set calendar reminders
4. **Review `.env.example`** - Keep it updated but without real values

## Project Integration

### For Team Members

1. Clone the repository
2. Run `mise trust && mise install`

3. Copy `.env.example` to `.env`
4. Add your API keys
5. Test with your preferred AI tool

### CI/CD Considerations

The MCP configurations can be safely committed as they use environment variable references. For
CI/CD:

```yaml
# Example GitHub Actions

env:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  PERPLEXITY_API_KEY: ${{ secrets.PERPLEXITY_API_KEY }}
```

## Adding New MCP Servers

1. Add to `mise.toml`:

   ```toml
   "npm:@example/new-server" = "latest"
   ```

2. Update all MCP config files:
   - `.mcp.json`

   - `.vscode/mcp.json`
   - `.gemini/settings.json`
   - `.claude/settings.json` (also update enabledMcpjsonServers)

3. Document in this file

4. Update `.env.example` if new environment variables are needed

## Resources

- [MCP Documentation](https://modelcontextprotocol.io)
- [MCP Server Registry](https://github.com/modelcontextprotocol/servers)
- [Mise Documentation](https://mise.jdx.dev)
- [Claude Desktop](https://claude.ai/download)

## Support

- **MCP Issues**: Check individual server repositories
- **Configuration Issues**: Review the debug output
- **Environment Issues**: Ensure `.env` is properly configured
