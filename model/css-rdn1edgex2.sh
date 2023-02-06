#!/usr/bin/env bash
#
# Copyright (c) 2020-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/SubSystemModels/11.17/33/models/$model_flavour/FVP_RD_N1_edge_dual"

cat <<EOF >"$model_param_file"
-C css0.scp.terminal_uart_aon.start_port=5000
-C css0.mcp.terminal_uart0.start_port=5001
-C css0.mcp.terminal_uart1.start_port=5002
-C css0.terminal_uart_ap.start_port=5003
-C css0.terminal_uart1_ap.start_port=5004
-C css1.scp.terminal_uart_aon.start_port=5005
-C css1.mcp.terminal_uart0.start_port=5006
-C css1.mcp.terminal_uart1.start_port=5007
-C css1.terminal_uart_ap.start_port=5008
-C css1.terminal_uart1_ap.start_port=5009
-C soc0.terminal_s0.start_port=5010
-C soc0.terminal_s1.start_port=5011
-C soc0.terminal_mcp.start_port=5012
-C board0.terminal_0.start_port=5013
-C board0.terminal_1.start_port=5014
-C soc1.terminal_s0.start_port=5015
-C soc1.terminal_s1.start_port=5016
-C soc1.terminal_mcp.start_port=5017
-C board1.terminal_0.start_port=5018
-C board1.terminal_1.start_port=5019

-C board0.flashloader0.fname=$fip_bin
-C board0.virtioblockdevice.image_path=$busybox_bin
-C css0.cmn600.force_rnsam_internal=false
-C css0.cmn600.mesh_config_file=RD_N1_E1_cmn600.yml
-C css0.gic_distributor.ITS-device-bits=20
-C css0.gic_distributor.multichip-threaded-dgi=0
-C css0.mcp.ROMloader.fname=$mcp_rom_bin
-C css0.pl011_uart_ap.unbuffered_output=1
-C css0.scp.pl011_uart_scp.unbuffered_output=1
-C css0.scp.ROMloader.fname=$scp_rom_bin
-C css0.trustedBootROMloader.fname=$bl1_bin
-C css1.cmn600.force_rnsam_internal=false
-C css1.cmn600.mesh_config_file=RD_N1_E1_cmn600.yml
-C css1.gic_distributor.ITS-device-bits=20
-C css1.gic_distributor.multichip-threaded-dgi=0
-C css1.mcp.ROMloader.fname=$mcp_rom_bin
-C css1.pl011_uart_ap.unbuffered_output=1
-C css1.scp.pl011_uart_scp.unbuffered_output=1
-C css1.scp.ROMloader.fname=$scp_rom_bin
-C css1.trustedBootROMloader.fname=$bl1_bin
-C soc0.pl011_uart_mcp.unbuffered_output=1
-C soc0.pl011_uart0.enable_dc4=0
-C soc0.pl011_uart0.flow_ctrl_mask_en=1
-C soc0.pl011_uart0.unbuffered_output=1
-C soc0.pl011_uart1.unbuffered_output=1
-C soc1.pl011_uart_mcp.unbuffered_output=1
-C soc1.pl011_uart0.unbuffered_output=1
-C soc1.pl011_uart1.unbuffered_output=1

--data css0.scp.armcortexm7ct=$scp_ram_bin@$scp_ram_addr
--data css1.scp.armcortexm7ct=$scp_ram_bin@$scp_ram_addr
EOF
