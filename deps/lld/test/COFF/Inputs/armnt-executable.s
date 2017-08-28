# void mainCRTStartup() {}
	.syntax unified
	.thumb
	.text
	.def mainCRTStartup
		.scl 2
		.type 32
	.endef
	.global mainCRTStartup
	.align 2
	.thumb_func
mainCRTStartup:
	bx lr
