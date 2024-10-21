#!/usr/bin/env bash
#
# Copyright (c) 2020-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

tc_prebuilts="${tc_prebuilts:-$tfa_downloads/total_compute}"

kernel_list[tc-kernel]="$tc_prebuilts/Image"
initrd_list[tc-ramdisk]="$tc_prebuilts/uInitrd-busybox.0x88000000"

initrd_addr=0x8000000
kernel_addr=0x80000
scp_ram_addr=0x0bd80000

rse_rom_addr=0x11000000
vmmaddrwidth=19
rvbaddr_lw=0x0000
rvbaddr_up=0x0000

# AP bl1 0x00 is mapped to 0x70000000 in RSE memory map
ap_bl1_flash_load_addr=0x70000000
ap_bl1_flash_size=0x20000

if [ $plat_variant -eq 2 ]; then
	rse_revision="4ab7a20d"
elif [ $plat_variant -eq 3 ]; then
	rse_revision="2fe1f7e"
elif [ $plat_variant -eq 4 ]; then
	rse_revision="213c553bf"
fi

# Hafnium build repo containing Secure hafnium binaries
spm_secure_out_dir=secure_tc_clang

# TC platform doesnt have non secure hafnium build configuration. Hence, we
# set it to an arbitrary name.
spm_non_secure_out_dir=not_found
