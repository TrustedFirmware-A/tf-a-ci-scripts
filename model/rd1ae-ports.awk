#
# Copyright (c) 2024, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

/terminal_sec_uart:/ { ports[0] = $NF }
/terminal_ns_uart0:/ { ports[1] = $NF }
/terminal_uart_scp:/ { ports[2] = $NF }
END {
    for (i = 0; i < num_uarts; i++) {
        if (ports[i] != "")
            print "ports[" i "]=" ports[i]
    }
}
