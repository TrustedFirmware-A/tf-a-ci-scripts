#!/usr/bin/env bash
#
# Copyright (c) 2023-2024 Arm Limited. All rights reserved.
# Copyright (c) 2024, STMicroelectronics - All Rights Reserved
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

gen_sp_min_bl2_sd_layout() {
    local layout_file="FlashLayout_sdcard-stm32mp15x-eval.tsv"
    local payload_type=${payload_type:?}

    case "$payload_type" in
        sp_min_bl2)
            cat <<EOF > $layout_file
#Opt	Id	Name	Type	IP	Offset	Binary
-	0x01	fsbl-boot	Binary	none	0x0	tf-a-stm32mp157c-ev1-usb.stm32
-	0x03	fip-boot	FIP	none	0x0	fip-stm32mp157c-ev1-trusted.bin
P	0x04	fsbl1	Binary	mmc0	0x00004400	tf-a-stm32mp157c-ev1.stm32
P	0x05	fsbl2	Binary	mmc0	0x00044400	tf-a-stm32mp157c-ev1.stm32
P	0x06	metadata1	Binary	mmc0	0x00084400	metadata_v2.bin
P	0x07	metadata2	Binary	mmc0	0x000C4400	metadata_v2.bin
P	0x08	fip-a	FIP	mmc0	0x00104400	fip.bin
PE	0x09	fip-b	FIP	mmc0	0x00504400	none
PE	0x0A	u-boot-env	Binary	mmc0	0x00904400	none
P	0x10	bootfs	System	mmc0	0x00984400	bootfs.ext2
P	0x12	rootfs	FileSystem	mmc0	0x02984400	rootfs.ext2
EOF
        ;;
    esac

    archive_file "$layout_file"
}

gen_stm32mp1_yaml() {
	local yaml_file="$workspace/stm32mp1.yaml"
	local job_file="$workspace/job.yaml"
	local payload_type="${payload_type:?}"

	bin_mode="$mode" payload_type="$payload_type" \
		"$ci_root/script/gen_stm32mp1_test_yaml.sh" > "$yaml_file"

	cp "$yaml_file" "$job_file"
	archive_file "$yaml_file"
	archive_file "$job_file"
}

set +u
