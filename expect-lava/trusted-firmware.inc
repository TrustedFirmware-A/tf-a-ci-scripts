#
# Copyright (c) 2021, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with AArch64 Trusted Firmware-A.
#

# Initial boot message won't be present if we're starting at BL31. Skip waiting
# for them by inspecting the environment variable 'skip_early_boot_msgs'.
if [ -z "$skip_early_boot_msgs" ]; then

        expect_string+=('i;Booting Trusted Firmware')

        prompt='Booting BL2'
        # Catch all 3 possible BL2 loading error messages, namely:
        #   "Failure in pre image load handling of BL2"
        #   "Failed to load BL2 firmware."
        #   "Failure in post image load handling of BL2"
        #   "BL2: Failed to load image id"
        failures='Fail.*load.*BL2|BL2.*Fail.*load'
        expect_string+=("i;${prompt};;${failures}")

	expect_string+=('i;BL1: Booting BL31')
fi
