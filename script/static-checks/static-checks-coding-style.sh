#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Check the coding style of the current patch (not the entire code base)
# against the Linux coding style using the checkpatch.pl script from
# the Linux kernel source tree.

TEST_CASE="Codestyle on the entire patch chain"

echo "# $TEST_CASE"

BASE_COMMIT=origin/$TF_GERRIT_BRANCH
COMMON_COMMIT=$(git merge-base HEAD $BASE_COMMIT)

git log --oneline $COMMON_COMMIT..HEAD

LOG_FILE=$(mktemp -t coding-style-check.XXXX)

chmod +x $CI_ROOT/script/static-checks/checkpatch.pl

CHECKPATCH=$CI_ROOT/script/static-checks/checkpatch.pl \
  make checkpatch BASE_COMMIT=origin/$TF_GERRIT_BRANCH &> "$LOG_FILE"
RES=$?

if [[ "$RES" == 0 ]]; then
  # Ignore warnings, only mark the test as failed if there are errors.
  grep --quiet "total: [^0][0-9]* errors" "$LOG_FILE"
  RES=$?
else
  RES=0
fi

if [[ "$RES" == 0 ]]; then
  EXIT_VALUE=1
else
  EXIT_VALUE=0
fi

echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
if [[ "$EXIT_VALUE" == 0 ]]; then
  echo "Result : SUCCESS" >> "$LOG_TEST_FILENAME"
else
  echo "Result : FAILURE" >> "$LOG_TEST_FILENAME"
fi
# Always print the script output to show the warnings
echo >> "$LOG_TEST_FILENAME"
cat "$LOG_FILE" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

rm -f "$LOG_FILE"

exit "$EXIT_VALUE"
