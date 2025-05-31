/* $NetBSD: endian_machdep.h,v 1.9 2014/01/29 01:03:13 matt Exp $ */

/* __ARMEB__ or __AARCH64EB__ is predefined when building big-endian ARM. */
#if defined(__ARMEB__) || defined(__AARCH64EB__)
#define _BYTE_ORDER _BIG_ENDIAN
#else
#define _BYTE_ORDER _LITTLE_ENDIAN
#endif