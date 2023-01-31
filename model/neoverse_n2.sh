#!/usr/bin/env bash
#
# Copyright (c) 2020-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version_11_16/$model_build_11_16/external/models/$model_flavour_11_16/FVP_Base_Neoverse-N1x4"

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"${model_param_file}"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003
EOF
