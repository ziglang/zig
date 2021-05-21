.text
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
	movem.l %d2-%d5,-(%sp)
	movea.l 20(%sp),%a0
__cp_begin:
	move.l (%a0),%d0
	bne __cp_cancel
	movem.l 24(%sp),%d0-%d5/%a0
	trap #0
__cp_end:
	movem.l (%sp)+,%d2-%d5
	rts
__cp_cancel:
	movem.l (%sp)+,%d2-%d5
	move.l __cancel-.-8,%a1
	jmp (%pc,%a1)
