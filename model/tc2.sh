#!/usr/bin/env bash
#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set_model_path "$warehouse/SysGen/SubSystemModels/11.18/28/models/$model_flavour/FVP_TC2"

cat <<EOF >"$model_param_file"
${fip_bin+-C board.flashloader0.fname=$fip_bin}
${initrd_bin+--data board.dram=$initrd_bin@${initrd_addr:?}}
${kernel_bin+--data board.dram=$kernel_bin@${kernel_addr:?}}
${uart0_out+-C soc.pl011_uart0.out_file=$uart0_out}
${uart0_out+-C soc.pl011_uart0.unbuffered_output=1}
${uart1_out+-C soc.pl011_uart1.out_file=$uart1_out}
${uart1_out+-C soc.pl011_uart1.unbuffered_output=1}
-C displayController=2
${rss_rom_bin+--data css.rss.cpu=$rss_rom_bin@${rss_rom_addr:?}}
${rss_flash_bin+--data css.rss.cpu=$rss_flash_bin@${rss_flash_addr:?}}
${vmmaddrwidth+-C css.rss.VMADDRWIDTH=$vmmaddrwidth}
${rvbaddr_lw+-C css.scp.c0_pik.rvbaraddr_lw=$rvbaddr_lw}
${rvbaddr_up+-C css.scp.c0_pik.rvbaraddr_up=$rvbaddr_up}
EOF
