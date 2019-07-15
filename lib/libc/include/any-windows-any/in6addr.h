/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef s6_addr

#ifdef __LP64__
#pragma push_macro("u_long")
#undef u_long
#define u_long __ms_u_long
#endif

#include <_bsd_types.h>

typedef struct in6_addr {
  union {
    u_char Byte[16];
    u_short Word[8];
#ifdef __INSIDE_CYGWIN__
    uint32_t __s6_addr32[4];
#endif
  } u;
} IN6_ADDR, *PIN6_ADDR, *LPIN6_ADDR;

#define in_addr6	in6_addr

#define _S6_un		u
#define _S6_u8		Byte
#define s6_addr		_S6_un._S6_u8

#define s6_bytes	u.Byte
#define s6_words	u.Word

#ifdef __INSIDE_CYGWIN__
#define s6_addr16	u.Word
#define s6_addr32       u.__s6_addr32
#endif

#ifdef __LP64__
#pragma pop_macro("u_long")
#endif

#endif /* s6_addr */

