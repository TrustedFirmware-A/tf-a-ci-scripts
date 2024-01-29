#!/usr/bin/env bash
#
# Copyright (c) 2023-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

sign_image() {
	# $1 ... host binary name to sign
	# $2 ... image load address
	# $3 ... signed bin size

	local tmpdir="$(mktempdir)"
	host_bin="`basename ${1}`"
	signed_bin="signed_`basename ${1}`"
	host_binary_layout="`basename -s .bin ${1}`_ns"

	# development PEM containing a key - use same key which is used for SCP BL1 in pre-built image
	url="$tc_prebuilts/tc$plat_variant/root-RSA-3072.pem" saveas="root-RSA-3072.pem" fetch_file
	archive_file "root-RSA-3072.pem"

	RSS_SIGN_PRIVATE_KEY=$archive/root-RSA-3072.pem
	RSS_SEC_CNTR_INIT_VAL=1
	RSS_LAYOUT_WRAPPER_VERSION="1.5.0"

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
	git clone "https://github.com/mcu-tools/mcuboot.git" $tmpdir/mcuboot
	# Fetch wrapper script
	saveas="$tmpdir" url="$tc_prebuilts/tc$plat_variant/wrapper_scripts" fetch_directory

	echo "Installing dependencies..."
	pip3 install cryptography cbor2 intelhex pyyaml

	pushd $tmpdir/mcuboot/scripts
	python3 $tmpdir/wrapper_scripts/wrapper/wrapper.py \
		-v $RSS_LAYOUT_WRAPPER_VERSION \
		--layout $tmpdir/$host_binary_layout \
		-k $RSS_SIGN_PRIVATE_KEY \
		--public-key-format full \
		--align 1 \
		--pad \
		--pad-header \
		-H 0x2000 \
		-s $RSS_SEC_CNTR_INIT_VAL \
		$archive/$host_bin  \
		$tmpdir/$signed_bin

	echo "created signed_`basename ${1}`"
	url="$tmpdir/$signed_bin" saveas="$signed_bin" fetch_file
	archive_file "$signed_bin"
	popd
}

update_fip() {
	local prebuild_prefix=$tc_prebuilts/tc$plat_variant/$rss_revision

	# Get pre-built rss rom
	url="$prebuild_prefix/rss_rom.bin" fetch_file
	archive_file "rss_rom.bin"

	# Get pre-built rss bl2 signed bin
	url="$prebuild_prefix/rss_bl2_signed.bin" fetch_file
	archive_file "rss_bl2_signed.bin"

	# Get pre-built rss TF-M S signed bin
	url="$prebuild_prefix/rss_s_signed.bin" fetch_file
	archive_file "rss_s_signed.bin"

	# Get pre-built SCP signed bin
	url="$prebuild_prefix/signed_scp_romfw.bin" fetch_file
	archive_file "signed_scp_romfw.bin"

	# Create FIP layout
	"$fiptool" update \
		--align 8192 --rss-bl2 "$archive/rss_bl2_signed.bin" \
		--align 8192 --rss-s "$archive/rss_s_signed.bin" \
		--align 8192 --rss-scp-bl1 "$archive/signed_scp_romfw.bin" \
		--align 8192 --rss-ap-bl1 "$archive/$signed_bin" \
		--out "host_flash_fip.bin" \
		"$archive/fip.bin"
	archive_file "host_flash_fip.bin"
}

get_rss_prov_bins() {
	local prebuild_prefix=$tc_prebuilts/tc$plat_variant/$rss_revision

	# Get pre-built rss rss_encrypted_cm_provisioning_bundle_0 bin
	url="$prebuild_prefix/rss_encrypted_cm_provisioning_bundle_0.bin" fetch_file
	archive_file "rss_encrypted_cm_provisioning_bundle_0.bin"

	# Get pre-built rss rss_encrypted_dm_provisioning_bundle bin
	url="$prebuild_prefix/rss_encrypted_dm_provisioning_bundle.bin" fetch_file
	archive_file "rss_encrypted_dm_provisioning_bundle.bin"
}
