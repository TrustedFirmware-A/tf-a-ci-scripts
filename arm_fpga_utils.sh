#!/bin/bash
#
# Copyright (c) 2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -u

#arm_fpga Kernel URLs
declare -A arm_fpga_kernels
arm_fpga_kernels=(
[test-kernel-aarch64]="$DOWNLOAD_SERVER_TF_A_URL/arm-fpga/kernel-image"
)

#arm_fpga initramfs
declare -A arm_fpga_initramfs
arm_fpga_initramfs=(
[busybox.initrd]="$DOWNLOAD_SERVER_TF_A_URL/arm-fpga/busybox.initrd"
)

get_kernel() {
	local kernel_type="${kernel_type:?}"
	local url="${arm_fpga_kernels[$kernel_type]}"
	local kernel_saveas="${saveas}"

	url="${url:?}" saveas="${kernel_saveas:?}" fetch_file
	archive_file "$kernel_saveas"
}

get_initrd() {
	local initrd_type="${initrd_type:?}"
	local url="${arm_fpga_initramfs[$initrd_type]}"
	local initrd_saveas="${saveas}"

	url="${url:?}" saveas="${initrd_saveas:?}" fetch_file
	archive_file "$initrd_saveas"
}

set +u
