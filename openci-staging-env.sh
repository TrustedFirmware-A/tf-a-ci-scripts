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

tfa_branch=${TF_GERRIT_BRANCH##*/}
if echo $tfa_branch | grep -q "^lts-v"; then
    # LTS branch, change the download space to the respective one
    tfa_downloads="https://downloads.trustedfirmware.org/tf-a-$tfa_branch"
fi

echo "*************************************"
echo "ci_env: $ci_env"
echo "tfa_downloads: $tfa_downloads"
echo "*************************************"

