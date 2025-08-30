/*	$NetBSD: ieeefp.h,v 1.9 2011/03/27 05:13:15 mrg Exp $	*/

/* 
 * Written by J.T. Conklin, Apr 6, 1995
 * Public domain.
 */

#ifndef _IEEEFP_H_
#define _IEEEFP_H_

#include <sys/cdefs.h>
#include <machine/ieeefp.h>

__BEGIN_DECLS
typedef fp_rnd fp_rnd_t;
#ifdef _X86_IEEEFP_H_	/* XXX */
typedef fp_prec fp_prec_t;
#endif
typedef fp_except fp_except_t;

fp_rnd_t	fpgetround(void);
fp_rnd_t	fpsetround(fp_rnd_t);
#ifdef _X86_IEEEFP_H_	/* XXX */
fp_prec_t	fpgetprec(void);
fp_prec_t	fpsetprec(fp_prec_t);
#endif
fp_except_t	fpgetmask(void);
fp_except_t	fpsetmask(fp_except_t);
fp_except_t	fpgetsticky(void);
fp_except_t	fpsetsticky(fp_except_t);
fp_except_t	fpresetsticky(fp_except_t);
__END_DECLS

#endif /* _IEEEFP_H_ */