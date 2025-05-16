/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#define FUNC_FTW ftw64i32
#define FUNC_NFTW nftw64i32
#define FUNC_STAT stat64i32
#define STRUCT_STAT struct _stat64i32
#include "ftw.c"

/* On 64-bit systems is stat ABI compatible with stat64i32 */
#ifdef _WIN64
#undef nftw
#undef ftw
struct stat;
int __attribute__ ((alias ("nftw64i32"))) __cdecl nftw(const char *, int (*) (const char *, const struct stat *, int, struct FTW *), int, int);
int __attribute__ ((alias ("ftw64i32"))) __cdecl ftw(const char *, int (*) (const char *, const struct stat *, int), int);
#endif
