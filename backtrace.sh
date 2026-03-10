#!/usr/bin/env bash

#
# Copyright (c) 2023-2024, Arm Limited and Contributors. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Dump the current call stack.
#
# This function takes no arguments, and prints the call stack of the script at
# the point at which it was called.
dump_stack() {(
	set +x

	for ((i = 1; i < ${#FUNCNAME[@]}; i++)); do
		local function="${FUNCNAME[$((i + 1))]:-<unknown>}"
		local line="${BASH_LINENO[$i]}"
		local source="${BASH_SOURCE[$((i + 1))]:-<unknown>}"

		echo -e "[$i]: ${source}:${line} (${function})"
	done
)}

# Dump the formatted call stack.
#
# This function takes no arguments, and prefixes the output of `dump_stack()`
# with a section header for inclusion in error backtraces.
dump() {(
	set +x

	echo "Call stack:"
	echo

	dump_stack | while IFS= read -r line; do
		echo "    ${line}"
	done
)}

# Generate an error backtrace.
#
# This function dumps the backtrace at the point at which the function is
# called, with additional information about the command that failed.
#
# This is best used as a trap handler (e.g. `trap backtrace ERR`) rather than by
# being called directly. If you want to explicitly dump the script state, prefer
# to use the `dump` function instead.
backtrace() {
	local error=$?
	local command=${BASH_COMMAND}

	(
		set +x

		echo "" >&2
		echo "ERROR: Command at ${BASH_SOURCE[1]:-<unknown>}:${BASH_LINENO[0]} exited with error ${error}:" >&2
		echo "ERROR:" >&2

		echo "${command}" | while IFS= read -r line; do
			echo "ERROR:     ${line}" >&2
		done

		echo "ERROR:" >&2

		dump | while IFS= read -r line; do
			echo "ERROR: ${line}" >&2
		done
	)
}
