#!/usr/bin/env bash

# Shared helpers for GitHub Actions kernel-module CI workflows.

kmod_log_section_begin() {
  local section_title="$1"
  echo "::group::[kmod-ci] ${section_title}"
}

kmod_log_section_end() {
  echo "::endgroup::"
}

kmod_log_info() {
  echo "[kmod-ci][info] $*"
}

kmod_log_warn() {
  echo "::warning::[kmod-ci] $*"
}

kmod_log_error() {
  echo "::error::[kmod-ci] $*"
}

kmod_fail() {
  kmod_log_error "$*"
  return 1
}

kmod_escape_annotation() {
  sed -e 's/%/%25/g' -e 's/\r/%0D/g' -e ':a;N;$!ba;s/\n/%0A/g'
}

kmod_extract_make_error_snippet() {
  local log_file="$1"
  awk '
    { lines[NR]=$0 }
    /: error: / && first == 0 { first=NR }
    END {
      if (first == 0) {
        exit
      }
      start=first
      for (i=first-1; i>=1 && i>=first-3; i--) {
        if (lines[i] ~ /: In function /) {
          start=i
          break
        }
      }
      end=first+4
      for (i=start; i<=end && i<=NR; i++) {
        print lines[i]
      }
    }
  ' "$log_file"
}

kmod_extract_command_failure_snippet() {
  local log_file="$1"
  awk '
    { lines[NR]=$0 }
    /(error:|undefined reference|No rule to make target|No such file or directory|failed|ERROR)/ && first == 0 { first=NR }
    END {
      if (NR == 0) {
        exit
      }
      if (first > 0) {
        start=first-2
        if (start < 1) {
          start=1
        }
        end=first+6
        if (end > NR) {
          end=NR
        }
      } else {
        start=NR-19
        if (start < 1) {
          start=1
        }
        end=NR
      }
      for (i=start; i<=end; i++) {
        print lines[i]
      }
    }
  ' "$log_file"
}

kmod_resolve_compiler_bin() {
  local cross_prefix="$1"
  local cc_bin=""

  if [ -n "$cross_prefix" ]; then
    if command -v "${cross_prefix}gcc-14" >/dev/null 2>&1; then
      cc_bin="${cross_prefix}gcc-14"
    elif command -v "${cross_prefix}gcc" >/dev/null 2>&1; then
      cc_bin="${cross_prefix}gcc"
    elif command -v "${cross_prefix}gcc-12" >/dev/null 2>&1; then
      cc_bin="${cross_prefix}gcc-12"
    fi
  else
    if command -v gcc-14 >/dev/null 2>&1; then
      cc_bin="gcc-14"
    elif command -v gcc >/dev/null 2>&1; then
      cc_bin="gcc"
    elif command -v gcc-12 >/dev/null 2>&1; then
      cc_bin="gcc-12"
    fi
  fi

  printf '%s\n' "$cc_bin"
}

kmod_parse_csv_tokens() {
  local raw_value="$1"
  local lowercase_mode="${2:-false}"

  if [ -z "$raw_value" ]; then
    return 0
  fi

  if [ "$lowercase_mode" = "true" ]; then
    printf '%s\n' "$raw_value" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | tr '[:upper:]' '[:lower:]' | awk '!seen[$0]++'
  else
    printf '%s\n' "$raw_value" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | awk '!seen[$0]++'
  fi
}

kmod_run_command_capture() {
  local log_file="$1"
  shift

  if [ $# -eq 0 ]; then
    kmod_fail "kmod_run_command_capture called without command"
    return 1
  fi

  "$@" >"$log_file" 2>&1
}

kmod_log_external_output_file() {
  local external_command_label="$1"
  local external_output_file="$2"

  if [ ! -f "$external_output_file" ]; then
    kmod_log_warn "No external output file found for '$external_command_label': $external_output_file"
    return 0
  fi

  kmod_log_info "--- external command output begin ($external_command_label) ---"
  cat "$external_output_file"
  kmod_log_info "--- external command output end ($external_command_label) ---"
}

kmod_log_external_output_excerpt() {
  local external_command_label="$1"
  local external_output_file="$2"
  local external_max_lines="${3:-200}"

  if [ ! -f "$external_output_file" ]; then
    kmod_log_warn "No external output file found for '$external_command_label': $external_output_file"
    return 0
  fi

  kmod_log_info "--- external command output excerpt begin ($external_command_label, max_lines=$external_max_lines) ---"
  tail -n "$external_max_lines" "$external_output_file"
  kmod_log_info "--- external command output excerpt end ($external_command_label) ---"
}

kmod_run_command_capture_with_label() {
  local external_command_label="$1"
  local external_output_file="$2"
  shift 2

  if [ $# -eq 0 ]; then
    kmod_fail "kmod_run_command_capture_with_label called without command for '$external_command_label'"
    return 1
  fi

  kmod_log_info "Running external command: $external_command_label"
  if kmod_run_command_capture "$external_output_file" "$@"; then
    kmod_log_info "External command succeeded: $external_command_label"
    return 0
  fi

  kmod_log_warn "External command failed: $external_command_label"
  return 1
}
