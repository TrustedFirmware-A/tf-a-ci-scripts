#!/usr/bin/env bash
#
# Copyright (c) 2022-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/SubSystemModels/11.23/17/models/$model_flavour/FVP_TC2"

if  is_arm_jenkins_env || upon "$local_ci"; then
	default_var sve_plugin_path "$warehouse/SysGen/PVModelLib/11.23/17/external/plugins/$model_flavour/sve2-HEAD/ScalableVectorExtension.so"
else
        # OpenCI enviroment
        source "$ci_root/fvp_utils.sh"

        # fvp_models variable contains the information for FVP paths, where 2nd field
	# points to the /opt/model/*/models/${model_flavour}
	models_dir="$(echo ${fvp_models[$model]} | awk -F ';' '{print $2}')"
        set_model_path "$models_dir"

        # ScalableVectorExtension is located at /opt/model/*/plugins/${model_flavour}
        default_var sve_plugin_path "${models_dir/models/plugins}/ScalableVectorExtension.so"
fi

reset_var sve_plugin

cat <<EOF >"$model_param_file"
-C css.terminal_uart_ap.start_port=5000
-C css.terminal_uart1_ap.start_port=5001
-C soc.terminal_s0.start_port=5002
-C soc.terminal_s1.start_port=5003
-C board.terminal_0.start_port=5004
-C board.terminal_1.start_port=5005
${fip_gpt_bin+-C board.flashloader0.fname=$fip_gpt_bin}
${tc_fitimage_bin+--data board.dram=$tc_fitimage_bin@0x20000000}
${vmmaddrwidth+-C css.rss.VMADDRWIDTH=$vmmaddrwidth}
${rse_rom_bin+-C css.rss.rom.raw_image=$rse_rom_bin}
-C displayController=2
-C css.rss.CMU0_NUM_DB_CH=16
-C css.rss.CMU1_NUM_DB_CH=16
${rse_encrypted_cm_provisioning_bundle_0_bin+--data css.rss.sram0=${rse_encrypted_cm_provisioning_bundle_0_bin}@0x400}
${rse_encrypted_dm_provisioning_bundle_bin+--data css.rss.sram1=${rse_encrypted_dm_provisioning_bundle_bin}@0x80000}

${sve_plugin+--plugin=$sve_plugin_path}
${sve_plugin+-C SVE.ScalableVectorExtension.enable_at_reset=0}
${sve_plugin+-C SVE.ScalableVectorExtension.veclen=$((128 / 8))}
EOF
