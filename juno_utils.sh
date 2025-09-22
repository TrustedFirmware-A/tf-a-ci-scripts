#!/usr/bin/env bash
#
# Copyright (c) 2019-2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

# Pre-built SCP/MCP binaries
scp_bl1_url="$scp_mcp_downloads/juno/platform_variant_BOARD/release/juno-bl1-bypass.bin"
scp_bl2_url="$scp_mcp_downloads/juno/platform_variant_BOARD/release/juno-bl2.bin"

psci_reset2_scp_bl2_url="$tfa_downloads/psci_reset2/scp_bl2.bin"
uboot_bl33_url="$linaro_release/juno-latest-oe-uboot/SOFTWARE/bl33-uboot.bin"
ml_uboot_bl33_url="$tfa_downloads/linux_boot/u-boot-juno.bin"
uboot_env_url="$tfa_downloads/linux_boot/u-boot-env.bin"
optee_fip_url="$linaro_release/juno-ack-android-uboot/SOFTWARE/fip.bin"

linux_image_url="$tfa_downloads/linux_boot/Image.gz"
# Busybox based initrd
linux_busybox_initrd_url="$tfa_downloads/linux_boot/initbb.img"

juno_recovery_root="$linaro_release/juno-latest-oe-uboot"

uboot32_fip_url="$linaro_release/juno32-latest-oe-uboot/SOFTWARE/fip.bin"
juno32_recovery_root="$linaro_release/juno32-latest-busybox-uboot"
juno32_recovery_root_oe="$linaro_release/juno32-latest-oe-uboot"

juno_rootfs_url="${juno_rootfs_url:-$linaro_release/linaro-image-minimal-genericarmv8-20170127-888.rootfs.tar.gz}"
juno32_rootfs_url="${juno32_rootfs_url:-$linaro_release/linaro-image-alip-genericarmv7a-20150710-336.rootfs.tar.gz}"

get_ml_uboot_bin() {
	url="$ml_uboot_bl33_url" saveas="uboot.bin" fetch_file
	archive_file "uboot.bin"
	url="$uboot_env_url" saveas="blank.img" fetch_file
	archive_file "blank.img"
}

get_linux_image() {
	url="$linux_image_url" saveas="Image" fetch_file
	archive_file "Image"
	url="$linux_busybox_initrd_url" saveas="ramdisk.img" fetch_file
	archive_file "ramdisk.img"
}

gen_recovery_image32() {
	url="$juno32_recovery_root" gen_recovery_image "$@"
}

gen_recovery_image32_oe() {
	url="$juno32_recovery_root_oe" gen_recovery_image "$@"
}

gen_recovery_image() {
	local zip_dir="$workspace/juno_recovery"
	local zip_file="${zip_dir}.zip"
	local url="${url:-$juno_recovery_root}"

	saveas="$zip_dir" url="$url" fetch_directory
	if [ "$*" ]; then
		# Replace files needed for this test. Copying them first so
		# that the subsequent copy can replace it if necessary.
		url="$scp_bl1_url" saveas="$zip_dir/SOFTWARE/scp_bl1.bin" fetch_file
		cp -f "$@" "$zip_dir/SOFTWARE"
	fi

	# The Linaro recovery image has a bug in the images.txt files, which
	# puts the U-Boot environment in the wrong place (the address is
	# relative to the beginning of NOR flash, it's not an absolute MMIO
	# address). Fix that up so that we can update the environment.
	sed -ie "s/0x0BFC0000/0x03FC0000/" "$zip_dir"/SITE1/HBI0262?/images.txt

	# If an image.txt file was specified, replace all image.txt file inside
	# the recovery with the specified one.
	if upon "$image_txt"; then
		find "$zip_dir" -name images.txt -exec cp -f "$image_txt" {} \;
	fi

	(cd "$zip_dir" && zip -rq "$zip_file" -- *)
	archive_file "$zip_file"
}

gen_juno_yaml() {
	local yaml_file="$workspace/juno.yaml"
	local job_file="$workspace/job.yaml"
	local payload_type="${payload_type:?}"

	bin_mode="$mode" juno_revision="$juno_revision" \
		"$ci_root/script/gen_juno_${payload_type}_yaml.sh" > "$yaml_file"

	cp "$yaml_file" "$job_file"
	archive_file "$yaml_file"
	archive_file "$job_file"
}

juno_aarch32_runtime() {
	echo "Building BL32 in AArch32 for Juno:"
	sed 's/^/\t/' < "${config_file:?}"

	# Build BL32 for Juno in AArch32. Since build_tf does a realclean, we'll
	# lose the tools binaries. Build that again for later use.
	if upon "$(get_tf_opt TRUSTED_BOARD_BOOT)"; then
		tf_build_targets="fiptool certtool bl32"
	else
		tf_build_targets="fiptool bl32"
	fi

	tf_build_config="$config_file" tf_build_targets="$tf_build_targets" \
		build_tf

	# Copy BL32 to a temporary directoy, and update it in the FIP
	local tmpdir="$(mktempdir)"
	from="$tf_build_root/juno/$mode" to="$tmpdir" collect_build_artefacts
	bin_name="tos-fw" src="$tmpdir/bl32.bin" fip_update
}

set +u
