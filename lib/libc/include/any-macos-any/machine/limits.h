/* This is the `system' limits.h, independent of any particular
 *  compiler.  GCC provides its own limits.h which can be found in
 *  /usr/lib/gcc, although it is not very informative.
 *  This file is public domain.  */
#ifndef _BSD_MACHINE_LIMITS_H_
#define _BSD_MACHINE_LIMITS_H_

#if defined (__i386__) || defined(__x86_64__)
#include <i386/limits.h>
#elif defined (__arm__) || defined (__arm64__)
#include <arm/limits.h>
#else
#error architecture not supported
#endif

#endif /* _BSD_MACHINE_LIMITS_H_ */
