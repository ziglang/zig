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
	ld.w $a0, $a0, 0
	bnez $a0, __cp_cancel
	move $t8, $a1    # reserve system call number
	move $a0, $a2
	move $a1, $a3
	move $a2, $a4
	move $a3, $a5
	move $a4, $a6
	move $a5, $a7
	move $a7, $t8
	syscall 0
__cp_end:
	jr $ra
__cp_cancel:
	la.local $t8, __cancel
	jr $t8
