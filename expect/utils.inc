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
	# Allow UART output to flush
	sleep 1
	puts "<<TIMEOUT>>"
	exit_uart -1
}

# Expect a given string, and an optional message to be output when it's found.
# If not supplied, the message defaults to the string itself.
proc expect_string {the_string {the_message ""}} {
	if {$the_message eq ""} {
		set the_message $the_string
	}

	expect {
		$the_string {
			puts "<<$the_message>>"
		}

		eof {
			puts "<<not found: \"$the_string\">>"
			exit -1
		}

		timeout {
			puts "<<Not found: $the_string>>"
			exit_timeout
		}
	}
}

# Expect a given regular expression, and an optional message to be output when
# it's found. If not supplied, the message defaults to the regular expression
# itself.
proc expect_re {the_re {the_message ""}} {
	if {$the_message eq ""} {
		set the_message $the_re
	}

	expect {
		-re $the_re {
			puts "<<$the_message>>"
		}

		eof {
			puts "<<not found: \"$the_re\">>"
			exit -1
		}

		timeout {
			puts "<<Not found: $the_re>>"
			exit_timeout
		}
	}
}
