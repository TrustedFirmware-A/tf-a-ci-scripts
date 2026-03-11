#!/usr/bin/env bash
#
# Copyright (c) 2026, Arm Limited.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

mv_ddr_basename="mv-ddr-marvell"
mv_ddr_revision="7bcb9dc7ea7fa233bf96bd0350a4ec7c205e342e"
mv_ddr_default_url="${DOWNLOAD_SERVER_TF_A_URL}/${mv_ddr_basename}/${mv_ddr_basename}-${mv_ddr_revision}.tar.gz"

# Fetch the Marvell DDR sources into the workspace and export MV_DDR_PATH.
#
# Usage: fetch_mv_ddr_files [url] [target_dir]
#   url: Optional tarball URL. Defaults to the pinned Marvell DDR archive.
#   target_dir: Optional workspace-relative destination directory name.
#               Defaults to "mv-ddr-marvell".
fetch_mv_ddr_files() {
	local mv_ddr_url="${1:-$mv_ddr_default_url}"
	local mv_ddr_target_dir="${2:-$mv_ddr_basename}"
	local mv_ddr_archive_name="$(basename "$mv_ddr_url")"
	local mv_ddr_archive_path="$workspace/$mv_ddr_archive_name"
	local mv_ddr_target_path="$workspace/$mv_ddr_target_dir"

	if [ ! -d "$mv_ddr_target_path" ]; then
		saveas="$mv_ddr_archive_path" \
			url="$mv_ddr_url" \
			fetch_file

		mkdir -p "$mv_ddr_target_path"
		tar -C "$mv_ddr_target_path" --strip-components=1 -xzf "$mv_ddr_archive_path"
	fi

	[ -d "$mv_ddr_target_path" ] || die "Could not fetch ${mv_ddr_basename} into $mv_ddr_target_path"

	echo "Set MV_DDR_PATH to $mv_ddr_target_path"
	set_hook_var "MV_DDR_PATH" "$mv_ddr_target_path"
}

set +u
