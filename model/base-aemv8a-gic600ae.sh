#!/usr/bin/env bash
#
# Copyright (c) 2021-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version_11_17/$model_build_11_17/external/models/$model_flavour_11_17/FVP_Base_AEMv8A-GIC600AE"

default_var sve_plugin_path "$warehouse/SysGen/PVModelLib/0.0/6415/external/plugins/$model_flavour/sve2-HEAD/ScalableVectorExtension.so"

source "$ci_root/model/base-aemva-common.sh"

# TF-A code maintain GICD and GICR base address at 0x2f000000
# 0x2f100000 respectively. Model provides provision to only
# put GICD base address, and there is a calculation to derive
# GICR base address i.e.
# GICR base address =  0x2f000000 + (4 + (2 × ITScount)+(RDnum × 2)) << 16
# Hence to set GICR base address to 0x2f100000, set the
# ITScount=6 where RDnum=0
cat <<EOF >>"$model_param_file"
-C gic_iri.ITS-count=6
EOF
