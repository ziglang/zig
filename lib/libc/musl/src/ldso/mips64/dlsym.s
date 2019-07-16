.set	noreorder
.global	dlsym
.hidden	__dlsym
.type	dlsym,@function
dlsym:
	lui	$3, %hi(%neg(%gp_rel(dlsym)))
	daddiu	$3, $3, %lo(%neg(%gp_rel(dlsym)))
	daddu	$3, $3, $25
	move	$6, $ra
	ld	$25, %got_disp(__dlsym)($3)
	daddiu	$sp, $sp, -32
	sd	$ra, 24($sp)
	jalr	$25
	nop
	ld	$ra, 24($sp)
	jr	$ra
	daddiu	$sp, $sp, 32
