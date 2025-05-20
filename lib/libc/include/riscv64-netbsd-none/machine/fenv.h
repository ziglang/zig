/*	$NetBSD: fenv.h,v 1.3 2020/03/14 16:12:16 skrll Exp $	*/

/*
 * Based on ieeefp.h written by J.T. Conklin, Apr 28, 1995
 * Public domain.
 */

#ifndef _RISCV_FENV_H_
#define _RISCV_FENV_H_

typedef int fenv_t;		/* FPSCR */
typedef int fexcept_t;

#define	FE_INEXACT	0x00	/* Result inexact */
#define	FE_UNDERFLOW	0x02	/* Result underflowed */
#define	FE_OVERFLOW	0x04	/* Result overflowed */
#define	FE_DIVBYZERO	0x08	/* divide-by-zero */
#define	FE_INVALID	0x10	/* Result invalid */

#define	FE_ALL_EXCEPT	0x1f

#define	FE_TONEAREST	0	/* round to nearest representable number */
#define	FE_TOWARDZERO	1	/* round to zero (truncate) */
#define	FE_DOWNWARD	2	/* round toward negative infinity */
#define	FE_UPWARD	3	/* round toward positive infinity */

__BEGIN_DECLS

/* Default floating-point environment */
extern const fenv_t	__fe_dfl_env;
#define FE_DFL_ENV	(&__fe_dfl_env)

__END_DECLS

#endif /* _RISCV_FENV_H_ */