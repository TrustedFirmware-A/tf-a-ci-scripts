#!/usr/bin/env bash
#
# Copyright (c) 2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/Models/$model_version/$model_build/external/models/$model_flavour/FVP_Base_AEMv8A-AEMv8A-AEMv8A-AEMv8A-CCN502"

default_var cluster_0_num_cores 4
default_var cluster_1_num_cores 4
default_var cluster_2_num_cores 4
default_var cluster_3_num_cores 4

reset_var gicv3_gicv2_only

reset_var ccn502_cache_size_in_kbytes

reset_var aarch64_only

source "$ci_root/model/fvp_common.sh"

cat <<EOF >>"$model_param_file"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003

${bmcov_plugin+--plugin=$bmcov_plugin_path}

${cluster_0_num_cores+-C cluster0.NUM_CORES=$cluster_0_num_cores}
${cluster_1_num_cores+-C cluster1.NUM_CORES=$cluster_1_num_cores}
${cluster_2_num_cores+-C cluster2.NUM_CORES=$cluster_2_num_cores}
${cluster_3_num_cores+-C cluster3.NUM_CORES=$cluster_3_num_cores}

${reset_to_bl31+-C cluster0.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster0.cpu3.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster1.cpu3.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster2.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster2.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster2.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster2.cpu3.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster3.cpu0.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster3.cpu1.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster3.cpu2.RVBAR=${bl31_addr:?}}
${reset_to_bl31+-C cluster3.cpu3.RVBAR=${bl31_addr:?}}

${el3_payload_bin+--data cluster0.cpu0=$el3_payload_bin@${el3_payload_addr:?}}

${aarch64_only+-C cluster2.max_32bit_el=-1}
${aarch64_only+-C cluster3.max_32bit_el=-1}

${gicv3_gicv2_only+-C gicv3.gicv2-only=$gicv3_gicv2_only}

${ccn502_cache_size_in_kbytes+-C ccn502.cache_size_in_kbytes=$ccn502_cache_size_in_kbytes}

${etm_present+-C cluster0.cpu0.etm-present=$etm_present}
${etm_present+-C cluster0.cpu1.etm-present=$etm_present}
${etm_present+-C cluster0.cpu2.etm-present=$etm_present}
${etm_present+-C cluster0.cpu3.etm-present=$etm_present}
${etm_present+-C cluster1.cpu0.etm-present=$etm_present}
${etm_present+-C cluster1.cpu1.etm-present=$etm_present}
${etm_present+-C cluster1.cpu2.etm-present=$etm_present}
${etm_present+-C cluster1.cpu3.etm-present=$etm_present}
${etm_present+-C cluster2.cpu0.etm-present=$etm_present}
${etm_present+-C cluster2.cpu1.etm-present=$etm_present}
${etm_present+-C cluster2.cpu2.etm-present=$etm_present}
${etm_present+-C cluster2.cpu3.etm-present=$etm_present}
${etm_present+-C cluster3.cpu0.etm-present=$etm_present}
${etm_present+-C cluster3.cpu1.etm-present=$etm_present}
${etm_present+-C cluster3.cpu2.etm-present=$etm_present}
${etm_present+-C cluster3.cpu3.etm-present=$etm_present}

EOF
