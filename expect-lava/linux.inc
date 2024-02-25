#
# Copyright (c) 2021 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with a Linux kernel
#

# Expect 8 CPUs in total by default
if [ -z "${num_cpus}" ]; then
	num_cpus=8
fi

failures='Kernel panic'
expect_string+=("i;Linux version;;${failures}")
failures='CPU[0-9]+: failed to come online'
expect_string+=("i;SMP: Total of ${num_cpus} processors activated;;${failures}")
expect_string+=('i;Freeing unused kernel memory')
