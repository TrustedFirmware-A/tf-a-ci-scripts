#!/usr/bin/env bash
#
# Copyright (c) 2020-2023, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Environmental settings for the Arm CI infrastructure.
#

nfs_volume="/arm"
jenkins_url="https://jenkins.oss.arm.com"
tfa_downloads="${DOWNLOAD_SERVER_URL:-https://downloads.trustedfirmware.org}/tf-a"
ci_env="armci"

# Source repositories.
arm_gerrit_url="gerrit.oss.arm.com"
tf_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/pdcs-platforms/ap/tf-topics.git"
tftf_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/trusted-firmware/tf-a-tests.git"
ci_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/pdswinf/ci/pdcs-platforms/platform-ci.git"
cc_src_repo_url="${cc_src_repo_url:-https://$arm_gerrit_url/tests/lava/test-definitions.git}"
cc_src_repo_tag="${cc_src_repo_tag:-kernel-team-workflow_2019-09-20}"
spm_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/trusted-firmware/spm.git"
spm_proj_ref_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/trusted-firmware/spm/project/reference.git"
spm_prebuilts_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/trusted-firmware/spm/prebuilts.git"
spm_driver_linux_arm_gerrit_repo="ssh://$arm_gerrit_url:29418/trusted-firmware/spm/driver/linux.git"

# Arm Coverity server.
export coverity_host="${coverity_host:-coverity.cambridge.arm.com}"
export coverity_port="${coverity_port:-8443}"

# License servers for the FVP models.
license_path_list=(
    "7010@cam-lic05.cambridge.arm.com"
    "7010@cam-lic07.cambridge.arm.com"
    "7010@cam-lic03.cambridge.arm.com"
    "7010@cam-lic04.cambridge.arm.com"
)
