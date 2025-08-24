/*	$NetBSD: cdefs.h,v 1.10 2014/02/28 05:29:57 matt Exp $	*/

#ifndef	_POWERPC_CDEFS_H_
#define	_POWERPC_CDEFS_H_

#define	__ALIGNBYTES	(sizeof(double) - 1)
#ifdef _KERNEL
#define	ALIGNBYTES32	__ALIGNBYTES
#endif

#endif /* !_POWERPC_CDEFS_H_ */