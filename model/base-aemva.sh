#!/usr/bin/env bash
#
# Copyright (c) 2019-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Use revc model
if  is_arm_jenkins_env || upon "$local_ci"; then
	set_model_path "$warehouse/SysGen/Models/$model_version/$model_build/external/models/$model_flavour/FVP_Base_RevC-2xAEMvA"

	default_var etm_plugin_path "$warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/ETMv4ExamplePlugin.so"
        default_var generictrace_plugin_path "$warehouse/SysGen/PVModelLib/$model_version/$model_build/external/plugins/$model_flavour/GenericTrace.so"
else
        # OpenCI enviroment
        source "$ci_root/fvp_utils.sh"

        # fvp_models variable contains the information for FVP paths, where 2nd field
	# points to the /opt/model/*/models/${model_flavour}
	models_dir="$(echo ${fvp_models[$model]} | awk -F ';' '{print $2}')"
        set_model_path "$models_dir"

       default_var etm_plugin_path "/opt/model/Base_RevC_AEMvA_pkg/plugins/Linux64_GCC-9.3/ETMv4ExamplePlugin.so"
       default_var generictrace_plugin_path "/opt/model/Base_RevC_AEMvA_pkg/plugins/Linux64_GCC-9.3/GenericTrace.so"
fi

default_var is_dual_cluster 1

source "$ci_root/model/base-aemva-common.sh"

cat <<EOF >>"${model_param_file}"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003
EOF

# Base address for each redistributor
if [ "$gicd_virtual_lpi" = "1" ]; then
	cat <<EOF >>"$model_param_file"
-C gic_distributor.reg-base-per-redistributor=0.0.0.0=0x2f100000,0.0.1.0=0x2f140000,0.0.2.0=0x2f180000,0.0.3.0=0x2f1c0000,0.1.0.0=0x2f200000,0.1.1.0=0x2f240000,0.1.2.0=0x2f280000,0.1.3.0=0x2f2c0000
-C gic_distributor.print-memory-map=1
EOF
fi

# GIC and pctl CPU affinity properties for aarch32.gicv2
if [ "$aarch32" = "1" ] && [ "$gicv3_gicv2_only" = "1" ]; then
        cat <<EOF >>"$model_param_file"
-C gic_distributor.CPU-affinities=0.0.0.0,0.0.0.1,0.0.0.2,0.0.0.3,0.0.1.0,0.0.1.1,0.0.1.2,0.0.1.3
-C pctl.CPU-affinities=0.0.0.0,0.0.0.1,0.0.0.2,0.0.0.3,0.0.1.0,0.0.1.1,0.0.1.2,0.0.1.3
-C gic_distributor.reg-base-per-redistributor=0.0.0.0=0x2f100000,0.0.0.1=0x2f120000,0.0.0.2=0x2f140000,0.0.0.3=0x2f160000,0.0.1.0=0x2f180000,0.0.1.1=0x2f1a0000,0.0.1.2=0x2f1c0000,0.0.1.3=0x2f1e0000
-C pctl.Affinity-shifted=0
EOF
fi
