/*	$NetBSD: cdefs.h,v 1.13 2014/03/18 17:11:19 christos Exp $	*/

#ifndef	_MACHINE_CDEFS_H_
#define	_MACHINE_CDEFS_H_

/* No arch-specific cdefs. */
#ifdef __arch64__
#define	__ALIGNBYTES		((size_t)0xf)
#else
#define	__ALIGNBYTES		((size_t)0x7)
#endif

#endif /* !_MACHINE_CDEFS_H_ */