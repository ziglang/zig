/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STDIO
#define _INC_STDIO

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#define BUFSIZ 512
#define _NFILE _NSTREAM_
#define _NSTREAM_ 512
#define _IOB_ENTRIES 20
#define EOF (-1)

#ifndef _FILE_DEFINED
  struct _iobuf {
    char *_ptr;
    int _cnt;
    char *_base;
    int _flag;
    int _file;
    int _charbuf;
    int _bufsiz;
    char *_tmpfname;
  };
  typedef struct _iobuf FILE;
#define _FILE_DEFINED
#endif

#ifdef _POSIX_
#define _P_tmpdir "/"
#define _wP_tmpdir L"/"
#else
#define _P_tmpdir "\\"
#define _wP_tmpdir L"\\"
#endif

#define L_tmpnam (sizeof(_P_tmpdir) + 12)

#ifdef _POSIX_
#define L_ctermid 9
#define L_cuserid 32
#endif

#define SEEK_CUR 1
#define SEEK_END 2
#define SEEK_SET 0

#define	STDIN_FILENO	0
#define	STDOUT_FILENO	1
#define	STDERR_FILENO	2

#define FILENAME_MAX 260
#define FOPEN_MAX 20
#define _SYS_OPEN 20
#define TMP_MAX 32767

#ifndef NULL
#ifdef __cplusplus
#ifndef _WIN64
#define NULL 0
#else
#define NULL 0LL
#endif  /* W64 */
#else
#define NULL ((void *)0)
#endif
#endif

#include <_mingw_off_t.h>

_CRTIMP FILE *__cdecl __acrt_iob_func(unsigned index);
#ifndef _STDIO_DEFINED
#ifdef _WIN64
  _CRTIMP FILE *__cdecl __iob_func(void);
#define _iob  __iob_func()
#else
#ifdef _MSVCRT_
extern FILE _iob[];	/* A pointer to an array of FILE */
#define __iob_func()	(_iob)
#else
extern FILE (* __MINGW_IMP_SYMBOL(_iob))[];	/* A pointer to an array of FILE */
#define __iob_func()	(* __MINGW_IMP_SYMBOL(_iob))
#define _iob __iob_func()
#endif
#endif
#endif

#ifndef _FPOS_T_DEFINED
#define _FPOS_T_DEFINED
#undef _FPOSOFF

#if (!defined(NO_OLDNAMES) || defined(__GNUC__))
  __MINGW_EXTENSION typedef __int64 fpos_t;
#define _FPOSOFF(fp) ((long)(fp))
#else
  __MINGW_EXTENSION typedef long long fpos_t;
#define _FPOSOFF(fp) ((long)(fp))
#endif

#endif

#ifndef _STDSTREAM_DEFINED
#define _STDSTREAM_DEFINED

#define stdin (__acrt_iob_func(0))
#define stdout (__acrt_iob_func(1))
#define stderr (__acrt_iob_func(2))
#endif

#define _IOREAD 0x0001
#define _IOWRT 0x0002

#define _IOFBF 0x0000
#define _IOLBF 0x0040
#define _IONBF 0x0004

#define _IOMYBUF 0x0008
#define _IOEOF 0x0010
#define _IOERR 0x0020
#define _IOSTRG 0x0040
#define _IORW 0x0080
#ifdef _POSIX_
#define _IOAPPEND 0x0200
#endif

#define _TWO_DIGIT_EXPONENT 0x1

#if !defined(_UCRTBASE_STDIO_DEFINED) && defined(_UCRT)
#define _UCRTBASE_STDIO_DEFINED

#define UCRTBASE_PRINTF_LEGACY_VSPRINTF_NULL_TERMINATION (0x0001)
#define UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR      (0x0002)
#define UCRTBASE_PRINTF_LEGACY_WIDE_SPECIFIERS           (0x0004)
#define UCRTBASE_PRINTF_LEGACY_MSVCRT_COMPATIBILITY      (0x0008)
#define UCRTBASE_PRINTF_LEGACY_THREE_DIGIT_EXPONENTS     (0x0010)

#define UCRTBASE_SCANF_SECURECRT                         (0x0001)
#define UCRTBASE_SCANF_LEGACY_WIDE_SPECIFIERS            (0x0002)
#define UCRTBASE_SCANF_LEGACY_MSVCRT_COMPATIBILITY       (0x0004)

// Default wide printfs and scanfs to the legacy wide mode. Only code built
// with -D__USE_MINGW_ANSI_STDIO=1 will expect the standard behaviour.
#ifndef UCRTBASE_PRINTF_DEFAULT_WIDE
#define UCRTBASE_PRINTF_DEFAULT_WIDE UCRTBASE_PRINTF_LEGACY_WIDE_SPECIFIERS
#endif
#ifndef UCRTBASE_SCANF_DEFAULT_WIDE
#define UCRTBASE_SCANF_DEFAULT_WIDE UCRTBASE_SCANF_LEGACY_WIDE_SPECIFIERS
#endif
#endif

#if __MINGW_FORTIFY_LEVEL > 0
__mingw_bos_declare;
#endif

#ifndef _STDIO_DEFINED
extern
  __attribute__((__format__ (gnu_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_sscanf(const char * __restrict__ _Src,const char * __restrict__ _Format,...);
extern
  __attribute__((__format__ (gnu_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vsscanf (const char * __restrict__ _Str,const char * __restrict__ Format,va_list argp);
extern
  __attribute__((__format__ (gnu_scanf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_scanf(const char * __restrict__ _Format,...);
extern
  __attribute__((__format__ (gnu_scanf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_vscanf(const char * __restrict__ Format, va_list argp);
extern
  __attribute__((__format__ (gnu_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_fscanf(FILE * __restrict__ _File,const char * __restrict__ _Format,...);
extern
  __attribute__((__format__ (gnu_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vfscanf (FILE * __restrict__ fp, const char * __restrict__ Format,va_list argp);

extern
  __attribute__((__format__ (gnu_printf, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __mingw_vsnprintf(char * __restrict__ _DstBuf,size_t _MaxCount,const char * __restrict__ _Format,
                               va_list _ArgList);
extern
  __attribute__((__format__ (gnu_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __mingw_snprintf(char * __restrict__ s, size_t n, const char * __restrict__  format, ...);
extern
  __attribute__((__format__ (gnu_printf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_printf(const char * __restrict__ , ... ) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_vprintf (const char * __restrict__ , va_list) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_fprintf (FILE * __restrict__ , const char * __restrict__ , ...) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vfprintf (FILE * __restrict__ , const char * __restrict__ , va_list) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_sprintf (char * __restrict__ , const char * __restrict__ , ...) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vsprintf (char * __restrict__ , const char * __restrict__ , va_list) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 3))) __attribute__((nonnull (1,2)))
  int __cdecl __mingw_asprintf(char ** __restrict__ , const char * __restrict__ , ...) __MINGW_NOTHROW;
extern
  __attribute__((__format__ (gnu_printf, 2, 0))) __attribute__((nonnull (1,2)))
  int __cdecl __mingw_vasprintf(char ** __restrict__ , const char * __restrict__ , va_list) __MINGW_NOTHROW;

#ifdef _UCRT
  int __cdecl __stdio_common_vsprintf(unsigned __int64 options, char *str, size_t len, const char *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vfprintf(unsigned __int64 options, FILE *file, const char *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vsscanf(unsigned __int64 options, const char *input, size_t length, const char *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vfscanf(unsigned __int64 options, FILE *file, const char *format, _locale_t locale, va_list valist);
#endif

#undef __MINGW_PRINTF_FORMAT
#undef __MINGW_SCANF_FORMAT

#if defined(__clang__)
#define __MINGW_PRINTF_FORMAT printf
#define __MINGW_SCANF_FORMAT  scanf
#elif defined(_UCRT) || __USE_MINGW_ANSI_STDIO
#define __MINGW_PRINTF_FORMAT gnu_printf
#define __MINGW_SCANF_FORMAT  gnu_scanf
#else
#define __MINGW_PRINTF_FORMAT ms_printf
#define __MINGW_SCANF_FORMAT  ms_scanf
#endif

#if __USE_MINGW_ANSI_STDIO
/*
 * User has expressed a preference for C99 conformance...
 */

#ifdef _GNU_SOURCE
__mingw_ovr
__attribute__ ((__format__ (gnu_printf, 2, 3))) __attribute__((nonnull (1,2)))
int asprintf(char **__ret, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vasprintf( __ret, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
__attribute__ ((__format__ (gnu_printf, 2, 0))) __attribute__((nonnull (1,2)))
int vasprintf(char **__ret, const char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vasprintf( __ret, __format, __local_argv );
}
#endif /* _GNU_SOURCE */

/* There seems to be a bug about builtins and static overrides of them
   in g++.  So we need to do here some trickery.  */
#ifdef __cplusplus
extern "C++" {
#endif

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int sscanf(const char *__source, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsscanf( __source, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
int scanf(const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfscanf( stdin, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int fscanf(FILE *__stream, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfscanf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */
#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
int vsscanf (const char *__source, const char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vsscanf( __source, __format, __local_argv );
}

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
int vscanf(const char *__format,  __builtin_va_list __local_argv)
{
  return __mingw_vfscanf( stdin, __format, __local_argv );
}

__mingw_ovr
__attribute__((__format__ (gnu_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
int vfscanf (FILE *__stream,  const char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfscanf( __stream, __format, __local_argv );
}

#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
#endif /* __NO_ISOCEXT */



__mingw_ovr
__attribute__((__format__ (gnu_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int fprintf (FILE *__stream, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
__attribute__((__format__ (gnu_printf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
int printf (const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfprintf( stdout, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#if __MINGW_FORTIFY_VA_ARG

__mingw_bos_ovr
__attribute__((__format__ (gnu_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int sprintf (char *__stream, const char *__format, ...)
{
  if (__mingw_bos_known(__stream)) {
    int __retval = __mingw_snprintf( __stream, __mingw_bos(__stream, 1), __format, __builtin_va_arg_pack() );
    if (__retval >= 0)
      __mingw_bos_ptr_chk(__stream, (size_t)__retval + 1, 1);
    return __retval;
  }
  return __mingw_sprintf( __stream, __format, __builtin_va_arg_pack() );
}

#else /* !__MINGW_FORTIFY_VA_ARG */

__mingw_ovr
__attribute__((__format__ (gnu_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int sprintf (char *__stream, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#endif /* __MINGW_FORTIFY_VA_ARG */

__mingw_ovr
__attribute__((__format__ (gnu_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
int vfprintf (FILE *__stream, const char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfprintf( __stream, __format, __local_argv );
}

__mingw_ovr
__attribute__((__format__ (gnu_printf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
int vprintf (const char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfprintf( stdout, __format, __local_argv );
}

__mingw_bos_ovr
__attribute__((__format__ (gnu_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
int vsprintf (char *__stream, const char *__format, __builtin_va_list __local_argv)
{
#if __MINGW_FORTIFY_LEVEL > 0
  if (__mingw_bos_known(__stream)) {
    int __retval = __mingw_vsnprintf( __stream, __mingw_bos(__stream, 1), __format, __local_argv );
    if (__retval >= 0)
      __mingw_bos_ptr_chk(__stream, (size_t)__retval + 1, 1);
    return __retval;
  }
#endif
  return __mingw_vsprintf( __stream, __format, __local_argv );
}
/* #ifndef __NO_ISOCEXT */  /* externs in libmingwex.a */

#if __MINGW_FORTIFY_VA_ARG

__mingw_bos_ovr
__attribute__((__format__ (gnu_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
int snprintf (char *__stream, size_t __n, const char *__format, ...)
{
  __mingw_bos_ptr_chk_warn(__stream, __n, 1);
  return __mingw_snprintf( __stream, __n, __format, __builtin_va_arg_pack() );
}

#else /* !__MINGW_FORTIFY_VA_ARG */

__mingw_ovr
__attribute__((__format__ (gnu_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
int snprintf (char *__stream, size_t __n, const char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsnprintf( __stream, __n, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#endif /* __MINGW_FORTIFY_VA_ARG */

__mingw_bos_ovr
__attribute__((__format__ (gnu_printf, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
int vsnprintf (char *__stream, size_t __n, const char *__format, __builtin_va_list __local_argv)
{
#if __MINGW_FORTIFY_LEVEL > 0
  __mingw_bos_ptr_chk_warn(__stream, __n, 1);
#endif
  return __mingw_vsnprintf( __stream, __n, __format, __local_argv );
}

/* Override __builtin_printf-routines ... Kludge for libstdc++ ...*/
#define __builtin_vsnprintf __mingw_vsnprintf
#define __builtin_vsprintf __mingw_vsprintf

/* #endif */ /* __NO_ISOCEXT */

#ifdef __cplusplus
}
#endif

#else /* !__USE_MINGW_ANSI_STDIO */

#undef __builtin_vsnprintf
#undef __builtin_vsprintf

/*
 * Default configuration: simply direct all calls to MSVCRT...
 */
#ifdef _UCRT
#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl fprintf(FILE * __restrict__ _File,const char * __restrict__ _Format,...);
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl printf(const char * __restrict__ _Format,...);
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl sprintf(char * __restrict__ _Dest,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl vfprintf(FILE * __restrict__ _File,const char * __restrict__ _Format,va_list _ArgList);
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl vprintf(const char * __restrict__ _Format,va_list _ArgList);
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl vsprintf(char * __restrict__ _Dest,const char * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl fscanf(FILE * __restrict__ _File,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfscanf(0, _File, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl scanf(const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfscanf(0, stdin, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl sscanf(const char * __restrict__ _Src,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vsscanf(0, _Src, (size_t)-1, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
#ifdef _GNU_SOURCE
  __attribute__ ((__format__ (__MINGW_PRINTF_FORMAT, 2, 0)))
  int __cdecl vasprintf(char ** __restrict__ _Ret,const char * __restrict__ _Format,va_list _Args);
  __attribute__ ((__format__ (__MINGW_PRINTF_FORMAT, 2, 3)))
  int __cdecl asprintf(char ** __restrict__ _Ret,const char * __restrict__ _Format,...);
#endif /*_GNU_SOURCE*/

  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int vfscanf (FILE *__stream,  const char *__format, __builtin_va_list __local_argv)
  {
    return __stdio_common_vfscanf(0, __stream, __format, NULL, __local_argv);
  }

  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int vsscanf (const char * __restrict__ __source, const char * __restrict__ __format, __builtin_va_list __local_argv)
  {
    return __stdio_common_vsscanf(0, __source, (size_t)-1, __format, NULL, __local_argv);
  }
  __mingw_ovr
  __attribute__((__format__ (__MINGW_SCANF_FORMAT, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int vscanf(const char *__format,  __builtin_va_list __local_argv)
  {
    return __stdio_common_vfscanf(0, stdin, __format, NULL, __local_argv);
  }

#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif

#else
  __attribute__((__format__ (ms_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl fprintf(FILE * __restrict__ _File,const char * __restrict__ _Format,...);
  __attribute__((__format__ (ms_printf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl printf(const char * __restrict__ _Format,...);
  __attribute__((__format__ (ms_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl sprintf(char * __restrict__ _Dest,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  __attribute__((__format__ (ms_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl vfprintf(FILE * __restrict__ _File,const char * __restrict__ _Format,va_list _ArgList);
  __attribute__((__format__ (ms_printf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl vprintf(const char * __restrict__ _Format,va_list _ArgList);
  __attribute__((__format__ (ms_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl vsprintf(char * __restrict__ _Dest,const char * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  __attribute__((__format__ (ms_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl fscanf(FILE * __restrict__ _File,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __attribute__((__format__ (ms_scanf, 1, 2))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl scanf(const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __attribute__((__format__ (ms_scanf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl sscanf(const char * __restrict__ _Src,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#ifdef _GNU_SOURCE
  int __cdecl vasprintf(char ** __restrict__ ret,const char * __restrict__ format,va_list ap)  __attribute__ ((format (__MINGW_PRINTF_FORMAT, 2, 0)));
  int __cdecl asprintf(char ** __restrict__ ret,const char * __restrict__ format,...) __attribute__ ((format (__MINGW_PRINTF_FORMAT, 2, 3)));
#endif /*_GNU_SOURCE*/
#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */
#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif

  __attribute__((__format__ (ms_scanf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __ms_vscanf(const char * __restrict__ Format, va_list argp);
  __attribute__((__format__ (ms_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __ms_vfscanf (FILE * __restrict__ fp, const char * __restrict__ Format,va_list argp);
  __attribute__((__format__ (ms_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __ms_vsscanf (const char * __restrict__ _Str,const char * __restrict__ Format,va_list argp);

  __mingw_ovr
  __attribute__((__format__ (ms_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int vfscanf (FILE *__stream,  const char *__format, __builtin_va_list __local_argv)
  {
    return __ms_vfscanf (__stream, __format, __local_argv);
  }

  __mingw_ovr
  __attribute__((__format__ (ms_scanf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
  int vsscanf (const char * __restrict__ __source, const char * __restrict__ __format, __builtin_va_list __local_argv)
  {
    return __ms_vsscanf( __source, __format, __local_argv );
  }
  __mingw_ovr
  __attribute__((__format__ (ms_scanf, 1, 0))) __MINGW_ATTRIB_NONNULL(1)
  int vscanf(const char *__format,  __builtin_va_list __local_argv)
  {
    return __ms_vscanf (__format, __local_argv);
  }

#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif

#endif /* __NO_ISOCEXT */
#endif /* _UCRT */
#endif /* __USE_MINGW_ANSI_STDIO */

  _CRTIMP int __cdecl _filbuf(FILE *_File);
  _CRTIMP int __cdecl _flsbuf(int _Ch,FILE *_File);
#ifdef _POSIX_
  _CRTIMP FILE *__cdecl _fsopen(const char *_Filename,const char *_Mode);
#else
  _CRTIMP FILE *__cdecl _fsopen(const char *_Filename,const char *_Mode,int _ShFlag);
#endif
  void __cdecl clearerr(FILE *_File);
  int __cdecl fclose(FILE *_File);
  _CRTIMP int __cdecl _fcloseall(void);
#ifdef _POSIX_
  FILE *__cdecl fdopen(int _FileHandle,const char *_Mode) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#else
  _CRTIMP FILE *__cdecl _fdopen(int _FileHandle,const char *_Mode);
#endif
  int __cdecl feof(FILE *_File);
  int __cdecl ferror(FILE *_File);
  int __cdecl fflush(FILE *_File);
  int __cdecl fgetc(FILE *_File);
  _CRTIMP int __cdecl _fgetchar(void);
  int __cdecl fgetpos(FILE * __restrict__ _File ,fpos_t * __restrict__ _Pos); /* 64bit only, no 32bit version */
  int __cdecl fgetpos64(FILE * __restrict__ _File ,fpos_t * __restrict__ _Pos); /* fgetpos already 64bit */
  char *__cdecl fgets(char * __restrict__ _Buf,int _MaxCount,FILE * __restrict__ _File);
  _CRTIMP int __cdecl _fileno(FILE *_File);
#ifdef _POSIX_
  int __cdecl fileno(FILE *_File) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
  _CRTIMP char *__cdecl _tempnam(const char *_DirName,const char *_FilePrefix);
  _CRTIMP int __cdecl _flushall(void);
  FILE *__cdecl fopen(const char * __restrict__ _Filename,const char * __restrict__ _Mode) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  FILE *fopen64(const char * __restrict__ filename,const char * __restrict__  mode);
  int __cdecl fputc(int _Ch,FILE *_File);
  _CRTIMP int __cdecl _fputchar(int _Ch);
  int __cdecl fputs(const char * __restrict__ _Str,FILE * __restrict__ _File);
  size_t __cdecl fread(void * __restrict__ _DstBuf,size_t _ElementSize,size_t _Count,FILE * __restrict__ _File);
  FILE *__cdecl freopen(const char * __restrict__ _Filename,const char * __restrict__ _Mode,FILE * __restrict__ _File) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl fsetpos(FILE *_File,const fpos_t *_Pos);
  int __cdecl fsetpos64(FILE *_File,const fpos_t *_Pos); /* fsetpos already 64bit */
  int __cdecl fseek(FILE *_File,long _Offset,int _Origin);
  long __cdecl ftell(FILE *_File);

  /* Shouldn't be any fseeko32 in glibc, 32bit to 64bit casting should be fine */
  /* int fseeko32(FILE* stream, _off_t offset, int whence);*/ /* fseeko32 redirects to fseeko64 */
  _CRTIMP int __cdecl _fseeki64(FILE *_File,__int64 _Offset,int _Origin);
  _CRTIMP __int64 __cdecl _ftelli64(FILE *_File);
#ifdef _UCRT
  __mingw_static_ovr int fseeko(FILE *_File, _off_t _Offset, int _Origin) {
    return fseek(_File, _Offset, _Origin);
  }
  __mingw_static_ovr int fseeko64(FILE *_File, _off64_t _Offset, int _Origin) {
    return _fseeki64(_File, _Offset, _Origin);
  }
  __mingw_static_ovr _off_t ftello(FILE *_File) {
    return ftell(_File);
  }
  __mingw_static_ovr _off64_t ftello64(FILE *_File) {
    return _ftelli64(_File);
  }
#else
  int fseeko64(FILE* stream, _off64_t offset, int whence);
  int fseeko(FILE* stream, _off_t offset, int whence);
  /* Returns truncated 64bit off_t */
  _off_t ftello(FILE * stream);
  _off64_t ftello64(FILE * stream);
#endif

#ifndef _FILE_OFFSET_BITS_SET_FSEEKO
#define _FILE_OFFSET_BITS_SET_FSEEKO
#if (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64))
#define fseeko fseeko64
#endif /* (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64)) */
#endif /* _FILE_OFFSET_BITS_SET_FSEEKO */

#ifndef _FILE_OFFSET_BITS_SET_FTELLO
#define _FILE_OFFSET_BITS_SET_FTELLO
#if (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64))
#define ftello ftello64
#endif /* (defined(_FILE_OFFSET_BITS) && (_FILE_OFFSET_BITS == 64)) */
#endif /* _FILE_OFFSET_BITS_SET_FTELLO */

  size_t __cdecl fwrite(const void * __restrict__ _Str,size_t _Size,size_t _Count,FILE * __restrict__ _File);
  int __cdecl getc(FILE *_File);
  int __cdecl getchar(void);
  _CRTIMP int __cdecl _getmaxstdio(void);
  char *__cdecl gets(char *_Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl _getw(FILE *_File);
#ifndef _CRT_PERROR_DEFINED
#define _CRT_PERROR_DEFINED
  void __cdecl perror(const char *_ErrMsg);
#endif
  _CRTIMP int __cdecl _pclose(FILE *_File);
  _CRTIMP FILE *__cdecl _popen(const char *_Command,const char *_Mode);
#if !defined(NO_OLDNAMES) && !defined(popen)
#define popen	_popen
#define pclose	_pclose
#endif
  int __cdecl putc(int _Ch,FILE *_File);
  int __cdecl putchar(int _Ch);
  int __cdecl puts(const char *_Str);
  _CRTIMP int __cdecl _putw(int _Word,FILE *_File);
#ifndef _CRT_DIRECTORY_DEFINED
#define _CRT_DIRECTORY_DEFINED
  int __cdecl remove(const char *_Filename);
  int __cdecl rename(const char *_OldFilename,const char *_NewFilename);
  _CRTIMP int __cdecl _unlink(const char *_Filename);
#ifndef	NO_OLDNAMES
  int __cdecl unlink(const char *_Filename) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#endif
  void __cdecl rewind(FILE *_File);
  _CRTIMP int __cdecl _rmtmp(void);
  void __cdecl setbuf(FILE * __restrict__ _File,char * __restrict__ _Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _setmaxstdio(int _Max);
  _CRTIMP unsigned int __cdecl _set_output_format(unsigned int _Format);
  _CRTIMP unsigned int __cdecl _get_output_format(void);
  int __cdecl setvbuf(FILE * __restrict__ _File,char * __restrict__ _Buf,int _Mode,size_t _Size);
#ifdef _UCRT
  __mingw_ovr
  int __cdecl _scprintf(const char * __restrict__ _Format,...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vsprintf(UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, NULL, 0, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl _snscanf(const char * __restrict__ _Src,size_t _MaxCount,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vsscanf(0, _Src, _MaxCount, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
#else
  _CRTIMP int __cdecl _scprintf(const char * __restrict__ _Format,...);
  _CRTIMP int __cdecl _snscanf(const char * __restrict__ _Src,size_t _MaxCount,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif
  FILE *__cdecl tmpfile(void) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  char *__cdecl tmpnam(char *_Buffer);
  int __cdecl ungetc(int _Ch,FILE *_File);

#ifdef _UCRT
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl _vsnprintf(char * __restrict__ _Dest,size_t _Count,const char * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __mingw_ovr
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl _snprintf(char * __restrict__ _Dest,size_t _Count,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = _vsnprintf(_Dest, _Count, _Format, ap);
    __builtin_va_end(ap);
    return ret;
  }
#else
  __attribute__((__format__ (ms_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
  _CRTIMP int __cdecl _snprintf(char * __restrict__ _Dest,size_t _Count,const char * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __attribute__((__format__ (ms_printf, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  _CRTIMP int __cdecl _vsnprintf(char * __restrict__ _Dest,size_t _Count,const char * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif

#if __MINGW_FORTIFY_LEVEL > 0

char * __cdecl __gets_chk(char *, size_t);
char * __cdecl __mingw_call_gets_warn(char *) __MINGW_ASM_CALL(gets)
  __attribute__((__warning__("Using gets() is always unsafe - use fgets() instead")));
char * __cdecl __mingw_call_fgets(char * __restrict__, int, FILE * __restrict__) __MINGW_ASM_CALL(fgets);
size_t __cdecl __mingw_call_fread(void * __restrict__, size_t, size_t, FILE * __restrict__) __MINGW_ASM_CALL(fread);
char * __cdecl __mingw_call_tmpnam(char *) __MINGW_ASM_CALL(tmpnam);

__mingw_bos_extern_ovr
char * gets(char * __dst)
{
  if (__mingw_bos_known(__dst))
    return __gets_chk(__dst, __mingw_bos(__dst, 1));
  return __mingw_call_gets_warn(__dst);
}

__mingw_bos_extern_ovr
char * fgets(char * __restrict__ __dst, int __n, FILE * __restrict__ __f)
{
  __mingw_bos_ptr_chk_warn(__dst, __n, 1);
  return __mingw_call_fgets(__dst, __n, __f);
}

__mingw_bos_extern_ovr
size_t fread(void * __restrict__ __dst, size_t __sz, size_t __n, FILE * __restrict__ __f)
{
  __mingw_bos_ptr_chk_warn(__dst, __sz * __n, 0);
  return __mingw_call_fread(__dst, __sz, __n, __f);
}

__mingw_bos_extern_ovr
char * tmpnam(char * __dst)
{
  __mingw_bos_ptr_chk_warn(__dst, L_tmpnam, 1);
  return __mingw_call_tmpnam(__dst);
}

#endif /* __MINGW_FORTIFY_LEVEL > 0 */

#if __USE_MINGW_ANSI_STDIO == 0

#ifdef _UCRT
#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif
  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  int vsnprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, va_list __local_argv);

  __attribute__((__format__ (__MINGW_PRINTF_FORMAT, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
  int snprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, ...);
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
#else

/* this is here to deal with software defining
 * vsnprintf as _vsnprintf, eg. libxml2.  */

#ifdef __GNUC__
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wshadow"
#endif

#pragma push_macro("snprintf")
#pragma push_macro("vsnprintf")
# undef snprintf
# undef vsnprintf
  __attribute__((__format__ (ms_printf, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __ms_vsnprintf(char * __restrict__ d,size_t n,const char * __restrict__ format,va_list arg)
    __MINGW_ATTRIB_DEPRECATED_MSVC2005 __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  __mingw_bos_ovr
  __attribute__((__format__ (ms_printf, 3, 0))) __MINGW_ATTRIB_NONNULL(3)
  int vsnprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, va_list __local_argv)
  {
#if __MINGW_FORTIFY_LEVEL > 0
    __mingw_bos_ptr_chk_warn(__stream, __n, 1);
#endif
    return __ms_vsnprintf (__stream, __n, __format, __local_argv);
  }

  __attribute__((__format__ (ms_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __ms_snprintf(char * __restrict__ s, size_t n, const char * __restrict__  format, ...);

#ifndef __NO_ISOCEXT
#if __MINGW_FORTIFY_VA_ARG

__mingw_bos_ovr
__attribute__((__format__ (ms_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
int snprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, ...)
{
  __mingw_bos_ptr_chk_warn(__stream, __n, 1);
  return __ms_snprintf(__stream, __n, __format, __builtin_va_arg_pack());
}

#else /* !__MINGW_FORTIFY_VA_ARG */

__mingw_ovr
__attribute__((__format__ (ms_printf, 3, 4))) __MINGW_ATTRIB_NONNULL(3)
int snprintf (char * __restrict__ __stream, size_t __n, const char * __restrict__ __format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __ms_vsnprintf (__stream, __n, __format, __local_argv);
  __builtin_va_end( __local_argv );
  return __retval;
}

#endif /* !__MINGW_FORTIFY_VA_ARG */
#endif /* !__NO_ISOCEXT */

#if __MINGW_FORTIFY_VA_ARG

int __cdecl __mingw_call_ms_sprintf(char * __restrict__, const char * __restrict__, ...) __MINGW_ASM_CALL(sprintf);

__mingw_bos_extern_ovr
__attribute__((__format__ (ms_printf, 2, 3))) __MINGW_ATTRIB_NONNULL(2)
int sprintf (char * __restrict__ __stream, const char * __restrict__ __format, ...)
{
  if (__mingw_bos_known(__stream)) {
    int __retval = __ms_snprintf( __stream, __mingw_bos(__stream, 1), __format, __builtin_va_arg_pack() );
    if (__retval >= 0)
      __mingw_bos_ptr_chk(__stream, (size_t)__retval + 1, 1);
    return __retval;
  }
  return __mingw_call_ms_sprintf( __stream, __format, __builtin_va_arg_pack() );
}

#endif /* __MINGW_FORTIFY_VA_ARG */

#if __MINGW_FORTIFY_LEVEL > 0

int __cdecl __mingw_call_ms_vsprintf(char * __restrict__, const char * __restrict__, va_list) __MINGW_ASM_CALL(vsprintf);

__mingw_bos_extern_ovr
__attribute__((__format__ (ms_printf, 2, 0))) __MINGW_ATTRIB_NONNULL(2)
int vsprintf (char * __restrict__ __stream, const char * __restrict__ __format, va_list __local_argv)
{
  if (__mingw_bos_known(__stream)) {
    int __retval = __ms_vsnprintf( __stream, __mingw_bos(__stream, 1), __format, __local_argv );
    if (__retval >= 0)
      __mingw_bos_ptr_chk(__stream, (size_t)__retval + 1, 1);
    return __retval;
  }
  return __mingw_call_ms_vsprintf( __stream, __format, __local_argv );
}

#endif /* __MINGW_FORTIFY_LEVEL > 0 */

#pragma pop_macro ("vsnprintf")
#pragma pop_macro ("snprintf")
#ifdef __GNUC__
#pragma GCC diagnostic pop
#endif
#endif /* _UCRT */
#endif /* __USE_MINGW_ANSI_STDIO */

#ifdef _UCRT
  __mingw_ovr
  int __cdecl _vscprintf(const char * __restrict__ _Format,va_list _ArgList)
  {
    return __stdio_common_vsprintf(UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, NULL, 0, _Format, NULL, _ArgList);
  }
#else
  _CRTIMP int __cdecl _vscprintf(const char * __restrict__ _Format,va_list _ArgList);
#endif /* _UCRT */

  _CRTIMP int __cdecl _set_printf_count_output(int _Value);
  _CRTIMP int __cdecl _get_printf_count_output(void);

#ifndef _WSTDIO_DEFINED
#define _WSTDIO_DEFINED

/* __attribute__((__format__ (gnu_wscanf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_swscanf(const wchar_t * __restrict__ _Src,const wchar_t * __restrict__ _Format,...);
/* __attribute__((__format__ (gnu_wscanf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vswscanf (const wchar_t * __restrict__ _Str,const wchar_t * __restrict__ Format,va_list argp);
/* __attribute__((__format__ (gnu_wscanf, 1, 2))) */ __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_wscanf(const wchar_t * __restrict__ _Format,...);
/* __attribute__((__format__ (gnu_wscanf, 1, 0))) */ __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_vwscanf(const wchar_t * __restrict__ Format, va_list argp);
/* __attribute__((__format__ (gnu_wscanf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_fwscanf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...);
/* __attribute__((__format__ (gnu_wscanf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vfwscanf (FILE * __restrict__ fp, const wchar_t * __restrict__ Format,va_list argp);

/* __attribute__((__format__ (gnu_wprintf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_fwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...);
/* __attribute__((__format__ (gnu_wprintf, 1, 2))) */ __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_wprintf(const wchar_t * __restrict__ _Format,...);
/* __attribute__((__format__ (gnu_wprintf, 2, 0))) */__MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vfwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,va_list _ArgList);
/*__attribute__((__format__ (gnu_wprintf, 1, 0))) */ __MINGW_ATTRIB_NONNULL(1)
  int __cdecl __mingw_vwprintf(const wchar_t * __restrict__ _Format,va_list _ArgList);
/* __attribute__((__format__ (gnu_wprintf, 3, 4))) */ __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __mingw_snwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, ...);
/* __attribute__((__format__ (gnu_wprintf, 3, 0))) */ __MINGW_ATTRIB_NONNULL(3)
  int __cdecl __mingw_vsnwprintf (wchar_t * __restrict__ , size_t, const wchar_t * __restrict__ , va_list);
/* __attribute__((__format__ (gnu_wprintf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_swprintf(wchar_t * __restrict__ , const wchar_t * __restrict__ , ...);
/* __attribute__((__format__ (gnu_wprintf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
  int __cdecl __mingw_vswprintf(wchar_t * __restrict__ , const wchar_t * __restrict__ ,va_list);

#ifdef _UCRT
  int __cdecl __stdio_common_vswprintf(unsigned __int64 options, wchar_t *str, size_t len, const wchar_t *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vfwprintf(unsigned __int64 options, FILE *file, const wchar_t *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vswscanf(unsigned __int64 options, const wchar_t *input, size_t length, const wchar_t *format, _locale_t locale, va_list valist);
  int __cdecl __stdio_common_vfwscanf(unsigned __int64 options, FILE *file, const wchar_t *format, _locale_t locale, va_list valist);
#endif

#if __USE_MINGW_ANSI_STDIO
/*
 * User has expressed a preference for C99 conformance...
 */

__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
int swscanf(const wchar_t *__source, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vswscanf( __source, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 1, 2))) */ __MINGW_ATTRIB_NONNULL(1)
int wscanf(const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwscanf( stdin, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
int fwscanf(FILE *__stream, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwscanf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */
__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
int vswscanf (const wchar_t * __restrict__ __source, const wchar_t * __restrict__ __format, __builtin_va_list __local_argv)
{
  return __mingw_vswscanf( __source, __format, __local_argv );
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 1, 0))) */ __MINGW_ATTRIB_NONNULL(1)
int vwscanf(const wchar_t *__format,  __builtin_va_list __local_argv)
{
  return __mingw_vfwscanf( stdin, __format, __local_argv );
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wscanf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
int vfwscanf (FILE *__stream,  const wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfwscanf( __stream, __format, __local_argv );
}
#endif /* __NO_ISOCEXT */



__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 2, 3))) */ __MINGW_ATTRIB_NONNULL(2)
int fwprintf (FILE *__stream, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 1, 2))) */ __MINGW_ATTRIB_NONNULL(1)
int wprintf (const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwprintf( stdout, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 2, 0))) */ __MINGW_ATTRIB_NONNULL(2)
int vfwprintf (FILE *__stream, const wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfwprintf( __stream, __format, __local_argv );
}

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 1, 0))) */ __MINGW_ATTRIB_NONNULL(1)
int vwprintf (const wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfwprintf( stdout, __format, __local_argv );
}

#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */

#if __MINGW_FORTIFY_VA_ARG

__mingw_bos_ovr
/* __attribute__((__format__ (gnu_wprintf, 3, 4))) */ __MINGW_ATTRIB_NONNULL(3)
int snwprintf (wchar_t *__stream, size_t __n, const wchar_t *__format, ...)
{
  __mingw_bos_ptr_chk_warn(__stream, __n * sizeof(wchar_t), 1);
  return __mingw_snwprintf( __stream, __n, __format, __builtin_va_arg_pack() );
}

#else /* !__MINGW_FORTIFY_VA_ARG */

__mingw_ovr
/* __attribute__((__format__ (gnu_wprintf, 3, 4))) */ __MINGW_ATTRIB_NONNULL(3)
int snwprintf (wchar_t *__stream, size_t __n, const wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsnwprintf( __stream, __n, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

#endif /* __MINGW_FORTIFY_VA_ARG */

__mingw_bos_ovr
/* __attribute__((__format__ (gnu_wprintf, 3, 0))) */ __MINGW_ATTRIB_NONNULL(3)
int vsnwprintf (wchar_t *__stream, size_t __n, const wchar_t *__format, __builtin_va_list __local_argv)
{
#if __MINGW_FORTIFY_LEVEL > 0
  __mingw_bos_ptr_chk_warn(__stream, __n * sizeof(wchar_t), 1);
#endif
  return __mingw_vsnwprintf( __stream, __n, __format, __local_argv );
}
#endif /* __NO_ISOCEXT */

#else /* !__USE_MINGW_ANSI_STDIO */

#ifdef _UCRT
  __mingw_ovr
  int __cdecl fwscanf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfwscanf(UCRTBASE_SCANF_DEFAULT_WIDE, _File, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl swscanf(const wchar_t * __restrict__ _Src,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vswscanf(UCRTBASE_SCANF_DEFAULT_WIDE, _Src, (size_t)-1, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl wscanf(const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfwscanf(UCRTBASE_SCANF_DEFAULT_WIDE, stdin, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(2)
  int vfwscanf (FILE *__stream,  const wchar_t *__format, va_list __local_argv)
  {
    return __stdio_common_vfwscanf(UCRTBASE_SCANF_DEFAULT_WIDE, __stream, __format, NULL, __local_argv);
  }

  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(2)
  int vswscanf (const wchar_t * __restrict__ __source, const wchar_t * __restrict__ __format, va_list __local_argv)
  {
    return __stdio_common_vswscanf(UCRTBASE_SCANF_DEFAULT_WIDE, __source, (size_t)-1, __format, NULL, __local_argv);
  }
  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(1)
  int vwscanf(const wchar_t *__format, va_list __local_argv)
  {
    return __stdio_common_vfwscanf(UCRTBASE_SCANF_DEFAULT_WIDE, stdin, __format, NULL, __local_argv);
  }

  __mingw_static_ovr
  int __cdecl fwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfwprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, _File, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl wprintf(const wchar_t * __restrict__ _Format,...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vfwprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, stdout, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl vfwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,va_list _ArgList)
  {
    return __stdio_common_vfwprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, _File, _Format, NULL, _ArgList);
  }
  __mingw_ovr
  int __cdecl vwprintf(const wchar_t * __restrict__ _Format,va_list _ArgList)
  {
    return __stdio_common_vfwprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, stdout, _Format, NULL, _ArgList);
  }
#else

  int __cdecl fwscanf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl swscanf(const wchar_t * __restrict__ _Src,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl wscanf(const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */
  int __cdecl __ms_vwscanf (const wchar_t * __restrict__ , va_list);
  int __cdecl __ms_vfwscanf (FILE * __restrict__ ,const wchar_t * __restrict__ ,va_list);
  int __cdecl __ms_vswscanf (const wchar_t * __restrict__ ,const wchar_t * __restrict__ ,va_list);

  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(2)
  int vfwscanf (FILE *__stream,  const wchar_t *__format, __builtin_va_list __local_argv)
  {
    return __ms_vfwscanf (__stream, __format, __local_argv);
  }

  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(2)
  int vswscanf (const wchar_t * __restrict__ __source, const wchar_t * __restrict__ __format, __builtin_va_list __local_argv)
  {
    return __ms_vswscanf( __source, __format, __local_argv );
  }
  __mingw_ovr
  __MINGW_ATTRIB_NONNULL(1)
  int vwscanf(const wchar_t *__format,  __builtin_va_list __local_argv)
  {
    return __ms_vwscanf (__format, __local_argv);
  }

#endif /* __NO_ISOCEXT */

  int __cdecl fwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,...);
  int __cdecl wprintf(const wchar_t * __restrict__ _Format,...);
  int __cdecl vfwprintf(FILE * __restrict__ _File,const wchar_t * __restrict__ _Format,va_list _ArgList);
  int __cdecl vwprintf(const wchar_t * __restrict__ _Format,va_list _ArgList);
#endif /* _UCRT */
#endif /* __USE_MINGW_ANSI_STDIO */

#ifndef WEOF
#define WEOF (wint_t)(0xFFFF)
#endif

#ifdef _POSIX_
  _CRTIMP FILE *__cdecl _wfsopen(const wchar_t *_Filename,const wchar_t *_Mode);
#else
  _CRTIMP FILE *__cdecl _wfsopen(const wchar_t *_Filename,const wchar_t *_Mode,int _ShFlag);
#endif

  wint_t __cdecl fgetwc(FILE *_File);
  _CRTIMP wint_t __cdecl _fgetwchar(void);
  wint_t __cdecl fputwc(wchar_t _Ch,FILE *_File);
  _CRTIMP wint_t __cdecl _fputwchar(wchar_t _Ch);
  wint_t __cdecl getwc(FILE *_File);
  wint_t __cdecl getwchar(void);
  wint_t __cdecl putwc(wchar_t _Ch,FILE *_File);
  wint_t __cdecl putwchar(wchar_t _Ch);
  wint_t __cdecl ungetwc(wint_t _Ch,FILE *_File);
  wchar_t *__cdecl fgetws(wchar_t * __restrict__ _Dst,int _SizeInWords,FILE * __restrict__ _File);
  int __cdecl fputws(const wchar_t * __restrict__ _Str,FILE * __restrict__ _File);
  _CRTIMP wchar_t *__cdecl _getws(wchar_t *_String) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _putws(const wchar_t *_Str);

#ifdef _UCRT
  __mingw_ovr
  int __cdecl _scwprintf(const wchar_t * __restrict__ _Format,...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE | UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, NULL, 0, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_static_ovr
  int __cdecl _snwprintf(wchar_t * __restrict__ _Dest,size_t _Count,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE | UCRTBASE_PRINTF_LEGACY_VSPRINTF_NULL_TERMINATION, _Dest, _Count, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  int __cdecl _vsnwprintf(wchar_t * __restrict__ _Dest,size_t _Count,const wchar_t * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

#if __USE_MINGW_ANSI_STDIO == 0
  __mingw_ovr
  int snwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, ...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, format);
    ret = __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE | UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, s, n, format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl vsnwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, va_list arg)
  {
    return __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE | UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, s, n, format, NULL, arg);
  }
#endif

  __mingw_ovr
  int __cdecl _swprintf(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Format,...)
  {
    __builtin_va_list ap;
    int ret;
    __builtin_va_start(ap, _Format);
    ret = __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, _Dest, (size_t)-1, _Format, NULL, ap);
    __builtin_va_end(ap);
    return ret;
  }
  __mingw_ovr
  int __cdecl _vswprintf(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Format,va_list _Args)
  {
    return __stdio_common_vswprintf(UCRTBASE_PRINTF_DEFAULT_WIDE, _Dest, (size_t)-1, _Format, NULL, _Args);
  }

  __mingw_ovr
  int __cdecl _vscwprintf(const wchar_t * __restrict__ _Format, va_list _ArgList)
  {
      int _Result = __stdio_common_vswprintf(UCRTBASE_PRINTF_STANDARD_SNPRINTF_BEHAVIOUR, NULL, 0, _Format, NULL, _ArgList);
      return _Result < 0 ? -1 : _Result;
  }
#else
  _CRTIMP int __cdecl _scwprintf(const wchar_t * __restrict__ _Format,...);
  _CRTIMP int __cdecl _swprintf_c(wchar_t * __restrict__ _DstBuf,size_t _SizeInWords,const wchar_t * __restrict__ _Format,...);
  _CRTIMP int __cdecl _vswprintf_c(wchar_t * __restrict__ _DstBuf,size_t _SizeInWords,const wchar_t * __restrict__ _Format,va_list _ArgList);
  _CRTIMP int __cdecl _snwprintf(wchar_t * __restrict__ _Dest,size_t _Count,const wchar_t * __restrict__ _Format,...) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _vsnwprintf(wchar_t * __restrict__ _Dest,size_t _Count,const wchar_t * __restrict__ _Format,va_list _Args) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _vscwprintf(const wchar_t * __restrict__ _Format,va_list _ArgList);

#ifndef __NO_ISOCEXT  /* externs in libmingwex.a */

#if __USE_MINGW_ANSI_STDIO == 0
#pragma push_macro("snwprintf")
#pragma push_macro("vsnwprintf")
# undef snwprintf
# undef vsnwprintf
  int __cdecl __ms_snwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, ...);
  int __cdecl __ms_vsnwprintf (wchar_t * __restrict__ , size_t, const wchar_t * __restrict__ , va_list);
  __mingw_ovr
  int snwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, ...)
  {
    int r;
    va_list argp;
    __builtin_va_start (argp, format);
    r = _vsnwprintf (s, n, format, argp);
    __builtin_va_end (argp);
    return r;
  }
  __mingw_ovr
  int __cdecl vsnwprintf (wchar_t * __restrict__ s, size_t n, const wchar_t * __restrict__ format, va_list arg)
  {
    return _vsnwprintf(s,n,format,arg);
  }
#pragma pop_macro ("vsnwprintf")
#pragma pop_macro ("snwprintf")
#endif

#endif /* ! __NO_ISOCEXT */
  _CRTIMP int __cdecl _swprintf(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Format,...);
  _CRTIMP int __cdecl _vswprintf(wchar_t * __restrict__ _Dest,const wchar_t * __restrict__ _Format,va_list _Args);
#endif /* _UCRT */

#ifndef RC_INVOKED
#include <swprintf.inl>
#endif

#ifdef _CRT_NON_CONFORMING_SWPRINTFS
#ifndef __cplusplus
#define _swprintf_l __swprintf_l
#define _vswprintf_l __vswprintf_l
#endif
#endif

  _CRTIMP wchar_t *__cdecl _wtempnam(const wchar_t *_Directory,const wchar_t *_FilePrefix);
  _CRTIMP int __cdecl _snwscanf(const wchar_t * __restrict__ _Src,size_t _MaxCount,const wchar_t * __restrict__ _Format,...);
  _CRTIMP FILE *__cdecl _wfdopen(int _FileHandle ,const wchar_t *_Mode);
  _CRTIMP FILE *__cdecl _wfopen(const wchar_t * __restrict__ _Filename,const wchar_t *__restrict__  _Mode) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP FILE *__cdecl _wfreopen(const wchar_t * __restrict__ _Filename,const wchar_t * __restrict__ _Mode,FILE * __restrict__ _OldFile) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

#ifndef _CRT_WPERROR_DEFINED
#define _CRT_WPERROR_DEFINED
  _CRTIMP void __cdecl _wperror(const wchar_t *_ErrMsg);
#endif
  _CRTIMP FILE *__cdecl _wpopen(const wchar_t *_Command,const wchar_t *_Mode);
#if !defined(NO_OLDNAMES) && !defined(wpopen)
#define wpopen	_wpopen
#endif

  _CRTIMP int __cdecl _wremove(const wchar_t *_Filename);
  _CRTIMP wchar_t *__cdecl _wtmpnam(wchar_t *_Buffer);
  _CRTIMP wint_t __cdecl _fgetwc_nolock(FILE *_File);
  _CRTIMP wint_t __cdecl _fputwc_nolock(wchar_t _Ch,FILE *_File);
  _CRTIMP wint_t __cdecl _ungetwc_nolock(wint_t _Ch,FILE *_File);

#undef _CRT_GETPUTWCHAR_NOINLINE

#if !defined(__cplusplus) || defined(_CRT_GETPUTWCHAR_NOINLINE) || defined (__CRT__NO_INLINE)
#define getwchar() fgetwc(stdin)
#define putwchar(_c) fputwc((_c),stdout)
#else
  __CRT_INLINE wint_t __cdecl getwchar() {return (fgetwc(stdin)); }
  __CRT_INLINE wint_t __cdecl putwchar(wchar_t _C) {return (fputwc(_C,stdout)); }
#endif

#define getwc(_stm) fgetwc(_stm)
#define putwc(_c,_stm) fputwc(_c,_stm)
#define _putwc_nolock(_c,_stm) _fputwc_nolock(_c,_stm)
#define _getwc_nolock(_c) _fgetwc_nolock(_c)
#endif

#define _STDIO_DEFINED
#endif

#ifdef _UCRT
  _CRTIMP int __cdecl _fgetc_nolock(FILE *_File);
  _CRTIMP int __cdecl _fputc_nolock(int _Char, FILE *_File);
  _CRTIMP int __cdecl _getc_nolock(FILE *_File);
  _CRTIMP int __cdecl _putc_nolock(int _Char, FILE *_File);
#else
#define _fgetc_nolock(_stream) (--(_stream)->_cnt >= 0 ? 0xff & *(_stream)->_ptr++ : _filbuf(_stream))
#define _fputc_nolock(_c,_stream) (--(_stream)->_cnt >= 0 ? 0xff & (*(_stream)->_ptr++ = (char)(_c)) : _flsbuf((_c),(_stream)))
#define _getc_nolock(_stream) _fgetc_nolock(_stream)
#define _putc_nolock(_c,_stream) _fputc_nolock(_c,_stream)
#endif
#define _getchar_nolock() _getc_nolock(stdin)
#define _putchar_nolock(_c) _putc_nolock((_c),stdout)
#define _getwchar_nolock() _getwc_nolock(stdin)
#define _putwchar_nolock(_c) _putwc_nolock((_c),stdout)

  _CRTIMP void __cdecl _lock_file(FILE *_File);
  _CRTIMP void __cdecl _unlock_file(FILE *_File);
  _CRTIMP int __cdecl _fclose_nolock(FILE *_File);
  _CRTIMP int __cdecl _fflush_nolock(FILE *_File);
  _CRTIMP size_t __cdecl _fread_nolock(void * __restrict__ _DstBuf,size_t _ElementSize,size_t _Count,FILE * __restrict__ _File);
  _CRTIMP int __cdecl _fseek_nolock(FILE *_File,long _Offset,int _Origin);
  _CRTIMP long __cdecl _ftell_nolock(FILE *_File);
  __MINGW_EXTENSION _CRTIMP int __cdecl _fseeki64_nolock(FILE *_File,__int64 _Offset,int _Origin);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _ftelli64_nolock(FILE *_File);
  _CRTIMP size_t __cdecl _fwrite_nolock(const void * __restrict__ _DstBuf,size_t _Size,size_t _Count,FILE * __restrict__ _File);
  _CRTIMP int __cdecl _ungetc_nolock(int _Ch,FILE *_File);

#if !defined(NO_OLDNAMES) || !defined(_POSIX)
#define P_tmpdir _P_tmpdir
#define SYS_OPEN _SYS_OPEN

  char *__cdecl tempnam(const char *_Directory,const char *_FilePrefix) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl fcloseall(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  FILE *__cdecl fdopen(int _FileHandle,const char *_Format) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl fgetchar(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl fileno(FILE *_File) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl flushall(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl fputchar(int _Ch) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl getw(FILE *_File) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl putw(int _Ch,FILE *_File) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl rmtmp(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

#ifndef __MINGW_MBWC_CONVERT_DEFINED
#define __MINGW_MBWC_CONVERT_DEFINED

/**
 * __mingw_str_wide_utf8
 * Converts a null terminated UCS-2 string to a multibyte (UTF-8) equivalent.
 * Caller is supposed to free allocated buffer with __mingw_str_free().
 * @param[in] wptr Pointer to wide string.
 * @param[out] mbptr Pointer to multibyte string.
 * @param[out] buflen Optional parameter for length of allocated buffer.
 * @return Number of characters converted, 0 for failure.
 *
 * WideCharToMultiByte - http://msdn.microsoft.com/en-us/library/dd374130(VS.85).aspx
 */
int __cdecl __mingw_str_wide_utf8 (const wchar_t * const wptr, char **mbptr, size_t * buflen);

/**
 * __mingw_str_utf8_wide
 * Converts a null terminated UTF-8 string to a UCS-2 equivalent.
 * Caller is supposed to free allocated buffer with __mingw_str_free().
 * @param[out] mbptr Pointer to multibyte string.
 * @param[in] wptr Pointer to wide string.
 * @param[out] buflen Optional parameter for length of allocated buffer.
 * @return Number of characters converted, 0 for failure.
 *
 * MultiByteToWideChar - http://msdn.microsoft.com/en-us/library/dd319072(VS.85).aspx
 */

int __cdecl __mingw_str_utf8_wide (const char *const mbptr, wchar_t ** wptr, size_t * buflen);

/**
 * __mingw_str_free
 * Frees buffer create by __mingw_str_wide_utf8 and __mingw_str_utf8_wide.
 * @param[in] ptr memory block to free.
 *
 */

void __cdecl __mingw_str_free(void *ptr);

#endif /* __MINGW_MBWC_CONVERT_DEFINED */

#ifndef _WSPAWN_DEFINED
#define _WSPAWN_DEFINED
  _CRTIMP intptr_t __cdecl _wspawnl(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnle(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnlp(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnlpe(int _Mode,const wchar_t *_Filename,const wchar_t *_ArgList,...);
  _CRTIMP intptr_t __cdecl _wspawnv(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wspawnve(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
  _CRTIMP intptr_t __cdecl _wspawnvp(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList);
  _CRTIMP intptr_t __cdecl _wspawnvpe(int _Mode,const wchar_t *_Filename,const wchar_t *const *_ArgList,const wchar_t *const *_Env);
#endif

#ifndef _P_WAIT
#define _P_WAIT 0
#define _P_NOWAIT 1
#define _OLD_P_OVERLAY 2
#define _P_NOWAITO 3
#define _P_DETACH 4
#define _P_OVERLAY 2

#define _WAIT_CHILD 0
#define _WAIT_GRANDCHILD 1
#endif

#ifndef _SPAWNV_DEFINED
#define _SPAWNV_DEFINED
  _CRTIMP intptr_t __cdecl _spawnv(int _Mode,const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _spawnve(int _Mode,const char *_Filename,const char *const *_ArgList,const char *const *_Env);
  _CRTIMP intptr_t __cdecl _spawnvp(int _Mode,const char *_Filename,const char *const *_ArgList);
  _CRTIMP intptr_t __cdecl _spawnvpe(int _Mode,const char *_Filename,const char *const *_ArgList,const char *const *_Env);
#endif

#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#include <sec_api/stdio_s.h>

#endif
