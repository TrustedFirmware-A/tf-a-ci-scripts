#!/usr/bin/env bash
#
# Copyright (c) 2020-2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

sgi_prebuilts="${sgi_prebuilts:-$css_downloads/sgi/rdv1}"

# Pre-built SCP/MCP binaries
scp_mcp_prebuilts="${scp_mcp_prebuilts:-$scp_mcp_downloads/rdv1/release}"


kernel_list[sgi-busybox]="$sgi_prebuilts/Image"
initrd_list[sgi-ramdisk]="$sgi_prebuilts/ramdisk-busybox.img"

scp_ram_addr=0x0bd80000
mcp_ram_addr=0x0BF80000
