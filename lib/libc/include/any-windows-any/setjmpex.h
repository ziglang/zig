/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SETJMPEX
#define _INC_SETJMPEX

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

#if (defined(_X86_) && !defined(__x86_64))
#define setjmp _setjmp
#define longjmp _longjmpex
#else
#ifdef setjmp
#undef setjmp
#endif
#define setjmp _setjmpex
#endif

#include <setjmp.h>
#endif
