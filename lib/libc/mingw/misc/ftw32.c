/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#define FUNC_FTW ftw32
#define FUNC_NFTW nftw32
#define FUNC_STAT stat32
#define STRUCT_STAT struct _stat32
#include "ftw.c"

/* On 32-bit systems is stat ABI compatible with stat32 */
#ifndef _WIN64
#undef nftw
#undef ftw
struct stat;
int __attribute__ ((alias ("nftw32"))) __cdecl nftw(const char *, int (*) (const char *, const struct stat *, int, struct FTW *), int, int);
int __attribute__ ((alias ("ftw32"))) __cdecl ftw(const char *, int (*) (const char *, const struct stat *, int), int);
#endif
