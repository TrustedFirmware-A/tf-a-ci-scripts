#!/usr/bin/env bash
#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"${model_param_file}"

-C cluster0.NUM_CORES=4

-C pctl.use_in_cluster_ppu=true
-C cluster0.core_power_on_by_default=false
EOF
#-C pctl.use_in_cluster_ppu=true - Needed since 11.22 to respect pctl.startup
#-C cluster0.core_power_on_by_default=false - Needed since 11.22 to respect pctl.startup
