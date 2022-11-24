#
# Copyright (c) 2020, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

/terminal_0/ { ports[1] = $NF }
/terminal_1/ { ports[0] = $NF }
END {
        for (i = 0; i < num_uarts; i++) {
                if (ports[i] != "")
                        print "ports[" i "]=" ports[i]
        }
}
