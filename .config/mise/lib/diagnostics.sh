#!/usr/bin/env bash
# shellcheck shell=bash
#
# diagnostics.sh - Advanced diagnostic and performance tracking functions
#
# Purpose:
#   Provides performance metrics, diagnostic information gathering,
#   and actionable remediation suggestions
#
# Usage:
#   source "${MISE_PROJECT_ROOT}/.config/mise/lib/diagnostics.sh"
#

# Guard against multiple sourcing
[[ -n "${_DIAGNOSTICS_SOURCED:-}" ]] && return 0
declare -r _DIAGNOSTICS_SOURCED=1

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

# Configuration values from mise config (00-env.toml)
# Environment variables like DOCKER_HIGH_CONTAINER_COUNT, DISK_USAGE_WARNING_PERCENT, etc. available

# Performance tracking - bash 3.2 compatible
# shellcheck disable=SC2034
# SC2034: Used by doctor tasks for performance reporting
DIAG_START_TIME=""

# Timer storage using parallel arrays instead of associative array
DIAG_TIMER_NAMES=()
DIAG_TIMER_START_TIMES=()
DIAG_TIMER_DURATIONS=()

#######################################
# Start performance timer
# Arguments:
#   $1 - timer_name: Name of the timer
#######################################
start_timer() {
    local timer_name="${1:-default}"
    local start_time
    start_time=$(date +%s.%N)
    
    # Find or add timer
    local found=0
    local i
    for i in "${!DIAG_TIMER_NAMES[@]}"; do
        if [[ "${DIAG_TIMER_NAMES[${i}]}" == "${timer_name}" ]]; then
            # shellcheck disable=SC2004
            # SC2004: False positive - i is array index not arithmetic variable
            DIAG_TIMER_START_TIMES[${i}]="${start_time}"
            found=1
            break
        fi
    done
    
    # Add new timer if not found
    if [[ ${found} -eq 0 ]]; then
        DIAG_TIMER_NAMES+=("${timer_name}")
        DIAG_TIMER_START_TIMES+=("${start_time}")
        DIAG_TIMER_DURATIONS+=("")
    fi
}

#######################################
# Stop timer and record duration
# Arguments:
#   $1 - timer_name: Name of the timer
# Returns:
#   Duration in seconds
#######################################
stop_timer() {
    local timer_name="${1:-default}"
    local end_time
    end_time=$(date +%s.%N)
    
    # Find timer
    local i
    for i in "${!DIAG_TIMER_NAMES[@]}"; do
        if [[ "${DIAG_TIMER_NAMES[${i}]}" == "${timer_name}" ]]; then
            local start_time="${DIAG_TIMER_START_TIMES[${i}]:-0}"
            local duration
            duration=$(echo "${end_time} - ${start_time}" | bc)
            # shellcheck disable=SC2004
            # SC2004: False positive - i is array index not arithmetic variable
            DIAG_TIMER_DURATIONS[${i}]="${duration}"
            echo "${duration}"
            return 0
        fi
    done
    
    echo "0"
}

#######################################
# Get system diagnostics
# Returns:
#   Key=value pairs with system info
#######################################
get_system_diagnostics() {
    # OS Information
    echo "os=${OSTYPE}"
    echo "kernel=$(uname -r)"
    echo "arch=$(uname -m)"

    # CPU Information
    if [[ -f /proc/cpuinfo ]]; then
        echo "cpu_cores=$(grep -c "processor" /proc/cpuinfo)"
        echo "cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
    elif command -v sysctl > /dev/null 2>&1; then
        echo "cpu_cores=$(sysctl -n hw.ncpu 2> /dev/null || echo "unknown")"
        echo "cpu_model=$(sysctl -n machdep.cpu.brand_string 2> /dev/null || echo "unknown")"
    fi

    # Memory Information
    if [[ -f /proc/meminfo ]]; then
        echo "memory_total=$(awk '/MemTotal:/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)"
        echo "memory_available=$(awk '/MemAvailable:/ {printf "%.1f GB", $2/1024/1024}' /proc/meminfo)"
    elif command -v vm_stat > /dev/null 2>&1; then
        local page_size
        page_size=$(vm_stat | grep "page size" | grep -o '[0-9]*')
        local total_pages
        total_pages=$(vm_stat | grep "Pages free:" | awk '{print $3}' | tr -d '.')
        echo "memory_available=$(echo "scale=1; ${total_pages} * ${page_size} / 1073741824" | bc) GB"
    fi

    # Disk Information
    if command -v df > /dev/null 2>&1; then
        local disk_info
        disk_info=$(df -h "${MISE_PROJECT_ROOT}" | tail -1)
        echo "disk_total=$(echo "${disk_info}" | awk '{print $2}')"
        echo "disk_used=$(echo "${disk_info}" | awk '{print $3}')"
        echo "disk_available=$(echo "${disk_info}" | awk '{print $4}')"
        echo "disk_usage=$(echo "${disk_info}" | awk '{print $5}')"
    fi

    # Docker Information
    if command -v docker > /dev/null 2>&1 && docker system info > /dev/null 2>&1; then
        echo "docker_version=$(docker --version | awk '{print $3}' | tr -d ',')"
        echo "docker_containers=$(docker ps -a | tail -n +2 | wc -l)"
        echo "docker_images=$(docker images | tail -n +2 | wc -l)"

        # Docker disk usage
        local docker_df
        docker_df=$(docker system df --format json 2> /dev/null || echo '{}')
        if [[ -n "${docker_df}" ]] && command -v jq > /dev/null 2>&1; then
            echo "docker_disk_images=$(echo "${docker_df}" | jq -r '.Images[0].Size // "unknown"' 2> /dev/null)"
            echo "docker_disk_containers=$(echo "${docker_df}" | jq -r '.Containers[0].Size // "unknown"' 2> /dev/null)"
            echo "docker_disk_volumes=$(echo "${docker_df}" | jq -r '.Volumes[0].Size // "unknown"' 2> /dev/null)"
        fi
    fi

    # Network Information
    echo "hostname=$(hostname -f 2> /dev/null || hostname)"

    # Git Information
    if command -v git > /dev/null 2>&1; then
        echo "git_version=$(git --version | awk '{print $3}')"
        echo "git_user=$(git config --global user.name || echo "not configured")"
        echo "git_email=$(git config --global user.email || echo "not configured")"
    fi
}

#######################################
# Generate performance report
#######################################
generate_performance_report() {
    local report=""

    report+="Performance Metrics:\n"
    report+="===================\n"

    local i
    for i in "${!DIAG_TIMER_NAMES[@]}"; do
        local timer_name="${DIAG_TIMER_NAMES[${i}]}"
        local duration="${DIAG_TIMER_DURATIONS[${i}]}"
        if [[ -n "${duration}" ]]; then
            report+=$(printf "%-30s: %.2f seconds\n" "${timer_name}" "${duration}")
        fi
    done

    echo -e "${report}"
}

#######################################
# Check and suggest performance optimizations
#######################################
suggest_performance_optimizations() {
    local suggestions=()

    # Check Docker performance
    if command -v docker > /dev/null 2>&1 && docker system info > /dev/null 2>&1; then
        local container_count
        container_count=$(docker ps -a | tail -n +2 | wc -l)

        if [[ ${container_count} -gt ${DOCKER_HIGH_CONTAINER_COUNT} ]]; then
            suggestions+=("High container count (${container_count}). Consider: docker container prune")
        fi

        local image_count
        image_count=$(docker images | tail -n +2 | wc -l)

        if [[ ${image_count} -gt ${DOCKER_HIGH_IMAGE_COUNT} ]]; then
            suggestions+=("High image count (${image_count}). Consider: docker image prune -a")
        fi
    fi

    # Check disk space
    local disk_usage
    disk_usage=$(df -h "${MISE_PROJECT_ROOT}" | tail -1 | awk '{print $5}' | tr -d '%')

    if [[ ${disk_usage} -gt ${DISK_USAGE_WARNING_PERCENT} ]]; then
        suggestions+=("High disk usage (${disk_usage}%). Consider cleaning up build artifacts and caches")
    fi

    # Check for large git repos
    if [[ -d .git ]]; then
        local git_size
        git_size=$(du -sh .git 2> /dev/null | cut -f1)
        suggestions+=("Git repository size: ${git_size}. Consider: git gc --aggressive if over 1GB")
    fi

    # Return suggestions
    if [[ ${#suggestions[@]} -gt 0 ]]; then
        echo "Performance Optimization Suggestions:"
        echo "===================================="
        for suggestion in "${suggestions[@]}"; do
            echo "• ${suggestion}"
        done
        return 0
    else
        return 1
    fi
}

#######################################
# Generate actionable fix commands
#######################################
generate_fix_commands() {
    local failed_checks=("$@")
    local fix_commands=()

    for check in "${failed_checks[@]}"; do
        case "${check}" in
            *"Docker daemon"*)
                fix_commands+=("# Start Docker:")
                fix_commands+=("open -a Docker  # macOS")
                fix_commands+=("sudo systemctl start docker  # Linux")
                ;;
            *"GitHub CLI"*)
                fix_commands+=("# Authenticate GitHub CLI:")
                fix_commands+=("gh auth login")
                fix_commands+=("gh auth setup-git")
                ;;
            *"mise trust"*)
                fix_commands+=("# Trust mise configuration:")
                fix_commands+=("mise trust --yes")
                ;;
            *"mise tools"*)
                fix_commands+=("# Install missing tools:")
                fix_commands+=("mise install")
                ;;
            *"SSH agent"*)
                fix_commands+=("# Start SSH agent:")
                fix_commands+=("eval \$(ssh-agent)")
                fix_commands+=("ssh-add")
                ;;
            *"Git user config"*)
                fix_commands+=("# Configure Git:")
                # Check if we're in Codespaces and have GITHUB_USER
                if [[ -n "${CODESPACES:-}" ]] && [[ -n "${GITHUB_USER:-}" ]]; then
                    fix_commands+=("# Auto-configure from Codespaces environment:")
                    fix_commands+=("git config --global user.name \"${GITHUB_USER}\"")
                    fix_commands+=("git config --global user.email \"${GITHUB_USER}@users.noreply.github.com\"")
                elif command -v gh > /dev/null 2>&1 && gh auth status > /dev/null 2>&1; then
                    fix_commands+=("# Auto-configure from GitHub:")
                    fix_commands+=("gh api user --jq '.login as \$u | .name as \$n | \"git config --global user.name \\\"\(\$n // \$u)\\\"\"' | sh")
                    fix_commands+=("gh api user --jq '.login as \$u | \"git config --global user.email \\\"\(\$u)@users.noreply.github.com\\\"\"' | sh")
                else
                    fix_commands+=("git config --global user.name 'Your Name'")
                    fix_commands+=("git config --global user.email 'your@email.com'")
                fi
                ;;
            *"Git credential helper"*)
                fix_commands+=("# Configure Git credential helper with GitHub CLI:")
                fix_commands+=("gh auth setup-git")
                ;;
            *"disk space"*)
                fix_commands+=("# Free up disk space:")
                fix_commands+=("docker system prune -a  # Warning: removes all unused images")
                fix_commands+=("mise cache clear")
                ;;
            *)
                fix_commands+=("# Uncaught check failure: ${check}")
                fix_commands+=("# Debug with increased verbosity:")
                fix_commands+=("export MISE_VERBOSE=1  # Enable verbose mise output")
                fix_commands+=("export MISE_DEBUG=1    # Enable debug-level logging")
                fix_commands+=("mise run doctor:workspace --verbose  # Run with detailed output")
                fix_commands+=("# Check the health check implementation:")
                fix_commands+=("grep -n \"${check}\" ${MISE_PROJECT_ROOT}/.config/mise/lib/health-checks.sh")
                ;;
        esac
    done

    if [[ ${#fix_commands[@]} -gt 0 ]]; then
        # In devcontainer or quick mode, show simplified output
        if [[ "${CONFIG_QUICK:-false}" == "true" ]] || [[ -n "${REMOTE_CONTAINERS:-}" ]] || [[ -n "${DEVCONTAINER:-}" ]]; then
            # Source formatting to ensure colors are available
            # shellcheck disable=SC1091
            source "${MISE_PROJECT_ROOT}/.config/mise/lib/formatting.sh"
            
            echo ""
            echo -e "${YELLOW}💡 Required Setup Commands${NC}"
            echo -e "${GRAY}─────────────────────────${NC}"
            echo ""
            
            # Group and deduplicate commands
            local git_config_shown=false
            local gh_auth_shown=false
            local current_section=""
            local last_was_header=false
            
            for cmd in "${fix_commands[@]}"; do
                # Skip debug-related commands and duplicates in quick mode
                if [[ "${cmd}" =~ "Debug with increased verbosity" ]] || 
                   [[ "${cmd}" =~ "export MISE_" ]] || 
                   [[ "${cmd}" =~ "grep -n" ]] ||
                   [[ "${cmd}" =~ "Uncaught check failure" ]] ||
                   [[ "${cmd}" =~ "verbose" ]] ||
                   [[ "${cmd}" =~ "Check the health check implementation" ]]; then
                    continue
                fi
                
                # Skip Git credential helper header if gh auth setup-git already shown
                if [[ "${cmd}" =~ "Configure Git credential helper" ]] && [[ "${gh_auth_shown}" == "true" ]]; then
                    continue
                fi
                
                # Deduplicate gh auth commands
                if [[ "${cmd}" == "gh auth setup-git" ]] && [[ "${gh_auth_shown}" == "true" ]]; then
                    continue
                elif [[ "${cmd}" == "gh auth setup-git" ]]; then
                    gh_auth_shown=true
                fi
                
                # Add spacing between sections
                if [[ "${cmd}" =~ ^#.*$ ]]; then
                    if [[ -n "${current_section}" ]] && [[ "${last_was_header}" == "false" ]]; then
                        echo ""  # Add space between sections
                    fi
                    current_section="${cmd}"
                    echo -e "${GRAY}${cmd}${NC}"
                    last_was_header=true
                else
                    echo -e "  ${RED}${cmd}${NC}"
                    last_was_header=false
                fi
            done
            echo ""
        else
            # Full output for verbose mode
            echo "Suggested Fix Commands:"
            echo "======================"
            for cmd in "${fix_commands[@]}"; do
                echo "${cmd}"
            done
        fi
    fi
}

#######################################
# Network diagnostics
#######################################
test_network_endpoints() {
    local endpoints=(
        "github.com:443:GitHub API"
        "ghcr.io:443:GitHub Container Registry"
        "registry.npmjs.org:443:NPM Registry"
        "pypi.org:443:Python Package Index"
        "registry-1.docker.io:443:Docker Hub"
    )

    echo "Network Connectivity Tests:"
    echo "=========================="

    for endpoint in "${endpoints[@]}"; do
        IFS=: read -r host port name <<< "${endpoint}"
        printf "%-40s: " "${name}"

        if timeout "${NETWORK_TIMEOUT_SECONDS}" bash -c "echo >/dev/tcp/${host}/${port}" 2> /dev/null; then
            print_status success "OK"
        else
            print_status error "FAILED"
        fi
    done
}

#######################################
# Generate comprehensive diagnostic bundle
#######################################
create_diagnostic_bundle() {
    local bundle_dir
    bundle_dir="${MISE_PROJECT_ROOT}/.diagnostic-bundle-$(date +%Y%m%d-%H%M%S)"

    echo "Creating diagnostic bundle in: ${bundle_dir}"
    mkdir -p "${bundle_dir}"

    # System diagnostics
    get_system_diagnostics > "${bundle_dir}/system-diagnostics.txt"

    # Environment variables (sanitized)
    env | grep -E '^(MISE_|WORKSPACE_|ORGANIZATION|GITHUB_|DOCKER_|CI)' |
        sed 's/\(TOKEN\|KEY\|SECRET\|PASSWORD\)=[^ ]*/\1=***REDACTED***/g' > "${bundle_dir}/environment.txt"

    # Tool versions
    {
        echo "Tool Versions:"
        echo "=============="
        command -v docker > /dev/null && echo "Docker: $(docker --version)"
        command -v git > /dev/null && echo "Git: $(git --version)"
        command -v gh > /dev/null && echo "GitHub CLI: $(gh --version)"
        command -v mise > /dev/null && echo "Mise: $(mise --version)"
        command -v node > /dev/null && echo "Node: $(node --version)"
        command -v npm > /dev/null && echo "NPM: $(npm --version)"
    } > "${bundle_dir}/tool-versions.txt"

    # Docker diagnostics (if available)
    if command -v docker > /dev/null 2>&1 && docker system info > /dev/null 2>&1; then
        docker system info > "${bundle_dir}/docker-info.txt" 2>&1
        docker system df > "${bundle_dir}/docker-disk.txt" 2>&1
        docker ps -a > "${bundle_dir}/docker-containers.txt" 2>&1
    fi

    # Network diagnostics
    test_network_endpoints > "${bundle_dir}/network-tests.txt" 2>&1

    # Create summary
    {
        echo "Diagnostic Bundle Summary"
        echo "========================"
        echo "Created: $(date)"
        echo "Location: ${bundle_dir}"
        echo ""
        echo "Contents:"
        ls -la "${bundle_dir}/"
    } > "${bundle_dir}/README.txt"

    echo "Diagnostic bundle created: ${bundle_dir}"
    echo "Share this bundle when reporting issues (sensitive data is redacted)"
}