#!/usr/bin/env bash
#
# Copyright (c) 2020-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Fast forward master branch with integration

set -ex

mkdir -p ~/.ssh/
ssh-keyscan -p 29418 review.trustedfirmware.org >> ~/.ssh/known_hosts
export GIT_SSH_COMMAND="ssh -i $CI_BOT_KEY -o StrictHostKeyChecking=no -o 'PubkeyAcceptedKeyTypes +ssh-rsa'"

# Use a directory which won't clash with a r/o clone made for building.
clone_dir=trusted-firmware-a-for-update

git clone ssh://$CI_BOT_USERNAME@review.trustedfirmware.org:29418/${GERRIT_PROJECT_PREFIX:-}TF-A/trusted-firmware-a ${clone_dir}
cd ${clone_dir}
git checkout master
git merge --ff-only origin/integration
git push origin master

cd ..
rm -rf ${clone_dir}
