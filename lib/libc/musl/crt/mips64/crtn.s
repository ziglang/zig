.set noreorder

.section .init
	ld $gp,16($sp)
	ld $ra,24($sp)
	j $ra
	daddu $sp,$sp,32

.section .fini
	ld $gp,16($sp)
	ld $ra,24($sp)
	j $ra
	daddu $sp,$sp,32
