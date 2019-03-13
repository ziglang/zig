.section .init
.global _init
_init:
	sub $12,%esp

.section .fini
.global _fini
_fini:
	sub $12,%esp
