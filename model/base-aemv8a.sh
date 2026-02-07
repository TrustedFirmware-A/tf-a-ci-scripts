#!/usr/bin/env bash
#
# Copyright (c) 2019-2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Use revc model
if upon "$local_ci"; then
    default_var bmcov_plugin_path "$workspace/artefacts/${bin_mode:?}/coverage_trace.so"

    # Locate the model binary
    model_bin="$(command -v FVP_Base_RevC-2xAEMvA)" || {
	    echo "FVP_Base_RevC-2xAEMvA not found in PATH" >&2
	    exit 1
    }

    model_dir="$(dirname -- "$model_bin")"

    # Search for Crypto.so starting from model_dir
    default_var crypto_plugin_path "$(find "$model_dir"/../ -type f -name 'Crypto.so' 2>/dev/null | head -n 1)"

   if [[ -z "$crypto_plugin_path" ]]; then
       echo "Crypto plugin not found under: $model_dir" >&2
   fi

   echo "Using Crypto plugin: $crypto_plugin_path"
else
    # OpenCI enviroment
    default_var crypto_plugin_path "/opt/model/FVP_Base_RevC_AEMvA_${model_version}_${model_build}/plugins/Crypto.so"
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
