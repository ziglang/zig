#include <string/endian.h>

#if defined _LIBC && !defined _ISOMAC
# if __FLOAT_WORD_ORDER == __BIG_ENDIAN
#  define BIG_ENDI 1
#  undef LITTLE_ENDI
#  define HIGH_HALF 0
#  define  LOW_HALF 1
# else
#  if __FLOAT_WORD_ORDER == __LITTLE_ENDIAN
#   undef BIG_ENDI
#   define LITTLE_ENDI 1
#   define HIGH_HALF 1
#   define  LOW_HALF 0
#  endif
# endif
#endif
