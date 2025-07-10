#!/usr/bin/env bash
# Shared execution functions for mise tasks

# Guard against multiple sourcing
if [[ -n "${_MISE_EXECUTION_SOURCED:-}" ]]; then
    return 0
fi
readonly _MISE_EXECUTION_SOURCED=1

# Source required libraries
# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise, path cannot be resolved statically
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise, path cannot be resolved statically
source "${MISE_PROJECT_ROOT}/.config/mise/lib/workspace.sh"

# Global state variables (bash 3.2 compatible)
MISE_EXEC_STATE_TOTAL_REPOS=0
MISE_EXEC_STATE_SUCCESS_COUNT=0
MISE_EXEC_FAILED_REPOS=()

#######################################
# Execute function across all repositories
# Arguments:
#   $1 - execute_func: Function name to call for each repo
#   $2 - include_workspace: Include workspace root (true|false)
#   $3 - quiet: Suppress output (true|false)
#   $@ - Additional arguments to pass to execute_func
# Returns:
#   0 if all succeed, 1 if any fail
#
# The execute_func will be called with:
#   - repo_name
#   - repo_path
#   - any additional arguments
#######################################
execute_across_repos() {
    local execute_func="$1"
    local include_workspace="$2"
    local quiet="$3"
    shift 3
    local args=("$@")

    # Track status
    local total_repos=0
    local success_count=0
    local -a failed_repos=()

    # First, run in the workspace root if requested
    if [[ "${include_workspace}" == "true" ]] && [[ -d "${MISE_PROJECT_ROOT}" ]]; then
        total_repos=$((total_repos + 1))

        local exec_result
        if [[ ${#args[@]} -gt 0 ]]; then
            "${execute_func}" "workspace" "." "${args[@]}"
            exec_result=$?
        else
            "${execute_func}" "workspace" "."
            exec_result=$?
        fi
        if [[ ${exec_result} -eq 0 ]]; then
            success_count=$((success_count + 1))
        else
            failed_repos+=("workspace")
        fi
    fi

    # Execute for each repository from workspace.json
    while IFS=: read -r name path; do
        total_repos=$((total_repos + 1))

        local exec_result
        if [[ ${#args[@]} -gt 0 ]]; then
            "${execute_func}" "${name}" "${path}" "${args[@]}"
            exec_result=$?
        else
            "${execute_func}" "${name}" "${path}"
            exec_result=$?
        fi
        if [[ ${exec_result} -eq 0 ]]; then
            success_count=$((success_count + 1))
        else
            failed_repos+=("${name}")
        fi
    done < <(list_repositories)

    # Return results via global variables (bash doesn't have good return mechanisms)
    # These variables are used by scripts that source this library (git and exec tasks)
    # shellcheck disable=SC2034
    # SC2034: MISE_EXEC_STATE_TOTAL_REPOS is used by git and exec tasks that source this library
    MISE_EXEC_STATE_TOTAL_REPOS=${total_repos}
    # shellcheck disable=SC2034
    # SC2034: MISE_EXEC_STATE_SUCCESS_COUNT is used by git and exec tasks that source this library
    MISE_EXEC_STATE_SUCCESS_COUNT=${success_count}
    # shellcheck disable=SC2034
    # SC2034: MISE_EXEC_FAILED_REPOS is used by git and exec tasks that source this library
    if [[ ${#failed_repos[@]} -gt 0 ]]; then
        MISE_EXEC_FAILED_REPOS=("${failed_repos[@]}")
    else
        MISE_EXEC_FAILED_REPOS=()
    fi

    # Return exit code
    [[ ${#failed_repos[@]} -eq 0 ]] && return 0 || return 1
}

#######################################
# Validate repository exists
# Arguments:
#   $1 - repo_name: Repository name
#   $2 - repo_path: Repository path
#   $3 - quiet: Suppress warnings (true|false)
# Returns:
#   0 if valid, 1 if not
#######################################
validate_repo_exists() {
    local repo_name="$1"
    local repo_path="$2"
    local quiet="${3:-false}"

    if [[ ! -d "${repo_path}" ]]; then
        if [[ "${quiet}" != "true" ]]; then
            echo ""
            print_status warning "[${repo_name}] Directory not found: ${repo_path}"
        fi
        return 1
    fi

    return 0
}

#######################################
# Validate repository is a git repo
# Arguments:
#   $1 - repo_name: Repository name
#   $2 - repo_path: Repository path
#   $3 - quiet: Suppress warnings (true|false)
# Returns:
#   0 if valid git repo, 1 if not
#######################################
validate_git_repo() {
    local repo_name="$1"
    local repo_path="$2"
    local quiet="${3:-false}"

    # First check if directory exists
    validate_repo_exists "${repo_name}" "${repo_path}" "${quiet}" || return 1

    if [[ ! -d "${repo_path}/.git" ]]; then
        if [[ "${quiet}" != "true" ]]; then
            echo ""
            print_status warning "[${repo_name}] Not a git repository"
        fi
        return 1
    fi

    return 0
}

#######################################
# Show available repositories
# Arguments:
#   None
# Outputs:
#   Formatted list of repositories
#######################################
show_available_repos() {
    echo "Available repositories:"
    while IFS=: read -r name path; do
        printf "  %-20s %s\n" "${name}" "${path}"
    done < <(list_repositories)
}

#######################################
# Create usage header
# Arguments:
#   $1 - command: Command name (e.g., "git", "exec")
#   $2 - description: Command description
# Outputs:
#   Formatted usage header
#######################################
format_usage_header() {
    local command="$1"
    local description="$2"

    cat << EOF
Usage: mise run ${command} <command> [args...]

${description}

EOF
}