#!/usr/bin/env bash
#
# Copyright (c) 2019-2020 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

set -e

# If we're skipping LAVA or Juno
if [ "$skip_juno" ] || [ "$skip_runs" ]; then
	exit 1
fi

# For Juno runs, we need let the board download build artefacts using a URL. The
# only way to have a board-accessible URL at the moment is to have build
# artefacts archived. Therefore, only for Juno do we spawn the build as a
# separate job; otherwise, we build within this job.
if echo "$RUN_CONFIG" | grep -iqe '^juno'; then
	exit 0
else
	exit 1
fi
