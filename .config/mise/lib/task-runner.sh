#!/usr/bin/env bash
# shellcheck shell=bash
#
# task-runner.sh - Common task execution framework for mise tasks
#
# Purpose:
#   Provides a reusable framework for tasks that execute commands across
#   all workspace repositories. Eliminates duplication between exec, git,
#   and similar tasks.
#
# Usage:
#   source "${MISE_PROJECT_ROOT}/.config/mise/lib/task-runner.sh"
#   run_task_across_repos "task_name" execute_function "$@"
#

# Guard against multiple sourcing
[[ -n "${_TASK_RUNNER_SOURCED:-}" ]] && return 0
declare -r _TASK_RUNNER_SOURCED=1

# Source required libraries
# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/workspace.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/formatting.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/execution.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise
source "${MISE_PROJECT_ROOT}/.config/mise/lib/command-validation.sh"

# Global configuration variables (bash 3.2 compatible)
CONFIG_QUIET=""
CONFIG_FORMAT=""
CONFIG_PARALLEL=""

# Global state variables
MISE_EXEC_STATE_TOTAL_REPOS=0
MISE_EXEC_STATE_SUCCESS_COUNT=0
MISE_EXEC_FAILED_REPOS=()

#######################################
# Convert string to uppercase (bash 3.2 compatible)
# Arguments:
#   $1 - string to convert
# Outputs:
#   Uppercase string
#######################################
to_uppercase() {
    echo "$1" | tr '[:lower:]' '[:upper:]'
}

#######################################
# Setup common task configuration
# Arguments:
#   $1 - task_name: Name of the task (e.g., "exec", "git")
# Returns:
#   Sets up CONFIG_* variables
#######################################
setup_task_config() {
    local task_name="$1"
    local task_upper
    task_upper=$(to_uppercase "${task_name}")

    # Build variable names
    local quiet_var="${task_upper}_TASK_QUIET"
    local format_var="${task_upper}_TASK_FORMAT"
    local parallel_var="${task_upper}_TASK_PARALLEL"

    # Set quiet configuration
    if [[ -n "${!quiet_var+x}" ]]; then
        CONFIG_QUIET="${!quiet_var}"
    else
        CONFIG_QUIET="${MISE_TASK_QUIET_DEFAULT:-false}"
    fi

    # Set format configuration
    if [[ -n "${!format_var+x}" ]]; then
        CONFIG_FORMAT="${!format_var}"
    else
        CONFIG_FORMAT="${MISE_TASK_FORMAT_DEFAULT:-pretty}"
    fi

    # Add parallel support if applicable
    if [[ -n "${!parallel_var+x}" ]]; then
        CONFIG_PARALLEL="${!parallel_var}"
    elif [[ -n "${MISE_TASK_PARALLEL_DEFAULT+x}" ]]; then
        CONFIG_PARALLEL="${MISE_TASK_PARALLEL_DEFAULT}"
    else
        CONFIG_PARALLEL="false"
    fi
}

#######################################
# Show generic usage header
# Arguments:
#   $1 - task_name: Name of the task
#   $2 - description: Task description
#   $3 - examples: Examples text
#   $4 - env_vars: Environment variables text
# Outputs:
#   Formatted usage information
#######################################
show_task_usage() {
    local task_name="$1"
    local description="$2"
    local examples="$3"
    local env_vars="$4"

    format_usage_header "${task_name}" "${description}"

    if [[ -n "${examples}" ]]; then
        echo "Examples:"
        echo "${examples}"
        echo
    fi

    if [[ -n "${env_vars}" ]]; then
        echo "Environment Variables:"
        echo "${env_vars}"
        echo
    fi

    show_available_repos
}

#######################################
# Execute command in parallel across repos
# Arguments:
#   $1 - execute_func: Function to execute in each repo
#   $2 - include_workspace: Include workspace root (true|false)
#   $@ - Additional arguments for execute_func
# Returns:
#   0 if all succeed, 1 if any fail
#######################################
execute_task_parallel() {
    local execute_func="$1"
    local include_workspace="$2"
    shift 2
    local args=("$@")

    local temp_dir
    temp_dir=$(mktemp -d)
    local exit_code=0

    # Execute in workspace root if requested
    if [[ "${include_workspace}" == "true" ]] && [[ -d "${MISE_PROJECT_ROOT}" ]]; then
        {
            local exec_result
            if [[ ${#args[@]} -gt 0 ]]; then
                "${execute_func}" "workspace" "." "${args[@]}"
                exec_result=$?
            else
                "${execute_func}" "workspace" "."
                exec_result=$?
            fi
            if [[ ${exec_result} -eq 0 ]]; then
                echo "success" > "${temp_dir}/workspace.status"
            else
                echo "failed" > "${temp_dir}/workspace.status"
            fi
        } &
    fi

    # Execute in all child repositories
    while IFS=: read -r name path; do
        {
            local exec_result
            if [[ ${#args[@]} -gt 0 ]]; then
                "${execute_func}" "${name}" "${path}" "${args[@]}"
                exec_result=$?
            else
                "${execute_func}" "${name}" "${path}"
                exec_result=$?
            fi
            if [[ ${exec_result} -eq 0 ]]; then
                echo "success" > "${temp_dir}/${name}.status"
            else
                echo "failed" > "${temp_dir}/${name}.status"
            fi
        } &
    done < <(list_repositories)

    # Wait for all background jobs
    wait

    # Check results
    local total=0
    local failed=0
    local -a failed_repos=()

    for status_file in "${temp_dir}"/*.status; do
        if [[ -f "${status_file}" ]]; then
            total=$((total + 1))
            local repo_name
            repo_name=$(basename "${status_file}" .status)
            if grep -q "failed" "${status_file}"; then
                failed=$((failed + 1))
                failed_repos+=("${repo_name}")
            fi
        fi
    done

    # Cleanup
    rm -rf "${temp_dir}"

    # Update global state for summary
    MISE_EXEC_STATE_TOTAL_REPOS=${total}
    MISE_EXEC_STATE_SUCCESS_COUNT=$((total - failed))
    if [[ ${#failed_repos[@]} -gt 0 ]]; then
        MISE_EXEC_FAILED_REPOS=("${failed_repos[@]}")
    else
        MISE_EXEC_FAILED_REPOS=()
    fi

    if [[ "${CONFIG_QUIET}" != "true" ]]; then
        echo ""
        echo "================================================================================"
        echo "📊 Parallel Execution Summary"
        echo "----------------------------"
        printf "Total repositories: %d\n" "${total}"
        printf "Successful: %d\n" "$((total - failed))"
        if [[ ${failed} -gt 0 ]]; then
            local failed_repos_str=""
            if [[ ${#failed_repos[@]} -gt 0 ]]; then
                failed_repos_str="${failed_repos[*]}"
            fi
            printf "Failed: %d (%s)\n" "${failed}" "${failed_repos_str}"
        fi
    fi

    [[ ${failed} -eq 0 ]] || exit_code=1
    return ${exit_code}
}

#######################################
# Main task runner framework
# Arguments:
#   $1 - task_name: Name of the task (e.g., "exec", "git")
#   $2 - execute_func: Function to execute in each repo
#   $3 - validate_func: Function to validate command (optional)
#   $4 - include_workspace: Include workspace root (true|false|auto)
#   $@ - Command and arguments
# Returns:
#   Exit code based on success/failure
#######################################
run_task_across_repos() {
    local task_name="$1"
    local execute_func="$2"
    local validate_func="$3"
    local include_workspace="$4"
    shift 4
    local cmd_args=("$@")

    # Set task name for error context
    export MISE_TASK_NAME="${task_name}"

    # Setup configuration
    setup_task_config "${task_name}"

    # Validate command if validation function provided
    if [[ -n "${validate_func}" ]] && declare -F "${validate_func}" > /dev/null 2>&1; then
        if ! "${validate_func}" "${cmd_args[*]}"; then
            return 1
        fi
    fi

    # Auto-detect workspace inclusion for git tasks
    if [[ "${include_workspace}" == "auto" ]]; then
        if [[ "${task_name}" == "git" ]] && [[ -d ".git" ]]; then
            include_workspace="true"
        else
            include_workspace="false"
        fi
    fi

    # Show operation header
    if [[ "${CONFIG_QUIET}" != "true" ]]; then
        local cmd_display="${cmd_args[*]}"
        if [[ "${task_name}" == "git" ]]; then
            format_operation_header "Running 'git ${cmd_display}' across all repositories..."
        else
            format_operation_header "Running '${cmd_display}' across all repositories..."
        fi
    fi

    # Check if parallel execution is requested
    if [[ "${CONFIG_PARALLEL:-false}" == "true" ]]; then
        if [[ "${CONFIG_QUIET}" != "true" ]]; then
            echo "🚀 Parallel execution enabled"
        fi
        if [[ ${#cmd_args[@]} -gt 0 ]]; then
            execute_task_parallel "${execute_func}" "${include_workspace}" "${cmd_args[@]}"
        else
            execute_task_parallel "${execute_func}" "${include_workspace}"
        fi
        local exit_code=$?
    else
        # Store the original execute function in a different variable to avoid naming conflict
        local original_execute_func="${execute_func}"

        # Create a wrapper function that passes the command
        execute_wrapper() {
            # shellcheck disable=SC2317
            # SC2317: This function is passed as a callback to execute_across_repos
            if [[ ${#cmd_args[@]} -gt 0 ]]; then
                "${original_execute_func}" "$1" "$2" "${cmd_args[@]}"
            else
                "${original_execute_func}" "$1" "$2"
            fi
        }

        # Execute sequentially - don't pass cmd_args here, they're already in the closure
        execute_across_repos execute_wrapper "${include_workspace}" "${CONFIG_QUIET}"
        local exit_code=$?
    fi

    # Show summary
    if [[ "${CONFIG_QUIET}" != "true" ]]; then
        local failed_repos_str=""
        if [[ ${#MISE_EXEC_FAILED_REPOS[@]} -gt 0 ]]; then
            failed_repos_str="${MISE_EXEC_FAILED_REPOS[*]}"
        fi
        format_summary "${MISE_EXEC_STATE_TOTAL_REPOS}" "${MISE_EXEC_STATE_SUCCESS_COUNT}" "${failed_repos_str}"
    fi

    return ${exit_code}
}

#######################################
# Generic repository executor for commands
# Arguments:
#   $1 - repo_name: Repository name
#   $2 - repo_path: Repository path
#   $3 - validate_repo_func: Function to validate repo (optional)
#   $@ - Command and arguments
# Returns:
#   Command exit code
#######################################
execute_in_repo_generic() {
    local repo_name="$1"
    local repo_path="$2"
    local validate_repo_func="$3"
    shift 3
    local cmd=("$@")

    # Validate repository if function provided
    if [[ -n "${validate_repo_func}" ]] && declare -F "${validate_repo_func}" > /dev/null 2>&1; then
        "${validate_repo_func}" "${repo_name}" "${repo_path}" "${CONFIG_QUIET}" || {
            handle_error $? "Repository validation failed for ${repo_name}"
            return 1
        }
    else
        # Default: just check directory exists
        validate_repo_exists "${repo_name}" "${repo_path}" "${CONFIG_QUIET}" || {
            handle_error $? "Repository validation failed for ${repo_name}"
            return 1
        }
    fi

    # Print header
    if [[ "${CONFIG_QUIET}" != "true" ]]; then
        echo ""
        # Determine if we should include git info
        local include_git="false"
        if [[ -d "${repo_path}/.git" ]]; then
            include_git="true"
        fi
        format_repo_header "${repo_name}" "${repo_path}" "${CONFIG_FORMAT}" "${include_git}"
    fi

    # Execute command
    local exit_code=0
    if [[ ${#cmd[@]} -gt 0 ]]; then
        if ! (cd "${repo_path}" && "${cmd[@]}"); then
            exit_code=$?
            if [[ "${CONFIG_QUIET}" != "true" ]]; then
                print_status error "Command failed with exit code: ${exit_code}"
            fi
        fi
    else
        # No command to execute
        return 0
    fi

    return ${exit_code}
}