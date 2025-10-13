#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Decode test description and extract TF build configuration, run configuration,
# test group etc.
#
# See gen_test_desc.py

set -e

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

test_desc="${test_desc:-$TEST_DESC}"
test_desc="${test_desc:?}"

# Strip test suffix
test_desc="${test_desc%%.test}"

lhs="$(echo "$test_desc" | awk -F: '{print $1}')"
rhs="$(echo "$test_desc" | awk -F: '{print $2}')"

test_group="$(echo "$lhs" | awk -F% '{print $2}')"
build_config="$(echo "$lhs" | awk -F% '{print $3}')"
run_config="${rhs%.test}"
test_config="$(cat $workspace/TEST_DESC)"

env_file="$workspace/env"
rm -f "$env_file"

emit_env "BUILD_CONFIG" "$build_config"
emit_env "RUN_CONFIG" "$run_config"
emit_env "TEST_CONFIG" "$test_config"
emit_env "TEST_GROUP" "$test_group"
emit_env "CC_ENABLE" "$cc_enable"
