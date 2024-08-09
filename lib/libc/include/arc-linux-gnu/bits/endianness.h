#ifndef _BITS_ENDIANNESS_H
#define _BITS_ENDIANNESS_H 1

#ifndef _BITS_ENDIAN_H
# error "Never use <bits/endian.h> directly; include <endian.h> instead."
#endif

/* ARC has selectable endianness.  */
#ifdef __BIG_ENDIAN__
# define __BYTE_ORDER __BIG_ENDIAN
#else
# define __BYTE_ORDER __LITTLE_ENDIAN
#endif

#endif /* bits/endianness.h */