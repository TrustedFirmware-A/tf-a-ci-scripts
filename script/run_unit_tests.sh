#!/usr/bin/env bash
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Runs the built unit tests

set -e

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/script/run_common.sh"
source "$ci_root/utils.sh"

artefacts="${artefacts-$workspace/artefacts}"

run_root="$workspace/unit_tests/run"

mkdir -p "$run_root"

export run_root

export tfut_root="${tfut_root:-$workspace/tfut}"


run_test() {
	test="${1:?}"
	echo "Running test $test..."
	"./$@"
}

export -f run_test

# Accept BIN_MODE from environment, or default to release. If bin_mode is set
# and non-empty (intended to be set from command line), that takes precedence.
pkg_bin_mode="${BIN_MODE:-release}"
bin_mode="${bin_mode:-$pkg_bin_mode}"

# Change directory so that all binaries can be accessed realtive to where they
# lie
run_cwd="$artefacts/$bin_mode"
cd "$run_cwd"

run_sh="$run_root/run.sh"

#Generate run.sh file
echo "echo \"Running unit tests\"" > "$run_sh"
echo "pwd" >> "$run_sh"
cat "tfut_artefacts.txt" | while read test; do
	if upon "$test_run"; then
		echo "run_test $test \$@" >> "$run_sh"
	fi
done
chmod +x "$run_sh"

# Run the unit tests directly
if upon "$test_run"; then
	echo
        "$run_sh" "$@" -v -c
        exit 0
fi
