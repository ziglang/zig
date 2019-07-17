.global __setjmp
.global _setjmp
.global setjmp
.type __setjmp, %function
.type _setjmp,  %function
.type setjmp,   %function
__setjmp:
_setjmp:
setjmp:
	sd s0,    0(a0)
	sd s1,    8(a0)
	sd s2,    16(a0)
	sd s3,    24(a0)
	sd s4,    32(a0)
	sd s5,    40(a0)
	sd s6,    48(a0)
	sd s7,    56(a0)
	sd s8,    64(a0)
	sd s9,    72(a0)
	sd s10,   80(a0)
	sd s11,   88(a0)
	sd sp,    96(a0)
	sd ra,    104(a0)

#ifndef __riscv_float_abi_soft
	fsd fs0,  112(a0)
	fsd fs1,  120(a0)
	fsd fs2,  128(a0)
	fsd fs3,  136(a0)
	fsd fs4,  144(a0)
	fsd fs5,  152(a0)
	fsd fs6,  160(a0)
	fsd fs7,  168(a0)
	fsd fs8,  176(a0)
	fsd fs9,  184(a0)
	fsd fs10, 192(a0)
	fsd fs11, 200(a0)
#endif

	li a0, 0
	ret
