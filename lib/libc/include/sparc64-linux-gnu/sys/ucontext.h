/* Copyright (C) 1998-2025 Free Software Foundation, Inc.
   This file is part of the GNU C Library.

   The GNU C Library is free software; you can redistribute it and/or
   modify it under the terms of the GNU Lesser General Public
   License as published by the Free Software Foundation; either
   version 2.1 of the License, or (at your option) any later version.

   The GNU C Library is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Lesser General Public License for more details.

   You should have received a copy of the GNU Lesser General Public
   License along with the GNU C Library; if not, see
   <https://www.gnu.org/licenses/>.  */

#ifndef _SYS_UCONTEXT_H
#define _SYS_UCONTEXT_H	1

#include <features.h>

#include <bits/types/sigset_t.h>
#include <bits/types/stack_t.h>

#include <bits/wordsize.h>


#ifdef __USE_MISC
# define __ctx(fld) fld
#else
# define __ctx(fld) __ ## fld
#endif

#if __WORDSIZE == 64

#define __MC_NGREG	19
#ifdef __USE_MISC
# define MC_TSTATE	0
# define MC_PC		1
# define MC_NPC		2
# define MC_Y		3
# define MC_G1		4
# define MC_G2		5
# define MC_G3		6
# define MC_G4		7
# define MC_G5		8
# define MC_G6		9
# define MC_G7		10
# define MC_O0		11
# define MC_O1		12
# define MC_O2		13
# define MC_O3		14
# define MC_O4		15
# define MC_O5		16
# define MC_O6		17
# define MC_O7		18
# define MC_NGREG	__MC_NGREG
#endif

typedef unsigned long mc_greg_t;
typedef mc_greg_t mc_gregset_t[__MC_NGREG];

#ifdef __USE_MISC
# define MC_MAXFPQ	16
#endif
struct __mc_fq {
	unsigned long	*__ctx(mcfq_addr);
	unsigned int	__ctx(mcfq_insn);
};

typedef struct {
	union {
		unsigned int	__ctx(sregs)[32];
		unsigned long	__ctx(dregs)[32];
		long double	__ctx(qregs)[16];
	} __ctx(mcfpu_fregs);
	unsigned long	__ctx(mcfpu_fsr);
	unsigned long	__ctx(mcfpu_fprs);
	unsigned long	__ctx(mcfpu_gsr);
	struct __mc_fq	*__ctx(mcfpu_fq);
	unsigned char	__ctx(mcfpu_qcnt);
	unsigned char	__ctx(mcfpu_qentsz);
	unsigned char	__ctx(mcfpu_enab);
} mc_fpu_t;

typedef struct {
	mc_gregset_t	__ctx(mc_gregs);
	mc_greg_t	__ctx(mc_fp);
	mc_greg_t	__ctx(mc_i7);
	mc_fpu_t	__ctx(mc_fpregs);
} mcontext_t;

typedef struct ucontext_t {
	struct ucontext_t	*uc_link;
	unsigned long		__ctx(uc_flags);
	unsigned long		__uc_sigmask;
	mcontext_t		uc_mcontext;
	stack_t			uc_stack;
	sigset_t		uc_sigmask;
} ucontext_t;

#endif /* __WORDISIZE == 64 */

/*
 * Location of the users' stored registers relative to R0.
 * Usage is as an index into a gregset_t array or as u.u_ar0[XX].
 */
#ifdef __USE_MISC
# define REG_PSR (0)
# define REG_PC  (1)
# define REG_nPC (2)
# define REG_Y   (3)
# define REG_G1  (4)
# define REG_G2  (5)
# define REG_G3  (6)
# define REG_G4  (7)
# define REG_G5  (8)
# define REG_G6  (9)
# define REG_G7  (10)
# define REG_O0  (11)
# define REG_O1  (12)
# define REG_O2  (13)
# define REG_O3  (14)
# define REG_O4  (15)
# define REG_O5  (16)
# define REG_O6  (17)
# define REG_O7  (18)
#endif

/*
 * A gregset_t is defined as an array type for compatibility with the reference
 * source. This is important due to differences in the way the C language
 * treats arrays and structures as parameters.
 *
 * Note that NGREG is really (sizeof (struct regs) / sizeof (greg_t)),
 * but that the ABI defines it absolutely to be 21 (resp. 19).
 */

#if __WORDSIZE == 64

# define __NGREG   21
# ifdef __USE_MISC
#  define REG_ASI	(19)
#  define REG_FPRS (20)

#  define NGREG   __NGREG
# endif
typedef long greg_t;

#else /* __WORDSIZE == 32 */

# define __NGREG   19
# ifdef __USE_MISC
#  define NGREG   __NGREG
# endif
typedef int greg_t;

#endif /* __WORDSIZE == 32 */

typedef greg_t  gregset_t[__NGREG];

/*
 * The following structures define how a register window can appear on the
 * stack. This structure is available (when required) through the `gwins'
 * field of an mcontext (nested within ucontext). SPARC_MAXWINDOW is the
 * maximum number of outstanding registers window defined in the SPARC
 * architecture (*not* implementation).
 */
# define __SPARC_MAXREGWINDOW	31	/* max windows in SPARC arch. */
#ifdef __USE_MISC
# define SPARC_MAXREGWINDOW	__SPARC_MAXREGWINDOW
#endif
struct  __rwindow
  {
    greg_t __ctx(rw_local)[8];			/* locals */
    greg_t __ctx(rw_in)[8];			/* ins */
  };

#ifdef __USE_MISC
# define rw_fp   __ctx(rw_in)[6]		/* frame pointer */
# define rw_rtn  __ctx(rw_in)[7]		/* return address */
#endif

typedef struct
  {
    int            __ctx(wbcnt);
    int           *__ctx(spbuf)[__SPARC_MAXREGWINDOW];
    struct __rwindow __ctx(wbuf)[__SPARC_MAXREGWINDOW];
  } gwindows_t;

/*
 * Floating point definitions.
 */

#ifdef __USE_MISC
# define MAXFPQ	16	/* max # of fpu queue entries currently supported */
#endif

/*
 * struct fq defines the minimal format of a floating point instruction queue
 * entry. The size of entries in the floating point queue are implementation
 * dependent. The union FQu is guaranteed to be the first field in any ABI
 * conformant system implementation. Any additional fields provided by an
 * implementation should not be used applications designed to be ABI conformant. */

struct __fpq
  {
    unsigned long *__ctx(fpq_addr);		/* address */
    unsigned long __ctx(fpq_instr);		/* instruction */
  };

struct __fq
  {
    union				/* FPU inst/addr queue */
      {
        double __ctx(whole);
        struct __fpq __ctx(fpq);
      } __ctx(FQu);
  };

#ifdef __USE_MISC
# define FPU_REGS_TYPE           unsigned
# define FPU_DREGS_TYPE          unsigned long long
# define V7_FPU_FSR_TYPE         unsigned
# define V9_FPU_FSR_TYPE         unsigned long long
# define V9_FPU_FPRS_TYPE        unsigned
#endif

#if __WORDSIZE == 64

typedef struct
  {
    union {				/* FPU floating point regs */
      unsigned		__ctx(fpu_regs)[32];	/* 32 singles */
      double            __ctx(fpu_dregs)[32];	/* 32 doubles */
      long double	__ctx(fpu_qregs)[16];  /* 16 quads */
    } __ctx(fpu_fr);
    struct __fq     *__ctx(fpu_q);		/* ptr to array of FQ entries */
    unsigned long   __ctx(fpu_fsr);		/* FPU status register */
    unsigned char   __ctx(fpu_qcnt);		/* # of entries in saved FQ */
    unsigned char   __ctx(fpu_q_entrysize);	/* # of bytes per FQ entry */
    unsigned char   __ctx(fpu_en);		/* flag signifying fpu in use */
  } fpregset_t;

#else /* __WORDSIZE == 32 */

typedef struct
  {
    union {				/* FPU floating point regs */
      __extension__ unsigned long long __ctx(fpu_regs)[32];	/* 32 singles */
      double             __ctx(fpu_dregs)[16];	/* 16 doubles */
    } __ctx(fpu_fr);
    struct __fq     *__ctx(fpu_q);		/* ptr to array of FQ entries */
    unsigned        __ctx(fpu_fsr);		/* FPU status register */
    unsigned char   __ctx(fpu_qcnt);		/* # of entries in saved FQ */
    unsigned char   __ctx(fpu_q_entrysize);	/* # of bytes per FQ entry */
    unsigned char   __ctx(fpu_en);		/* flag signifying fpu in use */
  } fpregset_t;

/*
 * The following structure is for associating extra register state with
 * the ucontext structure and is kept within the uc_mcontext filler area.
 *
 * If (xrs_id == XRS_ID) then the xrs_ptr field is a valid pointer to
 * extra register state. The exact format of the extra register state
 * pointed to by xrs_ptr is platform-dependent.
 *
 * Note: a platform may or may not manage extra register state.
 */
typedef struct
  {
    unsigned int __ctx(xrs_id);		/* indicates xrs_ptr validity */
    void *       __ctx(xrs_ptr);		/* ptr to extra reg state */
  } xrs_t;

#ifdef __USE_MISC
# define XRS_ID	0x78727300		/* the string "xrs" */
#endif

typedef struct
  {
    gregset_t   __ctx(gregs);		/* general register set */
    gwindows_t  *__ctx(gwins);		/* POSSIBLE pointer to register
					   windows */
    fpregset_t  __ctx(fpregs);		/* floating point register set */
    xrs_t       __ctx(xrs);		/* POSSIBLE extra register state
					   association */
    long        __glibc_reserved1[19];
  } mcontext_t;


/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long   __ctx(uc_flags);
    struct ucontext_t *uc_link;
    sigset_t	    uc_sigmask;
    stack_t         uc_stack;
    mcontext_t      uc_mcontext;
  } ucontext_t;

#endif /* __WORDSIZE == 32 */
#endif /* sys/ucontext.h */