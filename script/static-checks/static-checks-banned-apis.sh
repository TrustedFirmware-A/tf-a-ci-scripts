#! /usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# static-checks-banned-apis.sh <path-to-root-folder> [patch]

LOG_FILE=$(mktemp -t banned-api-check.XXXX)

if [[ "$2" == "patch" ]]; then
  echo "# Check for banned APIs in the patch"
  TEST_CASE="Banned API check on patch(es)"
  "$CI_ROOT/script/static-checks/check-banned-api.py" --tree "$1" \
      --patch --from-ref origin/lts-v2.8 \
      &> "$LOG_FILE"
else
  echo "# Check for banned APIs in entire source tree"
  TEST_CASE="Banned API check of the entire source tree"
  "$CI_ROOT/script/static-checks/check-banned-api.py" --tree "$1" \
      &> "$LOG_FILE"
fi

EXIT_VALUE=$?

echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
if [[ "$EXIT_VALUE" == 0 ]]; then
  echo "Result : SUCCESS" >> "$LOG_TEST_FILENAME"
else
  echo "Result : FAILURE" >> "$LOG_TEST_FILENAME"
  echo >> "$LOG_TEST_FILENAME"
  cat "$LOG_FILE" >> "$LOG_TEST_FILENAME"
fi
echo >> "$LOG_TEST_FILENAME"

rm -f "$LOG_FILE"

exit "$EXIT_VALUE"


