#!/usr/bin/env bash
#
# Copyright (c) 2019-2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

this_dir="$(readlink -f "$(dirname "$0")")"
. $this_dir/common.sh


TEST_CASE="Line endings are valid"

EXIT_VALUE=0

echo "# Check Line Endings"

LOG_FILE=$(mktemp -t common.XXXX)

if [[ "$2" == "patch" ]]; then
    cd "$1"
    shopt -s globstar
    parent=$(get_merge_base)
    git diff $parent..HEAD --no-ext-diff --unified=0 --exit-code -a \
      --no-prefix **/*.{S,c,h,i,dts,dtsi,rst,mk,rs} Makefile | \
      awk '/^\+/ && /\r$/' &> "$LOG_FILE"
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
      -name '*.rs' \
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
