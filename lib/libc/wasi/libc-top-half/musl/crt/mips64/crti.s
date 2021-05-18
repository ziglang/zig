.set noreorder

.section .init
.global _init
.align 3
_init:
	dsubu	$sp, $sp, 32
	sd	$gp, 16($sp)
	sd	$ra, 24($sp)

.section .fini
.global _fini
.align 3
_fini:
	dsubu	$sp, $sp, 32
	sd	$gp, 16($sp)
	sd	$ra, 24($sp)
