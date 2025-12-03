#!/usr/bin/env bash
#
# Copyright (c) 2025, Arm Limited.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate a LAVA YAML job for Raspberry Pi DTMP boot tests.

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

rpi_image_url="${rpi_image_url:-$rpi_default_image_url}"
armstub_bin_url="${armstub_bin_url:-$rpi_default_armstub_url}"

expand_template "$ci_root/script/lava-templates/rpi-dtpm-boot.yaml"
