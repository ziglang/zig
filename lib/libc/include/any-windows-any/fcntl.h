/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <crtdefs.h>

#include <io.h>

#ifndef _INC_FCNTL
#define _INC_FCNTL

#define _O_RDONLY 0x0000
#define _O_WRONLY 0x0001
#define _O_RDWR 0x0002
#define _O_APPEND 0x0008
#define _O_CREAT 0x0100
#define _O_TRUNC 0x0200
#define _O_EXCL 0x0400
#define _O_TEXT 0x4000
#define _O_BINARY 0x8000
#define _O_WTEXT 0x10000
#define _O_U16TEXT 0x20000
#define _O_U8TEXT 0x40000
#define _O_ACCMODE (_O_RDONLY|_O_WRONLY|_O_RDWR)

#define _O_RAW _O_BINARY
#define _O_NOINHERIT 0x0080
#define _O_TEMPORARY 0x0040
#define _O_SHORT_LIVED 0x1000

#define _O_SEQUENTIAL 0x0020
#define _O_RANDOM 0x0010

#if !defined(NO_OLDNAMES) || defined(_POSIX)
#define O_RDONLY _O_RDONLY
#define O_WRONLY _O_WRONLY
#define O_RDWR _O_RDWR
#define O_APPEND _O_APPEND
#define O_CREAT _O_CREAT
#define O_TRUNC _O_TRUNC
#define O_EXCL _O_EXCL
#define O_TEXT _O_TEXT
#define O_BINARY _O_BINARY
#define O_RAW _O_BINARY
#define O_TEMPORARY _O_TEMPORARY
#define O_NOINHERIT _O_NOINHERIT
#define O_SEQUENTIAL _O_SEQUENTIAL
#define O_RANDOM _O_RANDOM
#define O_ACCMODE _O_ACCMODE
#endif
#endif
