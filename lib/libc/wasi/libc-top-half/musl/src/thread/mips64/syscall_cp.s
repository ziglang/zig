.set	noreorder
.global	__cp_begin
.hidden	__cp_begin
.type	__cp_begin,@function
.global	__cp_end
.hidden	__cp_end
.type	__cp_end,@function
.global	__cp_cancel
.hidden	__cp_cancel
.type	__cp_cancel,@function
.global	__cp_cancel_data
.hidden	__cp_cancel_data
.type	__cp_cancel_data,@function
.hidden	__cancel
.global	__syscall_cp_asm
.hidden	__syscall_cp_asm
.type	__syscall_cp_asm,@function
__syscall_cp_asm:
__cp_begin:
	lw	$4, 0($4)
	bne	$4, $0, __cp_cancel
	move	$2, $5
	move	$4, $6
	move	$5, $7
	move	$6, $8
	move	$7, $9
	move	$8, $10
	move	$9, $11
	ld	$10, 0($sp)
	syscall
__cp_end:
	beq	$7, $0, 1f
	nop
	dsubu	$2, $0, $2
1:	jr	$ra
	nop

	# if cancellation flag is 1 then call __cancel
__cp_cancel:
	move	$2, $ra
.align 8
	bal	1f
	nop
__cp_cancel_data:
	.gpdword __cp_cancel_data
	.gpdword __cancel
1:	ld	$3, ($ra)
	dsubu	$3, $ra, $3
	ld	$25, 8($ra)
	daddu	$25, $25, $3
	jr	$25
	move	$ra, $2
