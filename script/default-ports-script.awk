/terminal_0/ { ports[0] = $NF }
/terminal_1/ { ports[1] = $NF }
/terminal_2/ { ports[2] = $NF }
/terminal_3/ { ports[3] = $NF }

END {
	for (i = 0; i < num_uarts; i++) {
		if (ports[i] != "")
			print "ports[" i "]=" ports[i]
	}
}
