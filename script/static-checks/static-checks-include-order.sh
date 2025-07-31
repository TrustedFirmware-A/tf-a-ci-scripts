#!/usr/bin/env bash
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# unittest-include-order.sh <path-to-root-folder> [patch]

LOG_FILE=$(mktemp -t include-order-check.XXXX)

if [[ "$2" == "patch" ]]; then
  TEST_CASE="Order of includes on the patch series"
  echo "# $TEST_CASE"
  "$CI_ROOT/script/static-checks/check-include-order.py" --tree "$1" \
      --patch --from-ref ${merge_base} \
      &> "$LOG_FILE"
else
  echo "# Check order of includes of the entire source tree"
  TEST_CASE="Order of includes of the entire source tree"
  "$CI_ROOT/script/static-checks/check-include-order.py" --tree "$1" \
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
  echo >> "$LOG_TEST_FILENAME"
  echo -e "Please refer to the docs for further information on include statement ordering: https://trustedfirmware-a.readthedocs.io/en/latest/process/coding-style.html#include-statement-ordering." >> "$LOG_TEST_FILENAME"
fi
echo >> "$LOG_TEST_FILENAME"

rm -f "$LOG_FILE"

exit "$EXIT_VALUE"
