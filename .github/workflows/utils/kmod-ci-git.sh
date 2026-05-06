#!/usr/bin/env bash

# Git resolver specific helpers for kernel-module CI workflows.

kmod_git_default_branch() {
  local repo_api_url="https://api.github.com/repos/raspberrypi/firmware"
  local response_file="$1"

  if ! curl -fsSL "$repo_api_url" > "$response_file"; then
    return 1
  fi

  jq -r '.default_branch // empty' "$response_file"
}

kmod_git_infer_target_meta() {
  local kernel_flavor_version="$1"
  local target_architecture_package=""
  local target_architecture_kernel=""
  local target_cross_compile_prefix=""
  local target_defconfig_name=""

  case "$kernel_flavor_version" in
    *-v6+)
      target_architecture_package="armhf"
      target_architecture_kernel="arm"
      target_cross_compile_prefix="arm-linux-gnueabihf-"
      target_defconfig_name="bcmrpi_defconfig"
      ;;
    *-v7+|*-v7l+)
      target_architecture_package="armhf"
      target_architecture_kernel="arm"
      target_cross_compile_prefix="arm-linux-gnueabihf-"
      target_defconfig_name="bcm2709_defconfig"
      ;;
    *-2712+)
      target_architecture_package="arm64"
      target_architecture_kernel="arm64"
      target_cross_compile_prefix=""
      target_defconfig_name="bcm2712_defconfig"
      ;;
    *-v8+|*-v8-rt+|*-v8-16k+)
      target_architecture_package="arm64"
      target_architecture_kernel="arm64"
      target_cross_compile_prefix=""
      target_defconfig_name="bcm2711_defconfig"
      ;;
    [0-9]*.[0-9]*.[0-9]*+)
      target_architecture_package="armhf"
      target_architecture_kernel="arm"
      target_cross_compile_prefix="arm-linux-gnueabihf-"
      target_defconfig_name="bcmrpi_defconfig"
      ;;
    *)
      ;;
  esac

  if [ -z "$target_architecture_package" ] || [ -z "$target_architecture_kernel" ] || [ -z "$target_defconfig_name" ]; then
    return 1
  fi

  printf '%s|%s|%s|%s\n' "$target_architecture_package" "$target_architecture_kernel" "$target_cross_compile_prefix" "$target_defconfig_name"
}

kmod_git_defconfig_candidates() {
  local target_architecture_kernel="$1"
  local inferred_defconfig_name="$2"

  case "$target_architecture_kernel" in
    arm)
      printf '%s\n' "$inferred_defconfig_name" bcm2709_defconfig bcmrpi_defconfig multi_v7_defconfig
      ;;
    arm64)
      printf '%s\n' "$inferred_defconfig_name" bcm2711_defconfig bcm2712_defconfig defconfig
      ;;
    *)
      printf '%s\n' "$inferred_defconfig_name"
      ;;
  esac | awk 'NF > 0 && !seen[$0]++'
}
