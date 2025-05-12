/*       $NetBSD: types.h,v 1.29 2021/08/08 00:53:39 thorpej Exp $        */

#ifndef _SPARC64_TYPES_H_
#define	_SPARC64_TYPES_H_

#include <sparc/types.h>

#ifdef __arch64__
#define	MD_TOPDOWN_INIT(epp)	/* no topdown VM flag for exec by default */
#endif

#define	__HAVE_COMPAT_NETBSD32
#define	__HAVE_UCAS_FULL
#define	__HAVE_OPENFIRMWARE_VARIANT_SUNW

#endif