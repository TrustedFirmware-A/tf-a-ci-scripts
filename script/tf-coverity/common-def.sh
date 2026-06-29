#!/usr/bin/env bash
#
# Copyright (c) 2019-2026 Arm Limited. All rights reserved.
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
    local jobs

    # By default, scale number of jobs based on number of available processors
    jobs=$(nproc || getconf _NPROCESSORS_ONLN || echo 1)

    # Scale number of jobs based on control group CPU quota if configured
    if [[ -r /sys/fs/cgroup/cpu.max ]]; then
        if read -r quota period < /sys/fs/cgroup/cpu.max; then
            # If quota is "max", then there is no restriction on CPU usage
            if [[ "${quota}" != "max" ]]; then
                jobs=$((quota / period))
                jobs=$((jobs == 0 ? 1 : jobs))
            fi
        fi
    fi

    # default to debug mode, unless a parameter is passed to the function
    debug="DEBUG=1"
    [ -n "$release" ] && debug=""

    echo " --jobs=${jobs} $debug -s "
}

# Use "$1" as a boolean
upon() {
	case "$1" in
		"" | "0" | "false") return 1;;
		*) return 0;;
	esac
}

# Provide correct armclang toolchain based on environment
set_armclang_toolchain() {
    local armclang_path="/home/buildslave/tools/armclang-6.23/bin"

    if upon "$local_ci"; then
        armclang_path="/arm/warehouse/Distributions/FA/ARMCompiler/6.23/37/standalone-linux-x86_64-rel/bin"
    fi

    echo "${armclang_path}/armclang"
}

# TF-M variables
export TF_M_TESTS_PATH=${WORKSPACE}/TF-M/tf-m-tests
export TF_M_EXTRAS_PATH=${WORKSPACE}/TF-M/tf-m-extras

QCBOR_LIB_DIR=qcbor
QCBOR_URL_REPO=https://github.com/laurencelundblade/QCBOR.git

ARMCLANG_PATH="$(set_armclang_toolchain)"

TBB_OPTIONS="TRUSTED_BOARD_BOOT=1 GENERATE_COT=1"
ARM_TBB_OPTIONS="$TBB_OPTIONS ARM_ROTPK_LOCATION=devel_rsa"
