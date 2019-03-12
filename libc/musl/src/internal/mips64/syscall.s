.set	noreorder
.global	__syscall
.hidden	__syscall
.type	__syscall,@function
__syscall:
	move	$2, $4
	move	$4, $5
	move	$5, $6
	move	$6, $7
	move	$7, $8
	move	$8, $9
	move	$9, $10
	move	$10, $11
	syscall
	beq	$7, $0, 1f
	nop
	dsubu	$2, $0, $2
1:	jr	$ra
	nop
