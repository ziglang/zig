/* The MIPS architecture has selectable endianness.
   It exists in both little and big endian flavours and we
   want to be able to share the installed header files between
   both, so we define __BYTE_ORDER based on GCC's predefines.  */

#ifndef _ENDIAN_H
# error "Never use <bits/endian.h> directly; include <endian.h> instead."
#endif

#ifdef __MIPSEB
# define __BYTE_ORDER __BIG_ENDIAN
#endif
#ifdef __MIPSEL
# define __BYTE_ORDER __LITTLE_ENDIAN
#endif
