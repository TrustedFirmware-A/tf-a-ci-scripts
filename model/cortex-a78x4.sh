#!/usr/bin/env bash
#
# Copyright (c) 2020-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Option not supported on A78 FVP yet.
export no_quantum=""

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"${model_param_file}"
EOF
