#!/usr/bin/env bash
#
# Copyright (c) 2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -ex

echo '----------------------------------------------'
echo '--           Running Cargo tests            --'
echo '----------------------------------------------'

export LOG_TEST_FILENAME=$(pwd)/next-generic-checks.log
export RUSTUP_HOME=/usr/local/rustup

REPO_SPACE=$1
REPO_NAME=$2

cd "${REPO_NAME}"

TEST_CASE="cargo test checks"

echo "# ${TEST_CASE}"
echo >> "$LOG_TEST_FILENAME"
echo "****** $TEST_CASE ******" >> "$LOG_TEST_FILENAME"
echo >> "$LOG_TEST_FILENAME"

ERROR_COUNT=0

# Run cargo test

if [ "$REPO_NAME" == "rusted-firmware-a" ]; then
  # These tests are platform independent. However, we are specifying a platform:
  #     The fvp platform is expected to cover all platform independent features that can be tested
  #     with cargo test.
  IFS=" " read -a all_features <<< "$(make PLAT=fvp --silent list_features)"
else
  IFS=" " read -a all_features <<< ${TEST_FEATURES}
  if [ ${#all_features[@]} = 0 ]; then
    all_features+=("")
  fi
fi

for features in "${all_features[@]}"; do
    features=$(echo $features | sed "s/'//g")
    echo "cargo test features: '$features'" >> "$LOG_TEST_FILENAME" 2>&1
    cargo test --features=$features >> "$LOG_TEST_FILENAME" 2>&1

    if [ "$?" != 0 ]; then
      echo "cargo test --features='$features': FAILURE"
      ((ERROR_COUNT++))
    else
      echo "cargo test --features='$features': PASS"
    fi

    echo "-------------------------------------" >> "$LOG_TEST_FILENAME" 2>&1
done

echo

# Run cargo doc

if [ "$REPO_NAME" != "rusted-firmware-a" ]; then
  echo "cargo doc --no-deps" >> "$LOG_TEST_FILENAME" 2>&1

  RUSTDOCFLAGS="-D warnings" cargo doc --no-deps >> "$LOG_TEST_FILENAME" 2>&1

  if [ "$?" != 0 ]; then
    echo "cargo doc: FAILURE"
    ((ERROR_COUNT++))
  else
    echo "cargo doc: PASS"
  fi

  echo "-------------------------------------" >> "$LOG_TEST_FILENAME" 2>&1
fi

# Run cargo vet

if [ "$REPO_NAME" == "rusted-firmware-a" ]; then
  echo "cargo vet:" >> "$LOG_TEST_FILENAME" 2>&1

  cargo vet >> "$LOG_TEST_FILENAME" 2>&1

  if [ "$?" != 0 ]; then
    echo "cargo vet: FAILURE"
    ((ERROR_COUNT++))
  else
    echo "cargo vet: PASS"
  fi

  echo "-------------------------------------" >> "$LOG_TEST_FILENAME" 2>&1
fi

cd -
if [ "$ERROR_COUNT" != 0 ]; then
  echo "Some cargo checks have failed."
  exit 1
fi

exit 0
