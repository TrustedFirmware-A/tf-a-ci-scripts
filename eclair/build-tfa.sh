#!/bin/bash
#
# Copyright (c) 2021-2022 BUGSENG srl. All rights reserved.
# Copyright (c) 2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -ex

. tf-a-ci-scripts/eclair/analyze_common2.sh

env

cd ${WORKSPACE}/trusted-firmware-a
# "make clean" seems to may leave some traces from previous builds, so start
# with removing the build dir. Still issue make clean, as it's best practice
# (for ECLAIR processing too).
rm -rf build/
make clean DEBUG=${DEBUG}

# Ensure tf_root is set so tf_config entries using ${tf_root} expand correctly.
tf_root=${tf_root:-$PWD}

# Replace '$(PWD)' with the *current* $PWD.
MAKE_TARGET=$(echo "${MAKE_TARGET}" | sed "s|\$(PWD)|$PWD|")

if [[ -z "${MAKE_JOBS}" ]]; then
    # By default, scale number of jobs based on number of available processors
    MAKE_JOBS=$(nproc || getconf _NPROCESSORS_ONLN || echo 1)

    # Scale number of jobs based on control group CPU quota if configured
    if [[ -r /sys/fs/cgroup/cpu.max ]]; then
        if read -r quota period < /sys/fs/cgroup/cpu.max; then
            # If quota is "max", then there is no restriction on CPU usage
            if [[ "${quota}" != "max" ]]; then
                MAKE_JOBS=$((quota / period))
                MAKE_JOBS=$((MAKE_JOBS == 0 ? 1 : MAKE_JOBS))
            fi
        fi
    fi
fi

# Expand ${tf_root} in the TF-A build fragment since command substitution doesn't expand it
# as intended.
TF_A_BUILD_ARGS=$(sed 's|\${tf_root}|'"$tf_root"'|g' "${WORKSPACE}/tf-a-ci-scripts/tf_config/$1")

make ${MAKE_TARGET} -j${MAKE_JOBS} ${TF_A_BUILD_ARGS} DEBUG=${DEBUG}
