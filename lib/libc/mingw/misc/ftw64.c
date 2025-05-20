/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#define FUNC_FTW ftw64
#define FUNC_NFTW nftw64
#define FUNC_STAT stat64
#define STRUCT_STAT struct stat64
#include "ftw.c"
