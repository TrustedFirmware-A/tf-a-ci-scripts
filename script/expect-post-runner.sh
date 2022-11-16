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

if [ -z "$WORKSPACE" ]; then
    echo "Error: WORKSPACE is not set. This script is intended to be run from Jenkins build. (Or suitably set up local env)."
    exit 1
fi

total=0
failed=0

# TODO: move dependency installation to the Dockerfile
sudo DEBIAN_FRONTEND=noninteractive apt update && \
    sudo DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt install -y expect ||
    exit 1

for uartdir in $WORKSPACE/artefacts-lava/run/uart*; do
    # In case no dirs exist and the glob above isn't expanded at all.
    if [ ! -d "$uartdir" ]; then
        break
    fi

    total=$((total + 1))

    expscript_fragment=$(cat ${uartdir}/expect)
    expscript=${WORKSPACE}/tf-a-ci-scripts/expect/${expscript_fragment}

    if [ ! -f "${expscript}" ]; then
        echo "expect/${expscript_fragment}: MISS"
        failed=$((failed + 1))

        continue
    fi

    uart=$(basename $uartdir)

    (
        if [ -f "${uartdir}/env" ]; then
            set -a
            source "${uartdir}/env"
            set +a
        fi

        export uart_log_file="${WORKSPACE}/lava-${uart}.log"

        2>&1 expect "${expscript}" > "${WORKSPACE}/lava-${uart}-expect.log"
    )

    if [ $? != 0 ]; then
        echo "expect/${expscript_fragment}(${uart}): FAIL"
        failed=$((failed + 1))
    else
        echo "expect/${expscript_fragment}(${uart}): pass"
    fi
done

echo "Post expect scripts: total=$total failed=$failed"

if [ $failed -gt 0 ]; then
    exit 1
fi
