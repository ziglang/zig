/*
 * Copyright (c) 2000-2009 Apple, Inc. All rights reserved.
 */
/*
 * Copyright (c) 1992 NeXT Computer, Inc.
 *
 */

#ifndef _ARM_SIGNAL_
#define _ARM_SIGNAL_ 1

#if defined (__arm__) || defined (__arm64__)

#include <sys/cdefs.h>

#ifndef _ANSI_SOURCE
typedef int sig_atomic_t;
#endif /* ! _ANSI_SOURCE */

#endif /* defined (__arm__) || defined (__arm64__) */

#endif  /* _ARM_SIGNAL_ */