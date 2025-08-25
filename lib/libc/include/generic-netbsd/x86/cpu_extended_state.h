/*	$NetBSD: cpu_extended_state.h,v 1.17.28.1 2023/07/25 11:41:42 martin Exp $	*/

#ifndef _X86_CPU_EXTENDED_STATE_H_
#define _X86_CPU_EXTENDED_STATE_H_

#ifdef __lint__
/* Lint has different packing rules and doesn't understand __aligned() */
#define __CTASSERT_NOLINT(x) __CTASSERT(1)
#else
#define __CTASSERT_NOLINT(x) __CTASSERT(x)
#endif

/*
 * This file contains definitions of structures that match the memory layouts
 * used on x86 processors to save floating point registers and other extended
 * cpu states.
 *
 * This includes registers (etc) used by SSE/SSE2/SSE3/SSSE3/SSE4 and the later
 * AVX instructions.
 *
 * The definitions are such that any future 'extended state' should be handled,
 * provided the kernel doesn't need to know the actual contents.
 *
 * The actual structures the cpu accesses must be aligned to 16 bytes for FXSAVE
 * and 64 for XSAVE. The types aren't aligned because copies do not need extra
 * alignment.
 *
 * The slightly different layout saved by the i387 fsave is also defined.
 * This is only normally written by pre Pentium II type cpus that don't
 * support the fxsave instruction.
 *
 * Associated save instructions:
 * FNSAVE:   Saves x87 state in 108 bytes (original i387 layout). Then
 *           reinitializes the fpu.
 * FSAVE:    Encodes to FWAIT followed by FNSAVE.
 * FXSAVE:   Saves the x87 state and XMM (aka SSE) registers to the first
 *           448 (max) bytes of a 512 byte area. This layout does not match
 *           that written by FNSAVE.
 * XSAVE:    Uses the same layout for the x87 and XMM registers, followed by
 *           a 64byte header and separate save areas for additional extended
 *           cpu states. The x87 state is always saved, the others
 *           conditionally.
 * XSAVEOPT: Same as XSAVE but only writes the registers blocks that have
 *           been modified.
 */

/*
 * Layout for code/data pointers relating to FP exceptions. Marked 'packed'
 * because they aren't always 64bit aligned. Since the x86 cpu supports
 * misaligned accesses it isn't worth avoiding the 'packed' attribute.
 */
union fp_addr {
	uint64_t fa_64;	/* Linear address for 64bit systems */
	struct {
		uint32_t fa_off;	/* linear address for 32 bit */
		uint16_t fa_seg;	/* code/data (etc) segment */
		uint16_t fa_opcode;	/* last opcode (sometimes) */
	} fa_32;
} __packed __aligned(4);

/* The x87 registers are 80 bits */
struct fpacc87 {
	uint64_t f87_mantissa;	/* mantissa */
	uint16_t f87_exp_sign;	/* exponent and sign */
} __packed __aligned(2);

/* The x87 registers padded out to 16 bytes for fxsave */
struct fpaccfx {
	struct fpacc87 r __aligned(16);
};

/* The SSE/SSE2 registers are 128 bits */
struct xmmreg {
	uint8_t xmm_bytes[16];
};

/* The AVX registers are 256 bits, but the low bits are the xmmregs */
struct ymmreg {
	uint8_t ymm_bytes[16];
};

/* The AVX-512 registers are 512 bits but the low bits are in xmmregs
 * and ymmregs */
struct zmmreg {
	uint8_t zmm_bytes[32];
};

/* 512-bit ZMM register. */
struct hi16_zmmreg {
	uint8_t zmm_bytes[64];
};

/*
 * Floating point unit registers (FSAVE instruction).
 *
 * The s87_ac[] and fx_87_ac[] are relative to the stack top. The 'tag word'
 * contains 2 bits per register and refers to absolute register numbers.
 *
 * The cpu sets the tag values 0b01 (zero) and 0b10 (special) when a value
 * is loaded. The software need only set 0b00 (used) and 0xb11 (unused).
 * The fxsave 'Abridged tag word' in inverted.
 */
struct save87 {
	uint16_t s87_cw __aligned(4);	/* control word */
	uint16_t s87_sw __aligned(4);	/* status word  */
	uint16_t s87_tw __aligned(4);	/* tag word */
	union fp_addr s87_ip;		/* floating point instruction pointer */
#define s87_opcode s87_ip.fa_32.fa_opcode	/* opcode last executed (11bits) */
	union fp_addr s87_dp;		/* floating operand offset */
	struct fpacc87 s87_ac[8];	/* accumulator contents */
};
__CTASSERT_NOLINT(sizeof(struct save87) == 108);

/*
 * FPU/MMX/SSE/SSE2 context (FXSAVE instruction).
 */
struct fxsave {
	uint16_t fx_cw;		/* FPU Control Word */
	uint16_t fx_sw;		/* FPU Status Word */
	uint8_t fx_tw;		/* FPU Tag Word (abridged) */
	uint8_t fx_zero;	/* zero */
	uint16_t fx_opcode;	/* FPU Opcode */
	union fp_addr fx_ip;	/* FPU Instruction Pointer */
	union fp_addr fx_dp;	/* FPU Data pointer */
	uint32_t fx_mxcsr;	/* MXCSR Register State */
	uint32_t fx_mxcsr_mask;
	struct fpaccfx fx_87_ac[8];	/* 8 x87 registers */
	struct xmmreg fx_xmm[16];	/* XMM regs (8 in 32bit modes) */
	uint8_t fx_rsvd[96];
} __aligned(16);
__CTASSERT_NOLINT(sizeof(struct fxsave) == 512);

/*
 * For XSAVE, a 64byte header follows the fxsave data.
 */
struct xsave_header {
	uint8_t xsh_fxsave[512];	/* struct fxsave */
	uint64_t xsh_xstate_bv;		/* bitmap of saved sub structures */
	uint64_t xsh_xcomp_bv;		/* bitmap of compact sub structures */
	uint8_t xsh_rsrvd[8];		/* must be zero */
	uint8_t xsh_reserved[40];	/* best if zero */
};
__CTASSERT(sizeof(struct xsave_header) == 512 + 64);

/*
 * The ymm save area actually follows the xsave_header.
 */
struct xsave_ymm {
	struct ymmreg xs_ymm[16];	/* High bits of YMM registers */
};
__CTASSERT(sizeof(struct xsave_ymm) == 256);

/*
 * AVX-512: opmask state.
 */
struct xsave_opmask {
	uint64_t xs_k[8];			/* k0..k7 registers. */
};
__CTASSERT(sizeof(struct xsave_opmask) == 64);

/*
 * AVX-512: ZMM_Hi256 state.
 */
struct xsave_zmm_hi256 {
	struct zmmreg xs_zmm[16];	/* High bits of zmm0..zmm15 registers. */
};
__CTASSERT(sizeof(struct xsave_zmm_hi256) == 512);

/*
 * AVX-512: Hi16_ZMM state.
 */
struct xsave_hi16_zmm {
	struct hi16_zmmreg xs_hi16_zmm[16];	/* zmm16..zmm31 registers. */
};
__CTASSERT(sizeof(struct xsave_hi16_zmm) == 1024);

/*
 * Structure used to hold all interesting data from XSAVE, in predictable form.
 * Note that this structure can have new members added to the end.
 */
struct xstate {
	/*
	 * The two following fields are bitmaps of XSAVE components.  They can be
	 * matched against XCR0_* constants from <machine/specialreg.h>).
	 */
	/*
	 * XSAVE/XRSTOR RFBM parameter.
	 *
	 * PT_GETXSTATE: 1 indicates that the respective XSAVE component is
	 * supported and has been enabled for saving.  0 indicates that it is not
	 * supported by the platform or kernel.
	 *
	 * PT_SETXSTATE: 1 indicates that the respective XSAVE component should
	 * be updated to the value of respective field (or reset if xs_xsave_bv
	 * bit is 0).  0 indicates that it should be left intact.  It is an error
	 * to enable bits that are not supported by the platform or kernel.
	 */
	uint64_t xs_rfbm;
	/*
	 * XSAVE/XRSTOR xstate header.
	 *
	 * PT_GETXSTATE: 1 indicates that the respective XSAVE component has been
	 * saved.  0 indicates that it had been in its CPU-defined initial value
	 * at the time of saving (i.e. was not used by the program).
	 *
	 * PT_SETXSTATE: 1 indicates that the respective XSAVE component (if present
	 * in xs_rfbm) should be set to the values in respective field.  0 indicates
	 * that it should be reset to CPU-defined initial value.
	 */
	uint64_t xs_xstate_bv;

	/* legacy FXSAVE area (used for x87 & SSE state) */
	struct fxsave xs_fxsave;
	/* AVX state: high bits of ymm0..ymm15 registers */
	struct xsave_ymm xs_ymm_hi128;
	/* AVX-512: opmask */
	struct xsave_opmask xs_opmask;
	/* AVX-512: high bits of zmm0..zmm15 registers */
	struct xsave_zmm_hi256 xs_zmm_hi256;
	/* AVX-512: whole zmm16..zmm31 registers */
	struct xsave_hi16_zmm xs_hi16_zmm;
};

/*
 * The following union is placed at the end of the pcb.
 * It is defined this way to separate the definitions and to
 * minimise the number of union/struct selectors.
 * NB: Some userspace stuff (eg firefox) uses it to parse ucontext.
 */
union savefpu {
	struct save87 sv_87;
	struct fxsave sv_xmm;
#ifdef _KERNEL
	struct xsave_header sv_xsave_hdr;
#endif
};

/*
 * 80387 control and status word bits
 *
 * The only reference I can find to bits 0x40 and 0x80 in the control word
 * is for the Weitek 1167/3167.
 * I (dsl) can't find why the default word has 0x40 set.
 *
 * A stack error is signalled as an INVOP that also sets STACK_FAULT
 * (other INVOP do not clear STACK_FAULT).
 */
/* Interrupt masks (set masks interrupt) and status bits */
#define EN_SW_INVOP		0x0001  /* Invalid operation */
#define EN_SW_DENORM		0x0002  /* Denormalized operand */
#define EN_SW_ZERODIV		0x0004  /* Divide by zero */
#define EN_SW_OVERFLOW		0x0008  /* Overflow */
#define EN_SW_UNDERFLOW		0x0010  /* Underflow */
#define EN_SW_PRECLOSS		0x0020  /* Loss of precision */
/* Status word bits (reserved in control word) */
#define EN_SW_STACK_FAULT	0x0040	/* Stack under/overflow */
#define EN_SW_ERROR_SUMMARY	0x0080	/* Unmasked error has occurred */
/* Control bits (badly named) */
#define EN_SW_CTL_PREC		0x0300	/* Precision control */
#define EN_SW_PREC_24		0x0000	/* Single precision */
#define EN_SW_PREC_53		0x0200	/* Double precision */
#define EN_SW_PREC_64		0x0300	/* Extended precision */
#define EN_SW_CTL_ROUND		0x0c00	/* Rounding control */
#define EN_SW_ROUND_EVEN	0x0000	/* Round to nearest even */
#define EN_SW_ROUND_DOWN	0x0400	/* Round towards minus infinity */
#define EN_SW_ROUND_UP		0x0800	/* Round towards plus infinity */
#define EN_SW_ROUND_ZERO	0x0c00	/* Round towards zero (truncates) */
#define EN_SW_CTL_INF		0x1000	/* Infinity control, not used  */

/*
 * The standard 0x87 control word from finit is 0x37F, giving:
 *	round to nearest
 *	64-bit precision
 *	all exceptions masked.
 *
 * NetBSD used to select:
 *	round to nearest
 *	53-bit precision
 *	all exceptions masked.
 * Stating: 64-bit precision often gives bad results with high level
 * languages because it makes the results of calculations depend on whether
 * intermediate values are stored in memory or in FPU registers.
 * Also some 'pathological divisions' give an error in the LSB because
 * the value is first rounded up when the 64bit mantissa is generated,
 * and then again when it is truncated to 53 bits.
 *
 * However the C language explicitly allows the extra precision.
 */
#define	__INITIAL_NPXCW__	0x037f
/* Modern NetBSD uses the default control word.. */
#define	__NetBSD_NPXCW__	__INITIAL_NPXCW__
/* NetBSD before 6.99.26 forced IEEE double precision. */
#define	__NetBSD_COMPAT_NPXCW__	0x127f
/* FreeBSD leaves some exceptions unmasked as well. */
#define	__FreeBSD_NPXCW__	0x1272
/* Linux just uses the default control word. */
#define	__Linux_NPXCW__		__INITIAL_NPXCW__

/*
 * The default MXCSR value at reset is 0x1f80, IA-32 Instruction
 * Set Reference, pg. 3-369.
 *
 * The low 6 bits of the mxcsr are the fp status bits (same order as x87).
 * Bit 6 is 'denormals are zero' (speeds up calculations).
 * Bits 7-16 are the interrupt mask bits (same order, 1 to mask).
 * Bits 13 and 14 are rounding control.
 * Bit 15 is 'flush to zero' - affects underflow.
 * Bits 16-31 must be zero.
 *
 * The safe MXCSR is fit for constant-time use, e.g. in crypto.  Some
 * CPU instructions take input- dependent time if an exception status
 * bit is not set; __SAFE_MXCSR__ has the exception status bits all set
 * already to mitigate this.  See:
 * https://www.intel.com/content/www/us/en/developer/articles/technical/software-security-guidance/best-practices/mxcsr-configuration-dependent-timing.html
 */
#define	__INITIAL_MXCSR__	0x1f80
#define	__INITIAL_MXCSR_MASK__	0xffbf
#define	__SAFE_MXCSR__		0x1fbf

#endif /* _X86_CPU_EXTENDED_STATE_H_ */