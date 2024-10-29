
#!/usr/bin/env bash
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

this_dir="$(readlink -f "$(dirname "$0")")"
. $this_dir/../static-checks/common.sh

TF_ROOT="$1"

TEST_CASE="Rust cargo fmt checks"

echo "# ${TEST_CASE}"

LOG_FILE=`mktemp -t common.XXXX`

EXIT_VALUE=0

cargo fmt --manifest-path=${TF_ROOT}/rust/Cargo.toml --all -- --check  &> "$LOG_FILE"

if [ "$?" -ne 0 ]; then
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

rm "$LOG_FILE"

exit "$EXIT_VALUE"
