.syntax unified
.text
.global dlsym
.hidden __dlsym
.type dlsym,%function
dlsym:
	mov r2,lr
	b __dlsym
