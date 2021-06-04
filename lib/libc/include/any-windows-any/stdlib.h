/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STDLIB
#define _INC_STDLIB

#include <corecrt.h>
#include <corecrt_wstdlib.h>
#include <limits.h>

#if __USE_MINGW_ANSI_STDIO && !defined (__USE_MINGW_STRTOX) && !defined(_CRTBLD)
#define __USE_MINGW_STRTOX 1
#endif

#if defined(__LIBMSVCRT__)
/* When building mingw-w64, this should be blank.  */
#define _SECIMP
#else
#ifndef _SECIMP
#define _SECIMP __declspec(dllimport)
#endif /* _SECIMP */
#endif /* defined(_CRTBLD) || defined(__LIBMSVCRT__) */

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

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

#define EXIT_SUCCESS 0
#define EXIT_FAILURE 1

#ifndef _ONEXIT_T_DEFINED
#define _ONEXIT_T_DEFINED

  typedef int (__cdecl *_onexit_t)(void);

#ifndef	NO_OLDNAMES
#define onexit_t _onexit_t
#endif
#endif

#ifndef _DIV_T_DEFINED
#define _DIV_T_DEFINED

  typedef struct _div_t {
    int quot;
    int rem;
  } div_t;

  typedef struct _ldiv_t {
    long quot;
    long rem;
  } ldiv_t;
#endif

#ifndef _CRT_DOUBLE_DEC
#define _CRT_DOUBLE_DEC

#pragma pack(4)
  typedef struct {
    unsigned char ld[10];
  } _LDOUBLE;
#pragma pack()

#define _PTR_LD(x) ((unsigned char *)(&(x)->ld))

  typedef struct {
    double x;
  } _CRT_DOUBLE;

  typedef struct {
    float f;
  } _CRT_FLOAT;

#pragma push_macro("long")
#undef long

  typedef struct {
    long double x;
  } _LONGDOUBLE;

#pragma pop_macro("long")

#pragma pack(4)
  typedef struct {
    unsigned char ld12[12];
  } _LDBL12;
#pragma pack()
#endif

#define RAND_MAX 0x7fff

#ifndef MB_CUR_MAX
#define MB_CUR_MAX ___mb_cur_max_func()
#ifndef __mb_cur_max
#ifdef _MSVCRT_
  extern int __mb_cur_max;
#define __mb_cur_max	__mb_cur_max
#else
#ifndef _UCRT
  extern int * __MINGW_IMP_SYMBOL(__mb_cur_max);
#endif
#define __mb_cur_max	(___mb_cur_max_func())
#endif
#endif
_CRTIMP int __cdecl ___mb_cur_max_func(void);
#endif

#define __max(a,b) (((a) > (b)) ? (a) : (b))
#define __min(a,b) (((a) < (b)) ? (a) : (b))

#define _MAX_PATH 260
#define _MAX_DRIVE 3
#define _MAX_DIR 256
#define _MAX_FNAME 256
#define _MAX_EXT 256

#define _OUT_TO_DEFAULT 0
#define _OUT_TO_STDERR 1
#define _OUT_TO_MSGBOX 2
#define _REPORT_ERRMODE 3

#define _WRITE_ABORT_MSG 0x1
#define _CALL_REPORTFAULT 0x2

#define _MAX_ENV 32767

  typedef void (__cdecl *_purecall_handler)(void);

  _CRTIMP _purecall_handler __cdecl _set_purecall_handler(_purecall_handler _Handler);
  _CRTIMP _purecall_handler __cdecl _get_purecall_handler(void);

  typedef void (__cdecl *_invalid_parameter_handler)(const wchar_t *,const wchar_t *,const wchar_t *,unsigned int,uintptr_t);
  _CRTIMP _invalid_parameter_handler __cdecl _set_invalid_parameter_handler(_invalid_parameter_handler _Handler);
  _CRTIMP _invalid_parameter_handler __cdecl _get_invalid_parameter_handler(void);

#ifndef _CRT_ERRNO_DEFINED
#define _CRT_ERRNO_DEFINED
  _CRTIMP extern int *__cdecl _errno(void);
#define errno (*_errno())
  errno_t __cdecl _set_errno(int _Value);
  errno_t __cdecl _get_errno(int *_Value);
#endif
  _CRTIMP unsigned long *__cdecl __doserrno(void);
#define _doserrno (*__doserrno())
  errno_t __cdecl _set_doserrno(unsigned long _Value);
  errno_t __cdecl _get_doserrno(unsigned long *_Value);
#ifdef _MSVCRT_
  extern char *_sys_errlist[];
  extern int _sys_nerr;
#else
#ifdef _UCRT
  _CRTIMP char **__cdecl __sys_errlist(void);
  _CRTIMP int *__cdecl __sys_nerr(void);
#define _sys_nerr (*__sys_nerr())
#define _sys_errlist (__sys_errlist())
#else
  extern __declspec(dllimport) char *_sys_errlist[1];
  extern __declspec(dllimport) int _sys_nerr;
#endif /* !_UCRT */
#endif

  /* We have a fallback definition of __p___argv and __p__fmode for
     msvcrt versions that lack it. */
  _CRTIMP char ***__cdecl __p___argv(void);
  _CRTIMP int *__cdecl __p__fmode(void);
#if (defined(_X86_) && !defined(__x86_64)) || defined(_UCRT)
  _CRTIMP int *__cdecl __p___argc(void);
  _CRTIMP wchar_t ***__cdecl __p___wargv(void);
  _CRTIMP char ***__cdecl __p__environ(void);
  _CRTIMP wchar_t ***__cdecl __p__wenviron(void);
  _CRTIMP char **__cdecl __p__pgmptr(void);
  _CRTIMP wchar_t **__cdecl __p__wpgmptr(void);
#endif

  errno_t __cdecl _get_pgmptr(char **_Value);
  errno_t __cdecl _get_wpgmptr(wchar_t **_Value);
  _CRTIMP errno_t __cdecl _set_fmode(int _Mode);
  _CRTIMP errno_t __cdecl _get_fmode(int *_PMode);

#ifndef _fmode
#define _fmode (* __p__fmode())
#endif

#ifdef _MSVCRT_

#ifndef __argc
  extern int __argc;
#endif
#ifndef __argv
  extern char **__argv;
#endif
#ifndef __wargv
  extern wchar_t **__wargv;
#endif

#ifndef _POSIX_
#ifndef _environ
  extern char **_environ;
#endif
#ifndef _wenviron
  extern wchar_t **_wenviron;
#endif
#endif /* !_POSIX_ */

#ifndef _pgmptr
  extern char *_pgmptr;
#endif

#ifndef _wpgmptr
  extern wchar_t *_wpgmptr;
#endif

#ifndef _osplatform
  extern unsigned int _osplatform;
#endif

#ifndef _osver
  extern unsigned int _osver;
#endif

#ifndef _winver
  extern unsigned int _winver;
#endif

#ifndef _winmajor
  extern unsigned int _winmajor;
#endif

#ifndef _winminor
  extern unsigned int _winminor;
#endif

#elif defined(_UCRT)

#ifndef __argc
#define __argc (* __p___argc())
#endif
#ifndef __argv
#define __argv (* __p___argv())
#endif
#ifndef __wargv
#define __wargv (* __p___wargv())
#endif

#ifndef _POSIX_
#ifndef _environ
#define _environ (* __p__environ())
#endif

#ifndef _wenviron
#define _wenviron (* __p__wenviron())
#endif
#endif /* !_POSIX_ */

#ifndef _pgmptr
#define _pgmptr (* __p__pgmptr())
#endif

#ifndef _wpgmptr
#define _wpgmptr (* __p__wpgmptr())
#endif

#else /* _UCRT */

#ifndef __argc
  extern int * __MINGW_IMP_SYMBOL(__argc);
#define __argc (* __MINGW_IMP_SYMBOL(__argc))
#endif
#ifndef __argv
  extern char *** __MINGW_IMP_SYMBOL(__argv);
#define __argv	(* __p___argv())
#endif
#ifndef __wargv
  extern wchar_t *** __MINGW_IMP_SYMBOL(__wargv);
#define __wargv (* __MINGW_IMP_SYMBOL(__wargv))
#endif

#ifndef _POSIX_
#if (defined(_ARM_) || defined(__arm__) || defined(_ARM64_) || defined(__aarch64__))
  /* The plain msvcrt.dll for arm/aarch64 (and msvcr120_app.dll for arm) lacks
   * _environ/_wenviron, but has these functions instead. */
  _CRTIMP void __cdecl _get_environ(char ***);
  _CRTIMP void __cdecl _get_wenviron(wchar_t ***);

  static __inline char **__get_environ_ptr(void) {
    char **__ptr;
    _get_environ(&__ptr);
    return __ptr;
  }

  static __inline wchar_t **__get_wenviron_ptr(void) {
    wchar_t **__ptr;
    _get_wenviron(&__ptr);
    return __ptr;
  }

#ifndef _environ
#define _environ (__get_environ_ptr())
#endif

#ifndef _wenviron
#define _wenviron (__get_wenviron_ptr())
#endif
#else /* ARM/ARM64 */
#ifndef _environ
  extern char *** __MINGW_IMP_SYMBOL(_environ);
#define _environ (* __MINGW_IMP_SYMBOL(_environ))
#endif

#ifndef _wenviron
  extern wchar_t *** __MINGW_IMP_SYMBOL(_wenviron);
#define _wenviron (* __MINGW_IMP_SYMBOL(_wenviron))
#endif
#endif /* !ARM/ARM64 */
#endif /* !_POSIX_ */

#ifndef _pgmptr
  extern char ** __MINGW_IMP_SYMBOL(_pgmptr);
#define _pgmptr	(* __MINGW_IMP_SYMBOL(_pgmptr))
#endif

#ifndef _wpgmptr
  extern wchar_t ** __MINGW_IMP_SYMBOL(_wpgmptr);
#define _wpgmptr (* __MINGW_IMP_SYMBOL(_wpgmptr))
#endif

#ifndef _osplatform
  extern unsigned int * __MINGW_IMP_SYMBOL(_osplatform);
#define _osplatform (* __MINGW_IMP_SYMBOL(_osplatform))
#endif

#ifndef _osver
  extern unsigned int * __MINGW_IMP_SYMBOL(_osver);
#define _osver	(* __MINGW_IMP_SYMBOL(_osver))
#endif

#ifndef _winver
  extern unsigned int * __MINGW_IMP_SYMBOL(_winver);
#define _winver	(* __MINGW_IMP_SYMBOL(_winver))
#endif

#ifndef _winmajor
  extern unsigned int * __MINGW_IMP_SYMBOL(_winmajor);
#define _winmajor (* __MINGW_IMP_SYMBOL(_winmajor))
#endif

#ifndef _winminor
  extern unsigned int * __MINGW_IMP_SYMBOL(_winminor);
#define _winminor (* __MINGW_IMP_SYMBOL(_winminor))
#endif

#endif /* !_MSVCRT_ && !_UCRT */

  errno_t __cdecl _get_osplatform(unsigned int *_Value);
  errno_t __cdecl _get_osver(unsigned int *_Value);
  errno_t __cdecl _get_winver(unsigned int *_Value);
  errno_t __cdecl _get_winmajor(unsigned int *_Value);
  errno_t __cdecl _get_winminor(unsigned int *_Value);
#ifndef _countof
#ifndef __cplusplus
#define _countof(_Array) (sizeof(_Array) / sizeof(_Array[0]))
#else
  extern "C++" {
    template <typename _CountofType,size_t _SizeOfArray> char (*__countof_helper(UNALIGNED _CountofType (&_Array)[_SizeOfArray]))[_SizeOfArray];
#define _countof(_Array) sizeof(*__countof_helper(_Array))
  }
#endif
#endif

#ifndef _CRT_TERMINATE_DEFINED
#define _CRT_TERMINATE_DEFINED
  void __cdecl __MINGW_NOTHROW exit(int _Code) __MINGW_ATTRIB_NORETURN;
  void __cdecl __MINGW_NOTHROW _exit(int _Code) __MINGW_ATTRIB_NORETURN;
#ifdef _UCRT
  void __cdecl __MINGW_NOTHROW quick_exit(int _Code) __MINGW_ATTRIB_NORETURN;
#endif

#if !defined __NO_ISOCEXT /* extern stub in static libmingwex.a */
  /* C99 function name */
  void __cdecl _Exit(int) __MINGW_ATTRIB_NORETURN;
#ifndef __CRT__NO_INLINE
  __CRT_INLINE __MINGW_ATTRIB_NORETURN void  __cdecl _Exit(int status)
  {  _exit(status); }
#endif /* !__CRT__NO_INLINE */
#endif /* Not  __NO_ISOCEXT */

#pragma push_macro("abort")
#undef abort
  void __cdecl __MINGW_ATTRIB_NORETURN abort(void);
#pragma pop_macro("abort")

#endif /* _CRT_TERMINATE_DEFINED */

  _CRTIMP unsigned int __cdecl _set_abort_behavior(unsigned int _Flags,unsigned int _Mask);

#ifndef _CRT_ABS_DEFINED
#define _CRT_ABS_DEFINED
  int __cdecl abs(int _X);
  long __cdecl labs(long _X);
#endif

  __MINGW_EXTENSION __int64 __cdecl _abs64(__int64);
#ifdef __MINGW_INTRIN_INLINE
  __MINGW_INTRIN_INLINE __int64 __cdecl _abs64(__int64 x) {
    return __builtin_llabs(x);
  }
#endif

  int __cdecl atexit(void (__cdecl *)(void));
#ifdef _UCRT
  int __cdecl at_quick_exit(void (__cdecl *)(void));
#endif
#ifndef _CRT_ATOF_DEFINED
#define _CRT_ATOF_DEFINED
  double __cdecl atof(const char *_String);
  double __cdecl _atof_l(const char *_String,_locale_t _Locale);
#endif
  int __cdecl atoi(const char *_Str);
  _CRTIMP int __cdecl _atoi_l(const char *_Str,_locale_t _Locale);
  long __cdecl atol(const char *_Str);
  _CRTIMP long __cdecl _atol_l(const char *_Str,_locale_t _Locale);
#ifndef _CRT_ALGO_DEFINED
#define _CRT_ALGO_DEFINED
  void *__cdecl bsearch(const void *_Key,const void *_Base,size_t _NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(const void *,const void *));
  void __cdecl qsort(void *_Base,size_t _NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(const void *,const void *));
#endif
  unsigned short __cdecl _byteswap_ushort(unsigned short _Short);
  unsigned long __cdecl _byteswap_ulong (unsigned long _Long);
  __MINGW_EXTENSION unsigned __int64 __cdecl _byteswap_uint64(unsigned __int64 _Int64);
  div_t __cdecl div(int _Numerator,int _Denominator);
  char *__cdecl getenv(const char *_VarName) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _itoa(int _Value,char *_Dest,int _Radix);
  __MINGW_EXTENSION _CRTIMP char *__cdecl _i64toa(__int64 _Val,char *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __MINGW_EXTENSION _CRTIMP char *__cdecl _ui64toa(unsigned __int64 _Val,char *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _atoi64(const char *_String);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _atoi64_l(const char *_String,_locale_t _Locale);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _strtoi64(const char *_String,char **_EndPtr,int _Radix);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _strtoi64_l(const char *_String,char **_EndPtr,int _Radix,_locale_t _Locale);
  __MINGW_EXTENSION _CRTIMP unsigned __int64 __cdecl _strtoui64(const char *_String,char **_EndPtr,int _Radix);
  __MINGW_EXTENSION _CRTIMP unsigned __int64 __cdecl _strtoui64_l(const char *_String,char **_EndPtr,int _Radix,_locale_t _Locale);
  ldiv_t __cdecl ldiv(long _Numerator,long _Denominator);
  _CRTIMP char *__cdecl _ltoa(long _Value,char *_Dest,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl mblen(const char *_Ch,size_t _MaxCount);
  _CRTIMP int __cdecl _mblen_l(const char *_Ch,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbstrlen(const char *_Str);
  _CRTIMP size_t __cdecl _mbstrlen_l(const char *_Str,_locale_t _Locale);
  _CRTIMP size_t __cdecl _mbstrnlen(const char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _mbstrnlen_l(const char *_Str,size_t _MaxCount,_locale_t _Locale);
  int __cdecl mbtowc(wchar_t * __restrict__ _DstCh,const char * __restrict__ _SrcCh,size_t _SrcSizeInBytes);
  _CRTIMP int __cdecl _mbtowc_l(wchar_t * __restrict__ _DstCh,const char * __restrict__ _SrcCh,size_t _SrcSizeInBytes,_locale_t _Locale);
  size_t __cdecl mbstowcs(wchar_t * __restrict__ _Dest,const char * __restrict__ _Source,size_t _MaxCount);
  _CRTIMP size_t __cdecl _mbstowcs_l(wchar_t * __restrict__ _Dest,const char * __restrict__ _Source,size_t _MaxCount,_locale_t _Locale);
  int __cdecl mkstemp(char *template_name);
  int __cdecl rand(void);
  _CRTIMP int __cdecl _set_error_mode(int _Mode);
  void __cdecl srand(unsigned int _Seed);
#if defined(_POSIX) || defined(_POSIX_THREAD_SAFE_FUNCTIONS)
  #ifndef rand_r
  #define rand_r(__seed) (__seed == __seed ? rand () : rand ())
  #endif
#endif
#ifdef _CRT_RAND_S
  _SECIMP errno_t __cdecl rand_s(unsigned int *randomValue);
#endif

#if defined(__USE_MINGW_STRTOX)
__mingw_ovr
double __cdecl __MINGW_NOTHROW strtod(const char * __restrict__ _Str,char ** __restrict__ _EndPtr)
{
  double __cdecl __mingw_strtod (const char * __restrict__, char ** __restrict__);
  return __mingw_strtod( _Str, _EndPtr);
}

__mingw_ovr
float __cdecl __MINGW_NOTHROW strtof(const char * __restrict__ _Str,char ** __restrict__ _EndPtr)
{
  float __cdecl __mingw_strtof (const char * __restrict__, char ** __restrict__);
  return __mingw_strtof( _Str, _EndPtr);
}

/* strtold is already an alias to __mingw_strtold */
#else
  double __cdecl __MINGW_NOTHROW strtod(const char * __restrict__ _Str,char ** __restrict__ _EndPtr);
  float __cdecl __MINGW_NOTHROW strtof(const char * __restrict__ nptr, char ** __restrict__ endptr);
#endif /* defined(__USE_MINGW_STRTOX) */
  long double __cdecl __MINGW_NOTHROW strtold(const char * __restrict__ , char ** __restrict__ );
#if !defined __NO_ISOCEXT
  /* libmingwex.a provides a c99-compliant strtod() exported as __strtod() */
  extern double __cdecl __MINGW_NOTHROW
  __strtod (const char * __restrict__ , char ** __restrict__);
/* The UCRT version of strtod is C99 compliant, so we don't need to redirect it to the mingw version. */
#if !defined(__USE_MINGW_STRTOX) && !defined(_UCRT)
#define strtod __strtod
#endif /* !defined(__USE_MINGW_STRTOX) */
#endif /* __NO_ISOCEXT */

#if !defined __NO_ISOCEXT  /* in libmingwex.a */
  float __cdecl __mingw_strtof (const char * __restrict__, char ** __restrict__);
  double __cdecl __mingw_strtod (const char * __restrict__, char ** __restrict__);
  long double __cdecl __mingw_strtold(const char * __restrict__, char ** __restrict__);
#endif /* __NO_ISOCEXT */
  _CRTIMP double __cdecl _strtod_l(const char * __restrict__ _Str,char ** __restrict__ _EndPtr,_locale_t _Locale);
  long __cdecl strtol(const char * __restrict__ _Str,char ** __restrict__ _EndPtr,int _Radix);
  _CRTIMP long __cdecl _strtol_l(const char * __restrict__ _Str,char ** __restrict__ _EndPtr,int _Radix,_locale_t _Locale);
  unsigned long __cdecl strtoul(const char * __restrict__ _Str,char ** __restrict__ _EndPtr,int _Radix);
  _CRTIMP unsigned long __cdecl _strtoul_l(const char * __restrict__ _Str,char ** __restrict__ _EndPtr,int _Radix,_locale_t _Locale);
#ifndef _CRT_SYSTEM_DEFINED
#define _CRT_SYSTEM_DEFINED
  int __cdecl system(const char *_Command);
#endif
  _CRTIMP char *__cdecl _ultoa(unsigned long _Value,char *_Dest,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  int __cdecl wctomb(char *_MbCh,wchar_t _WCh) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _wctomb_l(char *_MbCh,wchar_t _WCh,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  size_t __cdecl wcstombs(char * __restrict__ _Dest,const wchar_t * __restrict__ _Source,size_t _MaxCount) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP size_t __cdecl _wcstombs_l(char * __restrict__ _Dest,const wchar_t * __restrict__ _Source,size_t _MaxCount,_locale_t _Locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

#ifndef _CRT_ALLOCATION_DEFINED
#define _CRT_ALLOCATION_DEFINED
  void *__cdecl calloc(size_t _NumOfElements,size_t _SizeOfElements);
  void __cdecl free(void *_Memory);
  void *__cdecl malloc(size_t _Size);
  void *__cdecl realloc(void *_Memory,size_t _NewSize);
  _CRTIMP void *__cdecl _recalloc(void *_Memory,size_t _Count,size_t _Size);
  _CRTIMP void __cdecl _aligned_free(void *_Memory);
  _CRTIMP void *__cdecl _aligned_malloc(size_t _Size,size_t _Alignment);
  _CRTIMP void *__cdecl _aligned_offset_malloc(size_t _Size,size_t _Alignment,size_t _Offset);
  _CRTIMP void *__cdecl _aligned_realloc(void *_Memory,size_t _Size,size_t _Alignment);
  _CRTIMP void *__cdecl _aligned_recalloc(void *_Memory,size_t _Count,size_t _Size,size_t _Alignment);
  _CRTIMP void *__cdecl _aligned_offset_realloc(void *_Memory,size_t _Size,size_t _Alignment,size_t _Offset);
  _CRTIMP void *__cdecl _aligned_offset_recalloc(void *_Memory,size_t _Count,size_t _Size,size_t _Alignment,size_t _Offset);
#endif

#ifndef _WSTDLIB_DEFINED
#define _WSTDLIB_DEFINED

  _CRTIMP wchar_t *__cdecl _itow(int _Value,wchar_t *_Dest,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _ltow(long _Value,wchar_t *_Dest,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP wchar_t *__cdecl _ultow(unsigned long _Value,wchar_t *_Dest,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

  double __cdecl __mingw_wcstod(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr);
  float __cdecl __mingw_wcstof(const wchar_t * __restrict__ nptr, wchar_t ** __restrict__ endptr);
  long double __cdecl __mingw_wcstold(const wchar_t * __restrict__, wchar_t ** __restrict__);

#if defined(__USE_MINGW_STRTOX)
  __mingw_ovr
  double __cdecl wcstod(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr){
    return __mingw_wcstod(_Str,_EndPtr);
  }
  __mingw_ovr
  float __cdecl wcstof(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr){
    return __mingw_wcstof(_Str,_EndPtr);
  }
  /* wcstold is already a mingw implementation */
#else
  double __cdecl wcstod(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr);
  float __cdecl wcstof(const wchar_t * __restrict__ nptr, wchar_t ** __restrict__ endptr);
#endif /* defined(__USE_MINGW_STRTOX) */
#if !defined __NO_ISOCEXT /* in libmingwex.a */
  long double __cdecl wcstold(const wchar_t * __restrict__, wchar_t ** __restrict__);
#endif /* __NO_ISOCEXT */
  _CRTIMP double __cdecl _wcstod_l(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr,_locale_t _Locale);
  long __cdecl wcstol(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr,int _Radix);
  _CRTIMP long __cdecl _wcstol_l(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr,int _Radix,_locale_t _Locale);
  unsigned long __cdecl wcstoul(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr,int _Radix);
  _CRTIMP unsigned long __cdecl _wcstoul_l(const wchar_t * __restrict__ _Str,wchar_t ** __restrict__ _EndPtr,int _Radix,_locale_t _Locale);
  _CRTIMP wchar_t *__cdecl _wgetenv(const wchar_t *_VarName) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#ifndef _CRT_WSYSTEM_DEFINED
#define _CRT_WSYSTEM_DEFINED
  _CRTIMP int __cdecl _wsystem(const wchar_t *_Command);
#endif
  _CRTIMP double __cdecl _wtof(const wchar_t *_Str);
  _CRTIMP double __cdecl _wtof_l(const wchar_t *_Str,_locale_t _Locale);
  _CRTIMP int __cdecl _wtoi(const wchar_t *_Str);
  _CRTIMP int __cdecl _wtoi_l(const wchar_t *_Str,_locale_t _Locale);
  _CRTIMP long __cdecl _wtol(const wchar_t *_Str);
  _CRTIMP long __cdecl _wtol_l(const wchar_t *_Str,_locale_t _Locale);

  __MINGW_EXTENSION _CRTIMP wchar_t *__cdecl _i64tow(__int64 _Val,wchar_t *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __MINGW_EXTENSION _CRTIMP wchar_t *__cdecl _ui64tow(unsigned __int64 _Val,wchar_t *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _wtoi64(const wchar_t *_Str);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _wtoi64_l(const wchar_t *_Str,_locale_t _Locale);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _wcstoi64(const wchar_t *_Str,wchar_t **_EndPtr,int _Radix);
  __MINGW_EXTENSION _CRTIMP __int64 __cdecl _wcstoi64_l(const wchar_t *_Str,wchar_t **_EndPtr,int _Radix,_locale_t _Locale);
  __MINGW_EXTENSION _CRTIMP unsigned __int64 __cdecl _wcstoui64(const wchar_t *_Str,wchar_t **_EndPtr,int _Radix);
  __MINGW_EXTENSION _CRTIMP unsigned __int64 __cdecl _wcstoui64_l(const wchar_t *_Str ,wchar_t **_EndPtr,int _Radix,_locale_t _Locale);
#endif

  _CRTIMP int __cdecl _putenv(const char *_EnvString);
  _CRTIMP int __cdecl _wputenv(const wchar_t *_EnvString);

#ifndef _POSIX_
#define _CVTBUFSIZE (309+40)
  _CRTIMP char *__cdecl _fullpath(char *_FullPath,const char *_Path,size_t _SizeInBytes);
  _CRTIMP char *__cdecl _ecvt(double _Val,int _NumOfDigits,int *_PtDec,int *_PtSign) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _fcvt(double _Val,int _NumOfDec,int *_PtDec,int *_PtSign) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP char *__cdecl _gcvt(double _Val,int _NumOfDigits,char *_DstBuf) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP int __cdecl _atodbl(_CRT_DOUBLE *_Result,char *_Str);
  _CRTIMP int __cdecl _atoldbl(_LDOUBLE *_Result,char *_Str);
  _CRTIMP int __cdecl _atoflt(_CRT_FLOAT *_Result,char *_Str);
  _CRTIMP int __cdecl _atodbl_l(_CRT_DOUBLE *_Result,char *_Str,_locale_t _Locale);
  _CRTIMP int __cdecl _atoldbl_l(_LDOUBLE *_Result,char *_Str,_locale_t _Locale);
  _CRTIMP int __cdecl _atoflt_l(_CRT_FLOAT *_Result,char *_Str,_locale_t _Locale);

#if defined(__INTRIN_H_) || \
   (defined(_X86INTRIN_H_INCLUDED) && \
     ((__MINGW_GCC_VERSION >= 40902) || defined(__LP64__) || defined(_X86_)))

/* We already have bug-free prototypes and inline definitions for _lrotl
   and _lrotr from either intrin.h or x86intrin.h. */

#else

/* Remove buggy x86intrin.h definitions if present (see gcc bug 61662). */
#undef _lrotr
#undef _lrotl

/* These prototypes work for x86, x64 (native Windows), and cyginwin64. */
unsigned long __cdecl _lrotl(unsigned long,int);
unsigned long __cdecl _lrotr(unsigned long,int);

#endif /* defined(__INTRIN_H_) || \
    (defined(_X86INTRIN_H_INCLUDED) && \
       ((__MINGW_GCC_VERSION >= 40902) || defined(__LP64__))) */

  _CRTIMP void __cdecl _makepath(char *_Path,const char *_Drive,const char *_Dir,const char *_Filename,const char *_Ext);
  _onexit_t __cdecl _onexit(_onexit_t _Func);

#ifndef _CRT_PERROR_DEFINED
#define _CRT_PERROR_DEFINED
  void __cdecl perror(const char *_ErrMsg);
#endif
#pragma push_macro ("_rotr64")
#pragma push_macro ("_rotl64")
#undef _rotl64
#undef _rotr64
  __MINGW_EXTENSION unsigned __int64 __cdecl _rotl64(unsigned __int64 _Val,int _Shift);
  __MINGW_EXTENSION unsigned __int64 __cdecl _rotr64(unsigned __int64 Value,int Shift);
#pragma pop_macro ("_rotl64")
#pragma pop_macro ("_rotr64")
#pragma push_macro ("_rotr")
#pragma push_macro ("_rotl")
#undef _rotr
#undef _rotl
  unsigned int __cdecl _rotr(unsigned int _Val,int _Shift);
  unsigned int __cdecl _rotl(unsigned int _Val,int _Shift);
#pragma pop_macro ("_rotl")
#pragma pop_macro ("_rotr")
  __MINGW_EXTENSION unsigned __int64 __cdecl _rotr64(unsigned __int64 _Val,int _Shift);
  _CRTIMP void __cdecl _searchenv(const char *_Filename,const char *_EnvVar,char *_ResultPath) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP void __cdecl _splitpath(const char *_FullPath,char *_Drive,char *_Dir,char *_Filename,char *_Ext) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP void __cdecl _swab(char *_Buf1,char *_Buf2,int _SizeInBytes);

#ifndef _WSTDLIBP_DEFINED
#define _WSTDLIBP_DEFINED
  _CRTIMP wchar_t *__cdecl _wfullpath(wchar_t *_FullPath,const wchar_t *_Path,size_t _SizeInWords);
  _CRTIMP void __cdecl _wmakepath(wchar_t *_ResultPath,const wchar_t *_Drive,const wchar_t *_Dir,const wchar_t *_Filename,const wchar_t *_Ext);
#ifndef _CRT_WPERROR_DEFINED
#define _CRT_WPERROR_DEFINED
  _CRTIMP void __cdecl _wperror(const wchar_t *_ErrMsg);
#endif
  _CRTIMP void __cdecl _wsearchenv(const wchar_t *_Filename,const wchar_t *_EnvVar,wchar_t *_ResultPath) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _CRTIMP void __cdecl _wsplitpath(const wchar_t *_FullPath,wchar_t *_Drive,wchar_t *_Dir,wchar_t *_Filename,wchar_t *_Ext) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif

  _CRTIMP void __cdecl _beep(unsigned _Frequency,unsigned _Duration) __MINGW_ATTRIB_DEPRECATED;
  /* Not to be confused with  _set_error_mode (int).  */
  _CRTIMP void __cdecl _seterrormode(int _Mode) __MINGW_ATTRIB_DEPRECATED;
  _CRTIMP void __cdecl _sleep(unsigned long _Duration) __MINGW_ATTRIB_DEPRECATED;
#endif

#ifndef	NO_OLDNAMES
#ifndef _POSIX_
#if 0
#ifndef __cplusplus
#ifndef NOMINMAX
#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif
#endif
#endif
#endif

#define sys_errlist _sys_errlist
#define sys_nerr _sys_nerr
#define environ _environ
  char *__cdecl ecvt(double _Val,int _NumOfDigits,int *_PtDec,int *_PtSign) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl fcvt(double _Val,int _NumOfDec,int *_PtDec,int *_PtSign) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl gcvt(double _Val,int _NumOfDigits,char *_DstBuf) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl itoa(int _Val,char *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  char *__cdecl ltoa(long _Val,char *_DstBuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  int __cdecl putenv(const char *_EnvString) __MINGW_ATTRIB_DEPRECATED_MSVC2005;

#ifndef _CRT_SWAB_DEFINED
#define _CRT_SWAB_DEFINED  /* Also in unistd.h */
  void __cdecl swab(char *_Buf1,char *_Buf2,int _SizeInBytes) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

  char *__cdecl ultoa(unsigned long _Val,char *_Dstbuf,int _Radix) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  onexit_t __cdecl onexit(onexit_t _Func);
#endif
#endif

#if !defined __NO_ISOCEXT /* externs in static libmingwex.a */

  typedef struct { __MINGW_EXTENSION long long quot, rem; } lldiv_t;

  __MINGW_EXTENSION lldiv_t __cdecl lldiv(long long, long long);

  __MINGW_EXTENSION long long __cdecl llabs(long long);
#ifndef __CRT__NO_INLINE
  __MINGW_EXTENSION __CRT_INLINE long long __cdecl llabs(long long _j) { return (_j >= 0 ? _j : -_j); }
#endif

  __MINGW_EXTENSION long long  __cdecl strtoll(const char * __restrict__, char ** __restrict, int);
  __MINGW_EXTENSION unsigned long long  __cdecl strtoull(const char * __restrict__, char ** __restrict__, int);

  /* these are stubs for MS _i64 versions */
  __MINGW_EXTENSION long long  __cdecl atoll (const char *);

#ifndef __STRICT_ANSI__
  __MINGW_EXTENSION long long  __cdecl wtoll (const wchar_t *);
  __MINGW_EXTENSION char *__cdecl lltoa (long long, char *, int);
  __MINGW_EXTENSION char *__cdecl ulltoa (unsigned long long , char *, int);
  __MINGW_EXTENSION wchar_t *__cdecl lltow (long long, wchar_t *, int);
  __MINGW_EXTENSION wchar_t *__cdecl ulltow (unsigned long long, wchar_t *, int);

  /* __CRT_INLINE using non-ansi functions */
#ifndef __CRT__NO_INLINE
  __MINGW_EXTENSION __CRT_INLINE long long  __cdecl atoll (const char * _c) { return _atoi64 (_c); }
  __MINGW_EXTENSION __CRT_INLINE char *__cdecl lltoa (long long _n, char * _c, int _i) { return _i64toa (_n, _c, _i); }
  __MINGW_EXTENSION __CRT_INLINE char *__cdecl ulltoa (unsigned long long _n, char * _c, int _i) { return _ui64toa (_n, _c, _i); }
  __MINGW_EXTENSION __CRT_INLINE long long  __cdecl wtoll (const wchar_t * _w) { return _wtoi64 (_w); }
  __MINGW_EXTENSION __CRT_INLINE wchar_t *__cdecl lltow (long long _n, wchar_t * _w, int _i) { return _i64tow (_n, _w, _i); }
  __MINGW_EXTENSION __CRT_INLINE wchar_t *__cdecl ulltow (unsigned long long _n, wchar_t * _w, int _i) { return _ui64tow (_n, _w, _i); }
#endif /* !__CRT__NO_INLINE */
#endif /* (__STRICT_ANSI__)  */

#endif /* !__NO_ISOCEXT */

#ifdef __cplusplus
}
#endif

#pragma pack(pop)

#include <sec_api/stdlib_s.h>
#include <malloc.h>

#endif
