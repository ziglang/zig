.global __cp_begin
.hidden __cp_begin
.global __cp_end
.hidden __cp_end
.global __cp_cancel
.hidden __cp_cancel
.hidden __cancel
.global __syscall_cp_asm
.hidden __syscall_cp_asm
.type   __syscall_cp_asm,@function
__syscall_cp_asm:
__cp_begin:
	lwi     r5, r5, 0
	bnei    r5, __cp_cancel
	addi    r12, r6, 0
	add     r5, r7, r0
	add     r6, r8, r0
	add     r7, r9, r0
	add     r8, r10, r0
	lwi     r9, r1, 28
	lwi     r10, r1, 32
	brki    r14, 0x8
__cp_end:
	rtsd    r15, 8
	nop
__cp_cancel:
	bri     __cancel
