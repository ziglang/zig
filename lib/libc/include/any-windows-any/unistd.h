/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _UNISTD_H
#define _UNISTD_H
#define __UNISTD_H_SOURCED__ 1

#include <io.h>
#include <process.h>
#include <getopt.h>

/* These are also defined in stdio.h. */
#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif

/* These are also defined in stdio.h. */
#ifndef STDIN_FILENO
#define STDIN_FILENO  0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
#endif

/* Used by shutdown(2). */
#ifdef _POSIX_SOURCE

/* MySql connector already defined SHUT_RDWR. */
#ifndef SHUT_RDWR
#define SHUT_RD   0x00
#define SHUT_WR   0x01
#define SHUT_RDWR 0x02
#endif

#endif

#ifdef __cplusplus
extern "C" {
#endif

#pragma push_macro("sleep")
#undef sleep
unsigned int __cdecl sleep (unsigned int);
#pragma pop_macro("sleep")

#if !defined __NO_ISOCEXT
#include <sys/types.h> /* For useconds_t. */

int __cdecl __MINGW_NOTHROW usleep(useconds_t);
#endif  /* Not __NO_ISOCEXT */

#ifndef FTRUNCATE_DEFINED
#define FTRUNCATE_DEFINED
/* This is defined as a real library function to allow autoconf
   to verify its existence. */
#if !defined(NO_OLDNAMES) || defined(_POSIX)
int ftruncate(int, off32_t);
int ftruncate64(int, off64_t);
int truncate(const char *, off32_t);
int truncate64(const char *, off64_t);
#ifndef __CRT__NO_INLINE
__CRT_INLINE int ftruncate(int __fd, off32_t __length)
{
  return _chsize (__fd, __length);
}
#endif /* !__CRT__NO_INLINE */
#else
int ftruncate(int, _off_t);
int ftruncate64(int, _off64_t);
int truncate(const char *, _off_t);
int truncate64(const char *, _off64_t);
#ifndef __CRT__NO_INLINE
__CRT_INLINE int ftruncate(int __fd, _off_t __length)
{
  return _chsize (__fd, __length);
}
#endif /* !__CRT__NO_INLINE */
#endif
#endif /* FTRUNCATE_DEFINED */

#ifndef _FILE_OFFSET_BITS_SET_FTRUNCATE
#define _FILE_OFFSET_BITS_SET_FTRUNCATE
#if (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64))
#define ftruncate ftruncate64
#endif /* _FILE_OFFSET_BITS_SET_FTRUNCATE */
#endif /* _FILE_OFFSET_BITS_SET_FTRUNCATE */

#ifndef _CRT_SWAB_DEFINED
#define _CRT_SWAB_DEFINED /* Also in stdlib.h */
  void __cdecl swab(char *_Buf1,char *_Buf2,int _SizeInBytes) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

#if defined(_CRT_USE_WINAPI_FAMILY_DESKTOP_APP) || defined(WINSTORECOMPAT)
#ifndef _CRT_GETPID_DEFINED
#define _CRT_GETPID_DEFINED  /* Also in process.h */
  int __cdecl getpid(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif /* _CRT_USE_WINAPI_FAMILY_DESKTOP_APP || WINSTORECOMPAT */

#ifdef __cplusplus
}
#endif

#include <pthread_unistd.h>

#undef __UNISTD_H_SOURCED__
#endif /* _UNISTD_H */

