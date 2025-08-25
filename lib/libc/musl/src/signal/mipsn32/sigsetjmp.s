.set	noreorder
.global	sigsetjmp
.global	__sigsetjmp
.type	sigsetjmp,@function
.type	__sigsetjmp,@function
sigsetjmp:
__sigsetjmp:
	lui	$3, %hi(%neg(%gp_rel(sigsetjmp)))
	addiu	$3, $3, %lo(%neg(%gp_rel(sigsetjmp)))

	# comparing save mask with 0, if equals to 0 then
	# sigsetjmp is equal to setjmp.
	beq	$5, $0, 1f
	addu	$3, $3, $25
	sd	$ra, 160($4)
	sd	$16, 168($4)

	# save base of got so that we can use it later
	# once we return from 'longjmp'
	sd	$3, 176($4)
	lw	$25, %got_disp(setjmp)($3)
	jalr	$25
	move	$16, $4

	move	$5, $2		# Return from 'setjmp' or 'longjmp'
	move	$4, $16		# Restore the pointer-to-sigjmp_buf
	ld	$ra, 160($4)	# Restore ra of sigsetjmp
	ld	$16, 168($4)	# Restore $16 of sigsetjmp
	ld	$3, 176($4)	# Restore base of got

.hidden	__sigsetjmp_tail
	lw	$25, %got_disp(__sigsetjmp_tail)($3)
	jr	$25
	nop
1:
	lw	$25, %got_disp(setjmp)($3)
	jr	$25
	nop
