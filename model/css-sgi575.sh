#!/usr/bin/env bash
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/SubSystemModels/11.15/26/models/Linux64_GCC-6.4/FVP_CSS_SGI-575"

cat <<EOF >"$model_param_file"
-C board.terminal_0.start_port=5000
-C board.terminal_1.start_port=5001
-C css.mcp.terminal_uart0.start_port=5002
-C css.mcp.terminal_uart1.start_port=5003
-C css.scp.terminal_uart_aon.start_port=5004
-C css.terminal_uart1_ap.start_port=5005
-C css.terminal_uart_ap.start_port=5006
-C soc.terminal_mcp.start_port=5007
-C soc.terminal_s0.start_port=5008
-C soc.terminal_s1.start_port=5009

-C board.flashloader0.fname=$fip_bin
-C board.virtioblockdevice.image_path=$busybox_bin
-C css.cmn600.force_rnsam_internal=false
-C css.cmn600.mesh_config_file=SGI-575_cmn600.yml
-C css.gic_distributor.ITS-device-bits=20
-C css.mcp.ROMloader.fname=$mcp_rom_bin
-C css.pl011_uart_ap.unbuffered_output=1
-C css.pl011_uart1_ap.unbuffered_output=1
-C css.scp.ROMloader.fname=$scp_rom_bin
-C css.trustedBootROMloader.fname=$bl1_bin
-C soc.pl011_uart_mcp.unbuffered_output=1
-C soc.pl011_uart0.enable_dc4=0
-C soc.pl011_uart0.unbuffered_output=1
-C soc.pl011_uart1.unbuffered_output=1
--data css.scp.armcortexm7ct=$scp_ram_bin@$scp_ram_addr
--data css.mcp.armcortexm7ct=$mcp_ram_bin@0x0BF80000
EOF
