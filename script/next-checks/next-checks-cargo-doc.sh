#!/usr/bin/env bash
#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

TF_ROOT="$1"
TEST_CASE="Rust cargo doc checks"
LOG_FILE=`mktemp -t common.XXXX`
EXIT_VALUE=0

echo "# ${TEST_CASE}"
echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"
echo "Platforms:" >> "$LOG_TEST_FILENAME"

# Get all the sets of features, without the enclosing quotes.
available_features=$(make --silent -C ${TF_ROOT} list_features PLAT=fvp | xargs echo)

# Run cargo-doc for feature combinations on FVP platform
for feats in $available_features
do
    echo >> $LOG_FILE
    echo "############### ${TEST_CASE} - platform: FVP - features: ${feats}" >> "$LOG_FILE"
    echo >> $LOG_FILE
    make -C ${TF_ROOT} PLAT=fvp cargo-doc FEATURES=${feats}>> "$LOG_FILE" 2>&1

    if [ "$?" -ne 0 ]; then
        echo -e "  FVP (${feats})\t: FAIL" >> "$LOG_TEST_FILENAME"
        EXIT_VALUE=1
    else
        echo -e "  FVP (${feats})\t: PASS" >> "$LOG_TEST_FILENAME"
    fi
done

available_platforms=$(make --silent -C ${TF_ROOT} list_platforms)

# Run cargo doc for all platforms
for plat in $available_platforms
do
    echo >> $LOG_FILE
    echo "############### ${TEST_CASE} - platform: ${plat}" >> "$LOG_FILE"
    echo >> $LOG_FILE
    make -C ${TF_ROOT} PLAT=${plat} cargo-doc >> "$LOG_FILE" 2>&1

    if [ "$?" -ne 0 ]; then
        echo -e "  ${plat}\t: FAIL" >> "$LOG_TEST_FILENAME"
        EXIT_VALUE=1
    else
        echo -e "  ${plat}\t: PASS" >> "$LOG_TEST_FILENAME"
    fi
done

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
