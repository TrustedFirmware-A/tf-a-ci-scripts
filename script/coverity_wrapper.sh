#!/usr/bin/env bash
#
# Copyright (c) 2019-2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This file is sourced from the build_package.sh script to use
# coverity_wrapper() function as a build wrapper.
#
# This wrapper supports two work flows:
#
#  - Compare the branch under test with that of master, and print defects. If
#    there are defects, we arrange the build to be marked as unstable. Set
#    $cov_run_type to 'branch-report-compare' to use this.
#
#  - Commit and create snapshot for the entire branch. Set $cov_run_type to
#    'branch-report-full' to use this.
#
# Coverity analysis involves contacting the server, which have shown to be very
# slow. Depending on the type of analysis performed, we might have to do
# analysis more than once, and doing that in series would only increase the turn
# around time. To mitigate this, all Coverity commands, are called from a
# Makefile, and run in parallel.

coverity_wrapper() {
	local cov_dir="$workspace/coverity"
	local cov_compiler="${cov_compiler:-${CROSS_COMPILE}gcc}"

	local auth_file="$cov_auth_file"
	local makefile="$ci_root/script/coverity-Makefile"
	local defects_summary="$workspace/defects-summary.txt"

	local description
	local need_compare

	# If auth file is not provided and if on Arm infrastructure copy it
	if [ -z "$auth_file" ] && echo "$JENKINS_PUBLIC_URL" | grep -q "oss.arm.com"; then
		local auth_url="$project_filer/ci-files/coverity/tfcibot@$coverity_host"
		url="$auth_url" saveas="$workspace/tfcibot@$coverity_host" fetch_file
		auth_file="$workspace/tfcibot@$coverity_host"
	fi

	if [ -z "$auth_file" ]; then
		die "Coverity authentication token not provided"
	fi

	echo_w
	mkdir -p "$cov_dir"

	if echo "${cov_run_type:?}" | grep -iq "branch-report-compare"; then
		need_compare=1
		local golden_url="${cov_golden_url:-$tf_src_repo_url}"
		local golden_ref="${cov_golden_ref:-master}"
		local defects_file="$workspace/diff-defects.txt"
	else
		local defects_file="$workspace/full-defects.txt"
	fi

	if upon "$local_ci"; then
		description="$USER-local ${cov_checker:?}"
	else
		description="$JOB_NAME#$BUILD_NUMBER ${cov_checker:?}"
	fi

	# Create a stream and assign to Trusted Firmware project
	chmod 400 "$auth_file"

	local minus_j="-j"
	if upon "$cov_serial_build"; then
		minus_j=
	fi

	# Call Coverity targets
	echo "Coverity run type: ${cov_run_type:?}"
	# Remove the `make` from the front of the command line as we need to
	# insert -C <directory> inside the makefile
	shift
	MAKEFLAGS= SUBMAKE="$@" make -r $minus_j -f "$makefile" -C "$workspace" \
		auth_file=$auth_file\
		golden_url=$golden_url\
		golden_ref=$golden_ref\
		tf_src_repo_url=$tf_src_repo_url\
		cov_compiler=$cov_compiler\
		minus_j=$minus_j\
		description="$description"\
		ci_root="$ci_root"\
		$cov_run_type 2>&3 || exit 1

	# If there were defects, print them out to the console. For local CI,
	# print them in yellow--the same color we'd use for UNSTABLE builds.
	if [ -s "$defects_file" ]; then
		echo_w
		echo_w "Coverity defects found:"
		echo_w
		if upon "$local_ci"; then
			echo_w "$(tput setaf 3)"
		fi
		cat "$defects_file" >&3
		if upon "$local_ci"; then
			echo_w "$(tput sgr0)"
		fi
		echo_w
		cat $defects_summary >&3
		echo_w
		build_unstable >&3
		echo_w
	else
		echo_w
		echo_w "No coverity defects found."
		echo_w
	fi
}
