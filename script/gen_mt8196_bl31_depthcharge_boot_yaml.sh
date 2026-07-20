#!/usr/bin/env bash
#
# Copyright (c) 2026 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate a YAML file in order to dispatch Rauru Chromebook runs on LAVA. Note that
# this script would produce a meaningful output when run via. Jenkins.
#
# $bin_mode must be set. This script outputs to STDOUT

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

get_bl31_url() {
	local bin_mode="${bin_mode:?}"

	if upon "$jenkins_run"; then
		echo "$jenkins_url/job/$JOB_NAME/$BUILD_NUMBER/artifact/artefacts/$bin_mode/bl31.elf"
	else
		echo "file://$workspace/artefacts/$bin_mode/bl31.elf"
	fi
}

bl31_url="${bl31_url:-$(get_bl31_url)}" \
build_mode=$(echo $bin_mode | tr '[:lower:]' '[:upper:]') \
expand_template "$ci_root/script/lava-templates/mt8196-bl31-depthcharge-boot.yaml"
