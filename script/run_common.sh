#!/usr/bin/env bash
#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

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

	# If the execution is halted, handle the process termination properly,
	# so the caller does not keep looping waiting for the result file to be
	# generated.
	trap "{ touch \"$pid_dir/$name.fail\"; exit 1 }" SIGINT SIGHUP SIGTERM

	if wait "$pid"; then
		touch "$pid_dir/$name.success"
	else
		touch "$pid_dir/$name.fail"
	fi
}

# Provide signal as an argument to the trap function.
trap_with_sig() {
	local func

	func="$1" ; shift
	for sig ; do
		trap "$func $sig" "$sig"
	done
}
