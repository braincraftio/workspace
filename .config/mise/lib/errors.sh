#!/usr/bin/env bash
# errors.sh - Standardized error handling for mise tasks
# Provides consistent error codes, handling functions, and context tracking

# Guard against multiple sourcing
if [[ -n "${_MISE_ERRORS_SOURCED:-}" ]]; then
    return 0
fi
readonly _MISE_ERRORS_SOURCED=1

# Error codes - using standard Unix conventions
readonly MISE_ERROR_SUCCESS=0
readonly MISE_ERROR_GENERAL=1
readonly MISE_ERROR_MISUSE=2  # Command line usage error
readonly MISE_ERROR_EXEC_ERROR=126  # Command invoked cannot execute
readonly MISE_ERROR_NOT_FOUND=127  # Command not found
# Custom application error codes (64-113 are available for custom use)
readonly MISE_ERROR_CONFIG_ERROR=64  # Configuration file error
readonly MISE_ERROR_VALIDATION_ERROR=65  # Input validation failed
readonly MISE_ERROR_DEPENDENCY_ERROR=66  # Missing dependency
readonly MISE_ERROR_PERMISSION_ERROR=67  # Permission denied
readonly MISE_ERROR_NETWORK_ERROR=68  # Network operation failed
readonly MISE_ERROR_TIMEOUT_ERROR=69  # Operation timed out
readonly MISE_ERROR_STATE_ERROR=70  # Invalid state

# Error context tracking - using regular variables
MISE_ERROR_CONTEXT_TASK="${MISE_TASK_NAME:-unknown}"
MISE_ERROR_CONTEXT_FILE=""
MISE_ERROR_CONTEXT_FUNCTION=""
MISE_ERROR_CONTEXT_LINE=""
MISE_ERROR_CONTEXT_COMMAND=""
MISE_ERROR_CONTEXT_MESSAGE=""

# Enhanced handle_error that works with existing print_status
handle_error_with_context() {
    local exit_code="${1:-$?}"
    local context="${2:-Command execution}"
    local file="${3:-${BASH_SOURCE[1]}}"
    local function="${4:-${FUNCNAME[1]}}"
    local line="${5:-${LINENO}}"

    # Store context for detailed reporting
    MISE_ERROR_CONTEXT_FILE="${file}"
    MISE_ERROR_CONTEXT_FUNCTION="${function}"
    MISE_ERROR_CONTEXT_LINE="${line}"
    MISE_ERROR_CONTEXT_MESSAGE="${context}"

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
    MISE_ERROR_CONTEXT_TASK="${MISE_TASK_NAME:-${0##*/}}"

    print_status error "${message}"

    # Show context in debug mode
    if [[ "${MISE_DEBUG:-}" == "1" ]] && [[ -n "${MISE_ERROR_CONTEXT_FILE}" ]]; then
        echo "  Task: ${MISE_ERROR_CONTEXT_TASK}" >&2
        echo "  Location: ${MISE_ERROR_CONTEXT_FILE}:${MISE_ERROR_CONTEXT_FUNCTION}:${MISE_ERROR_CONTEXT_LINE}" >&2
  fi

    exit "${exit_code}"
}

# Exit with specific error type
die_with_code() {
    local error_type="$1"
    local message="${2:-Error occurred}"

    # Map error type to exit code
    local exit_code=1
    case "${error_type}" in
        SUCCESS) exit_code=$MISE_ERROR_SUCCESS ;;
        GENERAL) exit_code=$MISE_ERROR_GENERAL ;;
        MISUSE) exit_code=$MISE_ERROR_MISUSE ;;
        EXEC_ERROR) exit_code=$MISE_ERROR_EXEC_ERROR ;;
        NOT_FOUND) exit_code=$MISE_ERROR_NOT_FOUND ;;
        CONFIG_ERROR) exit_code=$MISE_ERROR_CONFIG_ERROR ;;
        VALIDATION_ERROR) exit_code=$MISE_ERROR_VALIDATION_ERROR ;;
        DEPENDENCY_ERROR) exit_code=$MISE_ERROR_DEPENDENCY_ERROR ;;
        PERMISSION_ERROR) exit_code=$MISE_ERROR_PERMISSION_ERROR ;;
        NETWORK_ERROR) exit_code=$MISE_ERROR_NETWORK_ERROR ;;
        TIMEOUT_ERROR) exit_code=$MISE_ERROR_TIMEOUT_ERROR ;;
        STATE_ERROR) exit_code=$MISE_ERROR_STATE_ERROR ;;
        *) exit_code=1 ;;
    esac
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

    # Use eval to set the variable (bash 3.2 compatible)
    # This is safe because var_name comes from our code, not user input
    eval "${var_name}=\${output}"
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
