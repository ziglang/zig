.set	noreorder
.section	.init
.global	_init
.type	_init,@function
.align	2
_init:
	subu	$sp, $sp, 32
	sd	$gp, 16($sp)
	sd	$ra, 24($sp)

.section	.fini
.global	_fini
.type	_fini,@function
.align	2
_fini:
	subu	$sp, $sp, 32
	sd	$gp, 16($sp)
	sd	$ra, 24($sp)
