.globl f
f:
	call	should_not_be_exported@PLT
	ret
