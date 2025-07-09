#!/usr/bin/env bash
# errors.sh - Standardized error handling for mise tasks
# Provides consistent error codes, handling functions, and context tracking

# Guard against multiple sourcing
if [[ -n "${_MISE_ERRORS_SOURCED:-}" ]]; then
    return 0
fi
readonly _MISE_ERRORS_SOURCED=1

# Error codes - using standard Unix conventions
declare -grA MISE_ERROR_CODES=(
                                                                                                          [SUCCESS]=0
                                                                                                          [GENERAL]=1
                                                                                                          [MISUSE]=2 # Command line usage error
                                                                                                          [EXEC_ERROR]=126 # Command invoked cannot execute
                                                                                                          [NOT_FOUND]=127 # Command not found
    # Custom application error codes (64-113 are available for custom use)
                                                                                                          [CONFIG_ERROR]=64 # Configuration file error
                                                                                                          [VALIDATION_ERROR]=65 # Input validation failed
                                                                                                          [DEPENDENCY_ERROR]=66 # Missing dependency
                                                                                                          [PERMISSION_ERROR]=67 # Permission denied
                                                                                                          [NETWORK_ERROR]=68 # Network operation failed
                                                                                                          [TIMEOUT_ERROR]=69 # Operation timed out
                                                                                                          [STATE_ERROR]=70 # Invalid state
)

# Error context tracking - using associative array like CONFIG pattern
declare -gA MISE_ERROR_CONTEXT=(
                                                                                                          [task]="${MISE_TASK_NAME:-unknown}"
                                                                                                          [file]=""
                                                                                                          [function]=""
                                                                                                          [line]=""
                                                                                                          [command]=""
                                                                                                          [message]=""
)

# Enhanced handle_error that works with existing print_status
handle_error_with_context() {
    local exit_code="${1:-$?}"
    local context="${2:-Command execution}"
    local file="${3:-${BASH_SOURCE[1]}}"
    local function="${4:-${FUNCNAME[1]}}"
    local line="${5:-${LINENO}}"

    # Store context for detailed reporting
    MISE_ERROR_CONTEXT[file]="${file}"
    MISE_ERROR_CONTEXT[function]="${function}"
    MISE_ERROR_CONTEXT[line]="${line}"
    MISE_ERROR_CONTEXT[message]="${context}"

    # Use existing print_status for consistency
    if [[ "${MISE_DEBUG:-}" == "1" ]]; then
        print_status error "${context} (${file}:${function}:${line})"
  else
        print_status error "${context}"
  fi

    return "${exit_code}"
}

# Wrap the existing handle_error to add context tracking
if declare -F handle_error > /dev/null 2>&1; then
    # Rename existing function
    eval "$(declare -f handle_error | sed '1s/handle_error/handle_error_original/')"

    # Create wrapper
    handle_error() {
        local exit_code="$1"
        local context="$2"
        handle_error_with_context "${exit_code}" "${context}"
        return "${exit_code}"
  }
fi

# Exit with error using mise conventions
die() {
    local message="${1:-Fatal error}"
    local exit_code="${2:-1}"

    # Set task name context if available
    MISE_ERROR_CONTEXT[task]="${MISE_TASK_NAME:-${0##*/}}"

    print_status error "${message}"

    # Show context in debug mode
    if [[ "${MISE_DEBUG:-}" == "1" ]] && [[ -n "${MISE_ERROR_CONTEXT[file]}" ]]; then
        echo "  Task: ${MISE_ERROR_CONTEXT[task]}" >&2
        echo "  Location: ${MISE_ERROR_CONTEXT[file]}:${MISE_ERROR_CONTEXT[function]}:${MISE_ERROR_CONTEXT[line]}" >&2
  fi

    exit "${exit_code}"
}

# Exit with specific error type
die_with_code() {
    local error_type="$1"
    local message="${2:-Error occurred}"

    local exit_code="${MISE_ERROR_CODES[${error_type}]:-1}"
    die "${message}" "${exit_code}"
}

# Assert command succeeded (mise-friendly version)
assert_success() {
    local exit_code=$?
    local message="${1:-Command failed}"

    if [[ ${exit_code} -ne 0 ]]; then
        handle_error ${exit_code} "${message}"
        return "${exit_code}"
  fi

    return 0
}

# Run command with automatic error context
run_or_die() {
    local error_message="${1:-Command failed}"
    shift

    if [[ "${MISE_DEBUG:-}" == "1" ]]; then
        echo "  Running: $*" >&2
  fi

    if ! "$@"; then
        local exit_code=$?
        die "${error_message}" ${exit_code}
  fi
}

# Run command and capture output with error handling
capture_or_die() {
    local var_name="$1"
    local error_message="${2:-Command failed}"
    shift 2

    local output
    if ! output=$("$@" 2>&1); then
        local exit_code=$?
        print_status error "${error_message}"
        [[ -n "${output}" ]] && echo "${output}" >&2
        exit "${exit_code}"
  fi

    # Use nameref to set the variable
    declare -n var_ref="${var_name}"
    # shellcheck disable=SC2034 # var_ref is a nameref that sets ${var_name}
    var_ref="${output}"
}

# Validate required tools/commands
require_command() {
    local cmd="$1"
    local message="${2:-Required command \"${cmd}\" not found}"

    if ! command -v "${cmd}" > /dev/null 2>&1; then
        die_with_code DEPENDENCY_ERROR "${message}"
  fi
}

# Validate required environment variables
require_env() {
    local var_name="$1"
    local message="${2:-Required environment variable \"${var_name}\" not set}"

    if [[ -z "${!var_name:-}" ]]; then
        die_with_code CONFIG_ERROR "${message}"
  fi
}

# Set consistent error handling options for tasks
init_task_error_handling() {
    # Use mise-standard error handling
    set -uo pipefail

    # Set error trap for better debugging
    if [[ "${MISE_DEBUG:-}" == "1" ]]; then
        set -E  # Inherit ERR trap
        trap 'handle_error_with_context $? "$BASH_COMMAND" "${BASH_SOURCE[0]}" "${FUNCNAME[0]}" "$LINENO"' ERR
  fi
}

# Export functions
export -f handle_error_with_context
export -f die
export -f die_with_code
export -f assert_success
export -f run_or_die
export -f capture_or_die
export -f require_command
export -f require_env
export -f init_task_error_handling
