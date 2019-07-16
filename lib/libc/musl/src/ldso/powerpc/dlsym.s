	.text
	.global dlsym
	.hidden __dlsym
	.type   dlsym,@function
dlsym:
	mflr    5                      # The return address is arg3.
	b       __dlsym
	.end    dlsym
	.size   dlsym, .-dlsym
