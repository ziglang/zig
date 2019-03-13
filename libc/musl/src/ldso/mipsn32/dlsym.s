.set	noreorder
.global	dlsym
.hidden	__dlsym
.type	dlsym,@function
dlsym:
	lui	$3, %hi(%neg(%gp_rel(dlsym)))
	addiu	$3, $3, %lo(%neg(%gp_rel(dlsym)))
	addu	$3, $3, $25
	move	$6, $ra
	lw	$25, %got_disp(__dlsym)($3)
	addiu	$sp, $sp, -32
	sd	$ra, 16($sp)
	jalr	$25
	nop
	ld	$ra, 16($sp)
	jr	$ra
	addiu	$sp, $sp, 32
