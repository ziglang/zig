.global dlsym
.hidden __dlsym
.type dlsym, %function
dlsym:
	mv a2, ra
	tail __dlsym
