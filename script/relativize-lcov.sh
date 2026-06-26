#!/usr/bin/env bash

#
# Copyright (c) 2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

#
# Rewrite LCOV source-file records to be relative to the project under test, so
# that the gateway job can generate correct coverage visualizations.
#

set -euo pipefail

info="${1:?}"

if [[ ! -f "${info}" ]]; then
    exit 0
fi

: "${GERRIT_PROJECT:?}"
: "${WORKSPACE:?}"

root="$(realpath -m -- "${WORKSPACE%/}/${GERRIT_PROJECT}")"
temp="$(mktemp "${info}.XXXXXX")"

while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" == SF:/* ]]; then
        line="SF:$(realpath -m -- "${line#SF:}")"
    fi

    printf '%s\n' "${line}"
done < "${info}" > "${temp}"

mv -- "${temp}" "${info}"

prefix="SF:${root}/"
temp="$(mktemp "${info}.XXXXXX")"

while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line:0:${#prefix}}" == "${prefix}" ]]; then
        line="SF:${line:${#prefix}}"
    fi

    printf '%s\n' "${line}"
done < "${info}" > "${temp}"

mv -- "${temp}" "${info}"
