.text
.global dlsym
.hidden __dlsym
.type dlsym,@function
dlsym:
	push (%esp)
	push 12(%esp)
	push 12(%esp)
	call __dlsym
	add $12,%esp
	ret
