.set noreorder

.global _longjmp
.global longjmp
.type   _longjmp,@function
.type   longjmp,@function
_longjmp:
longjmp:
	move    $2, $5
	bne     $2, $0, 1f
	nop
	addu    $2, $2, 1
1:
#ifndef __mips_soft_float
	lwc1    $20, 56($4)
	lwc1    $21, 60($4)
	lwc1    $22, 64($4)
	lwc1    $23, 68($4)
	lwc1    $24, 72($4)
	lwc1    $25, 76($4)
	lwc1    $26, 80($4)
	lwc1    $27, 84($4)
	lwc1    $28, 88($4)
	lwc1    $29, 92($4)
	lwc1    $30, 96($4)
	lwc1    $31, 100($4)
#endif
	lw      $ra,  0($4)
	lw      $sp,  4($4)
	lw      $16,  8($4)
	lw      $17, 12($4)
	lw      $18, 16($4)
	lw      $19, 20($4)
	lw      $20, 24($4)
	lw      $21, 28($4)
	lw      $22, 32($4)
	lw      $23, 36($4)
	lw      $30, 40($4)
	jr      $ra
	lw      $28, 44($4)
