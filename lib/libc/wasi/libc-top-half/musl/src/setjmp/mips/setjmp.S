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
	s.d     $f20, 56($4)
	s.d     $f22, 64($4)
	s.d     $f24, 72($4)
	s.d     $f26, 80($4)
	s.d     $f28, 88($4)
	s.d     $f30, 96($4)
#endif
	jr      $ra
	li      $2, 0
