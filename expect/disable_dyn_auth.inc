#
# Copyright (c) 2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#
# Script to interact with an TF-A built with Trusted Board Boot
#
source [file join [file dirname [info script]] handle-arguments.inc]

# This script tries to catch if dynamic authentication of images is enabled
# during trusted board boot(BL2). The authentication is done using certificates.

expect_string "BL1: Booting BL2" "BL2 is booting"
expect_string "Disabling authentication of images dynamically" "dynamic authentication was disabled"
expect {
	# Catch all loading of authentication certificates i.e.,
	# TRUSTED_BOOT_FW_CERT_ID         U(6)
	# TRUSTED_KEY_CERT_ID             U(7)
	# SCP_FW_KEY_CERT_ID              U(8)
	# SOC_FW_KEY_CERT_ID              U(9)
	# TRUSTED_OS_FW_KEY_CERT_ID       U(10)
	# NON_TRUSTED_FW_KEY_CERT_ID      U(11)
	# SCP_FW_CONTENT_CERT_ID          U(12)
	# SOC_FW_CONTENT_CERT_ID          U(13)
	# TRUSTED_OS_FW_CONTENT_CERT_ID   U(14)
	# NON_TRUSTED_FW_CONTENT_CERT_ID  U(15)

	-re "Loading image id=(6|7|8|9|10|11|12|13|14|15) at address " {
		message "dynamic authentication is still enabled"
		exit_uart -1
	}
	"BL1: Booting BL31" {
		message "BL31 is booting"
	}
    }
