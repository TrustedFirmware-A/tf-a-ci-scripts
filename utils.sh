#!/usr/bin/env bash
#
# Copyright (c) 2019-2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# This file is meant to be SOURCED only after setting $ci_root. $ci_root must be
# the absolute path to the root of the CI repository
#
# A convenient way to set ci_root from the calling script like this:
#  ci_root="$(readlink -f "$(dirname "$0")/..")"
#

# Accept root of CI location from $CI_ROOT or $ci_root, in that order
ci_root="${ci_root:-$CI_ROOT}"
ci_root="${ci_root:?}"

source "${ci_root}/lava_utils.sh"

# Optionally source a file containing environmental settings.
if [ -n "$host_env" ]; then
  source "$host_env"
else
  # Are we running on Arm infrastructure?
  if echo "$JENKINS_URL" | grep -q "oss.arm.com"; then
    source "$ci_root/arm-env.sh"
  elif echo "$JENKINS_URL" | grep -q "ci.trustedfirmware.org"; then
    if echo "$TF_GERRIT_BRANCH" | grep -q "lts-v2.8"; then
      source "$ci_root/openci-lts-v2.8-env.sh"
    elif echo "$TF_GERRIT_BRANCH" | grep -q "lts-v2.10"; then
      source "$ci_root/openci-lts-v2.10-env.sh"
    else
      source "$ci_root/openci-env.sh"
    fi
  elif echo "$JENKINS_URL" | grep -q "ci.staging.trustedfirmware.org"; then
    source "$ci_root/openci-staging-env.sh"
  fi
fi

# Storage area to host toolchains, rootfs, tools, models, binaries, etc...
nfs_volume="${nfs_volume:-$NFS_VOLUME}"
nfs_volume="${nfs_volume:?}"

# Override workspace for local runs
workspace="${workspace:-$WORKSPACE}"
workspace="${workspace:?}"
workspace="$(readlink -f "$workspace")"
artefacts="$workspace/artefacts"

# pushd and popd outputs the directory stack every time, which could be
# confusing when shown on the log. Suppress its output.
pushd() {
	builtin pushd "$1" &>/dev/null
}
popd() {
	builtin popd &>/dev/null
}

# Copy a file to the $archive directory
archive_file() {
	local f out target md5
	f="${1:?}"

	out="${archive:?}"
	[ ! -d "$out" ] && die "$out is not a directory"

	target="$out/$(basename $f)"
	if [ -f "$target" ]; then
		# Prevent same file error
		if [ "$(stat --format=%i "$target")" = \
				"$(stat --format=%i "$f")" ]; then
			return
		fi
	fi

	md5="$(md5sum "$f" | awk '{print $1}')"
	cp -t "$out" "$f"
	echo "Archived: $f (md5: $md5)"
}

die() {
	[ "$1" ] && echo "$1" >&2
	exit 1
}

# Emit environment variables for the purpose of sourcing from shells and as
# Jenkins property files. Whether the RHS is quoted depends on "$quote".
emit_env() {
	local env_file="${env_file:?}"
	local var="${1:?}"

	# Value parameter is mandatory, but allow for it to be empty
	local val="${2?}"

	if upon "$quote"; then
		val="\"$val\""
	else
		# If RHS is not required to be quoted, any white space in it
		# won't go well with a shell sourcing this file.
		if echo "$var" | grep -q '\s'; then
			die "$var: value '$val' has white space"
		fi
	fi

	echo "$var=$val" >> "$env_file"
}

fetch_directory() {
	local base="$(basename "${url:?}")"
	local sa

	case "${url}" in
		http*://*)
			# Have exactly one trailing /
			local modified_url="$(echo "${url}" | sed 's#/*$##')/"

			# Figure out the number of components between hostname and the
			# final one
			local cut_dirs="$(echo "$modified_url" | awk -F/ '{print NF - 5}')"
			sa="${saveas:-$base}"
			echo "Fetch: $modified_url -> $sa"
			wget -rq -nH --cut-dirs="$cut_dirs" --no-parent -e robots=off \
				--reject="index.html*" "$modified_url"
			if [ "$sa" != "$base" ]; then
				mv "$base" "$sa"
			fi
			;;
		file://*)
			sa="${saveas:-.}"
			echo "Fetch: ${url} -> $sa"
			cp -r "${url#file://}" "$sa"
			;;
		*)
			sa="${saveas:-.}"
			echo "Fetch: ${url} -> $sa"
			cp -r "${url}" "$sa"
			;;
	esac
}

fetch_file() {
	local url="${url:?}"
	local sa
	local saveas

	if is_url "$url"; then
		saveas="${saveas-"$(basename "$url")"}"
		sa="${saveas+-o $saveas}"
		echo "Fetch: $url -> $saveas"
		# Use curl to support file protocol
		curl --fail --no-progress-meter --connect-timeout 10 --retry 6 -LS $sa "$url"
	else
		sa="${saveas-.}"
		echo "Fetch: $url -> $sa"
		cp "$url" "$sa"
	fi
}

fetch_and_archive() {
	url=${url:?}
	filename=${filename:-basename $url}

	url="$url" saveas="$filename" fetch_file
	archive_file "$filename"
}

filter_artefacts(){
	local model_param_file="${model_param_file-$archive/model_params}"

	# Bash doesn't have array values, we have to create references to the
	# array of artefacts and the artefact filters.
	declare -ga "$1"
	declare -n artefacts="$1"
	declare -n filters="$2"

	for artefact in "${!filters[@]}"; do
		if grep -E -q "${filters[${artefact}]}" "$model_param_file"; then
			artefacts+=("${artefact}")
		fi
	done
}

# Generate link to an archived binary.
gen_bin_url() {
	local bin_mode="${bin_mode:?}"
	local bin="${1:?}"

	if upon "$jenkins_run"; then
		echo "$jenkins_url/job/$JOB_NAME/$BUILD_NUMBER/artifact/artefacts/$bin_mode/$bin"
	else
		echo "file://$workspace/artefacts/$bin_mode/$bin"
	fi
}

get_boot_image() {
	local image=${image:?}
	local type=${type:?}

	declare -n image_list=${image_list-${image}_list}

	local url="${image_list[${type}]}"

	url="${url:?}" filename="${image}.bin" fetch_and_archive
}

get_boot_image_from_fip() {(
	local url="${url:?}"
	local image="${image:?}"
	local output_name="${output_name-bl32.bin}"

	cd "$(mktempdir)"

	extract_fip "$url"
	mv "$image" "$output_name"
	archive_file "$output_name"
)}

# Get the path to the run environment variables file.
#
# Run environment variables are the test-specific environment variables
# configured by the CI's test configuration.
#
# Usage: get_run_env_path <archive>
get_run_env_path() {
	echo "${1:?}/run/env"
}

# Get a run environment variable.
#
# Run environment variables are the test-specific environment variables
# configured by the CI's test configuration.
#
# Usage: get_run_env <archive> <variable> [default]
get_run_env() {
	if [ -f "$(get_run_env_path "${1:?}")" ] && [ ! -v "${2:?}" ]; then
		. "$(get_run_env_path "${1:?}")"
	fi

	echo "${!2:-${3}}"
}

# Get the number of UARTs configured by the current test configuration. This
# defaults to `4`.
#
# Usage: get_num_uarts <archive> [default]
get_num_uarts() {
	local default=4

	get_run_env "${1:?}" num_uarts "${2-${default}}"
}

# Get the ports script configured by the current test configuration. This
# defaults to `script/default-ports-script.awk`.
#
# Usage: get_ports_script <archive> [default]
get_ports_script() {
	local default="${ci_root}/script/default-ports-script.awk"

	get_run_env "${1:?}" ports_script "${2-${default}}"
}

# Get the primary UART configured by the current test configuration. This
# defaults to `0`.
#
# Usage: get_primary_uart <archive> [default]
get_primary_uart() {
	local default=0

	get_run_env "${1:?}" primary_uart "${2-${default}}"
}

# Get the payload UART configured by the current test configuration. This
# defaults to the primary UART.
#
# Usage: get_payload_uart <archive> [default]
get_payload_uart() {
	local default="$(get_primary_uart "${1:?}")"

	get_run_env "${1:?}" payload_uart "${2-${default}}"
}

# Get the path to a UART's environment variable directory.
#
# UART environment variables are the UART-specific environment variables
# configured by the CI's test configuration.
#
# Usage: get_uart_env_path <archive> <uart>
get_uart_env_path() {
	echo "${1:?}/run/uart${2:?}"
}

# Get a UART environment variable.
#
# UART environment variables are the UART-specific environment variables
# configured by the CI's test configuration.
#
# Usage: get_uart_env <archive> <uart> <variable> [default]
get_uart_env() {
	if [ ! -v "${3:?}" ] && [ -f "$(get_uart_env_path "${1:?}" "${2:?}")/${3:?}" ]; then
		cat "$(get_uart_env_path "${1:?}" "${2:?}")/${3:?}"
	else
		echo "${!3-${4}}"
	fi
}

# Get the path to the Expect script for a given UART. This defaults to nothing.
#
# Usage: get_uart_expect_script <archive> <uart> [default]
get_uart_expect_script() {
	local default=

	get_uart_env "${1:?}" "${2:?}" expect "${3-${default}}"
}

# Get the FVP port for a given UART. This defaults to `5000 + ${uart}`.
#
# Usage: get_uart_port <archive> <uart> [default]
get_uart_port() {
	local default="$(( 5000 + "${2:?}" ))"

	get_uart_env "${1:?}" "${2:?}" port "${3-${default}}"
}

# Set a UART environment variable.
#
# UART environment variables are the UART-specific environment variables
# configured by the CI's test configuration.
#
# Usage: set_uart_env <archive> <uart> <variable> <value>
set_uart_env() {
	local path="$(get_uart_env_path "${1:?}" "${2:?}")"

	mkdir -p "${path}" && \
		echo "${4:?}" > "${path}/${3:?}"
}

# Set the FVP port for a given UART.
#
# Usage: set_uart_port <archive> <uart> <port>
set_uart_port() {
	set_uart_env "${1:?}" "${2:?}" port "${3:?}"
}

# Make a temporary directory/file insdie workspace, so that it doesn't need to
# be cleaned up. Jenkins is setup to clean up workspace before a job runs.
mktempdir() {
	local ws="${workspace:?}"

	mktemp -d --tmpdir="$ws"
}
mktempfile() {
	local ws="${workspace:?}"

	mktemp --tmpdir="$ws"
}

not_upon() {
	! upon "$1"
}

# Use "$1" as a boolean
upon() {
	case "$1" in
		"" | "0" | "false") return 1;;
		*) return 0;;
	esac
}

# Check if the argument is a URL
is_url() {
	echo "$1" | grep -q "://"
}

# Check if a path is absolute
is_abs() {
	[ "${1:0:1}" = "/" ]
}

# Unset a variable based on its boolean value
# If foo=, foo will be unset
# If foo=blah, then leave it as is
reset_var() {
	local var="$1"
	local val="${!var}"

	if [ -z "$val" ]; then
		unset "$var"
	else
		var="$val"
	fi
}

default_var() {
	local var="$1"
	local val="${!var}"
	local default="$2"

	if [ -z "$val" ]; then
		eval "$var=$default"
	fi
}

# String various items joined by ":" to form a path. Items are prepended by
# default; or 'op' can be set to 'append' to have them appended.
# For example, to set: PATH=foo:bar:baz:$PATH
extend_path() {
	local path_var="$1"
	local array_var="$2"
	local path_val="${!path_var}"
	local op="${op:-prepend}"
	local sep=':'
	local array_val

	eval "array_val=\"\${$array_var[@]}\""
	array_val="$(echo ${array_val// /:})"

	[ -z "$path_val" ] && sep=''

	if [ "$op" = "prepend" ]; then
		array_val="${array_val}${sep}${path_val}"
	elif [ "$op" = "append" ]; then
		array_val="${path_val}${sep}${array_val}"
	fi

	eval "$path_var=\"$array_val\""
}

# Expand and evaluate Bash variables and expressions in a file, whose path is
# given by the first parameter.
#
# For example, to expand a file containing the following:
#
#     My name is ${name}!
#
# You might use:
#
#     name="Chris" expand_template "path-to-my-file.txt"
#
# This would yield:
#
#     My name is Chris!
#
# If you need to run multiple expansions on a file (e.g. to fill out information
# incrementally), then you can escape expansion of a variable with a backslash,
# e.g. `\${name}`.
#
# The expanded output is printed to the standard output stream.
expand_template() {
	local path="$1"

	eval "cat <<-EOF
	$(<${path})
	EOF"
}

# Fetch and extract the latest supported version of the LLVM toolchain from
# a compressed archive file to a target directory, if it is required.
setup_llvm_toolchain() {
	link="${1:-$llvm_archive}"
	archive="${2:-"$workspace/llvm.tar.xz"}"
	target_dir="${3:-$llvm_dir}"

	if is_arm_jenkins_env || upon "$local_ci"; then
		url="$link" saveas="$archive" fetch_file
		mkdir -p $target_dir
		extract_tarball $archive $target_dir --strip-components=1 -k
	fi
}

# Extract files from compressed archive to target directory. Supports .zip,
# .tar.gz, and tar.xf format
extract_tarball() {
	local archive="$1"
	local target_dir="$2"
	local extra_params="${3:-}"

	pushd "$target_dir"
	case $(file --mime-type -b "$archive") in
		application/gzip)
				tar -xz $extra_params -f $archive
				;;
		application/zip)
				unzip -q $extra_params $archive
				;;
		application/x-xz)
				tar -x  $extra_params -f $archive
				;;
	esac
	popd "$target_dir"
}

# See if execution is done by Jenkins. If called with a parameter,
# representing a 'domain', e.g. arm.com, it will also check if
# JENKINS_URL contains the latter.
is_jenkins_env () {
    local domain="${1-}"

    # check if running under Jenkins, if not, return non-zero
    # the checks assumes Jenkins executing if JENKINS_HOME is set
    [ -z "$JENKINS_HOME" ] && return 1

    # if no parameter passed, no more checks, quit
    [ -z "$domain" ] && return 0

    if echo "$JENKINS_URL" | grep -q "$domain"; then
	return 0
    fi

    return 1
}


# Check if execution is under ARM's jenkins
is_arm_jenkins_env() {
    local arm_domain="arm.com"
    return $(is_jenkins_env "$arm_domain")
}


# Provide correct linaro cross toolchain based on environment
set_cross_compile_gcc_linaro_toolchain() {
    local cross_compile_path="/home/buildslave/tools"

    # if under arm enviroment, overide cross-compilation path
    is_arm_jenkins_env || upon "$local_ci" && cross_compile_path="/arm/pdsw/tools"

    echo "${cross_compile_path}/gcc-linaro-6.2.1-2016.11-x86_64_aarch64-linux-gnu/bin/aarch64-linux-gnu-"
}

if is_jenkins_env; then
	jenkins_run=1
	umask 0002
else
	unset jenkins_run
fi

# Project scratch location for Trusted Firmware CI
project_filer="${nfs_volume}/projectscratch/ssg/trusted-fw"
project_scratch="${PROJECT_SCRATCH:-$project_filer/ci-workspace}"
warehouse="${nfs_volume}/warehouse"
jenkins_url="${JENKINS_URL%/*}"
jenkins_url="${jenkins_url:-https://ci.trustedfirmware.org/}"

# Model revisions
model_version_11_24="${model_version:-11.24}"
model_build_11_24="${model_build:-24}"

model_version="${model_version:-11.26}"
model_build="${model_build:-11}"
model_flavour="${model_flavour:-Linux64_GCC-9.3}"

# Model snapshots from filer are not normally not accessible from developer
# systems. Ignore failures from picking real path for local runs.
pinned_cortex="$(readlink -f ${pinned_cortex:-$project_filer/models/cortex})" || true
pinned_css="$(readlink -f ${pinned_css:-$project_filer/models/css})" || true

tforg_gerrit_url="review.trustedfirmware.org"

# Repository URLs. We're using anonymous HTTP as they appear to be faster rather
# than any scheme with authentication.
tf_src_repo_url="${tf_src_repo_url:-$TF_SRC_REPO_URL}"
tf_src_repo_url="${tf_src_repo_url:-https://$tforg_gerrit_url/TF-A/trusted-firmware-a}"
tftf_src_repo_url="${tftf_src_repo_url:-$TFTF_SRC_REPO_URL}"
tftf_src_repo_url="${tftf_src_repo_url:-https://$tforg_gerrit_url/TF-A/tf-a-tests}"
ci_src_repo_url="${ci_src_repo_url:-$CI_SRC_REPO_URL}"
ci_src_repo_url="${ci_src_repo_url:-https://$tforg_gerrit_url/ci/tf-a-ci-scripts}"
tf_ci_repo_url="$ci_src_repo_url"
scp_src_repo_url="${scp_src_repo_url:-$SCP_SRC_REPO_URL}"
scp_src_repo_url="${scp_src_repo_url:-$scp_src_repo_default}"
spm_src_repo_url="${spm_src_repo_url:-$SPM_SRC_REPO_URL}"
spm_src_repo_url="${spm_src_repo_url:-https://$tforg_gerrit_url/hafnium/hafnium}"
tf_m_tests_src_repo_url="${tf_m_tests_src_repo_url:-$TF_M_TESTS_REPO_URL}"
tf_m_tests_src_repo_url="${tf_m_tests_src_repo_url:-https://$tforg_gerrit_url/TF-M/tf-m-tests}"
tf_m_extras_src_repo_url="${tf_m_extras_src_repo_url:-$TF_M_EXTRAS_REPO_URL}"
tf_m_extras_src_repo_url="${tf_m_extras_src_repo_url:-https://$tforg_gerrit_url/TF-M/tf-m-extras}"

tf_downloads="${tf_downloads:-file:///downloads/}"
tfa_downloads="${tfa_downloads:-file:///downloads/tf-a}"
css_downloads="${css_downloads:-$tfa_downloads/css}"

# SCP/MCP release binaries.
scp_mcp_downloads="${scp_mcp_downloads:-$tfa_downloads/css_scp_2.13.0}"

linaro_2001_release="${linaro_2001_release:-$tfa_downloads/linaro/20.01}"
linaro_release="${linaro_release:-$linaro_2001_release}"
mbedtls_version="${mbedtls_version:-3.6.1}"

# mbedTLS archive public hosting available at github.com
mbedtls_archive="${mbedtls_archive:-https://github.com/Mbed-TLS/mbedtls/archive/mbedtls-${mbedtls_version}.tar.gz}"

# FIXME: workaround to allow all on-prem host machines to access the latest LLVM
# LLVM archive public hosting available at github.com
llvm_version="${llvm_version:-14.0.0}"
llvm_dir="$workspace/llvm-$llvm_version"
llvm_archive="${llvm_archive:-https://github.com/llvm/llvm-project/releases/download/llvmorg-$llvm_version/clang+llvm-$llvm_version-x86_64-linux-gnu-ubuntu-18.04.tar.xz}"

coverity_path="${coverity_path:-${nfs_volume}/tools/coverity/static-analysis/2020.12}"
coverity_default_checkers=(
"--all"
"--checker-option DEADCODE:no_dead_default:true"
"--enable AUDIT.SPECULATIVE_EXECUTION_DATA_LEAK"
"--enable ENUM_AS_BOOLEAN"
"--enable-constraint-fpp"
"--ticker-mode none"
"--hfa"
)

docker_registry="${docker_registry:-}"

# Define toolchain version and toolchain binary paths
toolchain_version="12.3.rel1"

aarch64_none_elf_dir="${nfs_volume}/pdsw/tools/arm-gnu-toolchain-${toolchain_version}-x86_64-aarch64-none-elf"
aarch64_none_elf_prefix="aarch64-none-elf-"

arm_none_eabi_dir="${nfs_volume}/pdsw/tools/arm-gnu-toolchain-${toolchain_version}-x86_64-arm-none-eabi"
arm_none_eabi_prefix="arm-none-eabi-"

path_list=(
		"${aarch64_none_elf_dir}/bin"
		"${arm_none_eabi_dir}/bin"
		"${llvm_dir}/bin"
		"${nfs_volume}/pdsw/tools/gcc-arm-none-eabi-5_4-2016q3/bin"
		"$coverity_path/bin"
)

ld_library_path_list=(
)

license_path_list=${license_path_list-(
)}

# Setup various paths
if upon "$retain_paths"; then
	# If explicitly requested, retain local paths; apppend CI paths to the
	# existing ones.
	op="append" extend_path "PATH" "path_list"
	op="append" extend_path "LD_LIBRARY_PATH" "ld_library_path_list"
	op="append" extend_path "LM_LICENSE_FILE" "license_path_list"
else
	# Otherwise, prepend CI paths so that they take effect before local ones
	extend_path "PATH" "path_list"
	extend_path "LD_LIBRARY_PATH" "ld_library_path_list"
	extend_path "LM_LICENSE_FILE" "license_path_list"
fi

export LD_LIBRARY_PATH
export LM_LICENSE_FILE
export ARM_TOOL_VARIANT=ult

# vim: set tw=80 sw=8 noet:
