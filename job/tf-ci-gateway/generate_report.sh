#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -ex

# Jenkins Parameterized Trigger Plugin mangles job names as passed via
# environment variables, replacing most non-alphanumeric chars with
# underscore. The mangling is generally non-reversible, but we apply
# "heuristics" based on our naming conventions.
function unmangle_job_name() {
    # Two numbers seperated by undescore was likely a version number originally,
    # e.g. lts2.8 -> lts2_8.
    s=$(python3 -c 'import sys, re; print(re.sub(r"(\d+)_(\d+)", r"\1.\2", sys.argv[1]))' "$1")
    # Otherwise, we use hyphens as seperators.
    s=$(echo $s | tr "_" "-")
    echo $s
}

# Generate test report
if [ "$CI_ROOT" ]; then
	# Gather Coverity scan summary if it was performed as part of this job
	if [ "$(find -maxdepth 1 -name '*coverity*.test' -type f | wc -l)" != 0 ]; then
		if ! "$CI_ROOT/script/coverity_summary.py" "$BUILD_URL" > coverity.data; then
			rm -f coverity.data
		fi
	fi

	# set proper jobs names for test generation report script
	if echo "$JENKINS_PUBLIC_URL" | grep -q "oss.arm.com"; then
		worker_job="${worker_job:-tf-worker}"
		lava_job="${lava_job:-tf-build-for-lava}"
	else
		triggered_job=$(unmangle_job_name "${TRIGGERED_JOB_NAMES}")
		worker_job="${worker_job:-${triggered_job}}"
		lava_job="${lava_job:-${triggered_job}}"
	fi

	# Generate UI for test results, only if this is a visualization job.
	while getopts ":t" option; do
		case $option in
			t)
				target_job="$(dirname $TARGET_BUILD)"
				target=${target_job:-tf-a-main}
				"$CI_ROOT/script/gen_results_report.py" \
					--png "${target}-result.png" \
					--csv "${WORKSPACE}/${target}-result.csv" \
					-o "${WORKSPACE}/report.html" || true
				exit;;
		esac
	done

	"$CI_ROOT/script/gen_test_report.py" \
		--job "${worker_job}" \
		--build-job "${lava_job}" \
		--meta-data clone.data \
		--meta-data override.data \
		--meta-data inject.data \
		--meta-data html:coverity.data \
		|| true

    # Only call to merge reports if the test groups are for code coverage
    if [[ $TEST_GROUPS == *"code-coverage"* ]] ||
    [[ $TEST_GROUPS == "scp-boot-tests-coverage" ]]; then
  	   source $CI_ROOT/script/gen_merge_report.sh "${WORKSPACE}/report.json" \
  		   "${WORKSPACE}/report.html"
    fi
fi
