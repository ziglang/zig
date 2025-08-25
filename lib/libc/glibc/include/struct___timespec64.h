#ifndef _STRUCT_TIMESPEC64_H
#define _STRUCT_TIMESPEC64_H

#if __TIMESIZE == 64
# define __timespec64 timespec
#else
#include <endian.h>
/* The glibc Y2038-proof struct __timespec64 structure for a time value.
   To keep things Posix-ish, we keep the nanoseconds field a 32-bit
   signed long, but since the Linux field is a 64-bit signed int, we
   pad our tv_nsec with a 32-bit unnamed bit-field padding.

   As a general rule the Linux kernel is ignoring upper 32 bits of
   tv_nsec field.  */
struct __timespec64
{
  __time64_t tv_sec;         /* Seconds */
# if BYTE_ORDER == BIG_ENDIAN
  __int32_t :32;             /* Padding */
  __int32_t tv_nsec;         /* Nanoseconds */
# else
  __int32_t tv_nsec;         /* Nanoseconds */
  __int32_t :32;             /* Padding */
# endif
};
#endif
#endif /* _STRUCT_TIMESPEC64_H  */
