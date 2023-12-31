#!/usr/bin/env bash
#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Environmental settings for the OpenCI staging infrastructure.
#

nfs_volume="${WORKSPACE:?}/nfs"
jenkins_url="http://ci.staging.trustedfirmware.org"
tfa_downloads="https://downloads.trustedfirmware.org/tf-a"
ci_env="openci_staging"
