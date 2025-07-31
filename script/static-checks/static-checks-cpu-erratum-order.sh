#!/usr/bin/env bash
#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

LOG_FILE=$(mktemp -t cpu_workaround_order_check_log.XXXX)

if [[ "$2" == "patch" ]]; then
  TEST_CASE="Checking ascending order of CPU ERRATUM and CVE in the patch series"
  echo "# $TEST_CASE"
  "$CI_ROOT/script/static-checks/static-checks-cpu-erratum-order.py" --tree "$1" \
      --patch --from-ref ${merge_base} &> "$LOG_FILE"
else
  TEST_CASE="Checking ascending order of CPU ERRATUM and CVE in the entire source tree"
  echo "# $TEST_CASE"
  "$CI_ROOT/script/static-checks/static-checks-cpu-erratum-order.py" --tree "$1" &> "$LOG_FILE"
fi

EXIT_VALUE=$?

echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
cat "$LOG_FILE" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
if [[ "$EXIT_VALUE" == 0 ]]; then
  echo "Result : SUCCESS" >> "$LOG_TEST_FILENAME"
else
  echo "Result : FAILURE" >> "$LOG_TEST_FILENAME"
fi

rm -f "$LOG_FILE"

exit "$EXIT_VALUE"
