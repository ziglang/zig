.set noreorder
.global __clone
.hidden __clone
.type   __clone,@function
__clone:
	# Save function pointer and argument pointer on new thread stack
	and $5, $5, -8
	subu $5, $5, 16
	sw $4, 0($5)
	sw $7, 4($5)
	# Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
	move $4, $6
	lw $6, 16($sp)
	lw $7, 20($sp)
	lw $9, 24($sp)
	subu $sp, $sp, 16
	sw $9, 16($sp)
	li $2, 4120
	syscall
	beq $7, $0, 1f
	nop
	addu $sp, $sp, 16
	jr $ra
	subu $2, $0, $2
1:	beq $2, $0, 1f
	nop
	addu $sp, $sp, 16
	jr $ra
	nop
1:	lw $25, 0($sp)
	lw $4, 4($sp)
	jalr $25
	nop
	move $4, $2
	li $2, 4001
	syscall
