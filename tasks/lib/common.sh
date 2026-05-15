#!/usr/bin/env bash

declare -A SURVEY_ARGS=()

parse_survey_args() {
  local arg key value
  for arg in "$@"; do
    if [[ "${arg}" == *"="* ]]; then
      key="${arg%%=*}"
      value="${arg#*=}"
      SURVEY_ARGS["${key}"]="${value}"
    fi
  done
}

get_arg() {
  local key="$1"
  local default="${2:-}"
  printf '%s' "${SURVEY_ARGS[${key}]:-${default}}"
}

bool_arg() {
  local key="$1"
  local default="${2:-false}"
  local value
  value="$(get_arg "${key}" "${default}")"
  case "${value,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

require_non_empty() {
  local value="$1"
  local name="$2"
  if [[ -z "${value}" ]]; then
    echo "ERROR: ${name} is required." >&2
    exit 1
  fi
}

require_project_root() {
  local project_root="$1"
  local marker="$2"
  if [[ ! -e "${project_root}/${marker}" ]]; then
    echo "ERROR: ${project_root} does not look like the expected project root; missing ${marker}." >&2
    exit 1
  fi
}

safe_rel_path() {
  local path_value="$1"
  local label="$2"
  if [[ "${path_value}" = /* || "${path_value}" == *".."* ]]; then
    echo "ERROR: ${label} must be a relative path inside the project repository." >&2
    exit 1
  fi
}

append_extra_args() {
  local -n command_ref="$1"
  local extra="${2:-}"
  extra="${extra#EXTRA_ARGS=}"
  if [[ -n "${extra}" ]]; then
    local extra_parts=()
    read -r -a extra_parts <<< "${extra}"
    command_ref+=("${extra_parts[@]}")
  fi
}

print_command() {
  printf 'Running:'
  printf ' %q' "$@"
  printf '\n'
}
