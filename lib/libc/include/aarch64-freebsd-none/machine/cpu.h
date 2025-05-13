/*-
 * Copyright (c) 1990 The Regents of the University of California.
 * Copyright (c) 2014-2016 The FreeBSD Foundation
 * All rights reserved.
 *
 * This code is derived from software contributed to Berkeley by
 * William Jolitz.
 *
 * Portions of this software were developed by Andrew Turner
 * under sponsorship from the FreeBSD Foundation
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. Neither the name of the University nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 *
 *	from: @(#)cpu.h 5.4 (Berkeley) 5/9/91
 *	from: FreeBSD: src/sys/i386/include/cpu.h,v 1.62 2001/06/29
 */

#ifdef __arm__
#include <arm/cpu.h>
#else /* !__arm__ */

#ifndef _MACHINE_CPU_H_
#define	_MACHINE_CPU_H_

#if !defined(__ASSEMBLER__)
#include <machine/atomic.h>
#include <machine/frame.h>
#endif
#include <machine/armreg.h>

#define	TRAPF_PC(tfp)		((tfp)->tf_elr)
#define	TRAPF_USERMODE(tfp)	(((tfp)->tf_spsr & PSR_M_MASK) == PSR_M_EL0t)

#define	cpu_getstack(td)	((td)->td_frame->tf_sp)
#define	cpu_setstack(td, sp)	((td)->td_frame->tf_sp = (sp))
#define	cpu_spinwait()		__asm __volatile("yield" ::: "memory")
#define	cpu_lock_delay()	DELAY(1)

/* Extract CPU affinity levels 0-3 */
#define	CPU_AFF0(mpidr)	(u_int)(((mpidr) >> 0) & 0xff)
#define	CPU_AFF1(mpidr)	(u_int)(((mpidr) >> 8) & 0xff)
#define	CPU_AFF2(mpidr)	(u_int)(((mpidr) >> 16) & 0xff)
#define	CPU_AFF3(mpidr)	(u_int)(((mpidr) >> 32) & 0xff)
#define	CPU_AFF0_MASK	0xffUL
#define	CPU_AFF1_MASK	0xff00UL
#define	CPU_AFF2_MASK	0xff0000UL
#define	CPU_AFF3_MASK	0xff00000000UL
#define	CPU_AFF_MASK	(CPU_AFF0_MASK | CPU_AFF1_MASK | \
    CPU_AFF2_MASK| CPU_AFF3_MASK)	/* Mask affinity fields in MPIDR_EL1 */

#ifdef _KERNEL

#define	CPU_IMPL_ARM		0x41
#define	CPU_IMPL_BROADCOM	0x42
#define	CPU_IMPL_CAVIUM		0x43
#define	CPU_IMPL_DEC		0x44
#define	CPU_IMPL_FUJITSU	0x46
#define	CPU_IMPL_INFINEON	0x49
#define	CPU_IMPL_FREESCALE	0x4D
#define	CPU_IMPL_NVIDIA		0x4E
#define	CPU_IMPL_APM		0x50
#define	CPU_IMPL_QUALCOMM	0x51
#define	CPU_IMPL_MARVELL	0x56
#define	CPU_IMPL_APPLE		0x61
#define	CPU_IMPL_INTEL		0x69
#define	CPU_IMPL_AMPERE		0xC0

/* ARM Part numbers */
#define	CPU_PART_FOUNDATION	0xD00
#define	CPU_PART_CORTEX_A34	0xD02
#define	CPU_PART_CORTEX_A53	0xD03
#define	CPU_PART_CORTEX_A35	0xD04
#define	CPU_PART_CORTEX_A55	0xD05
#define	CPU_PART_CORTEX_A65	0xD06
#define	CPU_PART_CORTEX_A57	0xD07
#define	CPU_PART_CORTEX_A72	0xD08
#define	CPU_PART_CORTEX_A73	0xD09
#define	CPU_PART_CORTEX_A75	0xD0A
#define	CPU_PART_CORTEX_A76	0xD0B
#define	CPU_PART_NEOVERSE_N1	0xD0C
#define	CPU_PART_CORTEX_A77	0xD0D
#define	CPU_PART_CORTEX_A76AE	0xD0E
#define	CPU_PART_AEM_V8		0xD0F
#define	CPU_PART_NEOVERSE_V1	0xD40
#define	CPU_PART_CORTEX_A78	0xD41
#define	CPU_PART_CORTEX_A65AE	0xD43
#define	CPU_PART_CORTEX_X1	0xD44
#define	CPU_PART_CORTEX_A510	0xD46
#define	CPU_PART_CORTEX_A710	0xD47
#define	CPU_PART_CORTEX_X2	0xD48
#define	CPU_PART_NEOVERSE_N2	0xD49
#define	CPU_PART_NEOVERSE_E1	0xD4A
#define	CPU_PART_CORTEX_A78C	0xD4B
#define	CPU_PART_CORTEX_X1C	0xD4C
#define	CPU_PART_CORTEX_A715	0xD4D
#define	CPU_PART_CORTEX_X3	0xD4E
#define	CPU_PART_NEOVERSE_V2	0xD4F

/* Cavium Part numbers */
#define	CPU_PART_THUNDERX	0x0A1
#define	CPU_PART_THUNDERX_81XX	0x0A2
#define	CPU_PART_THUNDERX_83XX	0x0A3
#define	CPU_PART_THUNDERX2	0x0AF

#define	CPU_REV_THUNDERX_1_0	0x00
#define	CPU_REV_THUNDERX_1_1	0x01

#define	CPU_REV_THUNDERX2_0	0x00

/* APM / Ampere Part Number */
#define CPU_PART_EMAG8180	0x000

/* Qualcomm */
#define	CPU_PART_KRYO400_GOLD	0x804
#define	CPU_PART_KRYO400_SILVER	0x805

/* Apple part numbers */
#define CPU_PART_M1_ICESTORM      0x022
#define CPU_PART_M1_FIRESTORM     0x023
#define CPU_PART_M1_ICESTORM_PRO  0x024
#define CPU_PART_M1_FIRESTORM_PRO 0x025
#define CPU_PART_M1_ICESTORM_MAX  0x028
#define CPU_PART_M1_FIRESTORM_MAX 0x029
#define CPU_PART_M2_BLIZZARD      0x032
#define CPU_PART_M2_AVALANCHE     0x033
#define CPU_PART_M2_BLIZZARD_PRO  0x034
#define CPU_PART_M2_AVALANCHE_PRO 0x035
#define CPU_PART_M2_BLIZZARD_MAX  0x038
#define CPU_PART_M2_AVALANCHE_MAX 0x039

#define	CPU_IMPL(midr)	(((midr) >> 24) & 0xff)
#define	CPU_PART(midr)	(((midr) >> 4) & 0xfff)
#define	CPU_VAR(midr)	(((midr) >> 20) & 0xf)
#define	CPU_ARCH(midr)	(((midr) >> 16) & 0xf)
#define	CPU_REV(midr)	(((midr) >> 0) & 0xf)

#define	CPU_IMPL_TO_MIDR(val)	(((val) & 0xff) << 24)
#define	CPU_PART_TO_MIDR(val)	(((val) & 0xfff) << 4)
#define	CPU_VAR_TO_MIDR(val)	(((val) & 0xf) << 20)
#define	CPU_ARCH_TO_MIDR(val)	(((val) & 0xf) << 16)
#define	CPU_REV_TO_MIDR(val)	(((val) & 0xf) << 0)

#define	CPU_IMPL_MASK	(0xff << 24)
#define	CPU_PART_MASK	(0xfff << 4)
#define	CPU_VAR_MASK	(0xf << 20)
#define	CPU_ARCH_MASK	(0xf << 16)
#define	CPU_REV_MASK	(0xf << 0)

#define	CPU_ID_RAW(impl, part, var, rev)		\
    (CPU_IMPL_TO_MIDR((impl)) |				\
    CPU_PART_TO_MIDR((part)) | CPU_VAR_TO_MIDR((var)) |	\
    CPU_REV_TO_MIDR((rev)))

#define	CPU_MATCH(mask, impl, part, var, rev)		\
    (((mask) & PCPU_GET(midr)) ==			\
    ((mask) & CPU_ID_RAW((impl), (part), (var), (rev))))

#define	CPU_MATCH_RAW(mask, devid)			\
    (((mask) & PCPU_GET(midr)) == ((mask) & (devid)))

/*
 * Chip-specific errata. This defines are intended to be
 * booleans used within if statements. When an appropriate
 * kernel option is disabled, these defines must be defined
 * as 0 to allow the compiler to remove a dead code thus
 * produce better optimized kernel image.
 */
/*
 * Vendor:	Cavium
 * Chip:	ThunderX
 * Revision(s):	Pass 1.0, Pass 1.1
 */
#ifdef THUNDERX_PASS_1_1_ERRATA
#define	CPU_MATCH_ERRATA_CAVIUM_THUNDERX_1_1				\
    (CPU_MATCH(CPU_IMPL_MASK | CPU_PART_MASK | CPU_REV_MASK,		\
    CPU_IMPL_CAVIUM, CPU_PART_THUNDERX, 0, CPU_REV_THUNDERX_1_0) ||	\
    CPU_MATCH(CPU_IMPL_MASK | CPU_PART_MASK | CPU_REV_MASK,		\
    CPU_IMPL_CAVIUM, CPU_PART_THUNDERX, 0, CPU_REV_THUNDERX_1_1))
#else
#define	CPU_MATCH_ERRATA_CAVIUM_THUNDERX_1_1	0
#endif

#if !defined(__ASSEMBLER__)
extern char btext[];
extern char etext[];

extern uint64_t __cpu_affinity[];

struct arm64_addr_mask;
extern struct arm64_addr_mask elf64_addr_mask;

void	cpu_halt(void) __dead2;
void	cpu_reset(void) __dead2;
void	fork_trampoline(void);
void	identify_cache(uint64_t);
void	identify_cpu(u_int);
void	install_cpu_errata(void);

/* Pointer Authentication Code (PAC) support */
void	ptrauth_init(void);
void	ptrauth_fork(struct thread *, struct thread *);
void	ptrauth_exec(struct thread *);
void	ptrauth_copy_thread(struct thread *, struct thread *);
void	ptrauth_thread_alloc(struct thread *);
void	ptrauth_thread0(struct thread *);
#ifdef SMP
void	ptrauth_mp_start(uint64_t);
#endif

/* Functions to read the sanitised view of the special registers */
void	update_special_regs(u_int);
bool	extract_user_id_field(u_int, u_int, uint8_t *);
bool	get_kernel_reg(u_int, uint64_t *);
bool	get_kernel_reg_masked(u_int, uint64_t *, uint64_t);

void	cpu_desc_init(void);

#define	CPU_AFFINITY(cpu)	__cpu_affinity[(cpu)]
#define	CPU_CURRENT_SOCKET				\
    (CPU_AFF2(CPU_AFFINITY(PCPU_GET(cpuid))))

static __inline uint64_t
get_cyclecount(void)
{
	uint64_t ret;

	ret = READ_SPECIALREG(cntvct_el0);

	return (ret);
}

#define	ADDRESS_TRANSLATE_FUNC(stage)				\
static inline uint64_t						\
arm64_address_translate_ ##stage (uint64_t addr)		\
{								\
	uint64_t ret;						\
								\
	__asm __volatile(					\
	    "at " __STRING(stage) ", %1 \n"			\
	    "isb \n"						\
	    "mrs %0, par_el1" : "=r"(ret) : "r"(addr));		\
								\
	return (ret);						\
}

ADDRESS_TRANSLATE_FUNC(s1e0r)
ADDRESS_TRANSLATE_FUNC(s1e0w)
ADDRESS_TRANSLATE_FUNC(s1e1r)
ADDRESS_TRANSLATE_FUNC(s1e1w)

#endif /* !__ASSEMBLER__ */
#endif

#endif /* !_MACHINE_CPU_H_ */

#endif /* !__arm__ */