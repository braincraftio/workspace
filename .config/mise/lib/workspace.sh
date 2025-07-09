#!/usr/bin/env bash
# Workspace operations library

# IMPORTANT: Do NOT consolidate shellcheck disable comments.
# Each disable should be placed directly above the line it affects.
# This ensures we only disable specific checks where needed and don't
# accidentally mask other issues.

# Source common functions
# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise, path cannot be resolved statically
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise, path cannot be resolved statically
source "${MISE_PROJECT_ROOT}/.config/mise/lib/command-validation.sh"

# List repositories with name:path format
list_repositories() {
    validate_workspace_config || return 1

    # Get the raw repository data
    local repos
    repos=$(jq -r '.repositories[] | select(.clone != false) | "\(.name):\(.path // .name)"' "${WORKSPACE_CONFIG_PATH}" 2> /dev/null) || {
        print_status error "Failed to list repositories"
        return 1
  }

    # Validate each repository path before returning
    local validated_repos=""
    while IFS=: read -r name path; do
        # Use MISE_PROJECT_ROOT as the workspace root
        local workspace_root="${MISE_PROJECT_ROOT}"
        local full_path="${workspace_root}/${path}"

        # Validate the repository path
        if validate_repository_path "${full_path}"; then
            validated_repos+="${name}:${full_path}"$'\n'
    else
            print_status warning "Skipping repository '${name}' due to invalid path: ${path}"
    fi
  done   <<< "${repos}"

    # Return validated repositories
    echo -n "${validated_repos}"
}
