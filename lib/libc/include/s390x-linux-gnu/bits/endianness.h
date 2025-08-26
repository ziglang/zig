#ifndef _BITS_ENDIANNESS_H
#define _BITS_ENDIANNESS_H 1

#ifndef _BITS_ENDIAN_H
# error "Never use <bits/endianness.h> directly; include <endian.h> instead."
#endif

/* S/390 is big-endian.  */
#define __BYTE_ORDER __BIG_ENDIAN

#endif /* bits/endianness.h */