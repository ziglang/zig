#ifndef _STRUCT_TIMEVAL64_H
#define _STRUCT_TIMEVAL64_H

#if __TIMESIZE == 64
# define __timeval64 timeval
#else
/* The glibc Y2038-proof struct __timeval64 structure for a time value.
   This structure is NOT supposed to be passed to the Linux kernel.
   Instead, it shall be converted to struct __timespec64 and time shall
   be [sg]et via clock_[sg]ettime (which are now Y2038 safe).  */
struct __timeval64
{
  __time64_t tv_sec;         /* Seconds */
  __suseconds64_t tv_usec;       /* Microseconds */
};
#endif
#endif /* _STRUCT_TIMEVAL64_H  */
