#!/usr/bin/env bash
#
# Copyright (c) 2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generates a machine configuration for QEMU virt.
cat <<EOF >"$model_param_file"
-M virt
-machine 'secure=on,virtualization=on,gic-version=2'
-cpu max
-smp 4
-m 4G
-nographic -display none -d unimp
-append 'console=ttyAMA0,115200n8 root=/dev/vda earlycon'
${kernel_bin+-kernel $kernel_bin}
${rootfs_bin+-initrd $rootfs_bin}
${qemu_bios_bin+-bios $qemu_bios_bin}
${wait_debugger+-gdb tcp:localhost:9000}
${wait_debugger+-S}
EOF
