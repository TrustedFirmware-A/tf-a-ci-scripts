#!/usr/bin/env bash
#
# Copyright (c) 2019-2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

export CROSS_COMPILE=aarch64-none-elf-

# We need to clean the platform build between each configuration because Trusted
# Firmware's build system doesn't track build options dependencies and won't
# rebuild the files affected by build options changes.
clean_build()
{
    local flags="$*"
    echo "Building TF with the following build flags:"
    echo "  $flags"
    make distclean
    make $flags all
    echo "Build config complete."
    echo
}

# Defines common flags between platforms
common_flags() {
    local release="${1:-}"
    local num_cpus="$(/usr/bin/getconf _NPROCESSORS_ONLN)"
    local parallel_make="-j $num_cpus"

    # default to debug mode, unless a parameter is passed to the function
    debug="DEBUG=1"
    [ -n "$release" ] && debug=""

    echo " $parallel_make $debug -s "
}

# Check if execution environment is ARM's jenkins (Jenkins running under ARM
# infrastructure)
is_arm_jenkins_env() {
    if [ "$JENKINS_HOME" ]; then
	if echo "$JENKINS_URL" | grep -q "oss.arm.com"; then
	    return 0;
	fi
    fi
    return 1
}

# Use "$1" as a boolean
upon() {
	case "$1" in
		"" | "0" | "false") return 1;;
		*) return 0;;
	esac
}

# Provide correct linaro cross toolchain based on environment
set_cross_compile_gcc_linaro_toolchain() {
    local cross_compile_path="/home/buildslave/tools"

    # if under arm enviroment, overide cross-compilation path
    is_arm_jenkins_env || upon "$local_ci" && cross_compile_path="/arm/pdsw/tools"

    echo "${cross_compile_path}/gcc-linaro-6.2.1-2016.11-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
}

# Provide correct armclang toolchain based on environment
set_armclang_toolchain() {
    local armclang_path="/home/buildslave/tools/armclang-6.18/bin"

    # if under arm enviroment, overide cross-compilation path
    is_arm_jenkins_env || upon "$local_ci" && armclang_path="/arm/warehouse/Distributions/FA/ARMCompiler/6.18/19/standalone-linux-x86_64-rel/bin"

    echo "${armclang_path}/armclang"
}

# mbed TLS variables
MBED_TLS_DIR=mbedtls
MBED_TLS_URL_REPO=https://github.com/ARMmbed/mbedtls.git

# mbed TLS source tag to checkout when building Trusted Firmware with
# cryptography support (e.g. for Trusted Board Boot feature).
MBED_TLS_SOURCES_TAG="mbedtls-3.6.0"

ARMCLANG_PATH="$(set_armclang_toolchain)"

TBB_OPTIONS="TRUSTED_BOARD_BOOT=1 GENERATE_COT=1 MBEDTLS_DIR=$(pwd)/mbedtls"
ARM_TBB_OPTIONS="$TBB_OPTIONS ARM_ROTPK_LOCATION=devel_rsa"
