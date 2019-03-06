#ifndef _ENDIAN_H
# error "Never use <bits/endian.h> directly; include <endian.h> instead."
#endif

#ifdef __CSKYBE__
# error "Big endian not supported for C-SKY."
#else
# define __BYTE_ORDER __LITTLE_ENDIAN
#endif
