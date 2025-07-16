#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# test-package-check-copyright.sh DIRECTORY COPYRIGHT_FLAGS

this_dir="$(readlink -f "$(dirname "$0")")"
. $this_dir/common.sh


DIRECTORY="$1"
COPYRIGHT_FLAGS="$2"

TEST_CASE="Copyright headers of files modified by this patch"

echo "# Check Copyright Test"

LOG_FILE=`mktemp -t common.XXXX`

"$CI_ROOT"/script/static-checks/check-copyright.py --tree "$DIRECTORY" $COPYRIGHT_FLAGS --patch --from-ref ${merge_base} &> "$LOG_FILE"
RES=$?

if [ -s "$LOG_FILE" ]; then
  if [ "$RES" -eq 0 ]; then
    EXIT_VALUE=0
  else
    EXIT_VALUE=1
  fi
  cat "$LOG_FILE"
else
  echo "ERROR: Empty output log of copyright check script."
  EXIT_VALUE=1
fi

echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
if [[ "$EXIT_VALUE" == 0 ]]; then
  echo "Result : SUCCESS" >> "$LOG_TEST_FILENAME"
else
  echo "Result : FAILURE" >> "$LOG_TEST_FILENAME"
fi
echo >> "$LOG_TEST_FILENAME"
cat "$LOG_FILE" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

rm "$LOG_FILE"

exit "$EXIT_VALUE"
