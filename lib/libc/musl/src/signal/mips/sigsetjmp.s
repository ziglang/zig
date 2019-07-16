.set noreorder

.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	lui $gp, %hi(_gp_disp)
	addiu $gp, %lo(_gp_disp)
	beq $5, $0, 1f
	 addu $gp, $gp, $25

	sw $ra, 104($4)
	sw $16, 104+4+16($4)

	lw $25, %call16(setjmp)($gp)
	jalr $25
	 move $16, $4

	move $5,$2
	move $4,$16
	lw $ra, 104($4)
	lw $16, 104+4+16($4)

.hidden __sigsetjmp_tail
	lw $25, %call16(__sigsetjmp_tail)($gp)
	jr $25
	 nop

1:	lw $25, %call16(setjmp)($gp)
	jr $25
	 nop
