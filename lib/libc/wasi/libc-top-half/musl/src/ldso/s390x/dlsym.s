	.global dlsym
	.hidden __dlsym
	.type   dlsym,@function
dlsym:
	lgr %r4, %r14
	jg __dlsym
