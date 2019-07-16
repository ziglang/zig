.section .init
.align 2
	lmg  %r14, %r15, 272(%r15)
	br   %r14

.section .fini
.align 2
	lmg  %r14, %r15, 272(%r15)
	br   %r14
