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

kmod_log_notice() {
  echo "::notice::[kmod-ci] $*"
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

kmod_tokens_to_csv() {
  local token_input="${1:-}"
  if [ -z "$token_input" ]; then
    printf '%s\n' ""
    return 0
  fi

  printf '%s\n' "$token_input" | awk 'NF > 0' | paste -sd',' -
}

kmod_csv_to_markdown_list() {
  local label="$1"
  local csv_values="${2:-}"

  if [ -z "$csv_values" ]; then
    echo "- ${label}: none"
    return 0
  fi

  echo "- ${label}:"
  printf '%s\n' "$csv_values" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | while IFS= read -r item; do
    echo "  - $item"
  done
}

kmod_log_csv_list() {
  local label="$1"
  local csv_values="${2:-}"

  if [ -z "$csv_values" ]; then
    kmod_log_info "${label}: none"
    return 0
  fi

  kmod_log_info "${label}:"
  printf '%s\n' "$csv_values" | tr ',' '\n' | sed 's/^ *//;s/ *$//' | sed '/^$/d' | while IFS= read -r item; do
    kmod_log_info "  - $item"
  done
}

kmod_parse_resolver_sources() {
  local resolver_name="$1"
  local raw_sources="$2"

  if [ -z "$raw_sources" ]; then
    kmod_fail "Input 'sources' is required for resolver '$resolver_name'"
    return 1
  fi

  while IFS= read -r source_name; do
    [ -z "$source_name" ] && continue

    case "$resolver_name:$source_name" in
      apt:rpi-archive|apt:ubuntu-archive|git:rpi-firmware)
        printf '%s\n' "$source_name"
        ;;
      *)
        kmod_fail "Invalid source '$source_name' for resolver '$resolver_name'"
        return 1
        ;;
    esac
  done < <(kmod_parse_csv_tokens "$raw_sources" true)
}

kmod_assert_non_empty_stream_candidates() {
  local stream_label="$1"
  local candidate_count="$2"
  if [ -z "$candidate_count" ] || [ "$candidate_count" -le 0 ]; then
    kmod_fail "Resolved stream '$stream_label' produced no discovery candidates"
    return 1
  fi
}

kmod_apt_resolve_stream_to_suite() {
  local stream_name="$1"
  local stable_suite="$2"
  local oldstable_suite="$3"
  local next_suite="$4"
  local suite_name=""

  case "$stream_name" in
    stable)
      suite_name="$stable_suite"
      ;;
    oldstable)
      suite_name="$oldstable_suite"
      ;;
    next)
      suite_name="$next_suite"
      ;;
    *)
      suite_name="$stream_name"
      ;;
  esac

  suite_name="$(printf '%s' "$suite_name" | xargs | tr '[:upper:]' '[:lower:]')"
  printf '%s\n' "$suite_name"
}

kmod_log_requested_resolved_scope() {
  local resolver_name="$1"
  local requested_sources="$2"
  local resolved_sources="$3"
  local requested_streams="$4"
  local resolved_streams="$5"

  kmod_log_info "Requested ${resolver_name} sources: ${requested_sources:-none}"
  kmod_log_info "Resolved ${resolver_name} sources: ${resolved_sources:-none}"
  kmod_log_info "Requested ${resolver_name} streams: ${requested_streams:-none}"
  kmod_log_info "Resolved ${resolver_name} streams: ${resolved_streams:-none}"
}

kmod_emit_requested_resolved_outputs() {
  local requested_sources="$1"
  local resolved_sources="$2"
  local requested_streams="$3"
  local resolved_streams="$4"

  echo "requested_source_list=$requested_sources" >> "$GITHUB_OUTPUT"
  echo "resolved_source_list=$resolved_sources" >> "$GITHUB_OUTPUT"
  echo "requested_stream_list=$requested_streams" >> "$GITHUB_OUTPUT"
  echo "resolved_stream_list=$resolved_streams" >> "$GITHUB_OUTPUT"
}

kmod_emit_resolver_scope_outputs() {
  local requested_sources="$1"
  local resolved_sources="$2"
  local requested_streams="$3"
  local resolved_streams="$4"
  local resolved_cores="${5:-}"
  local resolved_flavors="${6:-}"

  kmod_emit_requested_resolved_outputs "$requested_sources" "$resolved_sources" "$requested_streams" "$resolved_streams"
  echo "resolved_core_list=$resolved_cores" >> "$GITHUB_OUTPUT"
  echo "resolved_flavor_list=$resolved_flavors" >> "$GITHUB_OUTPUT"
}

kmod_first_non_empty() {
  local candidate=""

  for candidate in "$@"; do
    if [ -n "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf '\n'
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

  # Keep failure visible in logs but avoid spamming workflow annotations.
  kmod_log_info "External command failed: $external_command_label"
  return 1
}

kmod_append_csv_value() {
  local target_var_name="$1"
  local value="$2"
  local current_value="${!target_var_name:-}"

  if [ -n "$current_value" ]; then
    printf -v "$target_var_name" '%s,%s' "$current_value" "$value"
  else
    printf -v "$target_var_name" '%s' "$value"
  fi
}

kmod_register_skip() {
  local target_key="$1"
  local reason_tag="$2"

  SKIP_COUNT=$((SKIP_COUNT + 1))
  kmod_append_csv_value SKIP_KERNELS "${target_key}(${reason_tag})"
}

kmod_register_fail() {
  local target_key="$1"
  local reason_tag="$2"

  FAIL=1
  FAIL_COUNT=$((FAIL_COUNT + 1))
  kmod_append_csv_value FAIL_KERNELS "${target_key}(${reason_tag})"
}

kmod_register_success() {
  local target_key="$1"

  OK_COUNT=$((OK_COUNT + 1))
  kmod_append_csv_value OK_KERNELS "$target_key"
}

kmod_link_kernel_build_dir() {
  local module_version="$1"
  local kernel_build_dir="$2"

  sudo mkdir -p "/lib/modules/$module_version"
  sudo rm -rf "/lib/modules/$module_version/build"
  sudo ln -s "$kernel_build_dir" "/lib/modules/$module_version/build"
}

kmod_resolve_module_name() {
  local module_name
  module_name="$(find . -maxdepth 1 -type f -name '*.ko' -print | sort | head -n1 | xargs -n1 basename | sed 's/\.ko$//' || true)"
  [ -z "$module_name" ] && module_name="module"
  printf '%s\n' "$module_name"
}

kmod_copy_target_artifacts() {
  local artifact_root="$1"
  local target_version="$2"
  local module_name=""
  local output_dir=""

  module_name="$(kmod_resolve_module_name)"
  output_dir="$artifact_root/${module_name}-${target_version}"
  mkdir -p "$output_dir"
  find . -maxdepth 1 -type f -name '*.ko' -exec cp -v {} "$output_dir/" \;
  find . -maxdepth 1 -type f -name '*.dtbo' -exec cp -v {} "$output_dir/" \;
}

kmod_build_target_with_make() {
  local subject_noun="$1"
  local subject_display="$2"
  local subject_key="$3"
  local module_version="$4"
  local kernel_build_dir="$5"
  local cross_compile_prefix="$6"
  local kernel_arch="$7"
  local artifact_root="$8"
  local build_context="$9"
  local make_log_file="${10}"
  local cc_bin=""
  local make_label=""
  local ko_count="0"
  local dtbo_count="0"
  local err_snippet=""
  local err_annotation=""

  cc_bin="$(kmod_resolve_compiler_bin "$cross_compile_prefix")"
  if [ -z "$cc_bin" ] || ! command -v "$cc_bin" >/dev/null 2>&1; then
    kmod_log_error "${subject_noun} '$subject_display' failed: compiler not found ('$cc_bin')"
    kmod_register_fail "$subject_key" "compiler-missing"
    return 1
  fi

  kmod_link_kernel_build_dir "$module_version" "$kernel_build_dir"

  export ARCH="$kernel_arch"
  export CROSS_COMPILE="$cross_compile_prefix"
  export CC="$cc_bin"
  export KVER="$module_version"

  make CC="$cc_bin" clean || true
  rm -f "$make_log_file"

  make_label="make CC=$cc_bin ($build_context)"
  if kmod_run_command_capture_with_label "$make_label" "$make_log_file" make CC="$cc_bin"; then
    ko_count="$(find . -maxdepth 1 -type f -name '*.ko' | wc -l | tr -d ' ')"
    dtbo_count="$(find . -maxdepth 1 -type f -name '*.dtbo' | wc -l | tr -d ' ')"

    if [ "$ko_count" -eq 0 ] || [ "$dtbo_count" -eq 0 ]; then
      kmod_log_error "${subject_noun} '$subject_display' failed: expected .ko and .dtbo outputs are required"
      kmod_register_fail "$subject_key" "artifact-contract-failed"
      return 1
    fi

    kmod_copy_target_artifacts "$artifact_root" "$module_version"
    kmod_register_success "$subject_key"
    kmod_log_info "${subject_noun} '$subject_display' build succeeded"
    kmod_log_notice "OK target: $subject_display"
    return 0
  fi

  kmod_log_info "${subject_noun} '$subject_display' failed: make returned non-zero"
  if [ -f "$make_log_file" ]; then
    kmod_log_external_output_excerpt "$make_label" "$make_log_file" 220
    err_snippet="$(kmod_extract_make_error_snippet "$make_log_file")"
    if [ -n "$err_snippet" ]; then
      err_annotation="$(printf '%s' "$err_snippet" | kmod_escape_annotation)"
      echo "::error::${subject_noun} '$subject_display' relevant error:%0A$err_annotation"
    fi
  fi
  kmod_register_fail "$subject_key" "make-failed"
  return 1
}

kmod_log_build_counts() {
  local resolver_heading="$1"

  kmod_log_section_begin "$resolver_heading resolver summary"
  kmod_log_info "Summary: targets=$TARGET_COUNT ok=$OK_COUNT skip=$SKIP_COUNT fail=$FAIL_COUNT"
  [ -n "$SKIP_KERNELS" ] && kmod_log_warn "Skipped targets: $SKIP_KERNELS"
  [ -n "$FAIL_KERNELS" ] && kmod_log_info "Failed targets: $FAIL_KERNELS"
  kmod_log_section_end
}

kmod_emit_build_outputs() {
  echo "target_count=$TARGET_COUNT" >> "$GITHUB_OUTPUT"
  echo "ok_count=$OK_COUNT" >> "$GITHUB_OUTPUT"
  echo "skip_count=$SKIP_COUNT" >> "$GITHUB_OUTPUT"
  echo "fail_count=$FAIL_COUNT" >> "$GITHUB_OUTPUT"
  echo "ok_kernels=$OK_KERNELS" >> "$GITHUB_OUTPUT"
  echo "skip_kernels=$SKIP_KERNELS" >> "$GITHUB_OUTPUT"
  echo "fail_kernels=$FAIL_KERNELS" >> "$GITHUB_OUTPUT"
}

kmod_finalize_build_status() {
  local fail_on_skip="$1"

  if [ "$TARGET_COUNT" -eq 0 ]; then
    kmod_fail "No targets were processed"
    return 1
  fi

  if [ "$fail_on_skip" = "true" ] && [ "$SKIP_COUNT" -gt 0 ]; then
    kmod_log_error "Skipping targets is configured as blocking and $SKIP_COUNT target(s) were skipped"
    FAIL=1
  fi

  return 0
}

kmod_summary_publish_resolver() {
  local resolver_name="$1"
  local requested_sources="${2:-}"
  local resolved_sources="${3:-}"
  local requested_streams="${4:-}"
  local resolved_streams="${5:-}"
  local resolved_cores="${6:-}"
  local resolved_flavors="${7:-}"
  local target_count="${8:-0}"
  local ok_count="${9:-0}"
  local skip_count="${10:-0}"
  local fail_count="${11:-0}"

  # Ensure all counters are integers
  [ -z "$target_count" ] && target_count=0
  [ -z "$ok_count" ] && ok_count=0
  [ -z "$skip_count" ] && skip_count=0
  [ -z "$fail_count" ] && fail_count=0

  # Log summary to workflow logs
  kmod_log_section_begin "${resolver_name} resolver summary"
  kmod_log_info "Requested sources: ${requested_sources:-none}"
  kmod_log_info "Resolved sources: ${resolved_sources:-none}"
  kmod_log_info "Requested streams: ${requested_streams:-none}"
  kmod_log_info "Resolved streams: ${resolved_streams:-none}"
  kmod_log_csv_list "Resolved cores" "$resolved_cores"
  kmod_log_csv_list "Resolved flavors" "$resolved_flavors"
  kmod_log_info "Result counts: targets=$target_count ok=$ok_count skip=$skip_count fail=$fail_count"
  kmod_log_section_end

  # Write summary to GitHub Step Summary markdown
  {
    local heading_name
    heading_name=$(printf '%s' "$resolver_name" | sed 's/^./\U&/')
    echo "- Resolver: $heading_name"
    echo "- Requested sources: ${requested_sources:-none}"
    echo "- Resolved sources: ${resolved_sources:-none}"
    echo "- Requested streams: ${requested_streams:-none}"
    echo "- Resolved streams: ${resolved_streams:-none}"
    kmod_csv_to_markdown_list "Resolved kernel cores" "$resolved_cores"
    kmod_csv_to_markdown_list "Resolved kernel flavors" "$resolved_flavors"
    echo "- Build counts: targets=$target_count ok=$ok_count skip=$skip_count fail=$fail_count"
    echo ""
  } >> "$GITHUB_STEP_SUMMARY"
}
