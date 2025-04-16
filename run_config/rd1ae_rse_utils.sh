#!/usr/bin/env bash
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

sign_host_ap_bl2_image() {
	# $1 ... host binary name to sign
	# $2 ... image load address
	# $3 ... signed bin size

	local tmpdir="$(mktemp -d)"
	host_bin="`basename ${1}`"
	signed_bin="signed_`basename ${1}`"
	host_binary_layout="`basename -s .bin ${1}`_ns"

	# Download the RSE public key
	url="$arm_automotive_solutions/rd1ae/root-EC-P256.pem" saveas="root-EC-P256.pem" fetch_file
	archive_file "root-EC-P256.pem"

	RSE_SIGN_PRIVATE_KEY=$archive/root-EC-P256.pem
	RSE_LAYOUT_WRAPPER_VERSION="0.0.7"

	cat << EOF > $tmpdir/$host_binary_layout
enum image_attributes {
	RE_IMAGE_LOAD_ADDRESS = $2,
	RE_SIGN_BIN_SIZE = $3,
};
EOF

	if [ ! -f $archive/$host_bin ]; then
		echo "$archive/$host_bin does not exist. Aborting...!"
		exit 1
	fi

	echo "Signing `basename ${1}`"
	# Get mcuboot
	git clone --branch v2.1.0 "https://github.com/mcu-tools/mcuboot.git" $tmpdir/mcuboot

	# Fetch wrapper script
	saveas="$tmpdir" url="$arm_automotive_solutions/rd1ae/wrapper_scripts" fetch_directory

	pushd $tmpdir/mcuboot/scripts
	python3 $tmpdir/wrapper_scripts/wrapper/wrapper.py \
		-v $RSE_LAYOUT_WRAPPER_VERSION \
		--layout $tmpdir/$host_binary_layout \
		-k $RSE_SIGN_PRIVATE_KEY \
		--public-key-format full \
		--align 1 \
		--pad \
		--pad-header \
		--measured-boot-record \
		-H 0x400 \
		-s auto \
		$archive/$host_bin  \
		$tmpdir/$signed_bin

	echo "Generated signed_`basename ${1}`"

	url="$tmpdir/$signed_bin" saveas="$signed_bin" fetch_file
	archive_file "$signed_bin"
	popd
}

downlaod_rd1ae_prebuilt() {
	url="$arm_automotive_solutions/rd1ae/core-image-minimal-fvp-rd-kronos.wic" saveas="rootfs.bin" fetch_file
	archive_file "rootfs.bin"

	# Get pre-built rse encrypted_cm_provisioning_bundle_0 bin
	url="$arm_automotive_solutions/rd1ae/encrypted_cm_provisioning_bundle_0.bin" \
		saveas=rse_encrypted_cm_provisioning_bundle_0.bin fetch_file
	archive_file "rse_encrypted_cm_provisioning_bundle_0.bin"

	# Get pre-built rse encrypted_dm_provisioning_bundle bin
	url="$arm_automotive_solutions/rd1ae/encrypted_dm_provisioning_bundle_0.bin" \
		saveas=rse_encrypted_dm_provisioning_bundle.bin fetch_file
	archive_file "rse_encrypted_dm_provisioning_bundle.bin"

	# Get pre-built rse-rom-image.img
	url="$arm_automotive_solutions/rd1ae/rse-rom-image.img" saveas=rse_rom.bin fetch_file
	archive_file "rse_rom.bin"

	# Get pre-built rse-flash-image.img
	url="$arm_automotive_solutions/rd1ae/rse-flash-image.img" saveas=rse_flash.bin fetch_file
	archive_file "rse_flash.bin"

	# Get pre-built rse-nvm-image.img
	url="$arm_automotive_solutions/rd1ae/rse-nvm-image.img" fetch_file
	archive_file "rse-nvm-image.img"
}

update_ap_flash_image() {
	# Downlaod prebuilt ap-flash-image.img
	url="$arm_automotive_solutions/rd1ae/ap-flash-image.img" saveas=fip_gpt.bin fetch_file
	archive_file "fip_gpt.bin"

	if [ ! -f "$archive/fip.bin" ]; then
		echo "$archive/fip.bin does not exist. Aborting...!"
		exit 1
	fi

	echo "Updating ap-flash-image..."
	dd if=$archive/fip.bin of=$archive/fip_gpt.bin bs=1 seek=0 conv=notrunc
	dd if=$archive/fip.bin of=$archive/fip_gpt.bin bs=1 seek=$((0x200000)) conv=notrunc
	echo "Succesfully updated."
}
