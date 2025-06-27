#!/usr/bin/env bash
#
# Copyright (c) 2023-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"$model_param_file"

-C cluster0.NUM_CORES=4

${bmcov_plugin+--plugin=$bmcov_plugin_path}

${reset_to_spmin+-C cluster0.cpu0.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu1.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu2.RVBARADDR=${bl32_addr:?}}
${reset_to_spmin+-C cluster0.cpu3.RVBARADDR=${bl32_addr:?}}

EOF
