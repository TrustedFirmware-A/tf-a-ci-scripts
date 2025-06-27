#!/usr/bin/env bash
#
# Copyright (c) 2026, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

source "$ci_root/model/base-aemva-common.sh"

cat <<EOF >>"${model_param_file}"
${gicv5_yaml_path+-C gicv5_config_file=${gicv5_yaml_path:?}}
EOF
