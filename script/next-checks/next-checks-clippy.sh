#!/usr/bin/env bash
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

this_dir="$(readlink -f "$(dirname "$0")")"
. $this_dir/../static-checks/common.sh

TF_ROOT="$1"
TEST_CASE="Rust clippy checks"
LOG_FILE=`mktemp -t common.XXXX`
EXIT_VALUE=0

echo "# ${TEST_CASE}"
echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
echo "Platforms:" >> "$LOG_TEST_FILENAME"

available_platforms=$(make --silent -C ${TF_ROOT} list_platforms)

# Run clippy for all platforms
for plat in $available_platforms
do
    echo >> $LOG_FILE
    echo "############### ${TEST_CASE} - platform: ${plat}" >> "$LOG_FILE"
    echo >> $LOG_FILE
    make -C ${TF_ROOT} PLAT=${plat} clippy >> "$LOG_FILE" 2>&1

    if [ "$?" -ne 0 ]; then
        echo -e "  ${plat}\t: FAIL" >> "$LOG_TEST_FILENAME"
        EXIT_VALUE=1
    else
        echo -e "  ${plat}\t: PASS" >> "$LOG_TEST_FILENAME"
    fi
done

# Now run clippy for tests
echo >> $LOG_FILE
echo "############### ${TEST_CASE} - platform: tests" >> "$LOG_FILE"
echo >> $LOG_FILE
make -C ${TF_ROOT} clippy-test >> "$LOG_FILE" 2>&1

if [ "$?" -ne 0 ]; then
    echo -e "  clippy-test\t: FAIL" >> "$LOG_TEST_FILENAME"
    EXIT_VALUE=1
else
    echo -e "  clippy-test\t: PASS" >> "$LOG_TEST_FILENAME"
fi

echo >> "$LOG_TEST_FILENAME"
if [[ "$EXIT_VALUE" == 0 ]]; then
  echo "Result : SUCCESS" >> "$LOG_TEST_FILENAME"
else
  echo "Result : FAILURE" >> "$LOG_TEST_FILENAME"
fi
echo >> "$LOG_TEST_FILENAME"
cat "$LOG_FILE" >> "$LOG_TEST_FILENAME"

rm "$LOG_FILE"

exit "$EXIT_VALUE"
