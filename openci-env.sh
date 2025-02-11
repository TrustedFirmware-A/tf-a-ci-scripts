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
jenkins_url="${JENKINS_PUBLIC_URL}"
tfa_downloads="${DOWNLOAD_SERVER_URL}/tf-a"
ci_env="openci"

tfa_branch=${TF_GERRIT_BRANCH##*/}
if echo $tfa_branch | grep -q "^lts-v"; then
    # LTS branch, change the download space to the respective one
    tfa_downloads="${DOWNLOAD_SERVER_URL}/tf-a-$tfa_branch"
fi
