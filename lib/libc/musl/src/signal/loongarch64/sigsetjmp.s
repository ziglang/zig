.global sigsetjmp
.global __sigsetjmp
.type sigsetjmp,@function
.type __sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	beq     $a1, $zero, 1f
	st.d    $ra, $a0, 184
	st.d    $s0, $a0, 200  #184+8+8
	move    $s0, $a0

	la.global  $t0, setjmp
	jirl       $ra, $t0, 0

	move    $a1, $a0        # Return from 'setjmp' or 'longjmp'
	move    $a0, $s0
	ld.d    $ra, $a0, 184
	ld.d    $s0, $a0, 200 #184+8+8

.hidden __sigsetjmp_tail
	la.global  $t0, __sigsetjmp_tail
	jr         $t0
1:
	la.global  $t0, setjmp
	jr         $t0
