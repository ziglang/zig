/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _INC_OSCALLS
#define _INC_OSCALLS

#ifndef _CRTBLD
#error ERROR: Use of C runtime library internal header file.
#endif

#include <crtdefs.h>

#ifdef NULL
#undef NULL
#endif

#define NOMINMAX

#define _WIN32_FUSION 0x0100
#include <windows.h>

#ifndef NULL
#ifdef __cplusplus
#define NULL 0
#else
#define NULL ((void *)0)
#endif
#endif

#ifdef _MSC_VER
#pragma warning(push)
#pragma warning(disable:4214)
#endif

typedef struct _FTIME
{
  unsigned short twosecs : 5;
  unsigned short minutes : 6;
  unsigned short hours : 5;
} FTIME;

typedef FTIME *PFTIME;

typedef struct _FDATE
{
  unsigned short day : 5;
  unsigned short month : 4;
  unsigned short year : 7;
} FDATE;

#ifdef _MSC_VER
#pragma warning(pop)
#endif

typedef FDATE *PFDATE;

#endif
