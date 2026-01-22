#!/usr/bin/env bash
#
# Copyright (c) 2025, Arm Limited.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

image_base_url="https://downloads.trustedfirmware.org/infra-assets/linaro_artifacts/lava/tf-a/rpi3b/"

rpi_default_image_url="${image_base_url}/2025-10-01-raspios-trixie-arm64-lite.img.xz"
rpi_default_armstub_url="${image_base_url}/armstub8.bin"

get_rpi_armstub_url() {
	if [ -f "${archive:?}/armstub8.bin" ]; then
		echo "$(gen_bin_url armstub8.bin)"
	else
		echo "$rpi_default_armstub_url"
	fi
}

get_rpi_image_url() {
	echo "${rpi_image_url:-$rpi_default_image_url}"
}

gen_rpi_yaml() {
	local yaml_file="$workspace/rpi.yaml"
	local job_file="$workspace/job.yaml"
	local payload_type="${payload_type:-dtpm_boot}"
	local generator

	case "$payload_type" in
	dtpm_boot)
		generator="$ci_root/script/gen_rpi_dtpm_boot_yaml.sh"
		;;
	*)
		echo "Unsupported Raspberry Pi payload type: $payload_type" >&2
		return 1
		;;
	esac

	local resolved_image_url
	local resolved_armstub_url

	resolved_image_url="$(get_rpi_image_url)"
	resolved_armstub_url="${armstub_bin_url:-$(get_rpi_armstub_url)}"

	bin_mode="$mode" \
		rpi_image_url="$resolved_image_url" \
		armstub_bin_url="$resolved_armstub_url" \
		"$generator" >"$yaml_file"

	cp "$yaml_file" "$job_file"
	archive_file "$yaml_file"
	archive_file "$job_file"
}

set +u
