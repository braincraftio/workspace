#!/usr/bin/env bash
# command-validation.sh - Command input validation for mise tasks
# Provides security validation for user-supplied commands to prevent injection attacks

# Validate command input to prevent malicious execution
validate_command_input() {
    local cmd_name="$1"
    local context="${2:-command}"  # Optional context (e.g., "git command")

    # Debug output
    [[ "${MISE_DEBUG:-}" == "1" ]] && echo "DEBUG: Validating ${context}: ${cmd_name}" >&2

    # Check for dangerous characters that could lead to command injection
    # Check each dangerous character individually for clarity
    local dangerous_chars=(';' '|' '&' '$' '(' ')' '{' '}' '[' ']' '<' '>' '`' "\\")
    for char in "${dangerous_chars[@]}"; do
        if [[ "${cmd_name}" == *"${char}"* ]]; then
            print_status error "Security: ${context} contains potentially dangerous character '${char}'"
            echo ""
            echo "  Command rejected: ${cmd_name}"
            echo ""
            echo "  For security reasons, the following characters are not allowed: ; | & $ ( ) { } [ ] < > \` \\"
            echo ""
            echo "  If you need to run multiple commands, please run them separately:"
            echo "    mise run ${MISE_TASK_NAME:-exec} echo test"
            echo "    mise run ${MISE_TASK_NAME:-exec} echo another"
            echo ""
            echo "  Or create a script file and execute that instead:"
            echo "    mise run ${MISE_TASK_NAME:-exec} bash my-script.sh"
            echo ""
            return 1
    fi
  done

    # Check for path traversal attempts
    if [[ "${cmd_name}" =~ \.\. ]]; then
        print_status error "Security: ${context} contains path traversal"
        echo ""
        echo "  Command rejected: ${cmd_name}"
        echo ""
        echo "  Path traversal attempts (../) are not allowed for security reasons."
        echo "  Please use absolute paths or paths relative to the repository root."
        echo ""
        return 1
  fi

    return 0
}

# Validate git-specific commands
validate_git_command_input() {
    local git_cmd="$1"

    # First run general validation
    if ! validate_command_input "${git_cmd}" "git command"; then
        return 1
  fi

    # Git-specific validations
    # Prevent certain dangerous git operations
    local dangerous_git_cmds=("config" "remote" "submodule" "worktree" "hook")
    local first_word
    first_word=$(echo "${git_cmd}" | awk '{print $1}')

    for dangerous_cmd in "${dangerous_git_cmds[@]}"; do
        if [[ "${first_word}" == "${dangerous_cmd}" ]]; then
            print_status warning "Git command '${dangerous_cmd}' requires careful review"
            echo "  This command can modify repository configuration."
            echo "  Proceeding with caution..."
            echo ""
            # Return 0 to allow but warn - can be changed to return 1 to block
    fi
  done

    return 0
}

# Validate repository path to prevent traversal attacks
validate_repository_path() {
    local repo_path="$1"
    # Use MISE_PROJECT_ROOT as the workspace root
    local workspace_root="${MISE_PROJECT_ROOT:-${WORKSPACE_ROOT:-$(pwd)}}"

    # Handle case where path doesn't exist yet (for new repos)
    if [[ ! -e "${repo_path}" ]]; then
        # For non-existent paths, check the parent directory
        local parent_dir
        parent_dir=$(dirname "${repo_path}")
        if [[ -d "${parent_dir}" ]]; then
            repo_path="${parent_dir}"
    else
            # Path doesn't exist and parent doesn't exist, allow it if it would be within workspace
            local abs_path
            abs_path=$(cd "${workspace_root}" && realpath -m "${repo_path}" 2> /dev/null)
            if [[ -z "${abs_path}" ]]; then
                print_status error "Invalid repository path: ${repo_path}"
                return 1
      fi

            if [[ "${abs_path}" == "${workspace_root}"* ]]; then
                return 0  # Allow non-existent paths within workspace
      fi
    fi
  fi

    # Resolve the absolute path
    local abs_path
    abs_path=$(cd "${repo_path}" 2> /dev/null && pwd)

    if [[ -z "${abs_path}" ]]; then
        print_status error "Invalid repository path: ${repo_path}"
        return 1
  fi

    # Ensure the path is within the workspace
    if [[ "${abs_path}" != "${workspace_root}"* ]]; then
        print_status error "Security: Repository path is outside workspace"
        echo ""
        echo "  Path rejected: ${repo_path}"
        echo "  Resolved to: ${abs_path}"
        echo ""
        echo "  All repositories must be within the workspace root: ${workspace_root}"
        echo ""
        return 1
  fi

    return 0
}

# Export functions
export -f validate_command_input
export -f validate_git_command_input
export -f validate_repository_path
