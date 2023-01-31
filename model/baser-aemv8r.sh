#!/usr/bin/env bash
#
# Copyright (c) 2021, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

if  is_arm_jenkins_env || upon "$local_ci"; then
	# Internal ARM Jenkins environment path
	set_model_path "$warehouse/SysGen/Models/$model_version/$model_build/external/models/$model_flavour/FVP_BaseR_AEMv8R"
else
	# OpenCI support will be added in a future patch
	set_model_path ""
fi

# Write model command line options
cat <<EOF >"$model_param_file"
-C bp.terminal_0.start_port=5000
-C bp.terminal_1.start_port=5001
-C bp.terminal_2.start_port=5002
-C bp.terminal_3.start_port=5003

-C bp.pl011_uart0.unbuffered_output=1
-C bp.pl011_uart0.untimed_fifos=true
-C cache_state_modelled=0
-C bp.vis.rate_limit-enable=0
-C cluster0.NUM_CORES=4
-C cluster0.has_aarch64=1
-C bp.exclusive_monitor.monitor_access_level=1
-C cluster0.cpu0.RVBAR=0x80000000
-C cluster0.cpu1.RVBAR=0x80000000
-C cluster0.cpu2.RVBAR=0x80000000
-C cluster0.cpu3.RVBAR=0x80000000
-C bp.dram_metadata.init_value=0
-C bp.dram_metadata.is_enabled=true
-C bp.dram_size=8
-C bp.refcounter.non_arch_start_at_default=1
-C bp.ve_sysregs.mmbSiteDefault=0
-C cluster0.gicv3.cpuintf-mmap-access-level=2
-C cluster0.gicv3.SRE-enable-action-on-mmap=2
-C cluster0.gicv3.SRE-EL2-enable-RAO=1
-C cluster0.gicv3.extended-interrupt-range-support=1
-C cluster0.stage12_tlb_size=512
-C gic_distributor.GICD_CTLR-DS-1-means-secure-only=1
-C gic_distributor.GITS_BASER0-type=1
-C gic_distributor.ITS-count=1
-C gic_distributor.ITS-hardware-collection-count=1
-C gic_distributor.direct-lpi-support=1
-C gic_distributor.has-two-security-states=0
-C pctl.startup=0.0.0.*
-C bp.secureflashloader.fname=$bl1_bin
-C bp.virtioblockdevice.image_path=$rootfs_bin
--data cluster0.cpu0=$fip_bin@$fip_addr
--data cluster0.cpu0=$dtb_bin@$dtb_addr
--data cluster0.cpu0=$kernel_bin@$kernel_addr

EOF
