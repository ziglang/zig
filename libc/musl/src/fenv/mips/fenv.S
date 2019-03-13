#ifndef __mips_soft_float

.set noreorder

.global feclearexcept
.type  feclearexcept,@function
feclearexcept:
	and     $4, $4, 0x7c
	cfc1    $5, $31
	or      $5, $5, $4
	xor     $5, $5, $4
	ctc1    $5, $31
	jr      $ra
	li      $2, 0

.global feraiseexcept
.type  feraiseexcept,@function
feraiseexcept:
	and     $4, $4, 0x7c
	cfc1    $5, $31
	or      $5, $5, $4
	ctc1    $5, $31
	jr      $ra
	li      $2, 0

.global fetestexcept
.type  fetestexcept,@function
fetestexcept:
	and     $4, $4, 0x7c
	cfc1    $2, $31
	jr      $ra
	and     $2, $2, $4

.global fegetround
.type  fegetround,@function
fegetround:
	cfc1    $2, $31
	jr      $ra
	andi    $2, $2, 3

.global __fesetround
.hidden __fesetround
.type __fesetround,@function
__fesetround:
	cfc1    $5, $31
	li      $6, -4
	and     $5, $5, $6
	or      $5, $5, $4
	ctc1    $5, $31
	jr      $ra
	li      $2, 0

.global fegetenv
.type  fegetenv,@function
fegetenv:
	cfc1    $5, $31
	sw      $5, 0($4)
	jr      $ra
	li      $2, 0

.global fesetenv
.type  fesetenv,@function
fesetenv:
	addiu   $5, $4, 1
	beq     $5, $0, 1f
	 nop
	lw      $5, 0($4)
1:	ctc1    $5, $31
	jr      $ra
	li      $2, 0

#endif
