#!/bin/bash
#
# Copyright (c) 2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause

set -ex

for TF_CONFIG in ${TF_CONFIG_LIST}; do
    echo "============== ${TF_CONFIG} =============="
    . tf-a-ci-scripts/eclair/analyze_common.sh
    unset ECLAIR_PROJECT_NAME
    detachLicense 3000
    tf-a-ci-scripts/eclair/build-tfa.sh ${TF_CONFIG}
done
