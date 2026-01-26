#!/usr/bin/env bash
#
# Copyright (c) 2023 Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Generate a YAML file in order to dispatch Tomato Chromebook runs on LAVA. Note that
# this script would produce a meaningful output when run via. Jenkins.
#
# $bin_mode must be set. This script outputs to STDOUT

ci_root="$(readlink -f "$(dirname "$0")/..")"
source "$ci_root/utils.sh"

get_bl31_url() {
	local bin_mode="${bin_mode:?}"

	if upon "$jenkins_run"; then
		echo "$jenkins_url/job/$JOB_NAME/$BUILD_NUMBER/artifact/artefacts/$bin_mode/bl31.elf"
	else
		echo "file://$workspace/artefacts/$bin_mode/bl31.elf"
	fi
}

bl31_url="${bl31_url:-$(get_bl31_url)}"

build_mode=$(echo $bin_mode | tr '[:lower:]' '[:upper:]')

cat <<EOF
device_type: mt8195-cherry-tomato-r2
job_name: MT8195 Tomato Chromebook BL31 depthcharge boot test - $build_mode
timeouts:
  job:
    minutes: 10
  action:
    minutes: 10
  connection:
    minutes: 5
priority: medium
visibility: public
actions:
- deploy:
    timeout:
      minutes: 5
    to: flasher
    images:
      image:
        url: https://downloads.trustedfirmware.org/infra-assets/linaro_artifacts/lava/chromebook/tomato/tomato_tf-a_golden_image.bin.gz
      bl31:
        url: $bl31_url
- boot:
    timeout:
      minutes: 5
    method: minimal
- test:
    timeout:
      minutes: 5
    interactive:
    - name: int_1
      prompts: ["Starting depthcharge on Tomato"]
      script:
      - command:
    - name: int_2
      prompts: ["This is a TF-A test build. Halting"]
      script:
      - command:
