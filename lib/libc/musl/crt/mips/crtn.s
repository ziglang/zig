.set noreorder

.section .init
	lw $gp,24($sp)
	lw $ra,28($sp)
	# zig patch: j <reg> -> jr <reg> for https://github.com/ziglang/zig/issues/21315
	jr $ra
	addu $sp,$sp,32

.section .fini
	lw $gp,24($sp)
	lw $ra,28($sp)
	# zig patch: j <reg> -> jr <reg> for https://github.com/ziglang/zig/issues/21315
	jr $ra
	addu $sp,$sp,32
