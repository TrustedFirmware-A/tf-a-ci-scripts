#
# Copyright (c) 2021-2025, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

/ terminal_uart:/ { ports[0] = $NF }
/ rse_terminal_uart:/ { ports[1] = $NF }
/ terminal_uart_ap:/ { ports[2] = $NF }
/ terminal_uart1_ap:/ { ports[3] = $NF }
END {
	for (i = 0; i < num_uarts; i++) {
		if (ports[i] != "")
			print "ports[" i "]=" ports[i]
	}
}
