#!/usr/bin/env bash
#
# Copyright (c) 2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Arguments to boot BaseV2 platform model
# Use arch rev 8.1 which has mandatory CRC32 needed to support
# GPT checksum verification in BaseV2 software stack
cat >"$model_param_file" <<EOF
--data board.dram=${basev2_fitImage_bin:?}@0x20000000
-C board.flashloader0.fname=${fip_gpt_bin:?}
-C css.sms.rse.rom.raw_image=${rse_rom_bin:?}
--data css.sms.rse.sram0=${rse_combined_provisioning_message_bin:?}@0x400
-C css.sms.rse_pl011_uart.uart_enable=1
-C css.terminal_uart_ap.start_port=5000
-C css.terminal_uart1_ap.start_port=5001
-C css.sms.scp.terminal_uart.start_port=5002
-C css.sms.rse_terminal_uart.start_port=5003
-C css.cluster0.has_arm_v8-1=1
-C css.cluster1.has_arm_v8-1=1
-C disable_visualisation=true
EOF

# Overrides needed by the current model, planned to become model defaults.
cat >>"$model_param_file" <<EOF
-C css.sms.rse.sic.SIC_AUTH_ENABLE=1
-C css.sms.rse.sic.SIC_DECRYPT_ENABLE=1
-C css.cluster0.NUM_CORES=4
-C css.cluster1.NUM_CORES=4
-C css.cluster0.has_internal_ppu_support=1
-C css.cluster1.has_internal_ppu_support=1
-C css.cluster0.cpu0.MPIDR-override=0x01000000
-C css.cluster0.cpu1.MPIDR-override=0x01000100
-C css.cluster0.cpu2.MPIDR-override=0x01000200
-C css.cluster0.cpu3.MPIDR-override=0x01000300
-C css.cluster1.cpu0.MPIDR-override=0x01010000
-C css.cluster1.cpu1.MPIDR-override=0x01010100
-C css.cluster1.cpu2.MPIDR-override=0x01010200
-C css.cluster1.cpu3.MPIDR-override=0x01010300
-C css.cluster0.gicv3.extended-interrupt-range-support=1
-C css.cluster1.gicv3.extended-interrupt-range-support=1
EOF
