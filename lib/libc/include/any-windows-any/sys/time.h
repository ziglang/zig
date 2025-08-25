/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _SYS_TIME_H_
#define _SYS_TIME_H_

#include <time.h>

#ifdef  __cplusplus
extern "C" {
#endif

#include <_timeval.h>

#ifndef _TIMEZONE_DEFINED /* also in sys/time.h */
#define _TIMEZONE_DEFINED
/* Provided for compatibility with code that assumes that
   the presence of gettimeofday function implies a definition
   of struct timezone. */
struct timezone
{
  int tz_minuteswest; /* of Greenwich */
  int tz_dsttime;     /* type of dst correction to apply */
};

  extern int __cdecl mingw_gettimeofday (struct timeval *p, struct timezone *z);

#endif /* _TIMEZONE_DEFINED */

/*
   Implementation as per:
   The Open Group Base Specifications, Issue 6
   IEEE Std 1003.1, 2004 Edition

   The timezone pointer arg is ignored.  Errors are ignored.
*/
#ifndef _GETTIMEOFDAY_DEFINED
#define _GETTIMEOFDAY_DEFINED
int __cdecl gettimeofday(struct timeval *__restrict__,
                         void *__restrict__  /* tzp (unused) */);
#endif

#ifdef  __cplusplus
}
#endif

/* Adding timespec definition.  */
#include <sys/timeb.h>


#endif /* _SYS_TIME_H_ */
