#!/usr/bin/env bash
#
# Copyright (c) 2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/fvp_utils.sh"

basev2_prebuilt_revision="${basev2_prebuilt_revision:-${BASEV2_PREBUILT_REVISION:-2026-09-16}}"
basev2_prebuilts="${basev2_prebuilts:-${BASEV2_PREBUILTS:-$DOWNLOAD_SERVER_TF_A_URL/basev2/$basev2_prebuilt_revision}}"
basev2_rse_prebuilts="$basev2_prebuilts/rse"

# Prepare external inputs for TF-A's flash image target.
fetch_basev2_flashimage_inputs() {
	git -C "$tf_root" submodule update --init contrib/mcuboot || return
	basev2_signing_dir="$(mktempdir)" || return
	(
		cd "$basev2_signing_dir" || return
		url="$basev2_prebuilts/root-EC-P256.pem" \
			saveas="root-EC-P256.pem" fetch_file || return
		url="$basev2_prebuilts/wrapper_scripts" \
			saveas="wrapper_scripts" fetch_directory || return
	) || return

	local image
	for image in rse_bl2_signed.bin rse_s_encrypted.bin \
		rse_s_sic_tables_signed.bin signed_scp-css.bin; do
		url="$basev2_rse_prebuilts/$image" saveas="$image" fetch_file || return
		archive_file "$image" || return
	done
}

get_rse_prov_bins() {
	url="$basev2_rse_prebuilts/rse_rom.bin" saveas="rse_rom.bin" fetch_file
	archive_file "rse_rom.bin"
	url="$basev2_rse_prebuilts/rse_combined_provisioning_message.bin" \
		saveas="rse_combined_provisioning_message.bin" fetch_file
	archive_file "rse_combined_provisioning_message.bin"
}
