#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

function get_base_branch() {
    # Remove prefix
    echo origin/${TF_GERRIT_BRANCH#refs/heads/}
}

function get_merge_base() {
    git merge-base HEAD $(get_base_branch) | head -1
}
