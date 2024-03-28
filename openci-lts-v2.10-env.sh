#!/usr/bin/env bash
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Environmental settings for the OpenCI LTS v2.10 infrastructure.
#

nfs_volume="${WORKSPACE:?}/nfs"
jenkins_url="http://ci.trustedfirmware.org"
tfa_downloads="https://downloads.trustedfirmware.org/tf-a-lts-v2.10"
