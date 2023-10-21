#!/usr/bin/env python3
#
# Copyright (c) 2024 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

import json
import subprocess

cmdres = subprocess.run(["ctest", "--show-only=json-v1"], stdout=subprocess.PIPE)

tests_info = json.loads(cmdres.stdout.decode("utf-8"))
tests = []
for test in tests_info["tests"]:
    if "command" in test:
        tests.append(test["name"])

tests_str = ' '.join(tests)
print(tests_str)

