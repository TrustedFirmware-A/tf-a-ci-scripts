#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

if echo "$RUN_CONFIG" | grep -iq 'tftf'; then
	payload_type="tftf"
else
	payload_type="linux"
fi

"$CI_ROOT/script/parse_lava_job.py" --payload-type "$payload_type"
