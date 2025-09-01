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

make ${MAKE_TARGET} -j${MAKE_JOBS} $(cat ${WORKSPACE}/tf-a-ci-scripts/tf_config/$1) DEBUG=${DEBUG}
