/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _TIME_H_
#define _TIME_H_

#include <crtdefs.h>

#ifndef _WIN32
#error Only Win32 target is supported!
#endif

#if defined(__LIBMSVCRT__)
/* When building mingw-w64, this should be blank.  */
#define _SECIMP
#else
#ifndef _SECIMP
#define _SECIMP __declspec(dllimport)
#endif /* _SECIMP */
#endif /* defined(__LIBMSVCRT__) */

/* Adding timespec definition.  */
#include <sys/timeb.h>

#pragma pack(push,_CRT_PACKING)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _CRTIMP
#define _CRTIMP __declspec(dllimport)
#endif

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
  typedef unsigned short wchar_t;
#endif

#ifndef _TIME32_T_DEFINED
#define _TIME32_T_DEFINED
  typedef long __time32_t;
#endif

#ifndef _TIME64_T_DEFINED
#define _TIME64_T_DEFINED
  __MINGW_EXTENSION typedef __int64 __time64_t;
#endif

#ifndef _TIME_T_DEFINED
#define _TIME_T_DEFINED
#ifdef _USE_32BIT_TIME_T
  typedef __time32_t time_t;
#else
  typedef __time64_t time_t;
#endif
#endif

#ifndef _CLOCK_T_DEFINED
#define _CLOCK_T_DEFINED
  typedef long clock_t;
#endif

#ifndef _SIZE_T_DEFINED
#define _SIZE_T_DEFINED
#undef size_t
#ifdef _WIN64
  __MINGW_EXTENSION typedef unsigned __int64 size_t;
#else
  typedef unsigned int size_t;
#endif
#endif

#ifndef _SSIZE_T_DEFINED
#define _SSIZE_T_DEFINED
#undef ssize_t
#ifdef _WIN64
  __MINGW_EXTENSION typedef __int64 ssize_t;
#else
  typedef int ssize_t;
#endif
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

#ifndef _TM_DEFINED
#define _TM_DEFINED
  struct tm {
    int tm_sec;
    int tm_min;
    int tm_hour;
    int tm_mday;
    int tm_mon;
    int tm_year;
    int tm_wday;
    int tm_yday;
    int tm_isdst;
  };
#endif

#define CLOCKS_PER_SEC 1000

#ifdef _UCRT
#define TIME_UTC 1
#endif

  _CRTIMP int *__cdecl __daylight(void);
  _CRTIMP long *__cdecl __dstbias(void);
  _CRTIMP long *__cdecl __timezone(void);
  _CRTIMP char **__cdecl __tzname(void);
#define _daylight (* __daylight())
#define _dstbias (* __dstbias())
#define _timezone (* __timezone())
#define _tzname (__tzname())

#undef __MINGW_STRFTIME_FORMAT

#if defined(__clang__)
#define __MINGW_STRFTIME_FORMAT strftime
#elif defined(_UCRT)
#define __MINGW_STRFTIME_FORMAT gnu_strftime
#else
#define __MINGW_STRFTIME_FORMAT ms_strftime
#endif

  _CRTIMP errno_t __cdecl _get_daylight(int *_Daylight);
  _CRTIMP errno_t __cdecl _get_dstbias(long *_Daylight_savings_bias);
  _CRTIMP errno_t __cdecl _get_timezone(long *_Timezone);
  _CRTIMP errno_t __cdecl _get_tzname(size_t *_ReturnValue,char *_Buffer,size_t _SizeInBytes,int _Index);
  char *__cdecl asctime(const struct tm *_Tm) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl asctime_s (char *_Buf,size_t _SizeInWords,const struct tm *_Tm);
  _CRTIMP char *__cdecl _ctime32(const __time32_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _ctime32_s (char *_Buf,size_t _SizeInBytes,const __time32_t *_Time);
  clock_t __cdecl clock(void);
  _CRTIMP double __cdecl _difftime32(__time32_t _Time1,__time32_t _Time2);
  _CRTIMP struct tm *__cdecl _gmtime32(const __time32_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _gmtime32_s (struct tm *_Tm,const __time32_t *_Time);
  _CRTIMP struct tm *__cdecl _localtime32(const __time32_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _localtime32_s (struct tm *_Tm,const __time32_t *_Time);
  size_t __cdecl strftime(char * __restrict__ _Buf,size_t _SizeInBytes,const char * __restrict__ _Format,const struct tm * __restrict__ _Tm) __attribute__((__format__ (__MINGW_STRFTIME_FORMAT, 3, 0)));
  _CRTIMP size_t __cdecl _strftime_l(char * __restrict__ _Buf,size_t _Max_size,const char * __restrict__ _Format,const struct tm * __restrict__ _Tm,_locale_t _Locale);
  _CRTIMP char *__cdecl _strdate(char *_Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _strdate_s (char *_Buf,size_t _SizeInBytes);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_0(errno_t, _strdate_s, char, _Str)
  _CRTIMP char *__cdecl _strtime(char *_Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _strtime_s (char *_Buf ,size_t _SizeInBytes);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_0(errno_t, _strtime_s, char, _Str)
  _CRTIMP __time32_t __cdecl _time32(__time32_t *_Time);
#ifdef _UCRT
  _CRTIMP int __cdecl _timespec32_get(struct _timespec32 *_Ts, int _Base);
#endif
  _CRTIMP __time32_t __cdecl _mktime32(struct tm *_Tm);
  _CRTIMP __time32_t __cdecl _mkgmtime32(struct tm *_Tm);

#if defined (_POSIX_) || defined(__GNUC__)
  void __cdecl tzset(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif
#if !defined (_POSIX_)
#ifndef _UCRT
  _CRTIMP
#endif
  void __cdecl _tzset(void);
#endif

  _CRTIMP double __cdecl _difftime64(__time64_t _Time1,__time64_t _Time2);
  _CRTIMP char *__cdecl _ctime64(const __time64_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _ctime64_s (char *_Buf,size_t _SizeInBytes,const __time64_t *_Time);
  _CRTIMP struct tm *__cdecl _gmtime64(const __time64_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _gmtime64_s (struct tm *_Tm,const __time64_t *_Time);
  _CRTIMP struct tm *__cdecl _localtime64(const __time64_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _localtime64_s (struct tm *_Tm,const __time64_t *_Time);
  _CRTIMP __time64_t __cdecl _mktime64(struct tm *_Tm);
  _CRTIMP __time64_t __cdecl _mkgmtime64(struct tm *_Tm);
  _CRTIMP __time64_t __cdecl _time64(__time64_t *_Time);
#ifdef _UCRT
  _CRTIMP int __cdecl _timespec64_get(struct _timespec64 *_Ts, int _Base);
#endif
  unsigned __cdecl _getsystime(struct tm *_Tm);
  unsigned __cdecl _setsystime(struct tm *_Tm,unsigned _MilliSec);

#ifndef _WTIME_DEFINED
  _CRTIMP wchar_t *__cdecl _wasctime(const struct tm *_Tm);
  _SECIMP errno_t __cdecl _wasctime_s (wchar_t *_Buf,size_t _SizeInWords,const struct tm *_Tm);
  wchar_t *__cdecl _wctime32(const __time32_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _wctime32_s (wchar_t *_Buf,size_t _SizeInWords,const __time32_t *_Time);
  size_t __cdecl wcsftime(wchar_t * __restrict__ _Buf,size_t _SizeInWords,const wchar_t * __restrict__ _Format,const struct tm * __restrict__ _Tm);
  _CRTIMP size_t __cdecl _wcsftime_l(wchar_t * __restrict__ _Buf,size_t _SizeInWords,const wchar_t * __restrict__ _Format,const struct tm * __restrict__ _Tm,_locale_t _Locale);
  _CRTIMP wchar_t *__cdecl _wstrdate(wchar_t *_Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _wstrdate_s (wchar_t *_Buf,size_t _SizeInWords);
  _CRTIMP wchar_t *__cdecl _wstrtime(wchar_t *_Buffer) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _wstrtime_s (wchar_t *_Buf,size_t _SizeInWords);
  _CRTIMP wchar_t *__cdecl _wctime64(const __time64_t *_Time) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
  _SECIMP errno_t __cdecl _wctime64_s (wchar_t *_Buf,size_t _SizeInWords,const __time64_t *_Time);

#if !defined (RC_INVOKED) && !defined (_INC_WTIME_INL)
#define _INC_WTIME_INL
#ifndef _USE_32BIT_TIME_T
  wchar_t *__cdecl _wctime(const time_t *_Time) __MINGW_ASM_CALL(_wctime64) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#else
  wchar_t *__cdecl _wctime(const time_t *_Time) __MINGW_ASM_CALL(_wctime32) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
#endif
#endif

#if !defined (RC_INVOKED) && !defined (_INC_WTIME_S_INL)
#define _INC_WTIME_S_INL
#ifndef _USE_32BIT_TIME_T
  errno_t __cdecl _wctime_s (wchar_t *_Buffer,size_t _SizeInWords,const time_t *_Time) __MINGW_ASM_CALL(_wctime64_s);
#else
  errno_t __cdecl _wctime_s (wchar_t *_Buffer,size_t _SizeInWords,const time_t *_Time) __MINGW_ASM_CALL(_wctime32_s);
#endif
#endif

#define _WTIME_DEFINED
#endif

#ifndef RC_INVOKED

#ifdef _USE_32BIT_TIME_T
time_t __CRTDECL time(time_t *_Time) __MINGW_ASM_CALL(_time32);
#ifdef _UCRT
int __CRTDECL timespec_get(struct timespec* _Ts, int _Base) __MINGW_ASM_CALL(_timespec32_get);
#endif
double __CRTDECL difftime(time_t _Time1,time_t _Time2) __MINGW_ASM_CALL(_difftime32);
struct tm *__CRTDECL localtime(const time_t *_Time) __MINGW_ASM_CALL(_localtime32);
errno_t __CRTDECL localtime_s(struct tm *_Tm,const time_t *_Time) __MINGW_ASM_CALL(_localtime32_s);
struct tm *__CRTDECL gmtime(const time_t *_Time) __MINGW_ASM_CALL(_gmtime32);
errno_t __CRTDECL gmtime_s(struct tm *_Tm, const time_t *_Time) __MINGW_ASM_CALL(_gmtime32_s);
char *__CRTDECL ctime(const time_t *_Time) __MINGW_ASM_CALL(_ctime32);
errno_t __CRTDECL ctime_s(char *_Buf,size_t _SizeInBytes,const time_t *_Time) __MINGW_ASM_CALL(_ctime32_s);
time_t __CRTDECL mktime(struct tm *_Tm) __MINGW_ASM_CALL(_mktime32);
time_t __CRTDECL _mkgmtime(struct tm *_Tm) __MINGW_ASM_CALL(_mkgmtime32);
#else
time_t __CRTDECL time(time_t *_Time) __MINGW_ASM_CALL(_time64);
#ifdef _UCRT
int __CRTDECL timespec_get(struct timespec* _Ts, int _Base) __MINGW_ASM_CALL(_timespec64_get);
#endif
double __CRTDECL difftime(time_t _Time1,time_t _Time2) __MINGW_ASM_CALL(_difftime64);
struct tm *__CRTDECL localtime(const time_t *_Time) __MINGW_ASM_CALL(_localtime64);
errno_t __CRTDECL localtime_s(struct tm *_Tm,const time_t *_Time) __MINGW_ASM_CALL(_localtime64_s);
struct tm *__CRTDECL gmtime(const time_t *_Time) __MINGW_ASM_CALL(_gmtime64);
errno_t __CRTDECL gmtime_s(struct tm *_Tm, const time_t *_Time) __MINGW_ASM_CALL(_gmtime64_s);
char *__CRTDECL ctime(const time_t *_Time) __MINGW_ASM_CALL(_ctime64);
errno_t __CRTDECL ctime_s(char *_Buf,size_t _SizeInBytes,const time_t *_Time) __MINGW_ASM_CALL(_ctime64_s);
time_t __CRTDECL mktime(struct tm *_Tm) __MINGW_ASM_CALL(_mktime64);
time_t __CRTDECL _mkgmtime(struct tm *_Tm) __MINGW_ASM_CALL(_mkgmtime64);
#endif

#endif /* !RC_INVOKED */

#if !defined(NO_OLDNAMES) || defined(_POSIX)
#define CLK_TCK CLOCKS_PER_SEC

#ifdef _UCRT
#define __MINGW_ATTRIB_DEPRECATED_UCRT \
    __MINGW_ATTRIB_DEPRECATED_MSG( \
        "Only provided for source compatibility; this variable might " \
        "not always be accurate when linking to UCRT.")
#else
#define __MINGW_ATTRIB_DEPRECATED_UCRT
#endif

  _CRTIMP extern int daylight __MINGW_ATTRIB_DEPRECATED_UCRT;
  _CRTIMP extern long timezone __MINGW_ATTRIB_DEPRECATED_UCRT;
  _CRTIMP extern char *tzname[2] __MINGW_ATTRIB_DEPRECATED_UCRT;
  void __cdecl tzset(void) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#endif

#include <_timeval.h>

#ifndef _TIMEZONE_DEFINED /* also in sys/time.h */
#define _TIMEZONE_DEFINED
struct timezone {
  int tz_minuteswest;
  int tz_dsttime;
};

  extern int __cdecl mingw_gettimeofday (struct timeval *p, struct timezone *z);
#endif /* _TIMEZONE_DEFINED */

#pragma pack(pop)

#if defined(_POSIX_C_SOURCE) && !defined(_POSIX_THREAD_SAFE_FUNCTIONS)
#define _POSIX_THREAD_SAFE_FUNCTIONS 200112L
#endif

#ifdef _POSIX_THREAD_SAFE_FUNCTIONS
__forceinline struct tm *__CRTDECL localtime_r(const time_t *_Time, struct tm *_Tm) {
  return localtime_s(_Tm, _Time) ? NULL : _Tm;
}
__forceinline struct tm *__CRTDECL gmtime_r(const time_t *_Time, struct tm *_Tm) {
  return gmtime_s(_Tm, _Time) ? NULL : _Tm;
}
__forceinline char *__CRTDECL ctime_r(const time_t *_Time, char *_Str) {
  return ctime_s(_Str, 0x7fffffff, _Time) ? NULL : _Str;
}
__forceinline char *__CRTDECL asctime_r(const struct tm *_Tm, char * _Str) {
  return asctime_s(_Str, 0x7fffffff, _Tm) ? NULL : _Str;
}
#endif

#ifdef __cplusplus
}
#endif

/* POSIX 2008 says clock_gettime and timespec are defined in time.h header,
   but other systems - like Linux, Solaris, etc - tend to declare such
   recent extensions only if the following guards are met.  */
#if !defined(IN_WINPTHREAD) && \
	((!defined(_STRICT_STDC) && !defined(__XOPEN_OR_POSIX)) || \
	 (_POSIX_C_SOURCE > 2) || defined(__EXTENSIONS__))
#include <pthread_time.h>
#endif

#endif /* End _TIME_H_ */

