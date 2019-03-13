.set noreorder

.section .init
.global _init
.type _init,@function
.align 2
_init:
	subu $sp,$sp,32
	sw $gp,24($sp)
	sw $ra,28($sp)

.section .fini
.global _fini
.type _fini,@function
.align 2
_fini:
	subu $sp,$sp,32
	sw $gp,24($sp)
	sw $ra,28($sp)
