/*	$NetBSD: sljit_machdep.h,v 1.2 2018/08/26 21:06:46 rjs Exp $	*/

#ifdef __aarch64__
#include <aarch64/sljit_machdep.h>
#else
#include <arm/sljit_machdep.h>
#endif