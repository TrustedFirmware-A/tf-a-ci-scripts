#!/usr/bin/env bash
#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

echo '----------------------------------------------'
echo '--           Running Cargo tests            --'
echo '----------------------------------------------'

export LOG_TEST_FILENAME=$(pwd)/next-generic-checks.log
export RUSTUP_HOME=/usr/local/rustup

# For local runs, we require GERRIT_BRANCH to be set to get the merge-base/diff
# between the checked out commit and the tip of $GERRIT_BRANCH - for running
# next tests, usually this will be tfa-next
export GERRIT_BRANCH=${GERRIT_BRANCH:="tfa-next"}

if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    # git operations rely on access to tfa-next branch, we need to access via SSH for that to work currently
    SSH_PARAMS="-o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PubkeyAcceptedKeyTypes=+ssh-rsa -p 29418 -i ${CI_BOT_KEY}"
    REPO_SSH_URL="ssh://${CI_BOT_USERNAME}@review.trustedfirmware.org:29418/TF-A/trusted-firmware-a"
    export GIT_SSH_COMMAND="ssh ${SSH_PARAMS}"
    git remote set-url origin ${REPO_SSH_URL}
    git fetch origin
fi

TEST_CASE="cargo test checks"

echo "# ${TEST_CASE}"
echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

cd rust

ERROR_COUNT=0

# Run cargo test

declare -a all_features=($(make PLAT=${platform} --silent list_features))
# append empty features by default
all_features+=("")

for features in "${all_features[@]}"; do
    echo "cargo test features: '$features'" >> "$LOG_TEST_FILENAME" 2>&1
    cargo test --features=$features >> "$LOG_TEST_FILENAME" 2>&1

    if [ "$?" != 0 ]; then
      echo "cargo test --features='$features': FAILURE"
      ((ERROR_COUNT++))
    else
      echo "cargo test --features='$features': PASS"
    fi

    echo "-------------------------------------" >> "$LOG_TEST_FILENAME" 2>&1
done

echo

cd -
if [ "$ERROR_COUNT" != 0 ]; then
  echo "Some cargo tests checks have failed."
  exit 1
fi

exit 0
