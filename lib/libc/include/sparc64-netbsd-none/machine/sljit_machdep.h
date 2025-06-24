/*	$NetBSD: sljit_machdep.h,v 1.1 2014/07/23 18:19:45 alnsn Exp $	*/

/* Only 32-bit SPARCs are supported. */
#ifndef __arch64__
#include <sparc/sljit_machdep.h>
#endif