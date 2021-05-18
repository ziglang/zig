.global __unmapself
.type   __unmapself,@function
__unmapself:
	ori     r12, r0, 91
	brki    r14, 0x8
	ori     r12, r0, 1
	brki    r14, 0x8
	nop
