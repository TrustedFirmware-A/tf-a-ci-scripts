#!/usr/bin/env bash
#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Environmental settings for the OpenCI infrastructure.
#

nfs_volume="${WORKSPACE:?}/nfs"
jenkins_url="http://ci.trustedfirmware.org"
tfa_downloads="${DOWNLOAD_SERVER_URL}/tf-a"
