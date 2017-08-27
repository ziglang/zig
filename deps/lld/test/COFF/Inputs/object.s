
	.text

	.def f
		.scl 2
		.type 32
	.endef
	.global f
f:
	retq $0

	.section .drectve,"rd"
	.ascii " /EXPORT:f"
