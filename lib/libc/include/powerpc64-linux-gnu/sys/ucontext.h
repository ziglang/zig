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


#ifdef __USE_MISC
# define __ctx(fld) fld
#else
# define __ctx(fld) __ ## fld
#endif

struct __ctx(pt_regs);

#if __WORDSIZE == 32

/* Number of general registers.  */
# define __NGREG	48
# ifdef __USE_MISC
#  define NGREG	__NGREG
# endif

/* Container for all general registers.  */
typedef unsigned long gregset_t[__NGREG];

/* Container for floating-point registers and status */
typedef struct _libc_fpstate
{
	double __ctx(fpregs)[32];
	double __ctx(fpscr);
	unsigned int _pad[2];
} fpregset_t;

/* Container for Altivec/VMX registers and status.
   Needs to be aligned on a 16-byte boundary. */
typedef struct _libc_vrstate
{
	unsigned int __ctx(vrregs)[32][4];
	unsigned int __ctx(vrsave);
	unsigned int _pad[2];
	unsigned int __ctx(vscr);
} vrregset_t;

/* Context to describe whole processor state.  */
typedef struct
{
	gregset_t __ctx(gregs);
	fpregset_t __ctx(fpregs);
	vrregset_t __ctx(vrregs) __attribute__((__aligned__(16)));
} mcontext_t;

#else

/* For 64-bit kernels with Altivec support, a machine context is exactly
 * a sigcontext.  For older kernel (without Altivec) the sigcontext matches
 * the mcontext upto but not including the v_regs field.  For kernels that
 * don't set AT_HWCAP or return AT_HWCAP without PPC_FEATURE_HAS_ALTIVEC the
 * v_regs field may not exist and should not be referenced.  The v_regs field
 * can be referenced safely only after verifying that PPC_FEATURE_HAS_ALTIVEC
 * is set in AT_HWCAP.  */

/* Number of general registers.  */
# define __NGREG	48	/* includes r0-r31, nip, msr, lr, etc.  */
# define __NFPREG	33	/* includes fp0-fp31 &fpscr.  */
# define __NVRREG	34	/* includes v0-v31, vscr, & vrsave in
				   split vectors */
# ifdef __USE_MISC
#  define NGREG	__NGREG
#  define NFPREG	__NFPREG
#  define NVRREG	__NVRREG
# endif

typedef unsigned long gregset_t[__NGREG];
typedef double fpregset_t[__NFPREG];

/* Container for Altivec/VMX Vector Status and Control Register.  Only 32-bits
   but can only be copied to/from a 128-bit vector register.  So we allocated
   a whole quadword speedup save/restore.  */
typedef struct _libc_vscr
{
#if __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
	unsigned int __pad[3];
	unsigned int __ctx(vscr_word);
#else
	unsigned int __ctx(vscr_word);
	unsigned int __pad[3];
#endif
} vscr_t;

/* Container for Altivec/VMX registers and status.
   Must to be aligned on a 16-byte boundary. */
typedef struct _libc_vrstate
{
	unsigned int	__ctx(vrregs)[32][4];
	vscr_t		__ctx(vscr);
	unsigned int	__ctx(vrsave);
	unsigned int	__pad[3];
} vrregset_t  __attribute__((__aligned__(16)));

typedef struct {
	unsigned long	__glibc_reserved[4];
	int		__ctx(signal);
	int		__pad0;
	unsigned long	__ctx(handler);
	unsigned long	__ctx(oldmask);
	struct __ctx(pt_regs)	*__ctx(regs);
	gregset_t	__ctx(gp_regs);
	fpregset_t	__ctx(fp_regs);
/*
 * To maintain compatibility with current implementations the sigcontext is
 * extended by appending a pointer (v_regs) to a quadword type (elf_vrreg_t)
 * followed by an unstructured (vmx_reserve) field of 69 doublewords.  This
 * allows the array of vector registers to be quadword aligned independent of
 * the alignment of the containing sigcontext or ucontext. It is the
 * responsibility of the code setting the sigcontext to set this pointer to
 * either NULL (if this processor does not support the VMX feature) or the
 * address of the first quadword within the allocated (vmx_reserve) area.
 *
 * The pointer (v_regs) of vector type (elf_vrreg_t) is essentially
 * an array of 34 quadword entries.  The entries with
 * indexes 0-31 contain the corresponding vector registers.  The entry with
 * index 32 contains the vscr as the last word (offset 12) within the
 * quadword.  This allows the vscr to be stored as either a quadword (since
 * it must be copied via a vector register to/from storage) or as a word.
 * The entry with index 33 contains the vrsave as the first word (offset 0)
 * within the quadword.
 */
	vrregset_t	*__ctx(v_regs);
	long		__ctx(vmx_reserve)[__NVRREG+__NVRREG+1];
} mcontext_t;

#endif

/* Userlevel context.  */
typedef struct ucontext_t
  {
    unsigned long int __ctx(uc_flags);
    struct ucontext_t *uc_link;
    stack_t uc_stack;
#if __WORDSIZE == 32
    /*
     * These fields are set up this way to maximize source and
     * binary compatibility with code written for the old
     * ucontext_t definition, which didn't include space for the
     * registers.
     *
     * Different versions of the kernel have stored the registers on
     * signal delivery at different offsets from the ucontext struct.
     * Programs should thus use the uc_mcontext.uc_regs pointer to
     * find where the registers are actually stored.  The registers
     * will be stored within the ucontext_t struct but not necessarily
     * at a fixed address.  As a side-effect, this lets us achieve
     * 16-byte alignment for the register storage space if the
     * Altivec registers are to be saved, without requiring 16-byte
     * alignment on the whole ucontext_t.
     *
     * The uc_mcontext.regs field is included for source compatibility
     * with programs written against the older ucontext_t definition,
     * and its name should therefore not change.  The uc_pad field
     * is for binary compatibility with programs compiled against the
     * old ucontext_t; it ensures that uc_mcontext.regs and uc_sigmask
     * are at the same offset as previously.
     */
    int __glibc_reserved1[7];
    union __ctx(uc_regs_ptr) {
      struct __ctx(pt_regs) *__ctx(regs);
      mcontext_t *__ctx(uc_regs);
    } uc_mcontext;
    sigset_t    uc_sigmask;
    /* last for extensibility */
    char __ctx(uc_reg_space)[sizeof (mcontext_t) + 12];
#else /* 64-bit */
    sigset_t    uc_sigmask;
    mcontext_t  uc_mcontext;  /* last for extensibility */
#endif
  } ucontext_t;

#undef __ctx

#endif /* sys/ucontext.h */