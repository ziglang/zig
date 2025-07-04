/*      $NetBSD: bswap.h,v 1.3 2008/10/26 00:08:15 mrg Exp $      */

/* Written by Manuel Bouyer. Public domain */

#ifndef _X86_64_BSWAP_H_
#define	_X86_64_BSWAP_H_

#ifdef __x86_64__

#include <machine/byte_swap.h>

#define __BSWAP_RENAME
#include <sys/bswap.h>

#else	/*	__x86_64__	*/

#include <i386/bswap.h>

#endif	/*	__x86_64__	*/

#endif /* !_X86_64_BSWAP_H_ */