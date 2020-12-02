#!/usr/bin/env bash
#
# Copyright (c) 2019-2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

in_red() {
	echo "$(tput setaf 1)${1:?}$(tput sgr0)"
}
export -f in_red

in_green() {
	echo "$(tput setaf 2)${1:?}$(tput sgr0)"
}
export -f in_green

in_yellow() {
	echo "$(tput setaf 3)${1:?}$(tput sgr0)"
}
export -f in_yellow

print_success() {
	in_green "$1: SUCCESS"
}
export -f print_success

print_failure() {
	in_red "$1: FAILURE"
}
export -f print_failure

print_unstable() {
	in_yellow "$1: UNSTABLE"
}
export -f print_unstable

gen_makefile() {
	local num="$(find -name "*.test" -type f | wc -l)"
	local i=0

	cat <<EOF >Makefile
SHELL=/bin/bash

all:

EOF

	# If we're using local checkouts for either TF or TFTF, we must
	# serialise builds
	while [ "$i" -lt "$num" ]; do
		{
		printf "all: %03d_run %03d_build\n" "$i" "$i"
		if upon "$serialize_builds" && [ "$i" -gt 0 ]; then
			printf "%03d_build: %03d_build\n" "$i" "$((i - 1))"
		fi
		echo
		} >>Makefile
		let "++i"
	done

	cat <<EOF >>Makefile

%_run: %_build
	@run_one_test "\$@"

%_build:
	@run_one_test "\$@"
EOF
}

# This function is invoked from the Makefile. Descriptor 5 points to the active
# terminal.
run_one_test() {
	id="${1%%_*}"
	action="${1##*_}"
	test_file="$(find -name "$id*.test" -printf "%f\n")"

	mkdir -p "$id"

	# Copy the test_file into the workspace directory with the name
	# TEST_DESC, just like Jenkins would.
	export TEST_DESC="$(basename "$test_file")"
	cp "$test_file" "$id/TEST_DESC"

	workspace="$id" test_desc="$test_file" cc_enable="$cc_enable" "$ci_root/script/parse_test.sh"

	set -a
	source "$id/env"
	set +a

	# Makefiles don't like commas and colons in file names. We therefore
	# replace them with _
	config_subst="$(echo "$TEST_CONFIG" | tr ',:' '_')"
	config_string="$id: $TEST_GROUP/$TEST_CONFIG"
	workspace="$workspace/$TEST_GROUP/$config_subst"
	mkdir -p "$workspace"

	log_file="$workspace/artefacts/build.log"
	if [ "$parallel" -gt 1 ]; then
		console_file="$workspace/console.log"
		exec 6>>"$console_file"
	else
		exec 6>&5
	fi

	# Unset make flags for build script
	MAKEFLAGS=

	if [ $import_cc -eq 1 ]; then
		# Path to plugin if there is no local reference
		cc_path_spec=$workspace/cc_plugin
	fi

	case "$action" in
		"build")
			echo "building: $config_string" >&5
			if ! ccpathspec="$cc_path_spec" bash $minus_x "$ci_root/script/build_package.sh" \
					>&6 2>&1; then
				{
				print_failure "$config_string (build)"
				if [ "$console_file" ]; then
					echo "	see $console_file"
				fi
				} >&5
				exit 1
			fi
			;;

		"run")
			# Local runs for FVP or arm_fpga unless asked not to
			if echo "$RUN_CONFIG" | grep -q "^fvp" && \
					not_upon "$skip_runs"; then
				echo "running: $config_string" >&5
				if [ -n "$cc_enable" ]; then
					# Enable of code coverage during run
					if cc_enable="$cc_enable" trace_file_prefix=tr \
					coverage_trace_plugin=$cc_path_spec/scripts/tools/code_coverage/fastmodel_baremetal/bmcov/model-plugin/CoverageTrace.so \
					bash $minus_x "$ci_root/script/run_package.sh" \
						>&6 2>&1; then
						if grep -q -e "--BUILD UNSTABLE--" \
							"$log_file"; then
							print_unstable "$config_string" >&5
						else
							print_success "$config_string" >&5
							if [ -d "$workspace/artefacts/release" ] && \
							[ -f "$workspace/artefacts/release/tr-FVP_Base_RevC_2xAEMv8A.cluster0.cpu0.log" ]; then
								cp $workspace/artefacts/release/*.log $workspace/artefacts/debug
							fi
							# Setting environmental variables for run of code coverage
							OBJDUMP=$TOOLCHAIN/bin/aarch64-none-elf-objdump \
							READELF=$TOOLCHAIN/bin/aarch64-none-elf-readelf \
							ELF_FOLDER=$workspace/artefacts/debug \
							TRACE_FOLDER=$workspace/artefacts/debug \
							workspace=$workspace \
							TRACE_PREFIX=tr python \
							$cc_path_spec/scripts/tools/code_coverage/fastmodel_baremetal/bmcov/report/gen-coverage-report.py --config \
							$cc_path_spec/scripts/tools/code_coverage/fastmodel_baremetal/bmcov/report/config_atf.py
						fi
						exit 0
					else
						{
						print_failure "$config_string (run)"
						if [ "$console_file" ]; then
							echo "	see $console_file"
						fi
						} >&5
						exit 1
					fi
				else
					if bash $minus_x "$ci_root/script/run_package.sh" \
						>&6 2>&1; then
						if grep -q -e "--BUILD UNSTABLE--" \
							"$log_file"; then
							print_unstable "$config_string" >&5
						else
							print_success "$config_string" >&5
						fi
						exit 0
					else
						{
						print_failure "$config_string (run)"
						if [ "$console_file" ]; then
							echo "	see $console_file"
						fi
						} >&5
						exit 1
					fi
				fi
			else
				# Local runs for arm_fpga platform
				if echo "$RUN_CONFIG" | grep -q "^arm_fpga" && \
					not_upon "$skip_runs"; then
					echo "running: $config_string" >&5
					if bash $minus_x "$ci_root/script/test_fpga_payload.sh" \
						>&6 2>&1; then
						if grep -q -e "--BUILD UNSTABLE--" \
							"$log_file"; then
							print_unstable "$config_string" >&5
						else
							print_success "$config_string" >&5
						fi
						exit 0
					else
						{
						print_failure "$config_string (run)"
						if [ "$console_file" ]; then
							echo "	see $console_file"
						fi
						} >&5
						exit 1
					fi
				else
					if grep -q -e "--BUILD UNSTABLE--" \
							"$log_file"; then
						print_unstable "$config_string (not run)" >&5
					else
						print_success "$config_string (not run)" >&5
					fi
					exit 0
				fi
			fi
			;;

		*)
			in_red "Invalid action: $action!" >&5
			exit 1
			;;
	esac
}
export -f run_one_test

workspace="${workspace:?}"
ci_root="$(readlink -f "$(dirname "$0")/..")"

# If this script was invoked with bash -x, have subsequent build/run invocations
# to use -x as well.
if echo "$-" | grep -q "x"; then
	export minus_x="-x"
fi

# if test_groups variable is not present, check if it can be formed at least from 'test_group' and 'tf_config'
# environment variables
if [ -z "${test_groups}" ]; then
  if [ -n "${test_group}" -a -n "${tf_config}" ]; then

    # default the rest to nil if not present
    tftf_config="${tftf_config:-nil}"
    scp_config="${scp_config:-nil}"
    scp_tools="${scp_tools:-nil}"
    run_config="${run_config:-nil}"

    # constuct the 'long form' so it takes into account all possible configurations
    tg=$(printf "%s/%s,%s,%s,%s:%s" "${test_group}" "${tf_config}" "${tftf_config}" "${scp_config}" "${scp_tools}" "${run_config}")

    # trim any ',nil:' from it
    tg="${tg/,nil:/:}" tg="${tg/,nil:/:}"; tg="${tg/,nil:/:}"

    # finally exported
    export test_groups="${tg}"
  fi
fi

# For a local run, when some variables as specified as "?", launch zenity to
# prompt for test config via. GUI. If it's "??", then choose a directory.
if [ "$test_groups" = "?" -o "$test_groups" = "??" ]; then
	zenity_opts=(
	--file-selection
	--filename="$ci_root/group/README"
	--multiple
	--title "Choose test config"
	)

	if [ "$test_groups" = "??" ]; then
		zenity_opts+=("--directory")
	fi

	# In case of multiple selections, zenity returns absolute paths of files
	# separated by '|'. We remove the pipe characters, and make the paths
	# relative to the group directory.
	selections="$(cd "$ci_root"; zenity ${zenity_opts[*]})"
	test_groups="$(echo "$selections" | tr '|' ' ')"
	test_groups="$(echo "$test_groups" | sed "s#$ci_root/group/##g")"
fi

test_groups="${test_groups:?}"
local_count=0

if [ -z "$tf_root" ]; then
	in_red "NOTE: NOT using local work tree for TF"
else
	tf_root="$(readlink -f $tf_root)"
	tf_refspec=
	in_green "Using local work tree for TF"
	let "++local_count"
fi

if [ -z "$tftf_root" ]; then
	in_red "NOTE: NOT using local work tree for TFTF"
	tforg_user="${tforg_user:?}"
else
	tftf_root="$(readlink -f $tftf_root)"
	tftf_refspec=
	in_green "Using local work tree for TFTF"
	let "++local_count"
fi

if [ -z "$scp_root" ]; then
	in_red "NOTE: NOT using local work tree for SCP"
else
	scp_root="$(readlink -f $scp_root)"
	scp_refspec=
	in_green "Using local work tree for SCP"
	let "++local_count"
fi

if [ -n "$cc_enable" ]; then
	in_green "Code Coverage enabled"
	if [ -z "$TOOLCHAIN" ]; then
		in_red "TOOLCHAIN not set for code coverage:  ex: export TOOLCHAIN=<path to toolchain>/gcc-arm-<gcc version>-x86_64-aarch64-none-elf"
		exit 1
	fi
	if [ -n "$cc_path" ]; then
		in_green "Code coverage plugin path specified"
		cc_path_spec=$cc_path
		import_cc=0
	else
		in_red "Code coverage plugin path not specified"
		cc_path_spec="$workspace/cc_plugin"
		import_cc=1
	fi
else
	in_green "Code coverage disabled"
	import_cc=1
fi

if [ -z "$spm_root" ]; then
	in_red "NOTE: NOT using local work tree for SPM"
else
	spm_root="$(readlink -f $spm_root)"
	spm_refspec=
	in_green "Using local work tree for SPM"
	let "++local_count"
fi

# User preferences
[ "$connect_debugger" ] && [ "$connect_debugger" -eq 1 ] && user_connect_debugger=1
user_test_run="${user_connect_debugger:-$test_run}"
user_dont_clean="$dont_clean"
user_keep_going="$keep_going"
user_primary_live="$primary_live"
user_connect_debugger="${user_connect_debugger:-0}"

export ci_root
export dont_clean=0
export local_ci=1
export parallel
export test_run=0
export primary_live=0
export cc_path_spec
export import_cc
export connect_debugger="$user_connect_debugger"

rm -rf "$workspace"
mkdir -p "$workspace"

source "$ci_root/utils.sh"

# SCP is not cloned by default
export clone_scp
export scp_root
if not_upon "$scp_root" && upon "$clone_scp"; then
	clone_scp=1
else
	clone_scp=0
fi

# Enable of code coverage and whether there is a local plugin
if upon "$cc_enable" && not_upon "$cc_path"; then
	no_cc_t=1
else
	no_cc_t=0
fi

# Use clone_repos.sh to clone and share repositories that aren't local.
no_tf="$tf_root" no_tftf="$tftf_root" no_ci="$ci_root" no_cc="$import_cc" \
	bash $minus_x "$ci_root/script/clone_repos.sh"

set -a
source "$workspace/env"
set +a

if [ "$local_count" -gt 0 ]; then
	# At least one repository is local
	serialize_builds=1
else
	dont_clean=0
fi

export -f upon not_upon

# Generate test descriptions
"$ci_root/script/gen_test_desc.py"

# Iterate through test files in workspace
pushd "$workspace"

if not_upon "$parallel" || echo "$parallel" | grep -vq "[0-9]"; then
	parallel=1
	test_run="$user_test_run"
	dont_clean="$user_dont_clean"
	primary_live="$user_primary_live"
fi

if [ "$parallel" -gt 1 ]; then
	msg="Running at most $parallel jobs in parallel"
	if upon "$serialize_builds"; then
		msg+=" (builds serialized)"
	fi
	msg+="..."
fi

# Generate Makefile
gen_makefile

if upon "$msg"; then
	echo "$msg"
	echo
fi

keep_going="${user_keep_going:-1}"
if not_upon "$keep_going"; then
	keep_going=
fi

MAKEFLAGS= make -r -j "$parallel" ${keep_going+-k} 5>&1 &>"make.log"
