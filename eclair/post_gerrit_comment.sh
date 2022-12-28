#!/bin/bash
#
# Copyright (c) 2019-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
set -ex

# Set to 0 to temporarily disable posting comments to Gerrit.
should_post_comment=1

# Don't post comments if run on the staging server.
if echo "$JENKINS_URL" | grep -q "ci\.staging"; then
    should_post_comment=0
fi

# Always enable posting comments to sandbox (test) projects, even if they're
# disabled above.
if echo "${GERRIT_PROJECT}" | grep -q sandbox; then
    should_post_comment=1
fi

if [ $should_post_comment -eq 1 ]; then
    mkdir -p ~/.ssh/
    ssh-keyscan -H -p 29418 $GERRIT_HOST >> ~/.ssh/known_hosts

    quoted="$(python3 -c 'import sys, shlex; print(shlex.quote(open(sys.argv[1]).read()))' misra_delta.txt)"

    ssh -o "PubkeyAcceptedKeyTypes +ssh-rsa" -p 29418 -i "$CI_BOT_KEY" "$CI_BOT_USERNAME@$GERRIT_HOST" gerrit \
        review  "$GERRIT_CHANGE_NUMBER,$GERRIT_PATCHSET_NUMBER" \
        --message "$quoted"
fi
