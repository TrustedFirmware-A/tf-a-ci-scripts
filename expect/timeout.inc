#
# Copyright (c) 2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

message "test completed, waiting for EOF or timeout"

expect {
    "Exiting tests." {
        message "expected hang, found TFTF completion"
    }

    "PANIC in EL3." {
        message "expected hang, found crash dump"
    }

    "Unhandled Exception in EL3." {
        message "expected hang, found crash dump"
    }

    "Unhandled Exception from EL" {
        message "expected hang, found crash dump"
    }

    eof {
        message "stream closed as expected, exiting"
        exit 0
    }

    timeout {
        message "timeout triggered as expected, exiting"
        exit_uart 0
    }
}

exit_uart -1
