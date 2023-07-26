#!/usr/bin/env bash
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

TEST_CASE="Line endings not valid"

EXIT_VALUE=0

echo "# Check Line Endings"

LOG_FILE=$(mktemp -t common.XXXX)

if [[ "$2" == "patch" ]]; then
    cd "$1"
    parent=$(git merge-base HEAD refs/remotes/origin/lts-v2.8 | head -1)
    git diff ${parent}..HEAD --no-ext-diff --unified=0 --exit-code -a --no-prefix | awk '/^\+/ && /\r$/' &> "$LOG_FILE"
else
  # For all the source and doc files
  # We only return the files that contain CRLF
  find "." -\( \
      -name '*.S' -or \
      -name '*.c' -or \
      -name '*.h' -or \
      -name '*.i' -or \
      -name '*.dts' -or \
      -name '*.dtsi' -or \
      -name '*.rst' -or \
      -name 'Makefile' -or \
      -name '*.mk' \
  -\) -exec grep --files-with-matches $'\r$' {} \; &> "$LOG_FILE"
fi

if [[ -s "$LOG_FILE" ]]; then
    EXIT_VALUE=1
fi

{ echo; echo "****** $TEST_CASE ******"; echo; } >> "$LOG_TEST_FILENAME"

{ if [[ "$EXIT_VALUE" == 0 ]]; then \
      echo "Result : SUCCESS"; \
  else  \
      echo "Result : FAILURE"; echo; cat "$LOG_FILE"; \
  fi \
} | tee -a "$LOG_TEST_FILENAME"

rm "$LOG_FILE"

exit "$EXIT_VALUE"
