.set	noreorder
.global	pipe
.type	pipe,@function
pipe:
	lui	$3, %hi(%neg(%gp_rel(pipe)))
	daddiu	$3, $3, %lo(%neg(%gp_rel(pipe)))
	daddu	$3, $3, $25
	li	$2, 5021
	syscall
	beq	$7, $0, 1f
	nop
	ld	$25, %got_disp(__syscall_ret)($3)
	jr	$25
	dsubu	$4, $0, $2
1:	sw	$2, 0($4)
	sw	$3, 4($4)
	move	$2, $0
	jr	$ra
	nop
