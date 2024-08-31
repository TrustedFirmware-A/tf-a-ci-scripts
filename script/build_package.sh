#!/usr/bin/env bash
#
# Copyright (c) 2019-2022 Arm Limited. All rights reserved.
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
export scp_root="${scp_root:-$workspace/scp}"
scp_tools_root="${scp_tools_root:-$workspace/scp_tools}"
cc_root="${cc_root:-$ccpathspec}"
spm_root="${spm_root:-$workspace/spm}"

scp_tf_tools_root="$scp_tools_root/scp_tf_tools"

# Refspecs
tf_refspec="$TF_REFSPEC"
tftf_refspec="$TFTF_REFSPEC"
scp_refspec="$SCP_REFSPEC"
scp_tools_commit="${SCP_TOOLS_COMMIT:-master}"
spm_refspec="$SPM_REFSPEC"

test_config="${TEST_CONFIG:?}"
test_group="${TEST_GROUP:?}"
build_configs="${BUILD_CONFIG:?}"
run_config="${RUN_CONFIG:?}"
cc_config="${CC_ENABLE:-}"

archive="$artefacts"
build_log="$artefacts/build.log"
fiptool="$tf_root/tools/fiptool/fiptool"
cert_create="$tf_root/tools/cert_create/cert_create"

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

# Check if a config is valid
config_valid() {
	local config="${1?}"
	if [ -z "$config" ] || [ "$(basename "$config")" = "nil" ]; then
		return 1
	fi

	return 0
}

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

	if [ "$run_config_candiates" ]; then
		for config_fragment in $run_config_candiates; do
			(
			source "$ci_root/run_config/$config_fragment"
			call_func "$func" "$config_fragment"
			)
		done
	fi

	# Also source test config file
	(
	unset "$func"
	source "$test_config_file"
	call_func "$func" "$(basename $test_config_file)"
	)

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

	if ! find "$from" \( -name "*.bin" -o -name '*.elf' -o -name '*.dtb' -o -name '*.axf' \) -exec cp -t "${to:?}" '{}' +; then
		echo "You probably are running local CI on local repositories."
		echo "Did you set 'dont_clean' but forgot to run 'distclean'?"
		die
	fi
}

# SCP and MCP binaries are named firmware.{bin,elf}, and are placed under
# scp/mcp_ramfw and scp/mcp_romfw directories, so can't be collected by
# collect_build_artefacts function.
collect_scp_artefacts() {
	to="${to:?}" \
	find "$scp_root" \( \( -name "*.bin" -o -name '*.elf' \) -and ! -name 'CMake*' \) -exec bash -c '
		for file; do
			ext="$(echo $file | awk -F. "{print \$NF}")"
			case $file in
				*/firmware-scp_ramfw/bin/*|*/firmware-scp_ramfw_fvp/bin/*)
					cp $file $to/scp_ram.$ext
					;;
				*/firmware-scp_romfw/bin/*)
					cp $file $to/scp_rom.$ext
					;;
				*/firmware-mcp_ramfw/bin/*|*/firmware-mcp_ramfw_fvp/bin/*)
					cp $file $to/mcp_ram.$ext
					;;
				*/firmware-mcp_romfw/bin/*)
					cp $file $to/mcp_rom.$ext
					;;
				*/firmware-scp_romfw_bypass/bin/*)
					cp $file $to/scp_rom_bypass.$ext
					;;
				*)
					echo "Unknown SCP binary: $file" >&2
					;;
			esac
		done
	' bash '{}' +
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
	echo "Build failed! Full build log below:"
	echo "[...]"
	echo
	cat "$build_log"
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

	if [ "$(get_tf_opt DEBUG)" = 0 ]; then
		DEBUG=0
	fi

	make -C "$tf_root" $(cat "$tf_config_file") DEBUG="$DEBUG" V=1 "$@" \
		${fip_targets:-fip} &>>"$build_log" || fail_build
	)
}

fip_update() {
	# Before the update process, check if the given image is supported by
	# the fiptool. It's assumed that both fiptool and cert_create move in
	# tandem, and therfore, if one has support, the other has it too.
	if ! "$fiptool" update 2>&1 | grep -qe "\s\+--${bin_name:?}"; then
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
		"$fiptool" unpack "$archive/fip.bin" &>>"$build_log"

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
		"$cert_create" $cert_args $common_args &>>"$build_log"

		# Recreate and archive FIP
		"$fiptool" create $common_args "fip.bin" &>>"$build_log"
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
		"$(get_tf_opt BL2_AT_EL3)")
			return 0;;
	esac

	if bin_name="hw-config" src="$archive/dtb.bin" fip_update; then
		# Remove the DTB so that model won't load it
		rm -f "$archive/dtb.bin"
	fi
}

get_scp_opt() {
	(
	name="${1:?}"
	if config_valid "$scp_config_file"; then
		source "$scp_config_file"
		echo "${!name}"
	fi
	)
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

build_tf() {
	(
	env_file="$workspace/tf.env"
	config_file="${tf_build_config:-$tf_config_file}"

	# Build fiptool and all targets by default
	build_targets="${tf_build_targets:-memmap fiptool all}"

	source "$config_file"

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

	cd "$tf_root"

	# Always distclean when running on Jenkins. Skip distclean when running
	# locally and explicitly requested.
	if upon "$jenkins_run" || not_upon "$dont_clean"; then
		make distclean &>>"$build_log" || fail_build
	fi

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator >/dev/null

Build command line:
	$tf_build_wrapper make $make_j_opts $(cat "$config_file" | tr '\n' ' ') DEBUG=$DEBUG V=1 $build_targets

CC version:
$(${CC-${CROSS_COMPILE}gcc} -v 2>&1)
EOF

	if not_upon "$local_ci"; then
		connect_debugger=0
	fi

	# Build TF. Since build output is being directed to the build log, have
	# descriptor 3 point to the current terminal for build wrappers to vent.
	$tf_build_wrapper poetry run make $make_j_opts $(cat "$config_file") \
		DEBUG="$DEBUG" V=1 SPIN_ON_BL1_EXIT="$connect_debugger" \
		$build_targets 3>&1 &>>"$build_log" || fail_build
	)
}

build_tftf() {
	(
	config_file="${tftf_build_config:-$tftf_config_file}"

	# Build tftf target by default
	build_targets="${tftf_build_targets:-all}"

	source "$config_file"

	cd "$tftf_root"

	# Always distclean when running on Jenkins. Skip distclean when running
	# locally and explicitly requested.
	if upon "$jenkins_run" || not_upon "$dont_clean"; then
		make distclean &>>"$build_log" || fail_build
	fi

	# TFTF build system cannot reliably deal with -j option, so we avoid
	# using that.

	# Log build command line
	cat <<EOF | log_separator >/dev/null

Build command line:
	make $(cat "$config_file" | tr '\n' ' ') DEBUG=$DEBUG V=1 $build_targets

EOF

	make $(cat "$config_file") DEBUG="$DEBUG" V=1 \
		$build_targets &>>"$build_log" || fail_build
	)
}

build_scp() {
	(
	config_file="${scp_build_config:-$scp_config_file}"

	source "$config_file"

	cd "$scp_root"

	# Always distclean when running on Jenkins. Skip distclean when running
	# locally and explicitly requested.
	if upon "$jenkins_run" || not_upon "$dont_clean"; then
		make -f Makefile.cmake clean &>>"$build_log" || fail_build
	fi

	python3 -m venv .venv
	. .venv/bin/activate

	# Install extra tools used by CMake build system
	pip install -r requirements.txt --timeout 30 --retries 15

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator >/dev/null

SCP build command line:
	make -f Makefile.cmake $(cat "$config_file" | tr '\n' ' ') \
		TOOLCHAIN=GNU \
		MODE="$mode" \
		EXTRA_CONFIG_ARGS+=-DDISABLE_CPPCHECK=true \
		V=1 &>>"$build_log"

EOF

	# Build SCP
	make -f Makefile.cmake $(cat "$config_file" | tr '\n' ' ') \
		TOOLCHAIN=GNU \
		MODE="$mode" \
		EXTRA_CONFIG_ARGS+=-DDISABLE_CPPCHECK=true \
		V=1 &>>"$build_log" \
		|| fail_build
	)
}

clone_scp_tools() {

	if [ ! -d "$scp_tools_root" ]; then
		echo "Cloning SCP-tools ... $scp_tools_commit" |& log_separator

	  	clone_url="${SCP_TOOLS_CHECKOUT_LOC:-$scp_tools_src_repo_url}" \
			where="$scp_tools_root" \
			refspec="${scp_tools_commit}"
			clone_repo &>>"$build_log"
	else
		echo "Already cloned SCP-tools ..." |& log_separator
	fi

	show_head "$scp_tools_root"

	cd "$scp_tools_root"

	echo "Updating submodules"

	git submodule init

	git submodule update

	lib_commit=$(grep "'scmi_lib_commit'" run_tests/settings.py | cut -d':' -f 2 | tr -d "'")

	cd "scmi"
	git checkout $lib_commit

	git show --quiet --no-color | sed 's/^/  > /g'
}

clone_tf_for_scp_tools() {
	scp_tools_arm_tf="$scp_tools_root/arm-tf"

	if [ ! -d "$scp_tools_arm_tf" ]; then
		echo "Cloning TF-4-SCP-tools ..." |& log_separator

		clone_url="$tf_for_scp_tools_src_repo_url"
		where="$scp_tools_arm_tf"

		git clone "$clone_url" "$where"

		cd "$scp_tools_arm_tf"

		git checkout --track origin/juno-v4.3

		git show --quiet --no-color | sed 's/^/  > /g'

	else
		echo "Already cloned TF-4-SCP-tools ..." |& log_separator
	fi
}

build_scmi_lib_scp_tools() {
	(
	cd "$scp_tools_root"

	cd "scmi"

	scp_tools_arm_tf="$scp_tools_root/arm-tf"

	cross_compile="$(set_cross_compile_gcc_linaro_toolchain)"

	std_libs="-I$scp_tools_arm_tf/include/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/common/tbbr"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/drivers/arm"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/lib"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/lib/aarch64"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/lib/stdlib"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/lib/stdlib/sys"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/lib/xlat_tables"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/plat/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/plat/arm/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/plat/arm/css/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/plat/arm/board/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/include/plat/arm/soc/common"
	std_libs="$std_libs -I$scp_tools_arm_tf/plat/arm/board/juno/include"

	cflags="-Og -g"
	cflags="$cflags -mgeneral-regs-only"
	cflags="$cflags -mstrict-align"
	cflags="$cflags -nostdinc"
	cflags="$cflags -fno-inline"
	cflags="$cflags -ffreestanding"
	cflags="$cflags -ffunction-sections"
	cflags="$cflags -fdata-sections"
	cflags="$cflags -DAARCH64"
	cflags="$cflags -DPRId32=\"ld\""
	cflags="$cflags -DVERBOSE_LEVEL=3"

	cflags="$cflags $std_libs"

	protocols="performance,power_domain,system_power,reset"

	echo "Building SCMI library (SCP-tools) ..."

	make "CROSS_COMPILE=$cross_compile" \
		"CFLAGS=$cflags" \
		"PLAT=baremetal" \
		"PROTOCOLS=$protocols" \
		"clean" \
		"all"
	)
}

build_tf_for_scp_tools() {

	cd "$scp_tools_root/arm-tf"

	cross_compile="$(set_cross_compile_gcc_linaro_toolchain)"

	if [ "$1" = "release" ]; then
		echo "Build TF-4-SCP-Tools rls..."
	else
		echo "Build TF-4-SCP-Tools dbg..."

		make realclean

		make "BM_TEST=scmi" \
			"ARM_BOARD_OPTIMISE_MEM=1" \
			"BM_CSS=juno" \
			"CSS_USE_SCMI_SDS_DRIVER=1" \
			"PLAT=juno" \
			"DEBUG=1" \
			"PLATFORM=juno" \
			"CROSS_COMPILE=$cross_compile" \
			"BM_WORKSPACE=$scp_tools_root/baremetal"

		archive_file "build/juno/debug/bl1.bin"

		archive_file "build/juno/debug/bl2.bin"

		archive_file "build/juno/debug/bl31.bin"
	fi
}

build_fip_for_scp_tools() {

	cd "$scp_tools_root/arm-tf"

	cross_compile="$(set_cross_compile_gcc_linaro_toolchain)"

	if [ ! -d "$scp_root/build/juno/GNU/debug/firmware-scp_ramfw" ]; then
		make fiptool
		echo "Make FIP 4 SCP-Tools rls..."

	else
		make fiptool
		echo "Make FIP 4 SCP-Tools dbg..."

		make "PLAT=juno" \
			"all" \
			"fip" \
			"DEBUG=1" \
			"CROSS_COMPILE=$cross_compile" \
			"BL31=$scp_tools_root/arm-tf/build/juno/debug/bl31.bin" \
			"BL33=$scp_tools_root/baremetal/dummy_bl33" \
			"SCP_BL2=$scp_root/build/juno/GNU/$mode/firmware-scp_ramfw/bin/juno-bl2.bin"

		archive_file "$scp_tools_root/arm-tf/build/juno/debug/fip.bin"
	fi
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

	make -C model-plugin PVLIB_HOME=$PVLIB_HOME &>>"$build_log"
}

build_spm() {
	(
	env_file="$workspace/spm.env"
	config_file="${spm_build_config:-$spm_config_file}"

	source "$config_file"

	if [ -f "$env_file" ]; then
		set -a
		source "$env_file"
		set +a
	fi

	cd "$spm_root"

	# Always clean when running on Jenkins. Skip clean when running
	# locally and explicitly requested.
	if upon "$jenkins_run" || not_upon "$dont_clean"; then
		# make clean fails on a fresh repo where the project has not
		# yet been built. Hence only clean if out/reference directory
	        # already exists.
		if [ -d "out/reference" ]; then
			make clean &>>"$build_log" || fail_build
		fi
	fi

	# Log build command line. It is left unfolded on purpose to assist
	# copying to clipboard.
	cat <<EOF | log_separator >/dev/null

Build command line:
	make $make_j_opts $(cat "$config_file" | tr '\n' ' ')

EOF

	# Build SPM. Since build output is being directed to the build log, have
	# descriptor 3 point to the current terminal for build wrappers to vent.
	export PATH=$PWD/prebuilts/linux-x64/clang/bin:$PWD/prebuilts/linux-x64/dtc:$PATH

	make $make_j_opts $(cat "$config_file") 3>&1 &>>"$build_log" \
		|| fail_build
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

set_scp_build_targets() {
	echo "Set build target to '${targets:?}'"
	set_hook_var "scp_build_targets" "$targets"
}

set_spm_build_targets() {
	echo "Set build target to '${targets:?}'"
	set_hook_var "spm_build_targets" "$targets"
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
	set_run_env "model_path" "${1:?}"
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

undo_patch_record() {
	if [ ! -f "${patch_record:?}" ]; then
		return
	fi

	# Undo patches in reverse
	echo
	for patch_name in $(tac "$patch_record"); do
		echo "Undoing $patch_name..."
		if ! git apply -R "$ci_root/patch/$patch_name"; then
			if upon "$local_ci"; then
				echo
				echo "Your local directory may have been dirtied."
				echo
			fi
			fail_build
		fi
	done

	rm -f "$patch_record"
}

undo_local_patches() {
	pushd "$tf_root"
	patch_record="$tf_patch_record" undo_patch_record
	popd

	if [ -d "$tftf_root" ]; then
		pushd "$tftf_root"
		patch_record="$tftf_patch_record" undo_patch_record
		popd
	fi
}

undo_tftf_patches() {
	pushd "$tftf_root"
	patch_record="$tftf_patch_record" undo_patch_record
	popd
}

undo_tf_patches() {
	pushd "$tf_root"
	patch_record="$tf_patch_record" undo_patch_record
	popd
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

	if git apply < "$ci_root/patch/$1"; then
		echo "$1" >> "${patch_record:?}"
	else
		if upon "$local_ci"; then
			undo_local_patches
		fi
		fail_build
	fi
}

apply_tftf_patch() {
	pushd "$tftf_root"
	patch_record="$tftf_patch_record" apply_patch "$1"
	popd
}

apply_tf_patch() {
	pushd "$tf_root"
	patch_record="$tf_patch_record" apply_patch "$1"
	popd
}

# Clear workspace for a local run
if not_upon "$jenkins_run"; then
	rm -rf "$workspace"

	# Clear residue from previous runs
	rm -rf "$archive"
fi

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
scp_config="$(echo "$build_configs" | awk -F, '{print $3}')"
scp_tools_config="$(echo "$build_configs" | awk -F, '{print $4}')"
spm_config="$(echo "$build_configs" | awk -F, '{print $5}')"

test_config_file="$ci_root/group/$test_group/$test_config"

tf_config_file="$ci_root/tf_config/$tf_config"
tftf_config_file="$ci_root/tftf_config/$tftf_config"
scp_config_file="$ci_root/scp_config/$scp_config"
scp_tools_config_file="$ci_root/scp_tools_config/$scp_tools_config"
spm_config_file="$ci_root/spm_config/$spm_config"

# File that keeps track of applied patches
tf_patch_record="$workspace/tf_patches"
tftf_patch_record="$workspace/tftf_patches"

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

if ! config_valid "$scp_config"; then
	scp_config=
else
	echo "SCP firmware config:"
	echo
	sort "$scp_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$scp_tools_config"; then
	scp_tools_config=
else
	echo "SCP Tools config:"
	echo
	sort "$scp_tools_config_file" | sed '/^\s*$/d;s/^/\t/'
fi

if ! config_valid "$spm_config"; then
	spm_config=
else
	echo "SPM config:"
	echo
	sort "$spm_config_file" | sed '/^\s*$/d;s/^/\t/'
	echo
fi

if ! config_valid "$run_config"; then
	run_config=
fi

if [ "$tf_config" ] && assert_can_git_clone "tf_root"; then
	# If the Trusted Firmware repository has already been checked out, use
	# that location. Otherwise, clone one ourselves.
	echo "Cloning Trusted Firmware..."
	clone_url="${TF_CHECKOUT_LOC:-$tf_src_repo_url}" where="$tf_root" \
		refspec="$TF_REFSPEC" clone_repo &>>"$build_log"
	show_head "$tf_root"
fi

if [ "$tftf_config" ] && assert_can_git_clone "tftf_root"; then
	# If the Trusted Firmware TF repository has already been checked out,
	# use that location. Otherwise, clone one ourselves.
	echo "Cloning Trusted Firmware TF..."
	clone_url="${TFTF_CHECKOUT_LOC:-$tftf_src_repo_url}" where="$tftf_root" \
		refspec="$TFTF_REFSPEC" clone_repo &>>"$build_log"
	show_head "$tftf_root"
fi

if [ "$scp_config" ] && assert_can_git_clone "scp_root"; then
	# If the SCP firmware repository has already been checked out,
	# use that location. Otherwise, clone one ourselves.
	echo "Cloning SCP Firmware..."
	clone_url="${SCP_CHECKOUT_LOC:-$scp_src_repo_url}" where="$scp_root" \
		refspec="${SCP_REFSPEC-master-upstream}" clone_repo &>>"$build_log"

	pushd "$scp_root"

	# Use filer submodule as a reference if it exists
	if [ -d "$SCP_CHECKOUT_LOC/cmsis" ]; then
		cmsis_reference="--reference $SCP_CHECKOUT_LOC/cmsis"
	fi

	# If we don't have a reference yet, fall back to $cmsis_root if set, or
	# then to project filer if accessible.
	if [ -z "$cmsis_reference" ]; then
		cmsis_ref_repo="${cmsis_root:-$project_filer/ref-repos/cmsis}"
		if [ -d "$cmsis_ref_repo" ]; then
			cmsis_reference="--reference $cmsis_ref_repo"
		fi
	fi

	git submodule -q update $cmsis_reference --init

	popd

	show_head "$scp_root"
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
			clone_repo &>>"$build_log"
	fi

	# Query git submodules
	pushd "$spm_root"
	# Check if submodules need initialising
	if git submodule status | grep '^-'; then
		git submodule init
		retry git submodule update
	fi
	popd

	show_head "$spm_root"
fi

if [ "$run_config" ]; then
	# Get candidates for run config
	run_config_candiates="$("$ci_root/script/gen_run_config_candidates.py" \
		"$run_config")"
	if [ -z "$run_config_candiates" ]; then
		die "No run config candidates!"
	else
		echo
		echo "Chosen fragments:"
		echo
		echo "$run_config_candiates" | sed 's/^\|\n/\t/g'
		echo
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

modes="${bin_mode:-debug release}"
for mode in $modes; do
	echo "===== Building package in mode: $mode ====="
	# Build with a temporary archive
	build_archive="$archive/$mode"
	mkdir "$build_archive"

	if [ "$mode" = "debug" ]; then
		export bin_mode="debug"
		DEBUG=1
	else
		export bin_mode="release"
		DEBUG=0
	fi

	# Perform builds in a subshell so as not to pollute the current and
	# subsequent builds' environment

	if config_valid "$cc_config"; then
	 # Build code coverage plugin
		build_cc
	fi

	# SCP build
	if config_valid "$scp_config"; then
		(
		echo "##########"

		# Source platform-specific utilities
		plat="$(get_scp_opt PRODUCT)"
		plat_utils="$ci_root/${plat}_utils.sh"
		if [ -f "$plat_utils" ]; then
			source "$plat_utils"
		fi

		archive="$build_archive"
		scp_build_root="$scp_root/build"

		echo "Building SCP Firmware ($mode) ..." |& log_separator

		build_scp
		to="$archive" collect_scp_artefacts

		echo "##########"
		echo
		)
	fi

	# SCP-tools build
	if config_valid "$scp_tools_config"; then
		(
		echo "##########"

		archive="$build_archive"
		scp_tools_build_root="$scp_tools_root/build"

		clone_scp_tools

		echo "##########"
		echo

		echo "##########"
		clone_tf_for_scp_tools
		echo "##########"
		echo
		)
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
		tftf_build_root="$tftf_root/build"

		echo "Building Trusted Firmware TF ($mode) ..." |& log_separator

		# Call pre-build hook
		call_hook pre_tftf_build

		build_tftf

		from="$tftf_build_root" to="$archive" collect_build_artefacts

		# Clear any local changes made by applied patches
		undo_tftf_patches

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
		spm_build_root="$spm_root/out/reference/$spm_secure_out_dir"
		hafnium_build_root="$spm_root/out/reference/$spm_non_secure_out_dir"

		echo "spm_build_root is $spm_build_root"
		echo "Building SPM ($mode) ..." |& log_separator

		# NOTE: mode has no effect on SPM build (for now), hence debug
		# mode is built but subsequent build using release mode just
		# goes through with "nothing to do".
		build_spm

		# Show SPM/Hafnium binary details
		cksum $spm_build_root/hafnium.bin

		# Some platforms only have secure configuration enabled. Hence,
		# non secure hanfnium binary might not be built.
		if [ -f $hafnium_build_root/hafnium.bin ]; then
			cksum $hafnium_build_root/hafnium.bin
		fi

		secure_from="$spm_build_root" non_secure_from="$hafnium_build_root" to="$archive" collect_spm_artefacts

		echo "##########"
		echo
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

		# Install python build dependencies
		if is_arm_jenkins_env; then
			source "$ci_root/script/install_python_deps_tf.sh"
		fi

		poetry -C "$tf_root" install --without doc

		fvp_tsram_size="$(get_tf_opt FVP_TRUSTED_SRAM_SIZE)"
		fvp_tsram_size="${fvp_tsram_size:-256}"

		archive="$build_archive"
		tf_build_root="$tf_root/build"

		echo "Building Trusted Firmware ($mode) ..." |& log_separator

		# Call pre-build hook
		call_hook pre_tf_build

		build_tf

		# Call post-build hook
		call_hook post_tf_build

		# Pre-archive hook
		call_hook pre_tf_archive

		from="$tf_build_root" to="$archive" collect_build_artefacts

		# Post-archive hook
		call_hook post_tf_archive

		call_hook fetch_tf_resource
		call_hook post_fetch_tf_resource

		# Generate LAVA job files if necessary
		call_hook generate_lava_job_template
		call_hook generate_lava_job

		# Clear any local changes made by applied patches
		undo_tf_patches

		echo "##########"
		)
	fi

	echo
	echo
done

call_hook pre_package

call_hook post_package

if upon "$jenkins_run" && upon "$artefacts_receiver" && [ -d "artefacts" ]; then
	source "$CI_ROOT/script/send_artefacts.sh" "artefacts"
fi

echo
echo "Done"
