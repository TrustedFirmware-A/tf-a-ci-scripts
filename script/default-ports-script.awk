{
	for (i = 0; i < num_uarts; i++) {
		pattern = "terminal_" i ": Listening for serial connection on port [0-9]+"

		if (match($0, pattern)) {
			port = substr($0, RSTART, RLENGTH)
			sub(/^.* port /, "", port)
			ports[i] = port
		}
	}
}

END {
	for (i = 0; i < num_uarts; i++) {
		if (ports[i] != "")
			print "ports[" i "]=" ports[i]
	}
}
