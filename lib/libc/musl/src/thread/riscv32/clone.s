# __clone(func, stack, flags, arg, ptid, tls, ctid)
#           a0,    a1,    a2,  a3,   a4,  a5,   a6

# syscall(SYS_clone, flags, stack, ptid, tls, ctid)
#                a7     a0,    a1,   a2,  a3,   a4

.global __clone
.type  __clone, %function
__clone:
	# Save func and arg to stack
	addi a1, a1, -16
	sw a0, 0(a1)
	sw a3, 4(a1)

	# Call SYS_clone
	mv a0, a2
	mv a2, a4
	mv a3, a5
	mv a4, a6
	li a7, 220 # SYS_clone
	ecall

	beqz a0, 1f
	# Parent
	ret

	# Child
1:      lw a1, 0(sp)
	lw a0, 4(sp)
	jalr a1

	# Exit
	li a7, 93 # SYS_exit
	ecall
