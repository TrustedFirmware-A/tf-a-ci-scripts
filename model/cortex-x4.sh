#!/usr/bin/env bash
#
# Copyright (c) 2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"${model_param_file}"

-C pctl.use_in_cluster_ppu=true
-C cluster0.core_power_on_by_default=false
EOF
