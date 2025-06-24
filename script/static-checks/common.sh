#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

function get_merge_base() {
    git fetch origin ${GERRIT_BRANCH#refs/heads/}
    git merge-base HEAD FETCH_HEAD | head -1
}
