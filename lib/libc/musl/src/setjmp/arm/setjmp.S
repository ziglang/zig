.syntax unified
.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp,%function
.type _setjmp,%function
.type setjmp,%function
__setjmp:
_setjmp:
setjmp:
	mov ip,r0
	stmia ip!,{v1,v2,v3,v4,v5,v6,sl,fp}
	mov r2,sp
	stmia ip!,{r2,lr}
	mov r0,#0

	adr r1,1f
	ldr r2,1f
	ldr r1,[r1,r2]

#if __ARM_ARCH < 8
	tst r1,#0x260
	beq 3f
	// HWCAP_ARM_FPA
	tst r1,#0x20
	beq 2f
	stc p2, cr4, [ip], #48
#endif
2:	tst r1,#0x40
	beq 2f
	.fpu vfp
	vstmia ip!, {d8-d15}
	.fpu softvfp
	.eabi_attribute 10, 0
	.eabi_attribute 27, 0
#if __ARM_ARCH < 8
	// HWCAP_ARM_IWMMXT
2:	tst r1,#0x200
	beq 3f
	stcl p1, cr10, [ip], #8
	stcl p1, cr11, [ip], #8
	stcl p1, cr12, [ip], #8
	stcl p1, cr13, [ip], #8
	stcl p1, cr14, [ip], #8
	stcl p1, cr15, [ip], #8
#endif
2:
3:	bx lr

.hidden __hwcap
.align 2
1:	.word __hwcap-1b
