#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version/$model_build/external/models/$model_flavour/FVP_Base_Cortex-A53x4"

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"$model_param_file"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003

${reset_to_spmin+-C cluster0.cpu0.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu1.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu2.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu3.RVBARADDR=${bl32_addr:?}}

EOF
