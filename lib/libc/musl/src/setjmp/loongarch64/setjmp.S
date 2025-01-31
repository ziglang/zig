.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp,@function
.type _setjmp,@function
.type setjmp,@function
__setjmp:
_setjmp:
setjmp:
	st.d    $ra, $a0, 0
	st.d    $sp, $a0, 8
	st.d    $r21,$a0, 16
	st.d    $fp, $a0, 24
	st.d    $s0, $a0, 32
	st.d    $s1, $a0, 40
	st.d    $s2, $a0, 48
	st.d    $s3, $a0, 56
	st.d    $s4, $a0, 64
	st.d    $s5, $a0, 72
	st.d    $s6, $a0, 80
	st.d    $s7, $a0, 88
	st.d    $s8, $a0, 96
#ifndef __loongarch_soft_float
	fst.d   $fs0, $a0, 104
	fst.d   $fs1, $a0, 112
	fst.d   $fs2, $a0, 120
	fst.d   $fs3, $a0, 128
	fst.d   $fs4, $a0, 136
	fst.d   $fs5, $a0, 144
	fst.d   $fs6, $a0, 152
	fst.d   $fs7, $a0, 160
#endif
	move    $a0, $zero
	jr      $ra
