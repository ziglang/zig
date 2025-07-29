/* $NetBSD: sysreg.h,v 1.28 2022/12/03 11:09:59 skrll Exp $ */

/*
 * Copyright (c) 2014 The NetBSD Foundation, Inc.
 * All rights reserved.
 *
 * This code is derived from software contributed to The NetBSD Foundation
 * by Matt Thomas of 3am Software Foundry.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE NETBSD FOUNDATION, INC. AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
 * TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE FOUNDATION OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef _RISCV_SYSREG_H_
#define	_RISCV_SYSREG_H_

#ifndef _KERNEL
#include <sys/param.h>
#endif

#include <riscv/reg.h>

#define	FCSR_FMASK	0	// no exception bits
#define	FCSR_FRM	__BITS(7, 5)
#define	 FCSR_FRM_RNE	0b000	// Round Nearest, ties to Even
#define	 FCSR_FRM_RTZ	0b001	// Round Towards Zero
#define	 FCSR_FRM_RDN	0b010	// Round DowN (-infinity)
#define	 FCSR_FRM_RUP	0b011	// Round UP (+infinity)
#define	 FCSR_FRM_RMM	0b100	// Round to nearest, ties to Max Magnitude
#define	 FCSR_FRM_DYN	0b111	// Dynamic rounding
#define	FCSR_FFLAGS	__BITS(4, 0)	// Sticky bits
#define	FCSR_NV		__BIT(4)	// iNValid operation
#define	FCSR_DZ		__BIT(3)	// Divide by Zero
#define	FCSR_OF		__BIT(2)	// OverFlow
#define	FCSR_UF		__BIT(1)	// UnderFlow
#define	FCSR_NX		__BIT(0)	// iNeXact

static inline uint32_t
riscvreg_fcsr_read(void)
{
	uint32_t __fcsr;
	__asm("frcsr %0" : "=r"(__fcsr));
	return __fcsr;
}


static inline uint32_t
riscvreg_fcsr_write(uint32_t __new)
{
	uint32_t __old;
	__asm("fscsr %0, %1" : "=r"(__old) : "r"(__new));
	return __old;
}

static inline uint32_t
riscvreg_fcsr_read_fflags(void)
{
	uint32_t __old;
	__asm("frflags %0" : "=r"(__old));
	return __SHIFTOUT(__old, FCSR_FFLAGS);
}

static inline uint32_t
riscvreg_fcsr_write_fflags(uint32_t __new)
{
	uint32_t __old;
	__new = __SHIFTIN(__new, FCSR_FFLAGS);
	__asm("fsflags %0, %1" : "=r"(__old) : "r"(__new));
	return __SHIFTOUT(__old, FCSR_FFLAGS);
}

static inline uint32_t
riscvreg_fcsr_read_frm(void)
{
	uint32_t __old;
	__asm("frrm\t%0" : "=r"(__old));
	return __SHIFTOUT(__old, FCSR_FRM);
}

static inline uint32_t
riscvreg_fcsr_write_frm(uint32_t __new)
{
	uint32_t __old;
	__new = __SHIFTIN(__new, FCSR_FRM);
	__asm __volatile("fsrm\t%0, %1" : "=r"(__old) : "r"(__new));
	return __SHIFTOUT(__old, FCSR_FRM);
}


#define	RISCVREG_READ_INLINE(regname)					\
static inline uintptr_t							\
csr_##regname##_read(void)						\
{									\
	uintptr_t __rv;							\
	asm volatile("csrr %0, " #regname : "=r"(__rv) :: "memory");	\
	return __rv;							\
}

#define	RISCVREG_WRITE_INLINE(regname)					\
static inline void							\
csr_##regname##_write(uintptr_t __val)					\
{									\
	asm volatile("csrw " #regname ", %0" :: "r"(__val) : "memory");	\
}

#define	RISCVREG_SET_INLINE(regname)					\
static inline void							\
csr_##regname##_set(uintptr_t __mask)					\
{									\
	if (__builtin_constant_p(__mask) && __mask < 0x20) {		\
		asm volatile("csrsi " #regname ", %0" :: "i"(__mask) :	\
		    "memory");						\
	} else {							\
		asm volatile("csrs " #regname ", %0" :: "r"(__mask) :	\
		    "memory");						\
	}								\
}

#define	RISCVREG_CLEAR_INLINE(regname)					\
static inline void							\
csr_##regname##_clear(uintptr_t __mask)					\
{									\
	if (__builtin_constant_p(__mask) && __mask < 0x20) {		\
		asm volatile("csrci " #regname ", %0" :: "i"(__mask) :	\
		    "memory");						\
	} else {							\
		asm volatile("csrc " #regname ", %0" :: "r"(__mask) :	\
		    "memory");						\
	}								\
}

#define	RISCVREG_READ_WRITE_INLINE(regname)				\
RISCVREG_READ_INLINE(regname)						\
RISCVREG_WRITE_INLINE(regname)
#define	RISCVREG_SET_CLEAR_INLINE(regname)				\
RISCVREG_SET_INLINE(regname)						\
RISCVREG_CLEAR_INLINE(regname)
#define	RISCVREG_READ_SET_CLEAR_INLINE(regname)				\
RISCVREG_READ_INLINE(regname)						\
RISCVREG_SET_CLEAR_INLINE(regname)
#define	RISCVREG_READ_WRITE_SET_CLEAR_INLINE(regname)			\
RISCVREG_READ_WRITE_INLINE(regname)					\
RISCVREG_SET_CLEAR_INLINE(regname)

/* Supervisor Status Register */
RISCVREG_READ_SET_CLEAR_INLINE(sstatus)		// supervisor status register
#ifdef _LP64
#define	SR_WPRI		__BITS(62, 34) | __BITS(31, 20) | \
			__BIT(17) | __BITS(12, 11) | __BIT(7) | __BITS(4, 2) | \
			__BIT(0)
#define	SR_SD		__BIT(63)	// any of FS or VS or XS dirty
			/* Bits 62-34 are WPRI */
#define	SR_UXL		__BITS(33, 32)	// U-mode XLEN
#define	 SR_UXL_32	1		//   XLEN ==  32
#define	 SR_UXL_64	2		//   XLEN ==  64
#define	 SR_UXL_128	3		//   XLEN == 128
			/* Bits 31-20 are WPRI*/
#else
#define	SR_WPRI		__BITS(30, 20) | \
			__BIT(17) | __BITS(12, 11) | __BIT(7) | __BITS(4, 2) | \
			__BIT(0)
#define	SR_SD		__BIT(31)	// any of FS or VS or XS dirty
			/* Bits 30-20 are WPRI*/
#endif /* _LP64 */

/* Both RV32 and RV64 have the bottom 20 bits shared */
#define	SR_MXR		__BIT(19)	// Make eXecutable Readable
#define	SR_SUM		__BIT(18)	// permit Supervisor User Memory access
			/* Bit 17 is WPRI */
#define	SR_XS		__BITS(16, 15)	// Vector extension state
#define	 SR_XS_OFF		0	//   All off
#define	 SR_XS_SOME_ON		1	//   None dirty or clean, some on
#define	 SR_XS_SOME_CLEAN	2	//   None dirty, some clean
#define	 SR_XS_SOME_DIRTY	3	//   Some dirty
#define	SR_FS		__BITS(14, 13)	// Floating-point unit state
#define	 SR_FS_OFF	0		//   Off
#define	 SR_FS_INITIAL	1		//   Initial
#define	 SR_FS_CLEAN	2		//   Clean
#define	 SR_FS_DIRTY	3		//   Dirty
			/* Bits 12-11 are WPRI */
#define	SR_VS		__BITS(10, 9)	// User-mode extention state
#define	 SR_VS_OFF	SR_FS_OFF	//   Off
#define	 SR_VS_INITIAL	SR_FS_INITIAL	//   Initial
#define	 SR_VS_CLEAN	SR_FS_CLEAN	//   Clean
#define	 SR_VS_DIRTY	SR_FS_DIRTY	//   Dirty
#define	SR_SPP		__BIT(8)	// Priv level before supervisor mode
			/* Bit 7 is WPRI */
#define	SR_UBE		__BIT(6)	// User-mode endianness
#define	SR_SPIE		__BIT(5)	// S-Mode interrupts enabled before trap
			/* Bits 4-2 are WPRI */
#define	SR_SIE		__BIT(1)	// Supervisor mode interrupt enable
			/* Bit 0 is WPRI */

/* Supervisor interrupt registers */
/* ... interrupt pending register (sip) */
RISCVREG_READ_SET_CLEAR_INLINE(sip)		// supervisor interrupt pending
			/* Bit (XLEN-1) - 10 is WIRI */
#define	SIP_SEIP	__BIT(9)	// S-mode interrupt pending
			/* Bit 8-6 is WIRI */
#define	SIP_STIP	__BIT(5)	// S-mode timer interrupt pending
			/* Bit 4-2 is WIRI */
#define	SIP_SSIP	__BIT(1)	// S-mode software interrupt pending
			/* Bit 0 is WIRI */

/* ... interrupt-enable register (sie) */
RISCVREG_READ_SET_CLEAR_INLINE(sie)		// supervisor interrupt enable
			/* Bit (XLEN-1) - 10 is WIRI */
#define	SIE_SEIE	__BIT(9)	// S-mode interrupt enable
			/* Bit 8-6 is WIRI */
#define	SIE_STIE	__BIT(5)	// S-mode timer interrupt enable
			/* Bit 4-2 is WIRI */
#define	SIE_SSIE	__BIT(1)	// S-mode software interrupt enable
			/* Bit 0 is WIRI */

/* Mask for all interrupts */
#define	SIE_IM		(SIE_SEI |SIE_STIE | SIE_SSIE)

#ifdef _LP64
#define	SR_USER64	(SR_SPIE | SR_UXL_64)	// 64-bit U-mode sstatus
#define	SR_USER32	(SR_SPIE | SR_UXL_32)	// 32-bit U-mode sstatus
#else
#define	SR_USER		(SR_SPIE)		// U-mode sstatus
#endif

// Cause register
#define	CAUSE_INTERRUPT_P(cause)	((cause) & __BIT(XLEN - 1))
#define	CAUSE_CODE(cause)		((cause) & __BITS(XLEN - 2, 0))

// Cause register - exceptions
#define	CAUSE_FETCH_MISALIGNED		0
#define	CAUSE_FETCH_ACCESS		1
#define	CAUSE_ILLEGAL_INSTRUCTION	2
#define	CAUSE_BREAKPOINT		3
#define	CAUSE_LOAD_MISALIGNED		4
#define	CAUSE_LOAD_ACCESS		5
#define	CAUSE_STORE_MISALIGNED		6
#define	CAUSE_STORE_ACCESS		7
#define	CAUSE_USER_ECALL		8
#define	CAUSE_SYSCALL			CAUSE_USER_ECALL /* convenience alias */
#define	CAUSE_SUPERVISOR_ECALL		9
/* 10 is reserved */
#define	CAUSE_MACHINE_ECALL		11
#define	CAUSE_FETCH_PAGE_FAULT		12
#define	CAUSE_LOAD_PAGE_FAULT		13
/* 14 is Reserved */
#define	CAUSE_STORE_PAGE_FAULT		15
/* >= 16 is reserved/custom */

// Cause register - interrupts
#define	IRQ_SUPERVISOR_SOFTWARE	1
#define	IRQ_MACHINE_SOFTWARE	3
#define	IRQ_SUPERVISOR_TIMER	5
#define	IRQ_MACHINE_TIMER	7
#define	IRQ_SUPERVISOR_EXTERNAL	9
#define	IRQ_MACHINE_EXTERNAL	11

RISCVREG_READ_INLINE(time)
#ifdef _LP64
RISCVREG_READ_INLINE(cycle)
#else /* !_LP64 */
static inline uint64_t
csr_cycle_read(void)
{
	uint32_t __hi0, __hi1, __lo0;
	do {
		__asm __volatile(
			"csrr\t%[__hi0], cycleh"
		"\n\t"	"csrr\t%[__lo0], cycle"
		"\n\t"	"csrr\t%[__hi1], cycleh"
		   :	[__hi0] "=r"(__hi0),
			[__lo0] "=r"(__lo0),
			[__hi1] "=r"(__hi1));
	} while (__hi0 != __hi1);
	return
	    __SHIFTIN(__hi0, __BITS(63, 32)) |
	    __SHIFTIN(__lo0, __BITS(31,  0));
}
#endif /* !_LP64 */

#ifdef _LP64
#define	SATP_MODE		__BITS(63, 60)	// Translation mode
#define	 SATP_MODE_BARE		0		//   No translation or protection
				/* modes 1-7 reserved for standard use */
#define	 SATP_MODE_SV39		8		//   Page-based 39-bit virt addr
#define	 SATP_MODE_SV48		9		//   Page-based 48-bit virt addr
#define	 SATP_MODE_SV57		10		//   Page-based 57-bit virt addr
#define	 SATP_MODE_SV64		11		//   Page-based 64-bit virt addr
				/* modes 12-13 reserved for standard use */
				/* modes 14-15 designated for custom use */
#define	SATP_ASID		__BITS(59, 44)	//   Address Space Identifier
#define	SATP_PPN		__BITS(43, 0)	//   Physical Page Number
#else
#define	SATP_MODE		__BIT(31)	// Translation mode
#define	 SATP_MODE_BARE		0		//   No translation or protection
#define	 SATP_MODE_SV32		1		//   Page-based 32-bit virt addr
#define	SATP_ASID		__BITS(30, 22)	//   Address Space Identifier
#define	SATP_PPN		__BITS(21, 0)	//   Physical Page Number
#endif

RISCVREG_READ_WRITE_INLINE(satp)

/* Fake "ASID" CSR (a field of SATP register) functions */
static inline uint32_t
csr_asid_read(void)
{
	uintptr_t satp = csr_satp_read();
	return __SHIFTOUT(satp, SATP_ASID);
}

static inline void
csr_asid_write(uint32_t asid)
{
	uintptr_t satp = csr_satp_read();
	satp &= ~SATP_ASID;
	satp |= __SHIFTIN(asid, SATP_ASID);
	csr_satp_write(satp);
}

#endif /* _RISCV_SYSREG_H_ */