#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"$model_param_file"

${reset_to_bl31+-C cluster0.cpu0.RVBARADDR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu1.RVBARADDR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu0.RVBARADDR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu1.RVBARADDR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu2.RVBARADDR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu3.RVBARADDR=${bl31_addr:?}}

EOF
