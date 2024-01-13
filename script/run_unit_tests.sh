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

export -f launch

artefacts="${artefacts-$workspace/artefacts}"

run_root="$workspace/unit_tests/run"
pid_dir="$workspace/unit_tests/pids"

mkdir -p "$run_root"
mkdir -p "$pid_dir"

export run_root
export pid_dir

export tfut_root="${tfut_root:-$workspace/tfut}"

kill_and_reap() {
	local gid
	# Kill an active process. Ignore errors
	[ "$1" ] || return 0
	kill -0 "$1" &>/dev/null || return 0

	# Kill the children
	kill -- "-$1"  &>/dev/null || true
	# Kill the group
	{ gid="$(awk '{print $5}' < /proc/$1/stat)";} 2>/dev/null || return
	kill -SIGTERM -- "-$gid" &>/dev/null || true
	wait "$gid" &>/dev/null || true
}

# Perform clean up and ignore errors
cleanup() {
	local pid
	local sig

	pushd "$pid_dir"
	set +e

	sig=${1:-SIGINT}
	echo "signal received: $sig"

	if [ "$sig" != "EXIT" ]; then
		# Kill all background processes so far and wait for them
		while read pid; do
			pid="$(cat $pid)"
			echo $pid

			kill_and_reap "$pid"

		done < <(find -name '*.pid')
	fi

	popd
}

# Cleanup actions
trap_with_sig cleanup SIGINT SIGHUP SIGTERM EXIT

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
	else
		echo "name=\"$test\" launch run_test $test \$@ " \
			"&> \"$run_root/${test}_output.txt\" &" >> "$run_sh"
	fi
done
chmod +x "$run_sh"

# Run the unit tests directly
if upon "$test_run"; then
	echo
        "$run_sh" "$@" -v -c
        exit 0
fi

# For an automated run, export a known variable so that we can identify stale
# processes spawned by Trusted Firmware CI by inspecting its environment.
export TRUSTED_FIRMWARE_CI="1"

# Otherwise, run tests in background and monitor them.
if upon "$jenkins_run"; then
	"$run_sh" "$@" -ojunit -v
else
	"$run_sh" "$@" -c -v
fi
batch_pid=$!

# Wait for all children. Note that the wait below is *not* a timed wait.
result=0

set +e
pushd "$pid_dir"

timeout=3600

echo

while :; do
	readarray -d '' all < <(find "${pid_dir}" -name '*.pid' -print0)
        readarray -d '' succeeded < <(find "${pid_dir}" -name '*.success' -print0)
        readarray -d '' failed < <(find "${pid_dir}" -name '*.fail' -print0)

	all=("${all[@]##${pid_dir}/}")
	all=("${all[@]%%.pid}")

	succeeded=("${succeeded[@]##${pid_dir}/}")
	succeeded=("${succeeded[@]%%.success}")

	failed=("${failed[@]##${pid_dir}/}")
	failed=("${failed[@]%%.fail}")

	completed=("${succeeded[@]}" "${failed[@]}")

	readarray -t remaining < <( \
		comm -23 \
			<(printf '%s\n' "${all[@]}" | sort) \
			<(printf '%s\n' "${completed[@]}" | sort) \
	)

        if [ ${#remaining[@]} = 0 ]; then
                break
        fi

	if [ ${timeout} = 0 ]; then
                echo "- Timeout exceeded! Killing all processes..."

                cleanup
        fi

	timeout=$((${timeout} - 5)) && sleep 5
done

echo

if [ ${#failed[@]} != 0 ]; then
        echo "${#failed[@]} tests failed:"
        echo

        for test in "${failed[@]}"; do
                echo " - Test ${test}: ${test}_output.txt"
        done

        echo

        result=1
fi

popd

if [ "$result" -eq 0 ]; then
        echo "Unit testing success!"
else
        echo "Unit testing failed!"
fi

if upon "$jenkins_run"; then
        echo
        echo "Artefacts location: $BUILD_URL."
        echo
fi

exit "$result"
