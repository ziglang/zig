	.text
	.global dlsym
	.hidden __dlsym
	.type   dlsym,@function
dlsym:
	addis   2, 12, .TOC.-dlsym@ha
	addi    2,  2, .TOC.-dlsym@l
	.localentry dlsym,.-dlsym
	mflr    5                      # The return address is arg3.
	b       __dlsym
	.size   dlsym, .-dlsym
