.text
.global dlsym
.hidden __dlsym
.type   dlsym, @function
dlsym:
	mov.l L1, r0
1:	braf  r0
	 sts pr, r6

.align 2
L1:	.long __dlsym@PLT-(1b+4-.)
