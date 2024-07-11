#!/usr/bin/env bash
#
# Copyright (c) 2022-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
set_model_path "$warehouse/SysGen/SubSystemModels/0.0/8304/models/$model_flavour/FVP_TC3"
cat <<EOF >"$model_param_file"
${fip_gpt_bin+-C board.flashloader0.fname=$fip_gpt_bin}
-C board.pl011_uart2.unbuffered_output=1
-C board.pl011_uart3.unbuffered_output=1
-C css.pl011_uart1_ap.unbuffered_output=1
-C css.pl011_uart_ap.unbuffered_output=1
-C soc.pl011_uart0.unbuffered_output=1
-C soc.pl011_uart1.unbuffered_output=1
-C css.sms.scp.uart.unbuffered_output=1
-C css.sms.rse_pl011_uart.unbuffered_output=1
-C css.terminal_uart_ap.start_port=5000
-C css.terminal_uart1_ap.start_port=5001
-C css.sms.scp.terminal_uart.start_port=5002
-C css.sms.rse_terminal_uart.start_port=5003
-C displayController=2
${rse_rom_bin+-C css.sms.rse.rom.raw_image=$rse_rom_bin}
-C css.sms.rse.VMADDRWIDTH=16
-C css.sms.rse.intchecker.ICBC_RESET_VALUE=0x0000011B
-C css.sms.rse.sic.SIC_AUTH_ENABLE=1
-C css.sms.rse.sic.SIC_DECRYPT_ENABLE=1
${rse_encrypted_cm_provisioning_bundle_0_bin+--data css.sms.rse.sram0=${rse_encrypted_cm_provisioning_bundle_0_bin}@0x400}
${rse_encrypted_dm_provisioning_bundle_bin+--data css.sms.rse.sram1=${rse_encrypted_dm_provisioning_bundle_bin}@0x0}
-C css.cluster0.subcluster0.has_ete=1
-C css.cluster0.subcluster1.has_ete=1
-C css.cluster0.subcluster2.has_ete=1
-C board.smsc_91c111.enabled=1
-C board.hostbridge.userNetworking=1
-C board.hostbridge.userNetPorts="8080=80,8022=22"
${tc_fitimage_bin+--data board.dram=$tc_fitimage_bin@0x20000000}
EOF
