#!/usr/bin/env bash
#
# Copyright (c) 2019-2024 Arm Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

nrd_prebuilts="${nrd_prebuilts:-$tfa_downloads/neoverse_rd/sgi575}"

# Pre-built SCP/MCP binaries
scp_mcp_prebuilts="${scp_mcp_prebuilts:-$scp_mcp_downloads/neoverse-rd/sgi575/release}"

kernel_list[nrd-busybox]="$nrd_prebuilts/Image"
initrd_list[nrd-ramdisk]="$nrd_prebuilts/ramdisk-busybox.img"

scp_ram_addr=0x0bd80000
mcp_ram_addr=0x0be00000
