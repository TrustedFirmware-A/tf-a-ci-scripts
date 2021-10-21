#!/usr/bin/env bash
#
# Copyright (c) 2020-2021, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

sgi_prebuilts="${sgi_prebuilts:-$css_downloads/sgi/rdn1edgex2}"

# Pre-built SCP/MCP binaries
scp_mcp_prebuilts="${scp_mcp_prebuilts:-$scp_mcp_downloads/rdn1e1/release}"

fvp_kernels[fvp-sgi-busybox]="$sgi_prebuilts/Image"
fvp_initrd_urls[fvp-sgi-ramdisk]="$sgi_prebuilts/ramdisk-busybox.img"

scp_ram_addr=0x0bd80000
mcp_ram_addr=0x0be00000
