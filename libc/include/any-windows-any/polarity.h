/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef POLARITY_HEADERFILE_IS_INCLUDED
#define POLARITY_HEADERFILE_IS_INCLUDED

#ifdef USE_POLARITY
#ifdef BUILDING_DLL
#define POLARITY __declspec(dllexport)
#else
#define POLARITY __declspec(dllimport)
#endif
#else
#define POLARITY
#endif

#endif
