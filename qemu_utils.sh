#!/usr/bin/env bash
#
# Copyright (c) 2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

rootfs_url="$DOWNLOAD_SERVER_TF_A_URL/linux_boot/busybox.cpio.gz"
uefi_url="$DOWNLOAD_SERVER_TF_A_URL/linux_boot/qemu/QEMU_EFI.fd"

# Default QEMU model variables
default_model_dtb="dtb.bin"

# QEMU Kernel URLs
declare -A kernel_list=(
	[qemu-busybox]="$DOWNLOAD_SERVER_TF_A_URL/linux_boot/Image.gz"
)

gen_qemu_yaml(){
	model="${model:?}"
	model_bin="${model_bin:qemu-system-aarch64}"

	yaml_template_file="$workspace/qemu_template.yaml"
	yaml_file="$workspace/qemu.yaml"
	yaml_job_file="$workspace/job.yaml"
	lava_model_params="$workspace/lava_model_params"

	# this function expects a template, quit if it is not present
	if [ ! -f "$yaml_template_file" ]; then
		return
	fi

	prompt="${prompt:-root@tf-busyboot:/root#}"

	# Any addition on this array requires an addition in the qemu
	# templates.
	declare -A qemu_artefact_urls=(
		[kernel]="$(gen_bin_url kernel.bin)"
		[bios]="$(gen_bin_url qemu_bios.bin)"
		[initrd]="$(gen_bin_url rootfs.bin.gz)"
		[uboot]="$(gen_bin_url uboot.bin)"
	)

	declare -A qemu_artefact_filters=(
		[kernel]="kernel.bin"
		[bios]="qemu_bios.bin"
		[initrd]="rootfs.bin"
		[uboot]="uboot.bin"
	)

	declare -A qemu_artefact_macros=(
		["kernel.bin"]="{kernel}"
		["qemu_bios.bin"]="{bios}"
		["rootfs.bin"]="{initrd}"
		["uboot.bin"]="{uboot}"
	)

	declare -a qemu_artefacts
	filter_artefacts qemu_artefacts qemu_artefact_filters

	lava_model_params="${lava_model_params}" \
		gen_lava_model_params qemu_artefact_macros

	yaml_template_file="$yaml_template_file" \
	yaml_file="$yaml_file" \
	yaml_job_file="$yaml_job_file" \
		gen_lava_job_def qemu_artefacts qemu_artefact_urls
}

gen_qemu_image(){
	local image=${image:?}
	local bl1_path=${bl1_path:?}
	local fip_path=${fip_path:?}

	# Cocatenate bl1 and fip images to create a single BIOS consumed by QEMU.
	cp $bl1_path "$image"
	dd if=$fip_path of="$image" bs=64k seek=4

	archive_file "$image"
}

set +u
