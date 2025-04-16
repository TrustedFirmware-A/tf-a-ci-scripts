#!/usr/bin/env bash
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

arm_automotive_solutions="${rd1ae_prebuilts:-$tfa_downloads/arm_automotive_solutions}"

# RD-1 AE AP bl2 0x00 is mapped to 0x70083C00 in RSE memory map
rd1ae_ap_bl2_flash_load_addr=0x70083C00
rd1ae_ap_bl2_flash_size=0x80000
