.global dlsym
.hidden __dlsym
.type dlsym,%function
dlsym:
	mov x2,x30
	b __dlsym
