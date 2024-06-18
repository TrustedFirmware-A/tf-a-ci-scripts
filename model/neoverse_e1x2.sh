#!/usr/bin/env bash
#
# Copyright (c) 2020-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version_11_24/$model_build_11_24/external/models/$model_flavour/FVP_Base_Neoverse-E1"

source "$ci_root/model/fvp_common.sh"

# Base address for each redistributor
if [ "$gicd_virtual_lpi" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C gic_distributor.reg-base-per-redistributor=0.0.0.0=0x2f100000,0.0.0.1=0x2f140000,0.0.1.0=0x2f180000,0.0.1.1=0x2f1c0000
-C gic_distributor.print-memory-map=1
EOF
fi
