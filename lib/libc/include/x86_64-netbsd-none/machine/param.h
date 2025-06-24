/*	$NetBSD: param.h,v 1.38 2020/06/29 09:56:51 jdolecek Exp $	*/

#ifdef __x86_64__

#ifndef XENPV
/* Must be defined before cpu.h */
#define	MAXCPUS		256
#endif

#ifdef _KERNEL
#include <machine/cpu.h>
#if defined(_KERNEL_OPT)
#include "opt_kasan.h"
#include "opt_kmsan.h"
#include "opt_svs.h"
#endif
#endif

#define	_MACHINE	amd64
#define	MACHINE		"amd64"
#define	_MACHINE_ARCH	x86_64
#define	MACHINE_ARCH	"x86_64"
#define MID_MACHINE	MID_X86_64

#define ALIGNED_POINTER(p,t)		1
#define ALIGNED_POINTER_LOAD(q,p,t)	memcpy((q), (p), sizeof(t))

/*
 * Align stack as required by AMD64 System V ABI. This is because
 * (1) we want to bypass libc/csu in LLDB, and
 * (2) rtld in glibc >= 2.23 for Linux/x86_64 requires it.
 */
#define STACK_ALIGNBYTES	(16 - 1)

#define ALIGNBYTES32		(sizeof(int) - 1)
#define ALIGN32(p)		(((u_long)(p) + ALIGNBYTES32) &~ALIGNBYTES32)

#define	PGSHIFT		12		/* LOG2(NBPG) */
#define	NBPG		(1 << PGSHIFT)	/* bytes/page */
#define	PGOFSET		(NBPG-1)	/* byte offset into page */
#define	NPTEPG		(NBPG/(sizeof (pt_entry_t)))

#define	MAXIOMEM	0xffffffffffff

/*
 * Maximum physical memory supported by the implementation.
 */
#if defined(KMSAN)
#define MAXPHYSMEM	0x008000000000ULL /* 512GB */
#else
#define MAXPHYSMEM	0x100000000000ULL /* 16TB */
#endif

/*
 * XXXfvdl change this (after bootstrap) to take # of bits from
 * config info into account.
 */
#define	KERNBASE	0xffffffff80000000 /* start of kernel virtual space */
#define	KERNTEXTOFF	0xffffffff80200000 /* start of kernel text */
#define	BTOPKERNBASE	((u_long)KERNBASE >> PGSHIFT)

#define KERNTEXTOFF_HI	0xffffffff
#define KERNTEXTOFF_LO	0x80200000

#define KERNBASE_HI	0xffffffff
#define KERNBASE_LO	0x80000000

#define	SSIZE		1		/* initial stack size/NBPG */
#define	SINCR		1		/* increment of stack/NBPG */

#if defined(KASAN) || defined(KMSAN)
#define	UPAGES		8
#elif defined(SVS)
#define	UPAGES		6		/* 1 page used internally by SVS */
#else
#define	UPAGES		5		/* pages of u-area (1 for redzone) */
#endif
#define	USPACE		(UPAGES * NBPG)	/* total size of u-area */

#ifndef MSGBUFSIZE
#define MSGBUFSIZE	(16*NBPG)	/* default message buffer size */
#endif

/*
 * Constants related to network buffer management.
 * MCLBYTES must be no larger than NBPG (the software page size), and,
 * on machines that exchange pages of input or output buffers with mbuf
 * clusters (MAPPED_MBUFS), MCLBYTES must also be an integral multiple
 * of the hardware page size.
 */
#define	MSIZE		512		/* size of an mbuf */

#ifndef MCLSHIFT
#define	MCLSHIFT	11		/* convert bytes to m_buf clusters */
					/* 2K cluster can hold Ether frame */
#endif	/* MCLSHIFT */

#define	MCLBYTES	(1 << MCLSHIFT)	/* size of a m_buf cluster */

#ifndef NFS_RSIZE
#define NFS_RSIZE       32768
#endif
#ifndef NFS_WSIZE
#define NFS_WSIZE       32768
#endif

/*
 * Minimum size of the kernel kmem_arena in PAGE_SIZE-sized
 * logical pages.
 * No enforced maximum on amd64.
 */
#define	NKMEMPAGES_MIN_DEFAULT	((8 * 1024 * 1024) >> PAGE_SHIFT)
#define	NKMEMPAGES_MAX_UNLIMITED 1

/*
 * XXXfvdl the PD* stuff is different from i386.
 */
/*
 * Mach derived conversion macros
 */
#define	x86_round_pdr(x) \
	((((unsigned long)(x)) + (NBPD_L2 - 1)) & ~(NBPD_L2 - 1))
#define	x86_trunc_pdr(x)	((unsigned long)(x) & ~(NBPD_L2 - 1))
#define	x86_btod(x)		((unsigned long)(x) >> L2_SHIFT)
#define	x86_dtob(x)		((unsigned long)(x) << L2_SHIFT)
#define	x86_round_page(x)	((((unsigned long)(x)) + PGOFSET) & ~PGOFSET)
#define	x86_trunc_page(x)	((unsigned long)(x) & ~PGOFSET)
#define	x86_btop(x)		((unsigned long)(x) >> PGSHIFT)
#define	x86_ptob(x)		((unsigned long)(x) << PGSHIFT)

#define btop(x)				x86_btop(x)
#define ptob(x)				x86_ptob(x)

#else	/*	__x86_64__	*/

#include <i386/param.h>

#endif	/*	__x86_64__	*/