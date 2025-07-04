#!/usr/bin/env bash
# Common functions for mise tasks

# Guard against multiple sourcing
if [[ -n "${_MISE_COMMON_SOURCED:-}" ]]; then
    return 0
fi
readonly _MISE_COMMON_SOURCED=1

# Source error handling first if available
if [[ -f "${MISE_PROJECT_ROOT}/.config/mise/lib/errors.sh" ]]; then
    # shellcheck disable=SC1091
    source "${MISE_PROJECT_ROOT}/.config/mise/lib/errors.sh"
fi

# Determine if color output should be used
# Respects NO_COLOR env var (https://no-color.org/), CI environments, and terminal capabilities
should_use_color() {
    # Check for --no-color flag in arguments
    local arg
    for arg in "$@"; do
        [[ "${arg}" == "--no-color" ]] && return 1
    done
    
    # Respect NO_COLOR environment variable
    [[ -n "${NO_COLOR:-}" ]] && return 1
    
    # Disable colors in CI environments
    [[ "${CI:-}" == "true" ]] && return 1
    
    # Disable colors if not running in a terminal
    [[ ! -t 1 ]] && return 1
    
    # Disable colors for dumb terminals
    [[ "${TERM:-}" == "dumb" ]] && return 1
    
    # Colors are supported
    return 0
}

# Initialize color variables based on environment
# Check script arguments passed to the sourcing script
if should_use_color "$@"; then
    # Color codes for terminal output
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly RED='\033[0;31m'
    # shellcheck disable=SC2034
    readonly BLUE='\033[1;34m'
    # shellcheck disable=SC2034
    readonly CYAN='\033[0;36m'
    # shellcheck disable=SC2034
    readonly GRAY='\033[0;90m'
    readonly NC='\033[0m'
else
    # No colors - all variables are empty
    readonly GREEN=''
    readonly YELLOW=''
    readonly RED=''
    # shellcheck disable=SC2034
    readonly BLUE=''
    # shellcheck disable=SC2034
    readonly CYAN=''
    # shellcheck disable=SC2034
    readonly GRAY=''
    readonly NC=''
fi

# Status indicators - will use colors if available, plain text otherwise
readonly CHECK="${GREEN}✓${NC}"
readonly WARN="${YELLOW}⚠${NC}"
readonly CROSS="${RED}✗${NC}"

# Print status message
print_status() {
    local status="$1"
    local message="$2"

    case "${status}" in
        success) echo -e "${CHECK} ${message}" ;;
        warning) echo -e "${WARN} ${message}" >&2 ;;
        error) echo -e "${CROSS} ${message}" >&2 ;;
        info) echo "ℹ️  ${message}" ;;
        *) echo "${message}" ;;
    esac
}

# Validate workspace configuration exists
validate_workspace_config() {
    # Resolve WORKSPACE_CONFIG_PATH relative to MISE_PROJECT_ROOT if it's relative
    local config_path="${WORKSPACE_CONFIG_PATH}"
    if [[ ! "${config_path}" = /* ]]; then
        config_path="${MISE_PROJECT_ROOT}/${config_path}"
    fi
    
    if [[ ! -f "${config_path}" ]]; then
        print_status error "workspace.json not found at ${config_path}"
        return 1
    fi

    if ! jq empty "${config_path}" 2>/dev/null; then
        print_status error "Invalid JSON in workspace.json"
        return 1
    fi

    # Update the global variable to use the resolved path
    WORKSPACE_CONFIG_PATH="${config_path}"
    return 0
}

# Safe error handling - enhanced version if errors.sh is loaded
if declare -F handle_error_with_context >/dev/null 2>&1; then
    handle_error() {
        local exit_code="$1"
        local context="$2"
        
        if [[ ${exit_code} -ne 0 ]]; then
            # Use enhanced version with context tracking
            handle_error_with_context "${exit_code}" "Failed: ${context}"
            return "${exit_code}"
        fi
        
        return 0
    }
else
    # Original simple version
    handle_error() {
        local exit_code="$1"
        local context="$2"

        if [[ ${exit_code} -ne 0 ]]; then
            print_status error "Failed: ${context}"
            return "${exit_code}"
        fi

        return 0
    }
fi
