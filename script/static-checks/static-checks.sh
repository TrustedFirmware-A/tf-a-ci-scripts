#!/usr/bin/env bash
#
# Copyright (c) 2019-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

echo '----------------------------------------------'
echo '-- Running static checks on the source code --'
echo '----------------------------------------------'

# Find the absolute path of the scripts' top directory

cd "$(dirname "$0")/../.."
export CI_ROOT=$(pwd)
cd -

. $CI_ROOT/script/static-checks/common.sh

merge_base=$(get_merge_base)
if [[ -z "$merge_base" ]]; then
    echo "Failed to find merge base, fetching entire change history"

    # Set GERRIT_REFSPEC if not already defined
    if [[ -z "$GERRIT_REFSPEC" ]]; then
        if [[ "$TF_GERRIT_PROJECT" == *tf-a-tests ]]; then
            GERRIT_REFSPEC="$TFTF_GERRIT_REFSPEC"
        else
            GERRIT_REFSPEC="$TF_GERRIT_REFSPEC"
        fi
    fi

    git fetch --unshallow
    git fetch origin "$GERRIT_REFSPEC"
    git checkout FETCH_HEAD

    merge_base=$(get_merge_base)

    if [[ -z "$merge_base" ]]; then
        echo "Failed to determine merge base after fetching. Exiting." >&2
        exit 1
    fi
fi

export merge_base

export LOG_TEST_FILENAME=$(pwd)/static-checks.log

echo
echo "###### Static checks ######"
echo

echo "###### Static checks ######" > "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

echo "Patch series being checked:" >> "$LOG_TEST_FILENAME"
git log --oneline ${merge_base}..HEAD >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
echo "Base branch reference commit:" >> "$LOG_TEST_FILENAME"
git log --oneline -1 ${merge_base} >> "$LOG_TEST_FILENAME"


echo >> "$LOG_TEST_FILENAME"

# Reset error counters

ERROR_COUNT=0
WARNING_COUNT=0

# Ensure all the files contain a copyright

echo 'Checking copyright in source files...'
echo
"$CI_ROOT"/script/static-checks/static-checks-check-copyright.sh .
if [ "$?" != 0 ]; then
  echo "Copyright test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Copyright test: PASS"
fi
echo

# Check alphabetic order of headers included.

if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    "$CI_ROOT"/script/static-checks/static-checks-include-order.sh . patch
else
    "$CI_ROOT"/script/static-checks/static-checks-include-order.sh .
fi
if [ "$?" != 0 ]; then
  echo "Include order test: FAILURE"
  ((WARNING_COUNT++))
else
  echo "Include order test: PASS"
fi
echo

# Check ascending order of CPU ERRATUM and CVE added.

if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    "$CI_ROOT"/script/static-checks/static-checks-cpu-erratum-order.sh . patch
else
    "$CI_ROOT"/script/static-checks/static-checks-cpu-erratum-order.sh .
fi
if [ "$?" != 0 ]; then
  echo "CPU Errata, CVE in-order test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "CPU Errata, CVE in-order test: PASS"
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

# Check coding style

echo 'Checking coding style compliance...'
echo
if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    "$CI_ROOT"/script/static-checks/static-checks-coding-style.sh
else
    "$CI_ROOT"/script/static-checks/static-checks-coding-style-entire-src-tree.sh
fi
if [ "$?" != 0 ]; then
  echo "Coding style test: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Coding style test: PASS"
fi
echo

# Check for any Banned API usage

echo 'Checking Banned API usage...'
echo
if [ "$IS_CONTINUOUS_INTEGRATION" == 1 ]; then
    "$CI_ROOT"/script/static-checks/static-checks-banned-apis.sh . patch
else
    "$CI_ROOT"/script/static-checks/static-checks-banned-apis.sh
fi
if [ "$?" != 0 ]; then
  echo "Banned API check: FAILURE"
  ((ERROR_COUNT++))
else
  echo "Banned API check: PASS"
fi
echo

# Check to ensure newly added source files are detected for Coverity Scan analysis

# Check to be executed only on trusted-firmware repository.
if [ "$REPO_UNDER_TEST" = "trusted-firmware" ] || [ "$REPO_UNDER_TEST" = "trusted-firmware-a" ]; then
    echo 'Checking whether the newly added source files are detected for Coverity Scan analysis...'
    echo
    "$CI_ROOT"/script/static-checks/static-checks-detect-newly-added-files.sh
    if [ "$?" != 0 ]; then
        echo "Files Detection check: FAILURE"
        ((ERROR_COUNT++))
    else
        echo "Files Detection check: PASS"
    fi
    echo
fi

# Check error count

if [ "$ERROR_COUNT" != 0 ] || [ "$WARNING_COUNT" != 0 ]; then
  echo "Some static checks have failed."
fi

if [ "$ERROR_COUNT" != 0 ]; then
  exit 1
fi

exit 0
