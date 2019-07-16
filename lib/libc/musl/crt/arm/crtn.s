.syntax unified

.section .init
	pop {r0,lr}
	bx lr

.section .fini
	pop {r0,lr}
	bx lr
