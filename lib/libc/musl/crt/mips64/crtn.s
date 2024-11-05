.set noreorder

.section .init
	ld $gp,16($sp)
	ld $ra,24($sp)
	# zig patch: j <reg> -> jr <reg> for https://github.com/ziglang/zig/issues/21315
	jr $ra
	daddu $sp,$sp,32

.section .fini
	ld $gp,16($sp)
	ld $ra,24($sp)
	# zig patch: j <reg> -> jr <reg> for https://github.com/ziglang/zig/issues/21315
	jr $ra
	daddu $sp,$sp,32
