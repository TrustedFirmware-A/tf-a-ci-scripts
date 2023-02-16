#!/usr/bin/env bash

#
# Copyright (c) 2021 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

python3 -m venv .venv

source .venv/bin/activate

(
    export PIP_CACHE_DIR=${project_filer}/pip-cache

    python3 -m pip install --upgrade pip
    python3 -m pip install poetry==1.3.2 ||
            python3 -m pip install poetry==1.3.2 --no-cache-dir
)
