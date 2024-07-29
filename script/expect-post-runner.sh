#!/usr/bin/env bash
#
# Copyright (c) 2021-2022, Linaro Limited
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Runner for scripts in expect-post/ directory. This script is intended
# to be run from Jenkins build, with $WORKSPACE set and per-UART test
# plans prepare in artefacts-lava/run/. See expect-post/README.md for
# more info about post-expect scripts.

ci_root="$(readlink -f "$(dirname "$0")/..")" && \
    . "${ci_root}/utils.sh"

# utils.sh automatically enablea fail-fast backtracing, but we don't to fail
# on first non-zero exit code, we handle them ourselves here.
trap - ERR

archive="${WORKSPACE}/artefacts-lava"

# Extract UART numbering from the FVP common log using the ports script
declare -a ports=()

ports_output="$(mktempfile)"

awk -v "num_uarts=$(get_num_uarts "${archive}")" \
    -f "$(get_ports_script "${archive}")" "${WORKSPACE}/lava-common.log" \
        > "${ports_output}"

. "${ports_output}" # Appends to `ports`

total=0
failed=0

for uart in "${!ports[@]}"; do
    total=$((total + 1))

    uart_log_file="${WORKSPACE}/lava-uart${uart}.log"
    uart_log_expect_file="${WORKSPACE}/lava-uart${uart}-expect.log"

    if [ "${uart}" = "$(get_payload_uart "${archive}")" ]; then
        mv "${WORKSPACE}/lava-common.log" "${uart_log_file}"
    else
        mv "${WORKSPACE}/lava-${ports[${uart}]:?}.log" "${uart_log_file}"
    fi

    expscript_stem="$(get_uart_expect_script "${archive}" "${uart}")"
    expscript="${WORKSPACE}/tf-a-ci-scripts/expect/${expscript_stem}"

    if [ -z "${expscript_stem}" ]; then
        continue # Some UARTs may (legitimately) not have expectations
    fi

    if [ ! -f "${expscript}" ]; then
        echo "expect/${expscript_stem}: MISS"
        failed=$((failed + 1))

        continue
    fi

    (
        export uart_log_file # Required by the Expect script

        if [ -f "$(get_uart_env_path "${archive}" "${uart}")/env" ]; then
            set -a

            . "$(get_uart_env_path "${archive}" "${uart}")/env"

            set +a
        fi

        2>&1 expect "${expscript}" > "${uart_log_expect_file}"
    )

    if [ $? != 0 ]; then
        echo "expect/${expscript_stem}(UART${uart}): FAIL"

        failed=$((failed + 1))
    else
        echo "expect/${expscript_stem}(UART${uart}): PASS"
    fi
done

echo "Post-LAVA Expect scripts results: total=$total failed=$failed"

if [ $failed -gt 0 ]; then
    exit 1
fi
