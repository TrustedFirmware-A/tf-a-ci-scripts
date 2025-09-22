#
# Copyright (c) 2019-2022, Arm Limited. All rights reserved.
#
# SPDX-License-Identifier: BSD-3-Clause
#

# Determine whether the script is being run on a live FVP UART terminal or
# postprocessing a UART log file (probably dumped by LAVA).
proc postprocessing {} {
	if { [info exists ::env(uart_log_file)] } {
		return 1
	} else {
		return 0
	}
}

# Retrieve script parameters from environment variables. If they don't exist,
# return empty string
proc get_param {name {default ""}} {
	if {[info exists ::env($name)]} {
		return $::env($name)
	} else {
		return $default
	}
}

proc exit_uart {status} {
	if { [postprocessing] != 1 } {
		# Allow UART output to flush
		sleep 1
		send "\x1b"
		send "close\r"
	}

	exit $status
}

proc exit_timeout {} {
	message "timeout exceeded, exiting"
	exit_uart -1
}

proc message {string} {
	puts "<<$string>>"
}

proc found {value {message ""}} {
	if {$message eq ""} {
		message "found: \"$value\""
	} else {
		message "found: \"$value\" ($message)"
	}
}

proc not_found {value {message ""}} {
	if {$message eq ""} {
		message "not found: \"$value\""
	} else {
		message "not found: \"$value\" ($message)"
	}
}

# Expect a given string, and an optional message to be output when it's found.
# If not supplied, the message defaults to the string itself.
proc expect_string {the_string {the_message ""}} {
	message "waiting for: \"$the_string\""

	expect {
		$the_string {
			found "$the_string" "$the_message"
		}

		eof {
			not_found "$the_string"
			exit -1
		}

		timeout {
			not_found "$the_string"
			exit_timeout
		}
	}
}

# Expect a given regular expression, and an optional message to be output when
# it's found. If not supplied, the message defaults to the regular expression
# itself.
proc expect_re {the_re {the_message ""}} {
	message "waiting for: \"$the_re\""

	expect {
		-re $the_re {
			found "$the_re" "$the_message"
		}

		eof {
			not_found "$the_re"
			exit -1
		}

		timeout {
			not_found "$the_re"
			exit_timeout
		}
	}
}

proc capture_log {out end_re} {
	set event_log [open $out w]

	expect -re {(?:\w+:  )?(TCG_EfiSpecIDEvent:)\r\n} {
		puts $event_log $expect_out(1,string)
	}

	while {1} {
		# Skip the known logging headers in the first non-capture group to
		# ensure we only capture the contents of the log.
		expect -re {(?:\w+:  |\S+: )?([^\n]*)\r\n} {
			set line $expect_out(1,string)

			if {[regexp -- $end_re $line]} {
				break
			}

			puts $event_log $line
		}
	}

	close $event_log
}

proc compare_log {out compare} {
    # Match the previously the given digests. The pass criteria is that both
    # digests must match.
    if {[catch {exec diff -ws $out $compare} result options] == 0} {
            message "tests succeeded, digests matched"
    } else {
            message "tests failed, digests did not match"
            exit_uart -1
    }
}

proc capture_and_compare_log {out end_re compare} {
    set event_log [open $out w]
    capture_log $out $end_re

    compare_log $out $compare
}
