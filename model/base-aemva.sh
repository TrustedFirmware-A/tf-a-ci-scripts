#!/usr/bin/env bash
#
# Copyright (c) 2019-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version/$model_build/external/models/$model_flavour/FVP_Base_AEMvA"

default_var sve_plugin_path "$warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/sve2-HEAD/ScalableVectorExtension.so"

default_var etm_plugin_path "$warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/ETMv4ExamplePlugin.so"

default_var ete_plugin_path "$warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/libete-plugin.so"

default_var is_dual_cluster 0

source "$ci_root/model/base-aemva-common.sh"

cat <<EOF >>"${model_param_file}"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003
EOF
