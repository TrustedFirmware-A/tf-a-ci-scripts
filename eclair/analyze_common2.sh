#!/bin/bash
#
# Copyright (c) 2021-2022 BUGSENG srl. All rights reserved.
# Copyright (c) 2022-2026 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Common code to setup analysis environment.

# Automatically export vars
set -a
source ${WORKSPACE}/tf-a-ci-scripts/tf_config/${TF_CONFIG}
set +a

which ${CROSS_COMPILE}gcc
${CROSS_COMPILE}gcc -v
