#!/usr/bin/env bash
#
# Copyright (c) 2019-2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Use revb model
default_var is_dual_cluster 1

source "$ci_root/model/base-aemva-common.sh"

cat <<EOF >>"${model_param_file}"
EOF
