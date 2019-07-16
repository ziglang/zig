.global dlsym
.hidden __dlsym
.type   dlsym,@function
dlsym:
	l.j	__dlsym
	 l.ori	r5, r9, 0
