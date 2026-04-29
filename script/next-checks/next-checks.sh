#!/usr/bin/env bash
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

echo '----------------------------------------------'
echo '-- Running Rust formatting and lint checks  --'
echo '----------------------------------------------'

LOG_TEST_FILENAME="${LOG_TEST_FILENAME:-"next-checks.log"}"
LOG_TEST_FILENAME="$(realpath -m "${LOG_TEST_FILENAME}")"

export LOG_TEST_FILENAME
export RUSTUP_HOME=/usr/local/rustup

merge_base=$(git merge-base \
    "refs/remotes/origin/${GERRIT_BRANCH:?}" \
    "refs/remotes/origin/${GERRIT_REFSPEC:?}")

export merge_base

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
