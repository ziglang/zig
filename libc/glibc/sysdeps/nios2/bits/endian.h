/* The Nios II architecture has selectable endianness.  */

#ifndef _ENDIAN_H
# error "Never use <bits/endian.h> directly; include <endian.h> instead."
#endif

#ifdef __nios2_big_endian__
# define __BYTE_ORDER __BIG_ENDIAN
#endif
#ifdef __nios2_little_endian__
# define __BYTE_ORDER __LITTLE_ENDIAN
#endif
