.set noreorder

.global __setjmp
.global _setjmp
.global setjmp
.type   __setjmp,@function
.type   _setjmp,@function
.type   setjmp,@function
__setjmp:
_setjmp:
setjmp:
	sw      $ra,  0($4)
	sw      $sp,  4($4)
	sw      $16,  8($4)
	sw      $17, 12($4)
	sw      $18, 16($4)
	sw      $19, 20($4)
	sw      $20, 24($4)
	sw      $21, 28($4)
	sw      $22, 32($4)
	sw      $23, 36($4)
	sw      $30, 40($4)
	sw      $28, 44($4)
#ifndef __mips_soft_float
	swc1    $20, 56($4)
	swc1    $21, 60($4)
	swc1    $22, 64($4)
	swc1    $23, 68($4)
	swc1    $24, 72($4)
	swc1    $25, 76($4)
	swc1    $26, 80($4)
	swc1    $27, 84($4)
	swc1    $28, 88($4)
	swc1    $29, 92($4)
	swc1    $30, 96($4)
	swc1    $31, 100($4)
#endif
	jr      $ra
	li      $2, 0
