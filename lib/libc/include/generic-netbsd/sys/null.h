/*	$NetBSD: null.h,v 1.9 2010/07/06 11:56:20 kleink Exp $	*/

/*
 * Written by Klaus Klein <kleink@NetBSD.org>, December 22, 1999.
 * Public domain.
 */

#ifndef _SYS_NULL_H_
#define _SYS_NULL_H_
#ifndef	NULL
#if !defined(__GNUG__) || __GNUG__ < 2 || (__GNUG__ == 2 && __GNUC_MINOR__ < 90)
#if !defined(__cplusplus)
#define	NULL	((void *)0)
#else
#define	NULL	0
#endif /* !__cplusplus */
#else
#define	NULL	__null
#endif
#endif
#endif /* _SYS_NULL_H_ */