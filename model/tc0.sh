#!/usr/bin/env bash
#
# Copyright (c) 2020-2021, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/SubSystemModels/11.17/18/models/$model_flavour/FVP_TC0"

cat <<EOF >"$model_param_file"
-C board.terminal_0.start_port=5000
-C board.terminal_1.start_port=5001
-C css.terminal_uart1_ap.start_port=5002
-C css.terminal_uart_ap.start_port=5003
-C soc.terminal_s0.start_port=5004
-C soc.terminal_s1.start_port=5005

${bl1_bin+-C css.trustedBootROMloader.fname=$bl1_bin}
${scp_rom_bin+-C css.scp.ROMloader.fname=$scp_rom_bin}
${fip_bin+-C board.flashloader0.fname=$fip_bin}
${initrd_bin+--data board.dram=$initrd_bin@${initrd_addr:?}}
${kernel_bin+--data board.dram=$kernel_bin@${kernel_addr:?}}
${uart0_out+-C soc.pl011_uart0.out_file=$uart0_out}
${uart0_out+-C soc.pl011_uart0.unbuffered_output=1}
${uart1_out+-C soc.pl011_uart1.out_file=$uart1_out}
${uart1_out+-C soc.pl011_uart1.unbuffered_output=1}
EOF
