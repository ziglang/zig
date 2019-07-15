/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_LOCKING
#define _INC_LOCKING

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

/* All the headers include this file. */
#include <crtdefs.h>

#define _LK_UNLCK 0
#define _LK_LOCK 1
#define _LK_NBLCK 2
#define _LK_RLCK 3
#define _LK_NBRLCK 4

#ifndef	NO_OLDNAMES
#define LK_UNLCK _LK_UNLCK
#define LK_LOCK _LK_LOCK
#define LK_NBLCK _LK_NBLCK
#define LK_RLCK _LK_RLCK
#define LK_NBRLCK _LK_NBRLCK
#endif

#endif
