.global _longjmp
.global longjmp
.type   _longjmp,@function
.type   longjmp,@function
_longjmp:
longjmp:
	ld.d    $ra, $a0, 0
	ld.d    $sp, $a0, 8
	ld.d    $r21,$a0, 16
	ld.d    $fp, $a0, 24
	ld.d    $s0, $a0, 32
	ld.d    $s1, $a0, 40
	ld.d    $s2, $a0, 48
	ld.d    $s3, $a0, 56
	ld.d    $s4, $a0, 64
	ld.d    $s5, $a0, 72
	ld.d    $s6, $a0, 80
	ld.d    $s7, $a0, 88
	ld.d    $s8, $a0, 96
#ifndef __loongarch_soft_float
	fld.d   $fs0, $a0, 104
	fld.d   $fs1, $a0, 112
	fld.d   $fs2, $a0, 120
	fld.d   $fs3, $a0, 128
	fld.d   $fs4, $a0, 136
	fld.d   $fs5, $a0, 144
	fld.d   $fs6, $a0, 152
	fld.d   $fs7, $a0, 160
#endif
	sltui   $a0, $a1, 1
	add.d   $a0, $a0, $a1
	jr      $ra
