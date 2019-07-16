/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TYPES
#define _INC_TYPES

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

#include <crtdefs.h>

#ifdef _USE_32BIT_TIME_T
#ifdef _WIN64
#undef _USE_32BIT_TIME_T
#endif
#endif

#ifndef _TIME32_T_DEFINED
#define _TIME32_T_DEFINED
typedef long	__time32_t;
#endif

#ifndef _TIME64_T_DEFINED
#define _TIME64_T_DEFINED
__MINGW_EXTENSION
typedef __int64	__time64_t;
#endif

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
#ifdef _USE_32BIT_TIME_T
typedef __time32_t time_t;
#else
typedef __time64_t time_t;
#endif
#endif

#ifndef _INO_T_DEFINED
#define _INO_T_DEFINED
typedef unsigned short _ino_t;
#ifndef	NO_OLDNAMES
typedef unsigned short ino_t;
#endif
#endif

#ifndef _DEV_T_DEFINED
#define _DEV_T_DEFINED
typedef unsigned int _dev_t;
#ifndef	NO_OLDNAMES
typedef unsigned int dev_t;
#endif
#endif

#ifndef _PID_T_
#define	_PID_T_
#ifndef _WIN64
typedef int	_pid_t;
#else
__MINGW_EXTENSION
typedef __int64	_pid_t;
#endif

#ifndef	NO_OLDNAMES
#undef pid_t
typedef _pid_t	pid_t;
#endif
#endif	/* Not _PID_T_ */

#ifndef _MODE_T_
#define	_MODE_T_
typedef unsigned short _mode_t;

#ifndef	NO_OLDNAMES
typedef _mode_t	mode_t;
#endif
#endif	/* Not _MODE_T_ */

#include <_mingw_off_t.h>

#ifndef __NO_ISOCEXT
typedef unsigned int useconds_t;
#endif

#ifndef _TIMESPEC_DEFINED
#define _TIMESPEC_DEFINED
struct timespec {
  time_t  tv_sec;	/* Seconds */
  long    tv_nsec;	/* Nanoseconds */
};

struct itimerspec {
  struct timespec  it_interval;	/* Timer period */
  struct timespec  it_value;	/* Timer expiration */
};
#endif	/* _TIMESPEC_DEFINED */

#ifndef _SIGSET_T_
#define _SIGSET_T_
#ifdef _WIN64
__MINGW_EXTENSION
typedef unsigned long long _sigset_t;
#else
typedef unsigned long	_sigset_t;
#endif

#ifdef _POSIX
typedef _sigset_t	sigset_t;
#endif
#endif	/* Not _SIGSET_T_ */

#endif	/* _INC_TYPES */

