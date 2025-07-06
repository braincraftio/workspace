#!/usr/bin/env bash
# Shared formatting functions for mise tasks

# Guard against multiple sourcing
if [[ -n "${_MISE_FORMATTING_SOURCED:-}" ]]; then
    return 0
fi
readonly _MISE_FORMATTING_SOURCED=1

# Source common functions for colors
# shellcheck disable=SC1091
# SC1091: MISE_PROJECT_ROOT is set at runtime by mise, path cannot be resolved statically
source "${MISE_PROJECT_ROOT}/.config/mise/lib/common.sh"

#######################################
# Get repository information
# Arguments:
#   $1 - repo_path: Path to repository
# Outputs:
#   branch:remote_url format
# Returns:
#   0 on success, 1 on failure
#######################################
get_repo_info() {
    local repo_path="$1"
    local branch remote_url

    # Get current branch
    if ! branch=$(cd "${repo_path}" && git rev-parse --abbrev-ref HEAD 2>/dev/null); then
        branch="<no-branch>"
    fi

    # Get remote URL (prefer origin)
    if ! remote_url=$(cd "${repo_path}" && git remote get-url origin 2>/dev/null); then
        # Try first available remote
        if ! remote_url=$(cd "${repo_path}" && git remote get-url "$(git remote | head -n1)" 2>/dev/null); then
            remote_url="<no-remote>"
        fi
    fi

    echo "${branch}:${remote_url}"
}

#######################################
# Make path absolute
# Arguments:
#   $1 - path: Path to make absolute
# Outputs:
#   Absolute path
#######################################
make_absolute_path() {
    local path="$1"

    if [[ "${path}" = /* ]]; then
        echo "${path}"
    elif [[ "${path}" = "." ]]; then
        echo "${MISE_PROJECT_ROOT}"
    else
        echo "${MISE_PROJECT_ROOT}/${path}"
    fi
}

#######################################
# Format repository header
# Arguments:
#   $1 - repo_name: Repository name
#   $2 - repo_path: Repository path
#   $3 - format: Output format (pretty|simple|minimal)
#   $4 - include_git_info: Include git info (true|false)
# Outputs:
#   Formatted header
#######################################
format_repo_header() {
    local repo_name="$1"
    local repo_path="$2"
    local format="${3:-pretty}"
    local include_git_info="${4:-true}"

    local abs_path
    abs_path=$(make_absolute_path "${repo_path}")

    case "${format}" in
        minimal)
            echo -e "${BLUE}[${repo_name}]${NC} ${GRAY}${abs_path}${NC}"
            echo "─────────────────────────────────────────────────"
            ;;

        simple)
            echo "[${repo_name}]"
            ;;

        pretty|*)
            if [[ "${include_git_info}" == "true" ]] && [[ -d "${repo_path}/.git" ]]; then
                local repo_info branch remote_url
                repo_info=$(get_repo_info "${repo_path}")
                IFS=: read -r branch remote_url <<< "${repo_info}"

                echo -e "${BLUE}[${repo_name}]${NC} ${GREEN}(${branch})${NC} → ${YELLOW}${abs_path}${NC}"
                if [[ "${remote_url}" != "<no-remote>" ]]; then
                    echo -e "  ${GRAY}↳ ${remote_url}${NC}"
                fi
            else
                # Non-git or git info not requested
                echo -e "${BLUE}[${repo_name}]${NC} → ${YELLOW}${abs_path}${NC}"
            fi
            ;;
    esac
}

#######################################
# Format summary section
# Arguments:
#   $1 - total: Total count
#   $2 - success: Success count
#   $3 - failed_repos: Array of failed repo names (as string)
# Outputs:
#   Formatted summary
#######################################
format_summary() {
    local total="$1"
    local success="$2"
    local failed_repos="$3"
    local failed_count=$((total - success))

    echo ""
    echo "================================================================================"
    echo "📊 Summary"
    echo "---------"
    printf "Total repositories: %d\n" "${total}"
    printf "Successful: %d\n" "${success}"

    if [[ ${failed_count} -gt 0 ]]; then
        printf "Failed: %d" "${failed_count}"
        if [[ -n "${failed_repos}" ]]; then
            printf " (%s)" "${failed_repos}"
        fi
        printf "\n"
    else
        print_status success "All repositories processed successfully! 🎉"
    fi
}

#######################################
# Format operation header
# Arguments:
#   $1 - operation: Operation description
# Outputs:
#   Formatted header
#######################################
format_operation_header() {
    local operation="$1"

    echo "🔄 ${operation}"
    echo "================================================================================"
}
