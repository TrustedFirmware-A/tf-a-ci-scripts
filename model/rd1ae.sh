#!/usr/bin/env bash
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

if upon "$local_ci"; then
	set_model_path "$warehouse/SysGen/SubSystemModels/$model_version/$model_build/models/$model_flavour/FVP_RD_1_AE"
else
	source "$ci_root/fvp_utils.sh"
	# fvp_models variable contains the information for FVP paths, where 2nd field
	# points to the /opt/model/*/models/${model_flavour}
	models_dir="$(echo ${fvp_models[$model]} | awk -F ';' '{print $2}')"
	set_model_path "$models_dir"
fi

# Write model command line options
cat <<EOF >"$model_param_file"
-C css.sysctrl.scp.terminal_uart_scp.start_port=5007
-C css.ap_periph.terminal_ns_uart0.start_port=5008
-C css.ap_periph.terminal_sec_uart.start_port=5009
-C ros.disable_visualisation=1
-C css.sysctrl.si.disable_visualisation=1
-C css.sysctrl.rse.rom.raw_image=$rse_rom_bin
-C css.sysctrl.rse_flashloader.fname=$rse_flash_bin
-C ros.board.flashloader0.fname=$fip_gpt_bin
-C ros.board.virtioblockdevice.image_path=$rootfs_bin
-C ros.board.virtio_net.enabled=1
-C ros.board.virtio_net.hostbridge.userNetworking=1
-C ros.board.virtio_net.hostbridge.userNetPorts=2222=22
-C ros.board.virtio_net.transport=legacy
-C ros.board.virtio_rng.enabled=1
-C ros.dram_size=0x100000000
-C css.sysctrl.rse.DISABLE_GATING=1
-C css.sysctrl.rse.CMU4_NUM_DB_CH=6
-C css.sysctrl.si.system_ctrl_regs.cl1_c1_cfgrvbaraddr=0x140000000
-C css.sysctrl.si.system_ctrl_regs.cl2_c1_cfgrvbaraddr=0x160000000
-C css.sysctrl.si.system_ctrl_regs.cl2_c2_cfgrvbaraddr=0x160000000
-C css.sysctrl.si.system_ctrl_regs.cl2_c3_cfgrvbaraddr=0x160000000
-C 'pcie_group_0.pcie4.hierarchy_file_name=<default>'
-C pcie_group_0.pcie4.pcie_rc.ahci0.endpoint.ats_supported=true
-C pcie_group_0.pcie4.pcie_rc.ahci0.ahci.image_path=
-C pcie_group_0.pcie4.pci_smmuv3.mmu.SMMU_ROOT_IDR0=0
-C css.sysctrl.rse_flashloader.fnameWrite=$rse_flash_bin
-C ros.board.flashloader0.fnameWrite=$fip_gpt_bin
-C css.sysctrl.rse_flashloader.write_flash_after_reset=true
-C ros.board.flashloader0.write_flash_after_reset=true
-C css.sysctrl.rse.lcm_nvm.otp_enabled=1
-C css.sysctrl.rse.lcm_nvm.read_from_file=1
-C css.sysctrl.rse.lcm_nvm.update_raw_image=1
-C css.sysctrl.rse.lcm_nvm.use_image_file=1
-C css.sysctrl.rse.clk_mul.mul=5
-C css.sysctrl.rse.intchecker.ICBC_RESET_VALUE=0x0000011B
--data css.sysctrl.rse.cpu=$rse_encrypted_cm_provisioning_bundle_0_bin@0x31000400
--data css.sysctrl.rse.cpu=$rse_encrypted_dm_provisioning_bundle_bin@0x31080000

EOF
