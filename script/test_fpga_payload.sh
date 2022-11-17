#!/bin/bash
#
# Copyright (c) 2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# Enable job control to have background processes run in their own process
# group. That way, we can kill a background process group in one go.
set -m

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

artefacts="${artefacts-$workspace/artefacts}"

run_root="$workspace/run"
pid_dir="$workspace/pids"

mkdir -p "$pid_dir"
mkdir -p "$run_root"

archive="$artefacts"
bootargs_file="bootargs_file"

gen_fpga_params() {
	local fpga_param_file="fpga_env.sh"

	echo "Generating parameters for FPGA $fpga..."
	echo

	echo "baudrate=$uart_baudrate" > $fpga_param_file
	echo "fpga=$fpga" >> $fpga_param_file
	echo "fpga_bitfile=$fpga_bitfile" >> $fpga_param_file
	echo "project_name=$project_name" >> $fpga_param_file
	echo "port=$uart_port" >> $fpga_param_file
	echo "uart=$uart_descriptor" >> $fpga_param_file

	if [ -n "$bl33_img" ]; then
        	echo "bl33_img=$bl33_img" >> $fpga_param_file
		echo "bl33_addr=$bl33_addr" >> $fpga_param_file
	fi

	if [ -n "$initrd_img" ]; then
        	echo "initrd_img=$initrd_img" >> $fpga_param_file
		echo "initrd_addr=$initrd_addr" >> $fpga_param_file
	fi

	if [ -n "$bootargs" ]; then
		echo "CMD:$bootargs" > $bootargs_file
		archive_file "$bootargs_file"
		echo "cmdline_file=$bootargs_file" >> $fpga_param_file
		echo "cmdline_addr=$bootargs_addr" >> $fpga_param_file
	fi

	archive_file "$fpga_param_file"
}

kill_and_reap() {
	local gid
	# Kill an active process. Ignore errors
	[ "$1" ] || return 0
	kill -0 "$1" &>/dev/null || return 0

	# Kill the children
	kill -- "-$1"  &>/dev/null || true
	# Kill the group
	{ gid="$(awk '{print $5}' < /proc/$1/stat)";} 2>/dev/null || return
	kill -SIGKILL -- "-$gid" &>/dev/null || true

	wait "$gid" &>/dev/null || true
}

# Perform clean up and ignore errors
cleanup() {
	local pid

	# Test success. Kill all background processes so far and wait for them
	pushd "$pid_dir"
	set +e
	while read pid; do
		pid="$(cat $pid)"
		kill_and_reap "$pid"
	done < <(find -name '*.pid')
	popd
}

# Launch a program. Have its PID saved in a file with given name with .pid
# suffix. When the program exits, create a file with .success suffix, or one
# with .fail if it fails. This function blocks, so the caller must '&' this if
# they want to continue. Call must wait for $pid_dir/$name.pid to be created
# should it want to read it.
launch() {
	local pid

	"$@" &
	pid="$!"
	echo "$pid" > "$pid_dir/${name:?}.pid"
	if wait "$pid"; then
		touch "$pid_dir/$name.success"
	else
		touch "$pid_dir/$name.fail"
	fi
}

# Cleanup actions
trap cleanup SIGINT SIGHUP SIGTERM EXIT

# Source variables required for run
source "$artefacts/env"

echo
echo "RUNNING: $TEST_CONFIG"
echo

# Accept BIN_MODE from environment, or default to release. If bin_mode is set
# and non-empty (intended to be set from command line), that takes precedence.
pkg_bin_mode="${BIN_MODE:-release}"
bin_mode="${bin_mode:-$pkg_bin_mode}"

artefacts_wd="$artefacts/$bin_mode"

# Change directory so that all binaries can be accessed relative to where they
# lie
run_cwd="$artefacts/$bin_mode"
cd "$run_cwd"

# Source environment for run
if [ -f "run/env" ]; then
	source "run/env"
fi

# Whether to display primary UART progress live on the console
primary_live="${primary_live-$PRIMARY_LIVE}"

# Assume 1 UARTs by default
num_uarts="$(get_num_uarts "${archive}" 1)"

# Generate the environment configuration file for the FPGA host.
for u in $(seq 0 $(( $(get_num_uarts "${archive}") - 1 )) | tac); do
	descriptor="run/uart$u/descriptor"
	if [ -f "$descriptor" ]; then
		uart_descriptor="$(cat "$descriptor")"
	else
		echo "Error: No descriptor specified for UART$u"
		exit 1
	fi

	baudrate="run/uart$u/baudrate"
	if [ -f "$baudrate" ]; then
		uart_baudrate="$(cat "$baudrate")"
	else
		echo "Error: No baudrate specified for UART$u"
		exit 1
	fi

	port="run/uart$u/port"
	if [ -f "$port" ]; then
		uart_port="$(cat "$port")"
	else
		echo "Error: No port specified for UART$u"
		exit 1
	fi

	fpga="$fpga_cluster" gen_fpga_params
done

if [ -z "$fpga_user" ]; then
	echo "FPGA user not configured!"
	exit 1
fi
if [ -z "$fpga_host" ]; then
	echo "FPGA host not configured!"
	exit 1
fi
remote_user="$fpga_user"
remote_host="$fpga_host"

echo
echo "Copying artefacts to $remote_host as user $remote_user"
echo

# Copy the image to the remote host.
if [ -n "$bl33_img" ]; then
	scp "$artefacts_wd/$bl33_img" "$remote_user@$remote_host:." > /dev/null
fi

if [ -n "$initrd_img" ]; then
	scp "$artefacts_wd/$initrd_img" "$remote_user@$remote_host:." > /dev/null
fi

if [ -n "$bootargs" ]; then
	scp "$artefacts_wd/$bootargs_file" "$remote_user@$remote_host:." > /dev/null
fi
scp "$artefacts_wd/bl31.axf" "$remote_user@$remote_host:." > /dev/null

# Copy the env and run scripts to the remote host.
scp "$artefacts_wd/fpga_env.sh" "$remote_user@$remote_host:." > /dev/null
scp "$ci_root/script/$fpga_run_script" "$remote_user@$remote_host:." > /dev/null

echo "FPGA configuration options:"
echo
while read conf_option; do
	echo -e "\t$conf_option"
done <$artefacts/fpga_env.sh
if [ -n "$bootargs" ]; then
echo -e "\tKernel bootargs: $bootargs"
fi

# For an automated run, export a known variable so that we can identify stale
# processes spawned by Trusted Firmware CI by inspecting its environment.
export TRUSTED_FIRMWARE_CI="1"

echo
echo "Executing on $remote_host as user $remote_user"
echo

# Run the FPGA from the remote host.
name="fpga_run" launch ssh "$remote_user@$remote_host" "bash ./$fpga_run_script" > \
							/dev/null 2>&1 &

# Wait enough time for the UART to show up on the FPGA host so the connection
# can be stablished.
sleep 65

# If it's a test run, skip all the hoops and start a telnet connection to the FPGA.
if upon "$test_run"; then
	telnet "$remote_host" "$(cat "run/uart$(get_primary_uart "${archive}")/port")"
	exit 0
fi

# Launch expect scripts for all UARTs
for u in $(seq 0 $(( $(get_num_uarts "${archive}") - 1 )) | tac); do
	script="run/uart$u/expect"
	if [ -f "$script" ]; then
		script="$(cat "$script")"
	else
		script=
	fi

	# Primary UART must have a script
	if [ -z "$script" ]; then
		if [ "$u" = "$(get_primary_uart "${archive}")" ]; then
			die "No primary UART script!"
		else
			echo "Ignoring UART$u (no expect script provided)."
			continue
		fi
	fi

	uart_descriptor="$(cat "run/uart$u/descriptor")"

	timeout="run/uart$u/timeout"
	uart_port="$(cat "run/uart$u/port")"

	if [ -f "$timeout" ]; then
		timeout="$(cat "$timeout")"
	else
		timeout=
	fi
	timeout="${timeout-600}"

	full_log="$run_root/uart${u}_full.txt"

	if [ "$u" = "$(get_primary_uart "${archive}")" ]; then
		star="*"
		uart_name="primary_uart"
	else
		star=" "
		uart_name="uart$u"
	fi

	# Launch expect after exporting required variables
	(
	if [ -f "run/uart$u/env" ]; then
		set -a
		source "run/uart$u/env"
		set +a
	fi

	if [ "$u" = "$(get_primary_uart "${archive}")" ] && upon "$primary_live"; then
		uart_port="$uart_port" remote_host="$remote_host" timeout="$timeout" \
			name="$uart_name" launch expect -f "$ci_root/expect/$script" | \
				tee "$full_log"
		echo
	else
		uart_port="$uart_port" remote_host="$remote_host" timeout="$timeout" \
			name="$uart_name" launch expect -f "$ci_root/expect/$script" \
				&>"$full_log"
	fi

	) &

	echo "Tracking UART$u$star ($uart_descriptor) with $script and timeout $timeout."
done
echo

result=0

set +e

# Wait for all the children. Note that the wait below is *not* a timed wait.
wait -n

pushd "$pid_dir"
# Wait for fpga_run to finish on the remote server.
while :; do
	if [ "$(wc -l < <(ls -l fpga_run.* 2> /dev/null))" -eq 2 ]; then
		break
	else
		sleep 1
	fi
done

# Check if there is any failure.
while :; do
	# Exit failure if we've any failures
	if [ "$(wc -l < <(find -name '*.fail'))" -ne 0 ]; then
		result=1
		break
	fi

	# We're done if the primary UART exits success
	if [ -f "$pid_dir/primary_uart.success" ]; then
		break
	fi
done

ssh "$remote_user@$remote_host" "rm ./$fpga_run_script"

cleanup

if [ "$result" -eq 0 ]; then
	echo "Test success!"
else
	echo "Test failed!"
fi

if upon "$jenkins_run"; then
	echo
	echo "Artefacts location: $BUILD_URL."
	echo
fi

if upon "$jenkins_run" && upon "$artefacts_receiver" && [ -d "$workspace/run" ]; then
	source "$CI_ROOT/script/send_artefacts.sh" "run"
fi

exit "$result"
# vim: set tw=80 sw=8 noet:
