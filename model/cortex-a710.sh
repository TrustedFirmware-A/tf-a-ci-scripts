#!/usr/bin/env bash
#
# Copyright (c) 2021-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version_11_17/$model_build_11_17/external/models/$model_flavour_11_17/FVP_Base_Cortex-A710x4"

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"${model_param_file}"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003

-C pctl.use_in_cluster_ppu=true
-C cluster0.core_power_on_by_default=false
EOF
#-C pctl.use_in_cluster_ppu=true - Needed since 11.22 to respect pctl.startup
#-C cluster0.core_power_on_by_default=false - Needed since 11.22 to respect pctl.startup
