#!/usr/bin/env bash
#
# Copyright (c) 2019-2025 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Builds a package with Trusted Firwmare and other payload binaries. The package
# is meant to be executed by run_package.sh

set -e

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

if [ ! -d "$workspace" ]; then
	die "Directory $workspace doesn't exist"
fi

# Directory to where the source code e.g. for Trusted Firmware is checked out.
export tf_root="${tf_root:-$workspace/trusted_firmware}"
export tftf_root="${tftf_root:-$workspace/trusted_firmware_tf}"
export tfut_root="${tfut_root:-$workspace/tfut}"
cc_root="${cc_root:-$ccpathspec}"
spm_root="${spm_root:-$workspace/spm}"
rmm_root="${rmm_root:-$workspace/tf-rmm}"

# Refspecs
tf_refspec="$TF_REFSPEC"
tftf_refspec="$TFTF_REFSPEC"
spm_refspec="$SPM_REFSPEC"
rmm_refspec="$RMM_REFSPEC"
tfut_gerrit_refspec="$TFUT_GERRIT_REFSPEC"

test_config="${TEST_CONFIG:?}"
test_group="${TEST_GROUP:?}"
build_configs="${BUILD_CONFIG:?}"
run_config="${RUN_CONFIG:?}"
cc_config="${CC_ENABLE:-}"

export archive="$artefacts"
build_log="$artefacts/build.log"

fiptool_path() {
	echo $tf_build_root/$(get_tf_opt PLAT)/${bin_mode}/tools/fiptool/fiptool
}

cert_create_path() {
	echo $tf_build_root/$(get_tf_opt PLAT)/${bin_mode}/tools/cert_create/cert_create
}

# Validate $bin_mode
case "$bin_mode" in
	"" | debug | release)
		;;
	*)
		die "Invalid value for bin_mode: $bin_mode"
		;;
esac

# File to save any environem
hook_env_file="$(mktempfile)"

# Echo from a build wrapper. Print to descriptor 3 that's opened by the build
# function.
echo_w() {
	echo $echo_flags "$@" >&3
}

# Print a separator to the log file. Intended to be used at the tail end of a pipe
log_separator() {
	{
		echo
		echo "----------"
	} >> "$build_log"

	tee -a "$build_log"

	{
		echo "----------"
		echo
	} >> "$build_log"
}

# Call function $1 if it's defined
call_func() {
	if type "${1:?}" &>/dev/null; then
		echo
		echo "> ${2:?}:$1()"
		eval "$1"
		echo "< $2:$1()"
	fi
}

# Retry a command a number of times if it fails. Intended for I/O commands
# in a CI environment which may be flaky.
function retry() {
    for i in $(seq 1 3); do
        if "$@"; then
            return 0
        fi
        sleep $(( i * 5 ))
    done
    return 1
}

# Call hook $1 in all chosen fragments if it's defined. Hooks are invoked from
# within a subshell, so any variables set within a hook are lost. Should a
# variable needs to be set from within a hook, the function 'set_hook_var'
# should be used
call_hook() {
	local func="$1"
	local config_fragment

	[ -z "$func" ] && return 0

	echo "=== Calling hooks: $1 ==="

	: >"$hook_env_file"

	if [ "$run_config_candidates" ]; then
		for config_fragment in $run_config_candidates; do
			(
			source "$ci_root/run_config/$config_fragment"
			call_func "$func" "$config_fragment"
			) || fail_build
		done
	fi

	if [ "$run_config_tfut_candidates" ]; then
		for config_fragment in $run_config_tfut_candidates; do
			(
			source "$ci_root/run_config_tfut/$config_fragment"
			call_func "$func" "$config_fragment"
			) || fail_build
		done
	fi

	# Also source test config file
	(
	unset "$func"
	source "$test_config_file"
	call_func "$func" "$(basename $test_config_file)"
	) || fail_build

	# Have any variables set take effect
	source "$hook_env_file"

	echo "=== End calling hooks: $1 ==="
}

# Set a variable from within a hook
set_hook_var() {
	echo "export $1=\"${2?}\"" >> "$hook_env_file"
}

# Append to an array from within a hook
append_hook_var() {
	echo "export $1+=\"${2?}\"" >> "$hook_env_file"
}

# Have the main build script source a file
source_later() {
	echo "source ${1?}" >> "$hook_env_file"
}

# Setup TF build wrapper function by pointing to a script containing a function
# that will be called with the TF build commands.
setup_tf_build_wrapper() {
	source_later "$ci_root/script/${wrapper?}_wrapper.sh"
	set_hook_var "tf_build_wrapper" "${wrapper}_wrapper"
	echo "Setup $wrapper build wrapper."
}

# Collect .bin files for archiving
collect_build_artefacts() {
	if [ ! -d "${from:?}" ]; then
		return
	fi

	if ! find "$from" \( -name "*.bin" -o -name '*.elf' -o -name '*.dtb' -o -name '*.axf' -o -name '*.stm32' -o -name '*.img' \) -exec cp -t "${to:?}" '{}' +; then
		echo "You probably are running local CI on local repositories."
		echo "Did you set 'dont_clean' but forgot to run 'distclean'?"
		die
	fi
}

# Collect SPM/hafnium artefacts with "secure_" appended to the files
# generated for SPM(secure hafnium).
collect_spm_artefacts() {
	if [ -d "${non_secure_from:?}" ]; then
		find "$non_secure_from" \( -name "*.bin" -o -name '*.elf' \) -exec cp -t "${to:?}" '{}' +
	fi

	if [ -d "${secure_from:?}" ]; then
		for f in $(find "$secure_from" \( -name "*.bin" -o -name '*.elf' \)); do cp -- "$f" "${to:?}"/secure_$(basename $f); done
	fi
}

collect_tfut_artefacts() {
	if [ ! -d "${from:?}" ]; then
                return
        fi

	pushd "$tfut_root/build"
	artefact_list=$(python3 "$ci_root/script/get_ut_test_list.py")
	for artefact in $artefact_list; do
		cp -t "${to:?}" "$from/$artefact"
	done
	echo "$artefact_list" | tr ' ' '\n' > "${to:?}/tfut_artefacts.txt"
	popd
}

collect_tfut_coverage() {
	if [ "$coverage" != "ON" ]; then
                return
        fi

	pushd "$tfut_root/build"
	touch "${to:?}/tfut_coverage.txt"
	popd
}

# Map the UART ID used for expect with the UART descriptor and port
# used by the FPGA automation tools.
map_uart() {
	local port="${port:?}"
	local descriptor="${descriptor:?}"
	local baudrate="${baudrate:?}"
	local run_root="${archive:?}/run"

	local uart_dir="$run_root/uart${uart:?}"
	mkdir -p "$uart_dir"

	echo "$port" > "$uart_dir/port"
	echo "$descriptor" > "$uart_dir/descriptor"
	echo "$baudrate" > "$uart_dir/baudrate"

	echo "UART${uart} mapped to port ${port} with descriptor ${descriptor} and baudrate ${baudrate}"
}

# Arrange environment varibles to be set when expect scripts are launched
set_expect_variable() {
	local var="${1:?}"
	local val="${2?}"

	local run_root="${archive:?}/run"
	local uart_dir="$run_root/uart${uart:?}"
	mkdir -p "$uart_dir"

	env_file="$uart_dir/env" quote="1" emit_env "$var" "$val"
	echo "UART$uart: env has $@"
}

# Place the binary package a pointer to expect script, and its parameters
track_expect() {
	local file="${file:?}"
	local timeout="${timeout-600}"
	local run_root="${archive:?}/run"

	local uart_dir="$run_root/uart${uart:?}"
	mkdir -p "$uart_dir"

	echo "$file" > "$uart_dir/expect"
	echo "$timeout" > "$uart_dir/timeout"
	if [ -n "$lava_timeout" ]; then
		set_run_env "lava_timeout" "$lava_timeout"
	fi

	echo "UART$uart to be tracked with $file; timeout ${timeout}s; lava_timeout ${lava_timeout:-N/A}s"

	if [ ! -z "${port}" ]; then
		echo "${port}" > "$uart_dir/port"
	fi

	# The run script assumes UART0 to be primary. If we're asked to set any
	# other UART to be primary, set a run environment variable to signal
	# that to the run script
	if upon "$set_primary"; then
		echo "Primary UART set to UART$uart."
		set_run_env "primary_uart" "$uart"
	fi

	# UART used by payload(such as tftf, Linux) may not be the same as the
	# primary UART. Set a run environment variable to track the payload
	# UART which is tracked to check if the test has finished sucessfully.
	if upon "$set_payload_uart"; then
		echo "Payload uses UART$uart."
		set_run_env "payload_uart" "$uart"
	fi
}

# Extract a FIP in $1 using fiptool
extract_fip() {
	local fip="$1"

	if is_url "$1"; then
		url="$1" fetch_file
		fip="$(basename "$1")"
	fi

	fiptool=$(fiptool_path)
	"$fiptool" unpack "$fip"
	echo "Extracted FIP: $fip"
}

# Report build failure by printing a the tail end of build log. Archive the
# build log for later inspection
fail_build() {
	local log_path

	if upon "$jenkins_run"; then
		log_path="$BUILD_URL/artifact/artefacts/build.log"
	else
		log_path="$build_log"
	fi

	echo
	echo "Build failed!"
	echo
	echo "See $log_path for full output"
	echo
	cp -t "$archive" "$build_log"
	exit 1;
}

# Build a FIP with supplied arguments
build_fip() {
	(
	echo "Building FIP with arguments: $@"
	local tf_env="$workspace/tf.env"

	if [ -f "$tf_env" ]; then
		set -a
		source "$tf_env"
		set +a
	fi

    if [ "$(get_tf_opt MEASURED_BOOT)" = 1 ]; then
		# These are needed for accurate hash verification
		local build_args_path="${workspace}/fip_build_args"
		echo $@ > $build_args_path
		archive_file $build_args_path
	fi

	make -C "$tf_root" $make_j_opts $(cat "$tf_config_file") DEBUG="$DEBUG" BUILD_BASE=$tf_build_root V=1 "$@" \
		${fip_targets:-fip} 2>&1 | tee -a "$build_log" || fail_build
	) 2>&1 | tee -a "$build_log" || fail_build
}

# Build any extra rule from TF-A makefile with supplied arguments.
#
# This is useful in case you need to build something else than firmware binaries
# or the FIP.
build_tf_extra() {
	(
	tf_extra_rules=${tf_extra_rules:?}
	echo "Building extra TF rule(s): $tf_extra_rules"
	echo "  Arguments: $@"

	local tf_env="$workspace/tf.env"

	if [ -f "$tf_env" ]; then
		set -a
		source "$tf_env"
		set +a
	fi

	make -C "$tf_root" $make_j_opts $(cat "$tf_config_file") DEBUG="$DEBUG" V=1 BUILD_BASE=$tf_build_root "$@" \
		${tf_extra_rules} 2>&1 | tee -a "$build_log" || fail_build
	)
}

fip_update() {
	fiptool=$(fiptool_path)
	# Before the update process, check if the given image is supported by
	# the fiptool. It's assumed that both fiptool and cert_create move in
	# tandem, and therefore, if one has support, the other has it too.
	if ! ("$fiptool" update 2>&1 || true) | grep -qe "\s\+--${bin_name:?}"; then
		return 1
	fi

	if not_upon "$(get_tf_opt TRUSTED_BOARD_BOOT)"; then
		echo "Updating FIP image: $bin_name"
		# Update HW config. Without TBBR, it's only a matter of using
		# the update sub-command of fiptool
		"$fiptool" update "--$bin_name" "${src:-}" \
				"$archive/fip.bin"
	else
		echo "Updating FIP image (TBBR): $bin_name"
		# With TBBR, we need to unpack, re-create certificates, and then
		# recreate the FIP.
		local fip_dir="$(mktempdir)"
		local bin common_args stem
		local rot_key="$(get_tf_opt ROT_KEY)"

		rot_key="${rot_key:?}"
		if ! is_abs "$rot_key"; then
			rot_key="$tf_root/$rot_key"
		fi

		# Arguments only for cert_create
		local cert_args="-n"
		cert_args+=" --tfw-nvctr ${nvctr:-31}"
		cert_args+=" --ntfw-nvctr ${nvctr:-223}"
		cert_args+=" --key-alg ${KEY_ALG:-rsa}"
		cert_args+=" --rot-key $rot_key"

		local dyn_config_opts=(
		"fw-config"
		"hw-config"
		"tb-fw-config"
		"nt-fw-config"
		"soc-fw-config"
		"tos-fw-config"
		)

		# Binaries without key certificates
		declare -A has_no_key_cert
		for bin in "tb-fw" "${dyn_config_opts[@]}"; do
			has_no_key_cert["$bin"]="1"
		done

		# Binaries without certificates
		declare -A has_no_cert
		for bin in "hw-config" "${dyn_config_opts[@]}"; do
			has_no_cert["$bin"]="1"
		done

		pushd "$fip_dir"

		# Unpack FIP
		"$fiptool" unpack "$archive/fip.bin" 2>&1 | tee -a "$build_log"

		# Remove all existing certificates
		rm -f *-cert.bin

		# Copy the binary to be updated
		cp -f "$src" "${bin_name}.bin"

		# FIP unpack dumps binaries with the same name as the option
		# used to pack it; likewise for certificates. Reverse-engineer
		# the command line from the binary output.
		common_args="--trusted-key-cert trusted_key.crt"
		for bin in *.bin; do
			stem="${bin%%.bin}"
			common_args+=" --$stem $bin"
			if not_upon "${has_no_cert[$stem]}"; then
				common_args+=" --$stem-cert $stem.crt"
			fi
			if not_upon "${has_no_key_cert[$stem]}"; then
				common_args+=" --$stem-key-cert $stem-key.crt"
			fi
		done

		# Create certificates
		cert_create=$(cert_create_path)
		"$cert_create" $cert_args $common_args 2>&1 | tee -a "$build_log"

		# Recreate and archive FIP
		"$fiptool" create $common_args "fip.bin" 2>&1 | tee -a "$build_log"
		archive_file "fip.bin"

		popd
	fi
}

# Update hw-config in FIP, and remove the original DTB afterwards.
update_fip_hw_config() {
	# The DTB needs to be loaded by the model (and not updated in the FIP)
	# in configs:
	#            1. Where BL2 isn't present
	#            2. Where we boot to Linux directly as BL33
	case "1" in
		"$(get_tf_opt RESET_TO_BL31)" | \
		"$(get_tf_opt ARM_LINUX_KERNEL_AS_BL33)" | \
		"$(get_tf_opt RESET_TO_SP_MIN)" | \
		"$(get_tf_opt RESET_TO_BL2)")
			return 0;;
	esac

	if bin_name="hw-config" src="$archive/dtb.bin" fip_update; then
		# Remove the DTB so that model won't load it
		rm -f "$archive/dtb.bin"
	fi
}

get_tftf_opt() {
	(
	name="${1:?}"
	if config_valid "$tftf_config_file"; then
		source "$tftf_config_file"
		echo "${!name}"
	fi
	)
}

get_tf_opt() {
	(
	name="${1:?}"
	if config_valid "$tf_config_file"; then
		source "$tf_config_file"
		echo "${!name}"
	fi
	)
}

get_rmm_opt() {
        (
        name="${1:?}"
        default="$2"
        if config_valid "$rmm_config_file"; then
                source "$rmm_config_file"
                # If !name is not defined, go with the default
                # value (if defined)
                if [ -z "${!name}" ]; then
                        echo "$default"
                else
                        echo "${!name}"
                fi
        fi
        )
}

clean_tf() {
	pushd "$tf_root"
	make distclean BUILD_BASE=$tf_build_root 2>&1 | tee -a "$build_log" || fail_build
	popd
}

build_tf() {
	(
	env_file="$workspace/tf.env"
	config_file="${tf_build_config:-$tf_config_file}"

	# Build fiptool and all targets by default
	build_targets="${tf_build_targets:-fiptool all}"

	source "$config_file" || fail_build

	# If it is a TBBR build, extract the MBED TLS library from archive
	if [ "$(get_tf_opt TRUSTED_BOARD_BOOT)" = 1 ] ||
	   [ "$(get_tf_opt MEASURED_BOOT)" = 1 ] ||
	   [ "$(get_tf_opt DRTM_SUPPORT)" = 1 ]; then
		mbedtls_dir="$workspace/mbedtls"
		if [ ! -d "$mbedtls_dir" ]; then
			mbedtls_ar="$workspace/mbedtls.tar.gz"

			url="$mbedtls_archive" saveas="$mbedtls_ar" fetch_file
			mkdir "$mbedtls_dir"
			extract_tarball $mbedtls_ar $mbedtls_dir --strip-components=1
		fi

		emit_env "MBEDTLS_DIR" "$mbedtls_dir"
	fi
	if [ "$(get_tf_opt PLATFORM_TEST)" = "tfm-testsuite" ] &&
	   not_upon "${TF_M_TESTS_PATH}"; then
		emit_env "TF_M_TESTS_PATH" "$WORKSPACE/tf-m-tests"
	fi
	if [ "$(get_tf_opt PLATFORM_TEST)" = "tfm-testsuite" ] &&
	   not_upon "${TF_M_EXTRAS_PATH}"; then
		emit_env "TF_M_EXTRAS_PATH" "$WORKSPACE/tf-m-extras"
	fi
	if [ "$(get_tf_opt DICE_PROTECTION_ENVIRONMENT)" = 1 ] &&
	   not_upon "${QCBOR_DIR}"; then
		emit_env "QCBOR_DIR" "$WORKSPACE/qcbor"
	fi

    # Hash verification only occurs if there is a sufficient amount of
    # information in the event log, which is as long as EVENT_LOG_LEVEL
    # is set to at least 20 or if it is a debug build
    if [[ ("$(get_tf_opt MEASURED_BOOT)" -eq 1) &&
        (($bin_mode == "debug") || ("$(get_tf_opt EVENT_LOG_LEVEL)" -ge 20)) ]]; then
		# This variable is later exported to the expect scripts so
		# the hashes in the TF-A event log can be verified
		set_run_env "verify_hashes" "1"
	fi
	if [ -f "$env_file" ]; then
		set -a
		source "$env_file"
		set +a
	fi

	if is_arm_jenkins_env || upon "$local_ci"; then
		path_list=(
			"$llvm_dir/bin"
		)
		extend_path "PATH" "path_list"
	fi

	pushd "$tf_root"

	if [ -f "$tf_patch_record" ]; then
		cat <<-EOF | log_separator
		Building with patches:
		        $(cat $tf_patch_record)
		EOF
	fi

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator

Build command line:
	$tf_build_wrapper make $make_j_opts $(cat "$config_file" | tr '\n' ' ') DEBUG=$DEBUG V=1 BUILD_BASE=$tf_build_root $build_targets

CC version:
$(${CC-${CROSS_COMPILE}gcc} -v 2>&1)
EOF

	if not_upon "$local_ci"; then
		connect_debugger=0
	fi

	# Build TF. Since build output is being directed to the build log, have
	# descriptor 3 point to the current terminal for build wrappers to vent.
	$tf_build_wrapper poetry run make $make_j_opts $(cat "$config_file") \
		DEBUG="$DEBUG" V=1 BUILD_BASE="$tf_build_root" SPIN_ON_BL1_EXIT="$connect_debugger" \
		$build_targets 3>&1 2>&1 | tee -a "$build_log" || fail_build

	# the memory command is slow and we only want it for keeping a record
	if upon "$dont_print_memory"; then
		return
	fi
        if [ "$build_targets" != "doc" ]; then
                (poetry run memory --root "$tf_build_root" symbols 2>&1 || true) | tee -a "${build_log}"

                for map in $(find "${tf_build_root}" -name '*.map'); do
                    (poetry run memory --root "${tf_build_root}" summary "${map}" 2>&1 || true) | tee -a "${build_log}"
                done
        fi
	popd
	)
}

build_tftf() {
	(
	config_file="${tftf_build_config:-$tftf_config_file}"

	# Build tftf target by default
	build_targets="${tftf_build_targets:-all}"

	source "$config_file" || fail_build

	cd "$tftf_root"

	# TFTF build system cannot reliably deal with -j option, so we avoid
	# using that.

	# Log build command line
	cat <<EOF | log_separator

Build command line:
	make $make_j_opts $(cat "$config_file" | tr '\n' ' ') DEBUG=$DEBUG V=1 BUILD_BASE="$tftf_build_root" $build_targets

EOF

	make $make_j_opts $(cat "$config_file") DEBUG="$DEBUG" V=1 BUILD_BASE="$tftf_build_root" \
		$build_targets 2>&1 | tee -a "$build_log" || fail_build
	)
}

build_cc() {
# Building code coverage plugin
	ARM_DIR=/arm
	pvlibversion=$(/arm/devsys-tools/abs/detag "SysGen:PVModelLib:$model_version::trunk")
	PVLIB_HOME=$warehouse/SysGen/PVModelLib/$model_version/${pvlibversion}/external
	if [ -n "$(find "$ARM_DIR" -maxdepth 0 -type d -empty 2>/dev/null)" ]; then
    		echo "Error: Arm warehouse not mounted. Please mount the Arm warehouse to your /arm local folder"
    		exit -1
	fi  # Error if arm warehouse not found
	cd "$ccpathspec/scripts/tools/code_coverage/fastmodel_baremetal/bmcov"

	make -C model-plugin PVLIB_HOME=$PVLIB_HOME 2>&1 | tee -a "$build_log"
}

build_spm() {
	(
	env_file="$workspace/spm.env"
	config_file="${spm_build_config:-$spm_config_file}"

	source "$config_file" || fail_build

	if [ -f "$env_file" ]; then
		set -a
		source "$env_file"
		set +a
	fi

	cd "$spm_root"

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator

Build command line:
	make $make_j_opts OUT=$spm_build_root $(cat "$config_file" | tr '\n' ' ')

EOF

	# Build SPM. Since build output is being directed to the build log, have
	# descriptor 3 point to the current terminal for build wrappers to vent.
	make $make_j_opts OUT=$spm_build_root $(cat "$config_file") 3>&1 2>&1 | tee -a "$build_log" \
		|| fail_build
	)
}

build_rmm() {
	(
	env_file="$workspace/rmm.env"
	config_file="${rmm_build_config:-$rmm_config_file}"

	# Build fiptool and all targets by default
	export CROSS_COMPILE="aarch64-none-elf-"

	source "$config_file" || fail_build

	if [ -f "$env_file" ]; then
		set -a
		source "$env_file"
		set +a
	fi

	cd "$rmm_root"

	if [ -f "$rmm_root/requirements.txt" ]; then
		export PATH="$HOME/.local/bin:$PATH"
		python3 -m pip install --upgrade pip
		python3 -m pip install -r "$rmm_root/requirements.txt"
	fi

	if not_upon "$local_ci"; then
                connect_debugger=0
	fi

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator

Build command line:
        cmake -DRMM_CONFIG=${plat}_defcfg "$cmake_gen" -S $rmm_root -B $rmm_build_root -DRMM_TOOLCHAIN=$rmm_toolchain -DRMM_FPU_USE_AT_REL2=$rmm_fpu_use_at_rel2 -DATTEST_EL3_TOKEN_SIGN=$rmm_attest_el3_token_sign -DRMM_V1_1=$rmm_v1_1 ${extra_options}
        cmake --build $rmm_build_root --config $cmake_build_type $make_j_opts -v ${extra_targets+-- $extra_targets}

EOF
        cmake \
             -DRMM_CONFIG=${plat}_defcfg $cmake_gen \
             -S $rmm_root -B $rmm_build_root \
             -DRMM_TOOLCHAIN=$rmm_toolchain \
             -DRMM_FPU_USE_AT_REL2=$rmm_fpu_use_at_rel2 \
             -DATTEST_EL3_TOKEN_SIGN=$rmm_attest_el3_token_sign \
             -DRMM_V1_1=$rmm_v1_1 \
             ${extra_options}
        cmake --build $rmm_build_root --config $cmake_build_type $make_j_opts -v ${extra_targets+-- $extra_targets} 3>&1 2>&1 | tee -a "$build_log" || fail_build
        )
}

build_tfut() {
	(
	config_file="${tfut_build_config:-$tfut_config_file}"

        # Build tfut target by default
        build_targets="${tfut_build_targets:-all}"

        source "$config_file" || fail_build

	mkdir -p "$tfut_root/build"
        cd "$tfut_root/build"

	#Override build targets only if the run config did not set them.
	if [ $build_targets == "all" ]; then
		tests_line=$(cat "$config_file" | { grep "tests=" || :; })
		if [ -z "$tests_line" ]; then
			build_targets=$(echo "$tests_line" | awk -F= '{ print $NF }')
		fi
	fi

	#TODO: extract vars from env to use them for cmake

	test -f "$config_file"

	config=$(cat "$config_file" | grep -v "tests=") \
		&& cmake_config=$(echo "$config" | sed -e 's/^/\-D/')

	# Check if cmake is installed
	if ! command -v cmake &> /dev/null
	then
		echo "cmake could not be found"
		exit 1
	fi

	# Log build command line
        cat <<EOF | log_separator

Build command line:
cmake $(echo "$cmake_config") -G"Unix Makefiles" --debug-output -DCMAKE_VERBOSE_MAKEFILE -DCOVERAGE="$COVERAGE" -DUNIT_TEST_PROJECT_PATH="$tf_root" ..
        make $(echo "$config" | tr '\n' ' ') DEBUG=$DEBUG V=1 $build_targets

EOF
	cmake $(echo "$cmake_config") -G"Unix Makefiles" --debug-output \
		-DCMAKE_VERBOSE_MAKEFILE=ON 				\
		-DCOVERAGE="$COVERAGE" 					\
		-DUNIT_TEST_PROJECT_PATH="$tf_root" 			\
		.. 2>&1 | tee -a "$build_log" || fail_build
	echo "Done with cmake" | tee -a "$build_log"
        make $(echo "$config") VERBOSE=1 \
                $build_targets 2>&1 | tee -a "$build_log" || fail_build
        )

}

# Set metadata for the whole package so that it can be used by both Jenkins and
# shell
set_package_var() {
	env_file="$artefacts/env" emit_env "$@"
}

set_tf_build_targets() {
	echo "Set build target to '${targets:?}'"
	set_hook_var "tf_build_targets" "$targets"
}

set_tftf_build_targets() {
	echo "Set build target to '${targets:?}'"
	set_hook_var "tftf_build_targets" "$targets"
}

set_spm_build_targets() {
	echo "Set build target to '${targets:?}'"
	set_hook_var "spm_build_targets" "$targets"
}

add_tfut_build_targets() {
	echo "Add TFUT build targets '${targets:?}'"
	append_hook_var "tfut_build_targets" "$targets "
}

set_spm_out_dir() {
	echo "Set SPMC binary build to '${out_dir:?}'"
	set_hook_var "spm_secure_out_dir" "$out_dir"
}
# Look under $archive directory for known files such as blX images, kernel, DTB,
# initrd etc. For each known file foo, if foo.bin exists, then set variable
# foo_bin to the path of the file. Make the path relative to the workspace so as
# to remove any @ characters, which Jenkins inserts for parallel runs. If the
# file doesn't exist, unset its path.
set_default_bin_paths() {
	local image image_name image_path path
	local archive="${archive:?}"
	local set_vars
	local var

	pushd "$archive"

	for file in *.bin; do
		# Get a shell variable from the file's stem
		var_name="${file%%.*}_bin"
		var_name="$(echo "$var_name" | sed -r 's/[^[:alnum:]]/_/g')"

		# Skip setting the variable if it's already
		if [ "${!var_name}" ]; then
			echo "Note: not setting $var_name; already set to ${!var_name}"
			continue
		else
			set_vars+="$var_name "
		fi

		eval "$var_name=$file"
	done

	echo "Binary paths set for: "
	{
	for var in $set_vars; do
		echo -n "\$$var "
	done
	} | fmt -80 | sed 's/^/  /'
	echo

	popd
}

gen_model_params() {
	local model_param_file="$archive/model_params"
	[ "$connect_debugger" ] && [ "$connect_debugger" -eq 1 ] && wait_debugger=1

	set_default_bin_paths
	echo "Generating model parameter for $model..."
	source "$ci_root/model/${model:?}.sh"
	archive_file "$model_param_file"
}

set_model_path() {
	local input_path="${1:?}"

	set_run_env "model_path" "$input_path"
}

set_model_env() {
	local var="${1:?}"
	local val="${2?}"
	local run_root="${archive:?}/run"

	mkdir -p "$run_root"
	echo "export $var=$val" >> "$run_root/model_env"
}
set_run_env() {
	local var="${1:?}"
	local val="${2?}"
	local run_root="${archive:?}/run"

	mkdir -p "$run_root"
	env_file="$run_root/env" quote="1" emit_env "$var" "$val"
}

show_head() {
	# Display HEAD descripton
	pushd "$1"
	git show --quiet --no-color | sed 's/^/  > /g'
	echo
	popd
}

# Choose debug binaries to run; by default, release binaries are chosen to run
use_debug_bins() {
	local run_root="${archive:?}/run"

	echo "Choosing debug binaries for execution"
	set_package_var "BIN_MODE" "debug"
}

assert_can_git_clone() {
	local name="${1:?}"
	local dir="${!name}"

	# If it doesn't exist, it can be cloned into
	if [ ! -e "$dir" ]; then
		return 0
	fi

	# If it's a directory, it must be a Git clone already
	if [ -d "$dir" ] && [ -d "$dir/.git" ]; then
		# No need to clone again
		echo "Using existing git clone for $name: $dir"
		return 1
	fi

	die "Path $dir exists but is not a git clone"
}

clone_repo() {
	if ! is_url "${clone_url?}"; then
		# For --depth to take effect on local paths, it needs to use the
		# file:// scheme.
		clone_url="file://$clone_url"
	fi

	git clone -q --depth 1 "$clone_url" "${where?}"
	if [ "$refspec" ]; then
		pushd "$where"
		git fetch -q --depth 1 origin "$refspec"
		git checkout -q FETCH_HEAD
		popd
	fi
}

build_unstable() {
	echo "--BUILD UNSTABLE--" | tee -a "$build_log"
}

apply_patch() {
	# If skip_patches is set, the developer has applied required patches
	# manually. They probably want to keep them applied for debugging
	# purposes too. This means we don't have to apply/revert them as part of
	# build process.
	if upon "$skip_patches"; then
		echo "Skipped applying ${1:?}..."
		return 0
	else
		echo "Applying ${1:?}..."
	fi

	if git apply --reverse --check < "$ci_root/patch/$1" 2> /dev/null; then
		echo "Skipping already applied ${1:?}"
		return 0
	fi

	if git apply < "$ci_root/patch/$1"; then
		echo "$1" >> "${patch_record:?}"
	else
		fail_build
	fi
}

apply_tf_patch() {
	root="$tf_root"
	new_root="$archive/tfa_mirror"

	# paralell builds are only used locally. Don't do for CI since this will
	# have a speed penalty. Also skip if this was already done as a single
	# job may apply many patches.
	if upon "$local_ci"; then
		# collect diff on first run for either a fresh or dirty build
		if [[ ! -d $new_root ]] || [[ ! -e "$tf_patch_record" ]]; then
			diff=$(mktempfile)

			# get anything still uncommitted (including submodules)
			pushd  $tf_root
			git diff --submodule=diff HEAD > $diff
			popd
		fi

		if [[ ! -d $new_root ]]; then
			# git will hard link when cloning locally, no need for --depth=1
			git clone "$root" $new_root --shallow-submodules --recurse-submodules
		fi

		tf_root=$new_root # next apply_tf_patch will run in the same hook
		set_hook_var "tf_root" "$tf_root" # for anyone outside the hook

		if [[ ! -e "$tf_patch_record" ]]; then
			# apply uncommited changes so they are picked up in the build
			pushd  $tf_root
			if upon "$dont_clean"; then
				# tree is dirty, refresh
				git stash
			fi
			git apply $diff &> /dev/null || true
			popd
			set +x

		fi
	fi

	pushd "$tf_root"
	patch_record="$tf_patch_record" apply_patch "$1"
	popd
}

mkdir -p "$workspace"
mkdir -p "$archive"
set_package_var "TEST_CONFIG" "$test_config"

{
echo
echo "CONFIGURATION: $test_group/$test_config"
echo
} |& log_separator

tf_config="$(echo "$build_configs" | awk -F, '{print $1}')"
tftf_config="$(echo "$build_configs" | awk -F, '{print $2}')"
spm_config="$(echo "$build_configs" | awk -F, '{print $3}')"
rmm_config="$(echo "$build_configs" | awk -F, '{print $4}')"
tfut_config="$(echo "$build_configs" | awk -F, '{print $5}')"

test_config_file="$ci_root/group/$test_group/$test_config"

tf_config_file="$ci_root/tf_config/$tf_config"
tftf_config_file="$ci_root/tftf_config/$tftf_config"
spm_config_file="$ci_root/spm_config/$spm_config"
rmm_config_file="$ci_root/rmm_config/$rmm_config"
tfut_config_file="$ci_root/tfut_config/$tfut_config"

# File that keeps track of applied patches
tf_patch_record="$workspace/tf_patches"

# Split run config into TF and TFUT components
run_config_tfa="$(echo "$run_config" | awk -F, '{print $1}')"
run_config_tfut="$(echo "$run_config" | awk -F, '{print $2}')"

pushd "$workspace"

if ! config_valid "$tf_config"; then
	tf_config=
else
	echo "Trusted Firmware config:"
	echo
	sort "$tf_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$tftf_config"; then
	tftf_config=
else
	echo "Trusted Firmware TF config:"
	echo
	sort "$tftf_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$spm_config"; then
	spm_config=
else
	echo "SPM config:"
	echo
	sort "$spm_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$rmm_config"; then
        rmm_config=
else
        echo "Trusted Firmware RMM config:"
        echo
        sort "$rmm_config_file" | sed '/^\s*$/d;s/^/\t/'
        echo
fi

if ! config_valid "$tfut_config"; then
	tfut_config=
else
	echo "TFUT config:"
	echo
	sort "$tfut_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$run_config_tfa"; then
	run_config_tfa=
fi

if { [ "$tf_config" ] || [ "$tfut_config" ]; } && assert_can_git_clone "tf_root"; then
	# If the Trusted Firmware repository has already been checked out, use
	# that location. Otherwise, clone one ourselves.
	echo "Cloning Trusted Firmware..."
	clone_url="${TF_CHECKOUT_LOC:-$tf_src_repo_url}" where="$tf_root" \
		refspec="$TF_REFSPEC" clone_repo 2>&1 | tee -a "$build_log"
	show_head "$tf_root"
fi

if [ "$tftf_config" ] && assert_can_git_clone "tftf_root"; then
	# If the Trusted Firmware TF repository has already been checked out,
	# use that location. Otherwise, clone one ourselves.
	echo "Cloning Trusted Firmware TF..."
	clone_url="${TFTF_CHECKOUT_LOC:-$tftf_src_repo_url}" where="$tftf_root" \
		refspec="$TFTF_REFSPEC" clone_repo 2>&1 | tee -a "$build_log"
	show_head "$tftf_root"
fi

if [ -n "$cc_config" ] ; then
	if [ "$cc_config" -eq 1 ] && assert_can_git_clone "cc_root"; then
		# Copy code coverage repository
		echo "Cloning Code Coverage..."
		git clone -q $cc_src_repo_url cc_plugin --depth 1 -b $cc_src_repo_tag > /dev/null
		show_head "$cc_root"
	fi
fi

if [ "$spm_config" ] ; then
	if assert_can_git_clone "spm_root"; then
		# If the SPM repository has already been checked out, use
		# that location. Otherwise, clone one ourselves.
		echo "Cloning SPM..."
		clone_url="${SPM_CHECKOUT_LOC:-$spm_src_repo_url}" \
			where="$spm_root" refspec="$SPM_REFSPEC" \
			clone_repo 2>&1 | tee -a "$build_log"
	fi

	# Query git submodules
	pushd "$spm_root"
	# Check if submodules need initialising

	# This handling is needed to reliably fetch submodules
	# in CI environment.
	for subm in $(git submodule status | awk '/^-/ {print $2}'); do
		for i in $(seq 1 7); do
			git submodule init $subm
			if git submodule update $subm; then
				break
			fi
			git submodule deinit --force $subm
			echo "Retrying $subm"
			sleep $((RANDOM % 10 + 5))
		done
	done

	git submodule status
	popd

	show_head "$spm_root"
fi

if [ "$rmm_config" ] && assert_can_git_clone "rmm_root"; then
	# If the RMM repository has already been checked out,
	# use that location. Otherwise, clone one ourselves.
	echo "Cloning TF-RMM..."
	clone_url="${RMM_CHECKOUT_LOC:-$rmm_src_repo_url}" where="$rmm_root" \
		refspec="$RMM_REFSPEC" clone_repo 2>&1 | tee -a "$build_log"
	show_head "$rmm_root"
fi

if [ "$tfut_config" ] && assert_can_git_clone "tfut_root"; then
	# If the Trusted Firmware UT repository has already been checked out,
	# use that location. Otherwise, clone one ourselves.
	echo "Cloning Trusted Firmware UT..."
	clone_url="${TFUT_CHECKOUT_LOC:-$tfut_src_repo_url}" where="$tfut_root" \
		refspec="$TFUT_GERRIT_REFSPEC" clone_repo 2>&1 | tee -a "$build_log"
	show_head "$tfut_root"
fi

if [ "$run_config_tfa" ]; then
	# Get candidates for TF-A run config
	run_config_candidates="$("$ci_root/script/gen_run_config_candidates.py" \
		"$run_config_tfa")"
	if [ -z "$run_config_candidates" ]; then
		die "No run config candidates!"
	else
		echo
		echo "Chosen fragments:"
		echo
		echo "$run_config_candidates" | sed 's/^\|\n/\t/g'
		echo
	fi
fi

if [ "$run_config_tfut" ]; then
	# Get candidates for run TFUT config
	run_config_tfut_candidates="$("$ci_root/script/gen_run_config_candidates.py" \
		"--unit-testing" "$run_config_tfut")"
	if [ -z "$run_config_tfut_candidates" ]; then
		die "No run TFUT config candidates!"
	else
		echo
		echo "Chosen fragments:"
		echo
		echo "$run_config_tfut_candidates" | sed 's/^\|\n/\t/g'
	fi
fi

call_hook "test_setup"
echo

if upon "$local_ci"; then
	# For local runs, since each config is tried in sequence, it's
	# advantageous to run jobs in parallel
	if [ "$make_j" ]; then
		make_j_opts="-j $make_j"
	else
		n_cores="$(getconf _NPROCESSORS_ONLN)" 2>/dev/null || true
		if [ "$n_cores" ]; then
			make_j_opts="-j $n_cores"
		fi
	fi
fi

# Install python build dependencies
if is_arm_jenkins_env; then
	source "$ci_root/script/install_python_deps.sh"
fi

# Install c-picker dependency
if config_valid "$tfut_config"; then
	echo "started building"
	python3 -m venv .venv
	source .venv/bin/activate

	if ! python3 -m pip show c-picker &> /dev/null; then
		echo "Installing c-picker"
		pip install git+https://git.trustedfirmware.org/${GERRIT_PROJECT_PREFIX:-}TS/trusted-services.git@topics/c-picker || {
			echo "c-picker was not installed!"
			exit 1
		}
		echo "c-picker was installed"
	else
		echo "c-picker is already installed"
	fi
fi

# Print CMake version
cmake_ver=$(echo `cmake --version | sed -n '1p'`)
echo "Using $cmake_ver"

# Check for Ninja
if [ -x "$(command -v ninja)" ]; then
        # Print Ninja version
        ninja_ver=$(echo `ninja --version | sed -n '1p'`)
        echo "Using ninja $ninja_ver"
        export cmake_gen="-G Ninja"
else
        echo 'Ninja is not installed'
        export cmake_gen=""
fi

modes="${bin_mode:-debug release}"
for mode in $modes; do
	echo "===== Building package in mode: $mode ====="
	# Build with a temporary archive
	build_archive="$archive/$mode"
	mkdir -p "$build_archive"

	if [ "$mode" = "debug" ]; then
		export bin_mode="debug"
		cmake_build_type="Debug"
		DEBUG=1
	else
		export bin_mode="release"
		cmake_build_type="Release"
		DEBUG=0
	fi

	# Perform builds in a subshell so as not to pollute the current and
	# subsequent builds' environment

	if config_valid "$cc_config"; then
	 # Build code coverage plugin
		build_cc
	fi

	# TFTF build
	if config_valid "$tftf_config"; then
		(
		echo "##########"

		plat_utils="$(get_tf_opt PLAT_UTILS)"
		if [ -z ${plat_utils} ]; then
			# Source platform-specific utilities.
			plat="$(get_tftf_opt PLAT)"
			plat_utils="$ci_root/${plat}_utils.sh"
		else
			# Source platform-specific utilities by
			# using plat_utils name.
			plat_utils="$ci_root/${plat_utils}.sh"
		fi

		if [ -f "$plat_utils" ]; then
			source "$plat_utils"
		fi

		archive="$build_archive"
		tftf_build_root="$archive/build/tftf"
		mkdir -p ${tftf_build_root}

		echo "Building Trusted Firmware TF ($mode) ..." |& log_separator

		# Call pre-build hook
		call_hook pre_tftf_build

		build_tftf

		from="$tftf_build_root" to="$archive" collect_build_artefacts

		echo "##########"
		echo
		)
	fi

	# SPM build
	if config_valid "$spm_config"; then
		(
		echo "##########"

		# Get platform name from spm_config file
		plat="$(echo "$spm_config" | awk -F- '{print $1}')"
		plat_utils="$ci_root/${plat}_utils.sh"
		if [ -f "$plat_utils" ]; then
			source "$plat_utils"
		fi

		# Call pre-build hook
		call_hook pre_spm_build

		# SPM build generates two sets of binaries, one for normal and other
		# for Secure world. We need both set of binaries for CI.
		archive="$build_archive"
		spm_build_root="$archive/build/spm"

		spm_secure_build_root="$spm_build_root/$spm_secure_out_dir"
		spm_ns_build_root="$spm_build_root/$spm_non_secure_out_dir"

		echo "spm_build_root is $spm_build_root"
		echo "Building SPM ($mode) ..." |& log_separator

		# NOTE: mode has no effect on SPM build (for now), hence debug
		# mode is built but subsequent build using release mode just
		# goes through with "nothing to do".
		build_spm

		# Show SPM/Hafnium binary details
		cksum $spm_secure_build_root/hafnium.bin

		# Some platforms only have secure configuration enabled. Hence,
		# non secure hanfnium binary might not be built.
		if [ -f $spm_ns_build_root/hafnium.bin ]; then
			cksum $spm_ns_build_root/hafnium.bin
		fi

		secure_from="$spm_secure_build_root" non_secure_from="$spm_ns_build_root" to="$archive" collect_spm_artefacts

		echo "##########"
		echo
		)
	fi

        # TF RMM build
        if  config_valid "$rmm_config"; then
                (
                echo "##########"

                plat_utils="$(get_rmm_opt PLAT_UTILS)"
                if [ -z ${plat_utils} ]; then
                        # Source platform-specific utilities.
                        plat="$(get_rmm_opt PLAT)"
                        extra_options="$(get_rmm_opt EXTRA_OPTIONS)"
                        extra_targets="$(get_rmm_opt EXTRA_TARGETS "")"
                        rmm_toolchain="$(get_rmm_opt TOOLCHAIN gnu)"
                        rmm_fpu_use_at_rel2="$(get_rmm_opt RMM_FPU_USE_AT_REL2 OFF)"
                        rmm_attest_el3_token_sign="$(get_rmm_opt ATTEST_EL3_TOKEN_SIGN OFF)"
                        rmm_v1_1="$(get_rmm_opt RMM_V1_1 ON)"
                        plat_utils="$ci_root/${plat}_utils.sh"
                else
                        # Source platform-specific utilities by
                        # using plat_utils name.
                        plat_utils="$ci_root/${plat_utils}.sh"
                fi

                if [ -f "$plat_utils" ]; then
                        source "$plat_utils"
                fi

                archive="$build_archive"
                rmm_build_root="$rmm_root/build"

                echo "Building Trusted Firmware RMM ($mode) ..." |& log_separator

                #call_hook pre_rmm_build
                build_rmm

                # Collect all rmm.* files: rmm.img, rmm.elf, rmm.dump, rmm.map
                from="$rmm_build_root" to="$archive" collect_build_artefacts

                echo "##########"
                )
        fi

	# TF build
	if config_valid "$tf_config"; then
		(
		echo "##########"

		plat_utils="$(get_tf_opt PLAT_UTILS)"
		export plat_variant="$(get_tf_opt TARGET_PLATFORM)"

		if [ -z ${plat_utils} ]; then
			# Source platform-specific utilities.
			plat="$(get_tf_opt PLAT)"
			plat_utils="$ci_root/${plat}_utils.sh"
		else
			# Source platform-specific utilities by
			# using plat_utils name.
			plat_utils="$ci_root/${plat_utils}.sh"
		fi

		if [ -f "$plat_utils" ]; then
			source "$plat_utils"
		fi

		fvp_tsram_size="$(get_tf_opt FVP_TRUSTED_SRAM_SIZE)"
		fvp_tsram_size="${fvp_tsram_size:-384}"

		archive="$build_archive"
		tf_build_root="$archive/build/tfa"
		mkdir -p ${tf_build_root}
		# we rely on the patch record to know when to setup a clone.
		# Remove it to signal we're building again.
		rm -rf "$tf_patch_record"

		echo "Building Trusted Firmware ($mode) ..." |& log_separator

		if upon "$(get_tf_opt RUST)" && not_upon "$local_ci"; then
			# In the CI Dockerfile, rustup is installed by the root user in the
			# non-default location /usr/local/rustup, so $RUSTUP_HOME is required to
			# access rust config e.g. default toolchains and run cargo
			#
			# Leave $CARGO_HOME blank so when this script is run in CI by the buildslave
			# user, it uses the default /home/buildslave/.cargo directory which it has
			# write permissions for - that allows it to download new crates during
			# compilation
			#
			# The buildslave user does not have write permissions to the default
			# $CARGO_HOME=/usr/local/cargo dir and so will error when trying to download
			# new crates otherwise
			#
			# note: $PATH still contains /usr/local/cargo/bin at this point so cargo is
			# still run via the root installation
			#
			# see https://github.com/rust-lang/rustup/issues/1085
			set_hook_var "RUSTUP_HOME" "/usr/local/rustup"
		fi

		# Call pre-build hook
		call_hook pre_tf_build

		build_tf

		# Call post-build hook
		call_hook post_tf_build

		# Pre-archive hook
		call_hook pre_tf_archive

		if upon "$(get_tf_opt RUST)"; then
			# for archiving into the Jenkins artifacts directory
			ln -fsr $tf_root/rust/target/bl31.{bin,elf} $tf_build_root
		fi

		from="$tf_build_root" to="$archive" collect_build_artefacts

		# Post-archive hook
		call_hook post_tf_archive

		call_hook fetch_tf_resource
		call_hook post_fetch_tf_resource

		# Generate LAVA job files if necessary
		call_hook generate_lava_job_template
		call_hook generate_lava_job

		echo "##########"
		)
	fi

	# TFUT build
	if config_valid "$tfut_config"; then
		(
		echo "##########"

		archive="$build_archive"
		tfut_build_root="$tfut_root/build"

		echo "Building Trusted Firmware UT ($mode) ..." |& log_separator

		# Clean TFUT build targets
		set_hook_var "tfut_build_targets" ""

		# Call pre-build hook
		call_hook pre_tfut_build

		build_tfut

		from="$tfut_build_root" to="$archive" collect_tfut_artefacts

		to="$archive" coverage="$COVERAGE" collect_tfut_coverage

		echo "##########"
		echo
		)
	fi
	echo
	echo
done

if config_valid "$tfut_config"; then
	deactivate
fi

call_hook pre_package

call_hook post_package

if upon "$jenkins_run" && upon "$artefacts_receiver" && [ -d "artefacts" ]; then
	source "$CI_ROOT/script/send_artefacts.sh" "artefacts"
fi

echo
echo "Done"
