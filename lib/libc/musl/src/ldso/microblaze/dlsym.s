.global dlsym
.hidden __dlsym
.type   dlsym,@function
dlsym:
	brid    __dlsym
	add     r7, r15, r0
