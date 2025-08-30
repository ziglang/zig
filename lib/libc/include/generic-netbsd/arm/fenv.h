/*	$NetBSD: fenv.h,v 1.6 2021/10/06 05:33:15 skrll Exp $	*/

/*
 * Based on ieeefp.h written by J.T. Conklin, Apr 28, 1995
 * Public domain.
 */

#ifndef _ARM_FENV_H_
#define _ARM_FENV_H_

#include <sys/cdefs.h>

#ifdef __ARM_PCS_AAPCS64
/* AArch64 split FPSCR into two registers FPCR and FPSR */
typedef struct {
	unsigned int __fpcr;
	unsigned int __fpsr;
} fenv_t;
#else
typedef int fenv_t;		/* FPSCR */
#endif
typedef int fexcept_t;

#define	FE_INVALID	0x01	/* invalid operation exception */
#define	FE_DIVBYZERO	0x02	/* divide-by-zero exception */
#define	FE_OVERFLOW	0x04	/* overflow exception */
#define	FE_UNDERFLOW	0x08	/* underflow exception */
#define	FE_INEXACT	0x10	/* imprecise (loss of precision; "inexact") */

#define	FE_ALL_EXCEPT	0x1f

#define	FE_TONEAREST	0	/* round to nearest representable number */
#define	FE_UPWARD	1	/* round toward positive infinity */
#define	FE_DOWNWARD	2	/* round toward negative infinity */
#define	FE_TOWARDZERO	3	/* round to zero (truncate) */

#ifdef __SOFTFP__

/*
 * Provide a platform-specific softfloat ABI.
 */

#include <arm/vfpreg.h>

#define __FENV_GET_FLAGS(__envp)	__SHIFTOUT(*(__envp), VFP_FPSCR_CSUM)
#define __FENV_GET_MASK(__envp)		__SHIFTOUT(*(__envp), VFP_FPSCR_ESUM)
#define __FENV_GET_ROUND(__envp)	__SHIFTOUT(*(__envp), VFP_FPSCR_RMODE)
#define __FENV_SET_FLAGS(__envp, __val) \
	*(__envp) = __SHIFTIN((__val), VFP_FPSCR_CSUM)
#define __FENV_SET_MASK(__envp, __val) \
	*(__envp) = __SHIFTIN((__val), VFP_FPSCR_ESUM)
#define __FENV_SET_ROUND(__envp, __val) \
	*(__envp) = __SHIFTIN((__val), VFP_FPSCR_RMODE)

#define __HAVE_FENV_SOFTFLOAT_DEFS

#endif /* __SOFTFP__ */

__BEGIN_DECLS

/* Default floating-point environment */
extern const fenv_t	__fe_dfl_env;
#define FE_DFL_ENV	(&__fe_dfl_env)

__END_DECLS

#endif /* _ARM_FENV_H_ */