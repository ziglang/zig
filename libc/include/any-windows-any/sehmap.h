/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __cplusplus
#undef try
#undef except
#undef finally
#undef leave
#define try __try
#define except __except
#define finally __finally
#define leave __leave
#endif
