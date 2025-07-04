#!/usr/bin/env bash
# shellcheck shell=bash
#
# health-checks.sh - Reusable health check functions for workspace diagnostics
#
# Purpose:
#   Provides comprehensive health check functions for DevOps, security,
#   repository, and system health validation
#
# Usage:
#   source "${MISE_PROJECT_ROOT}/.config/mise/lib/health-checks.sh"
#

# Guard against multiple sourcing
[[ -n "${_HEALTH_CHECKS_SOURCED:-}" ]] && return 0
declare -r _HEALTH_CHECKS_SOURCED=1

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

# Configuration values from mise config (00-env.toml)
# Environment variables like MIN_DOCKER_MEMORY_GB, NETWORK_MIN_ENDPOINTS_SUCCESS, etc. are available

# Health check result tracking
declare -g -A HEALTH_CHECK_RESULTS=()
# shellcheck disable=SC2034
# SC2034: Used by doctor tasks for error reporting
declare -g -A HEALTH_CHECK_ERRORS=()
declare -g -A HEALTH_CHECK_CATEGORIES=()
declare -g -A CHECK_CATEGORIES=()  # Track category per check name

# Global counters - using namespaced associative array
declare -gA MISE_HEALTH_CHECK_STATE=(
    [total]=0
    [passed]=0
)

#######################################
# Enhanced health check runner with error capture
# Arguments:
#   $1 - check_name: Display name
#   $2 - check_command: Command to execute
#   $3 - category: critical|important|optional
#   $4 - verbose_errors: true|false (default: false)
# Returns:
#   0 on success, 1 on failure
#######################################
run_health_check() {
    local check_name="$1"
    local check_command="$2"
    local category="${3:-important}"
    local verbose_errors="${4:-false}"
    
    # Store category for this check
    # shellcheck disable=SC2034
    # SC2034: Used by doctor-workspace to categorize failures
    CHECK_CATEGORIES["${check_name}"]="${category}"
    
    # Increment total checks
    ((MISE_HEALTH_CHECK_STATE[total]++))
    
    # Capture both stdout and stderr
    local output
    local exit_code
    
    # Check if the command starts with a function name
    local first_word="${check_command%% *}"
    
    if declare -F "${first_word}" >/dev/null 2>&1; then
        # It's a function call - evaluate it in current shell
        # Using eval is safe here because we've verified the function exists
        output=$(eval "${check_command}" 2>&1)
        exit_code=$?
    else
        # It's a shell command - execute safely using bash -c
        # This avoids eval's security issues while still allowing complex commands
        output=$(bash -c "${check_command}" 2>&1)
        exit_code=$?
    fi
    
    # Build status parts separately to control alignment
    local check_display="${check_name}:"
    local status_symbol
    local status_text
    
    if [[ ${exit_code} -eq 0 ]]; then
        status_symbol="✓"
        status_text="OK"
        HEALTH_CHECK_RESULTS["${check_name}"]="success"
        ((MISE_HEALTH_CHECK_STATE[passed]++))
    else
        status_symbol="✗"
        if [[ "${category}" == "optional" ]]; then
            status_text="SKIPPED"
        else
            status_text="FAILED"
        fi
        HEALTH_CHECK_RESULTS["${check_name}"]="failed"
        # shellcheck disable=SC2034
        # SC2034: Used by doctor-workspace for detailed error reporting
        HEALTH_CHECK_ERRORS["${check_name}"]="${output}"
    fi
    
    # Print with consistent alignment
    # Use printf to ensure consistent column widths
    printf "%-50s %s %-8s\n" "${check_display}" "${status_symbol}" "${status_text}"
    
    # Show error details if verbose or critical failure
    if [[ ${exit_code} -ne 0 ]] && {
        [[ "${verbose_errors}" == "true" ]] || 
        [[ "${MISE_VERBOSE:-0}" -ge 1 ]] ||
        [[ "${category}" == "critical" && -n "${output}" ]]
    }; then
        echo "  └─ Error: ${output}" | head -3
    fi
    
    # Track by category count
    if [[ -z "${HEALTH_CHECK_CATEGORIES[${category}]:-}" ]]; then
        HEALTH_CHECK_CATEGORIES["${category}"]=1
    else
        ((HEALTH_CHECK_CATEGORIES["${category}"]++))
    fi
    
    return ${exit_code}
}

#######################################
# Docker health checks
#######################################
check_docker_daemon() {
    docker system info >/dev/null 2>&1
}

check_docker_compose() {
    docker compose version >/dev/null 2>&1
}

check_docker_resources() {
    local df_output
    df_output=$(docker system df --format json 2>/dev/null)
    [[ -n "${df_output}" ]]
}

check_docker_memory() {
    if [[ -f /proc/meminfo ]]; then
        local available_gb
        available_gb=$(awk '/MemAvailable:/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
        (( $(echo "${available_gb} >= ${MIN_DOCKER_MEMORY_GB}" | bc -l) ))
    else
        # macOS doesn't have /proc/meminfo, check Docker's allocated memory
        local docker_mem
        docker_mem=$(docker system info --format '{{.MemTotal}}' 2>/dev/null || echo "0")
        [[ -n "${docker_mem}" ]] && [[ "${docker_mem}" != "0" ]]
    fi
}

#######################################
# GitHub/Git health checks
#######################################
check_github_cli_auth() {
    # Check if gh command exists first
    command -v gh >/dev/null 2>&1 || return 1
    
    # Get full auth status output
    local auth_output
    auth_output=$(gh auth status 2>&1 || true)
    
    # Check for any successful login
    if echo "${auth_output}" | grep -q "✓ Logged in to"; then
        # Check if there are any failures mixed in
        if echo "${auth_output}" | grep -q "X Failed to log in to"; then
            # Mixed success/failure - still return success but details will show in verbose
            return 0
        fi
        return 0
    fi
    
    # No successful logins found
    return 1
}

check_github_token_scopes() {
    local token_info
    token_info=$(gh auth status 2>&1)
    
    # Check for required scopes
    echo "${token_info}" | grep -q "Token scopes:" || return 1
    
    # Verify critical scopes
    local required_scopes=("repo" "read:org")
    for scope in "${required_scopes[@]}"; do
        echo "${token_info}" | grep -q "${scope}" || return 1
    done
}

# Get detailed GitHub auth information for reporting
get_github_auth_details() {
    local auth_output
    auth_output=$(gh auth status 2>&1 || true)
    
    local details=""
    local current_host=""
    
    while IFS= read -r line; do
        if [[ "${line}" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]+$ ]]; then
            current_host="${line}"
        elif [[ "${line}" =~ "Logged in to" ]] && [[ -n "${current_host}" ]]; then
            local account
            account=$(echo "${line}" | sed -n 's/.*account \([^ ]*\).*/\1/p')
            
            if echo "${line}" | grep -q "✓"; then
                if echo "${auth_output}" | grep -A2 "${line}" | grep -q "Active account: true"; then
                    details+="${account}@${current_host} [active] "
                else
                    details+="${account}@${current_host} [inactive] "
                fi
            else
                details+="${account}@${current_host} [failed] "
            fi
        fi
    done <<< "${auth_output}"
    
    echo "${details}"
}

check_git_config() {
    [[ -n "$(git config --global user.name)" ]] &&
    [[ -n "$(git config --global user.email)" ]]
}

check_git_credential_helper() {
    # Check if gh auth git-credential is configured
    # This handles both direct and https-specific configurations
    if git config --global --get-regexp 'credential.*helper' 2>/dev/null | grep -q "gh auth git-credential"; then
        return 0
    fi
    
    # Also accept if just credential.helper is set to gh
    local helper
    helper=$(git config --global credential.helper 2>/dev/null || true)
    [[ "${helper}" == "!gh auth git-credential" ]] || [[ "${helper}" =~ gh.*auth.*git-credential ]]
}

check_ssh_agent() {
    ssh-add -l >/dev/null 2>&1
}

#######################################
# Repository health checks
#######################################
check_repo_remote_connectivity() {
    local repo_path="$1"
    # shellcheck disable=SC2034
    # SC2034: repo_name is passed by caller for consistency with other check functions
    local repo_name="$2"
    
    if [[ ! -d "${repo_path}/.git" ]]; then
        return 1
    fi
    
    (
        cd "${repo_path}" || return 1
        git ls-remote --exit-code origin HEAD >/dev/null 2>&1
    )
}

check_repo_clean_status() {
    local repo_path="$1"
    
    if [[ ! -d "${repo_path}/.git" ]]; then
        return 1
    fi
    
    (
        cd "${repo_path}" || return 1
        git diff-index --quiet HEAD -- 2>/dev/null
    )
}


#######################################
# System resource checks
#######################################
check_disk_space() {
    local min_gb="${1:-5}"
    local available_gb
    
    if command -v df >/dev/null 2>&1; then
        # Different df implementations have different options
        if df -BG "${MISE_PROJECT_ROOT}" 2>/dev/null | grep -q "${MISE_PROJECT_ROOT}"; then
            # GNU df (Linux)
            available_gb=$(df -BG "${MISE_PROJECT_ROOT}" | awk 'NR==2 {gsub(/G/,"",$4); print int($4)}')
        else
            # BSD df (macOS) - use -g flag for GB
            available_gb=$(df -g "${MISE_PROJECT_ROOT}" 2>/dev/null | awk 'NR==2 {print int($4)}')
        fi
        
        [[ -n "${available_gb}" ]] && (( available_gb >= min_gb ))
    else
        return 0  # Skip check if df not available
    fi
}

check_network_connectivity() {
    # Test TCP connectivity to critical services
    local test_endpoints=(
        "github.com:443"
        "ghcr.io:443"
        "registry.npmjs.org:443"
    )
    local success=0
    
    # Debug output when verbose
    if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
        echo "DEBUG: Testing network connectivity..." >&2
    fi
    
    for endpoint in "${test_endpoints[@]}"; do
        local host="${endpoint%:*}"
        local port="${endpoint#*:}"
        
        # Debug each endpoint test
        if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
            echo "DEBUG: Testing ${host}:${port}..." >&2
        fi
        
        # Use nc (netcat) for cross-platform compatibility
        # -z: scan mode (no data), -w: timeout in seconds
        if nc -z -w "${NETWORK_TIMEOUT_SECONDS}" "${host}" "${port}" 2>/dev/null; then
            ((success++))
            if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
                echo "DEBUG: ${host}:${port} - success" >&2
            fi
        else
            if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
                echo "DEBUG: ${host}:${port} - failed" >&2
            fi
        fi
    done
    
    if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
        echo "DEBUG: Network connectivity: ${success}/3 endpoints successful" >&2
    fi
    
    # Success if at least NETWORK_MIN_ENDPOINTS_SUCCESS out of 3 work (allows for one service being down)
    [[ ${success} -ge ${NETWORK_MIN_ENDPOINTS_SUCCESS} ]]
}

#######################################
# Security checks
#######################################
check_env_file_permissions() {
    local env_file="${MISE_PROJECT_ROOT}/.env"
    
    [[ ! -f "${env_file}" ]] && return 0  # OK if no .env file
    
    local perms
    perms=$(stat -c "%a" "${env_file}" 2>/dev/null || stat -f "%p" "${env_file}" 2>/dev/null | tail -c 4)
    
    # Should be 600 or 644 at most
    [[ "${perms}" == "600" ]] || [[ "${perms}" == "644" ]]
}

check_ssh_key_permissions() {
    local ssh_dir="${HOME}/.ssh"
    local failed=0
    
    [[ ! -d "${ssh_dir}" ]] && return 1
    
    # Check directory permissions
    local dir_perms
    dir_perms=$(stat -c "%a" "${ssh_dir}" 2>/dev/null || stat -f "%p" "${ssh_dir}" 2>/dev/null | tail -c 4)
    [[ "${dir_perms}" != "700" ]] && ((failed++))
    
    # Check private key permissions
    for key in "${ssh_dir}"/id_*; do
        [[ -f "${key}" ]] || continue
        [[ "${key}" == *.pub ]] && continue
        
        local key_perms
        key_perms=$(stat -c "%a" "${key}" 2>/dev/null || stat -f "%p" "${key}" 2>/dev/null | tail -c 4)
        [[ "${key_perms}" != "600" ]] && ((failed++))
    done
    
    [[ ${failed} -eq 0 ]]
}

#######################################
# Tool version checks
#######################################
check_tool_version() {
    local tool="$1"
    local min_version="$2"
    local current_version
    
    case "${tool}" in
        docker)
            current_version=$(docker --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        git)
            current_version=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        gh)
            current_version=$(gh --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        node|npm)
            current_version=$(${tool} --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        mise)
            current_version=$(mise --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        *)
            return 1
            ;;
    esac
    
    [[ -n "${current_version}" ]] || return 1
    
    # Use sort -V for proper version comparison
    # This returns the minimum version, so if it equals min_version, current >= min
    local min_found
    min_found=$(printf '%s\n%s\n' "${min_version}" "${current_version}" | sort -V | head -1)
    [[ "${min_found}" == "${min_version}" ]]
}

#######################################
# Container-specific checks (for inside devcontainer)
#######################################
check_devcontainer_env() {
    # Multiple ways to detect if we're in a container
    [[ -n "${REMOTE_CONTAINERS:-}" ]] || \
    [[ -n "${CODESPACES:-}" ]] || \
    [[ -f "/.dockerenv" ]]
}

check_workspace_mount() {
    # Debug output when verbose
    if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
        echo "DEBUG: MISE_PROJECT_ROOT='${MISE_PROJECT_ROOT}'" >&2
        echo "DEBUG: REMOTE_CONTAINERS='${REMOTE_CONTAINERS:-}'" >&2
        echo "DEBUG: CODESPACES='${CODESPACES:-}'" >&2
        echo "DEBUG: /.dockerenv exists: $([[ -f "/.dockerenv" ]] && echo "yes" || echo "no")" >&2
    fi
    
    # Check if we're in a container using multiple methods
    if [[ -n "${REMOTE_CONTAINERS:-}" ]] || \
       [[ -n "${CODESPACES:-}" ]] || \
       [[ -f "/.dockerenv" ]]; then
        # In container - check /workspace mount
        [[ -d "/workspace" ]] && [[ -w "/workspace" ]]
    else
        # On host, check that project root exists and is writable
        local project_root="${MISE_PROJECT_ROOT:-.}"
        
        # More debug output
        if [[ "${MISE_VERBOSE:-0}" -ge 1 ]]; then
            echo "DEBUG: Running on host system" >&2
            echo "DEBUG: project_root='${project_root}'" >&2
            echo "DEBUG: directory exists: $([[ -d "${project_root}" ]] && echo "yes" || echo "no")" >&2
            echo "DEBUG: directory writable: $([[ -w "${project_root}" ]] && echo "yes" || echo "no")" >&2
        fi
        
        [[ -d "${project_root}" ]] && [[ -w "${project_root}" ]]
    fi
}

#######################################
# Mise-specific health checks
#######################################
check_mise_trust() {
    mise list >/dev/null 2>&1
}

check_mise_tools_installed() {
    local missing_tools
    missing_tools=$(mise list --missing 2>/dev/null | wc -l)
    [[ ${missing_tools} -eq 0 ]]
}

#######################################
# Self-healing suggestions
#######################################

#######################################
# Summary and reporting functions
#######################################