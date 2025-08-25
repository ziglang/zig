.global __longjmp
.global _longjmp
.global longjmp
.type __longjmp, %function
.type _longjmp,  %function
.type longjmp,   %function
__longjmp:
_longjmp:
longjmp:
	ld s0,    0(a0)
	ld s1,    8(a0)
	ld s2,    16(a0)
	ld s3,    24(a0)
	ld s4,    32(a0)
	ld s5,    40(a0)
	ld s6,    48(a0)
	ld s7,    56(a0)
	ld s8,    64(a0)
	ld s9,    72(a0)
	ld s10,   80(a0)
	ld s11,   88(a0)
	ld sp,    96(a0)
	ld ra,    104(a0)

#ifndef __riscv_float_abi_soft
	fld fs0,  112(a0)
	fld fs1,  120(a0)
	fld fs2,  128(a0)
	fld fs3,  136(a0)
	fld fs4,  144(a0)
	fld fs5,  152(a0)
	fld fs6,  160(a0)
	fld fs7,  168(a0)
	fld fs8,  176(a0)
	fld fs9,  184(a0)
	fld fs10, 192(a0)
	fld fs11, 200(a0)
#endif

	seqz a0, a1
	add a0, a0, a1
	ret
