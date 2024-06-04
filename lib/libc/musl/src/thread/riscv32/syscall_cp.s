.global __cp_begin
.hidden __cp_begin
.global __cp_end
.hidden __cp_end
.global __cp_cancel
.hidden __cp_cancel
.hidden __cancel
.global __syscall_cp_asm
.hidden __syscall_cp_asm
.type __syscall_cp_asm, %function
__syscall_cp_asm:
__cp_begin:
	lw t0, 0(a0)
	bnez t0, __cp_cancel

	mv t0, a1
	mv a0, a2
	mv a1, a3
	mv a2, a4
	mv a3, a5
	mv a4, a6
	mv a5, a7
	lw a6, 0(sp)
	mv a7, t0
	ecall
__cp_end:
	ret
__cp_cancel:
	tail __cancel
