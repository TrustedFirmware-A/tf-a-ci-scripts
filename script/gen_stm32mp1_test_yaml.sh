#!/usr/bin/env bash
#
# Copyright (c) 2023 Arm Limited. All rights reserved.
# Copyright (c) 2024, STMicroelectronics - All Rights Reserved
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate a YAML file in order to dispatch STM32MP1 runs on LAVA. Note that this
# script would produce a meaningful output when run via. Jenkins
#
# $bin_mode must be set. This script outputs to STDOUT

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"
source "$ci_root/stm32mp1_utils.sh"
payload_type=${payload_type:?}
build_mode=$(echo $bin_mode | tr '[:lower:]' '[:upper:]')
layout_file="FlashLayout_sdcard-stm32mp15x-eval.tsv"

# There will be two types of tests, SP_min BL2 and OP-TEE
# We do SP_min BL2 first
case "$payload_type" in
    sp_min_bl2)
        job_name="SP_min BL2"
        rep_bin_file="rep_bin.tar.bz2"
        ;;
esac

if upon "$jenkins_run"; then
    file_url="$jenkins_url/job/$JOB_NAME/$BUILD_NUMBER/artifact/artefacts/$bin_mode"
else
    file_url="file://$workspace/artefacts/$bin_mode"
fi

rep_bin_url="$file_url/$rep_bin_file"
flash_layout_url="$file_url/$layout_file"

expand_template "$(dirname "$0")/lava-templates/stm32mp1-boot-test.yaml"
