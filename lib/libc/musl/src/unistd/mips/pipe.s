.set noreorder

.global pipe
.type   pipe,@function
pipe:
	lui $gp, %hi(_gp_disp)
	addiu $gp, %lo(_gp_disp)
	addu $gp, $gp, $25
	li $2, 4042
	syscall
	beq $7, $0, 1f
	nop
	lw $25, %call16(__syscall_ret)($gp)
	jr $25
	subu $4, $0, $2
1:	sw $2, 0($4)
	sw $3, 4($4)
	move $2, $0
	jr $ra
	nop
