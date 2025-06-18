#!/usr/bin/env bash
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

echo '----------------------------------------------'
echo '-- Running Rust formatting and lint checks  --'
echo '----------------------------------------------'

export LOG_TEST_FILENAME=$(pwd)/next-checks.log
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
    git fetch --unshallow --update-shallow origin
    git fetch --unshallow --update-shallow origin ${GERRIT_BRANCH} ${GERRIT_REFSPEC}

    export merge_base=$(git merge-base \
      $(head -n1 .git/FETCH_HEAD | cut -f1) \
      $(tail -n1 .git/FETCH_HEAD | cut -f1))
fi

# Find the absolute path of the scripts' top directory
cd "$(dirname "$0")/../.."
export CI_ROOT=$(pwd)
cd -

echo
echo "###### Rust checks ######" > "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

echo "Patch series being checked:" >> "$LOG_TEST_FILENAME"
git log --oneline ${merge_base}..HEAD >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
echo "Base branch reference commit:" >> "$LOG_TEST_FILENAME"
git log --oneline -1 ${merge_base} >> "$LOG_TEST_FILENAME"

echo >> "$LOG_TEST_FILENAME"

ERROR_COUNT=0

# Ensure all the files contain a copyright

"$CI_ROOT"/script/static-checks/static-checks-check-copyright.sh . --rusted

if [ "$?" != 0 ]; then
  echo "Copyright test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Copyright test: PASS"
fi
echo

# Check line endings

if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    "$CI_ROOT"/script/static-checks/static-checks-coding-style-line-endings.sh . patch
else
    "$CI_ROOT"/script/static-checks/static-checks-coding-style-line-endings.sh
fi

if [ "$?" != 0 ]; then
  echo "Line ending test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Line ending test: PASS"
fi
echo

# Check coding style with cargo fmt

"$CI_ROOT"/script/next-checks/next-checks-cargo-fmt.sh .

if [ "$?" != 0 ]; then
  echo "cargo fmt test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "cargo fmt test: PASS"
fi
echo

# Check documentation with cargo doc

"$CI_ROOT"/script/next-checks/next-checks-cargo-doc.sh .

if [ "$?" != 0 ]; then
  echo "cargo doc test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "cargo doc test: PASS"
fi
echo

# Check lints with clippy

"$CI_ROOT"/script/next-checks/next-checks-clippy.sh .

if [ "$?" != 0 ]; then
  echo "Rust clippy: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Rust clippy: PASS"
fi
echo

if [ "$ERROR_COUNT" != 0 ]; then
  echo "Some static checks have failed."
  exit 1
fi

exit 0
