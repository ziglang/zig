/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TCHAR_S
#define _INC_TCHAR_S

#include <tchar.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifdef _UNICODE

#define _tprintf_s wprintf_s
#define _tprintf_s_l _wprintf_s_l
#define _tcprintf_s _cwprintf_s
#define _tcprintf_s_l _cwprintf_s_l
#define _vtcprintf_s _vcwprintf_s
#define _vtcprintf_s_l _vcwprintf_s_l
#define _ftprintf_s fwprintf_s
#define _ftprintf_s_l _fwprintf_s_l
#define _stprintf_s swprintf_s
#define _stprintf_s_l _swprintf_s_l
#define _sntprintf_s _snwprintf_s
#define _sntprintf_s_l _snwprintf_s_l
#define _vtprintf_s vwprintf_s
#define _vtprintf_s_l _vwprintf_s_l
#define _vftprintf_s vfwprintf_s
#define _vftprintf_s_l _vfwprintf_s_l
#define _vstprintf_s vswprintf_s
#define _vstprintf_s_l _vswprintf_s_l
#define _vsntprintf_s _vsnwprintf_s
#define _vsntprintf_s_l _vsnwprintf_s_l

#define _tscanf_s wscanf_s
#define _tscanf_s_l _wscanf_s_l
#define _tcscanf_s _cwscanf_s
#define _tcscanf_s_l _cwscanf_s_l
#define _ftscanf_s fwscanf_s
#define _ftscanf_s_l _fwscanf_s_l
#define _stscanf_s swscanf_s
#define _stscanf_s_l _swscanf_s_l
#define _sntscanf_s _snwscanf_s
#define _sntscanf_s_l _snwscanf_s_l
#define _vtscanf_s vwscanf_s
#define _vftscanf_s vfwscanf_s
#define _vstscanf_s vswscanf_s

#define _cgetts_s _cgetws_s
#define _getts_s _getws_s

#define _itot_s _itow_s
#define _ltot_s _ltow_s
#define _ultot_s _ultow_s
#define _i64tot_s _i64tow_s
#define _ui64tot_s _ui64tow_s

#define _tcscat_s wcscat_s
#define _tcscpy_s wcscpy_s
#define _tcsncat_s wcsncat_s
#define _tcsncat_s_l _wcsncat_s_l
#define _tcsncpy_s wcsncpy_s
#define _tcsncpy_s_l _wcsncpy_s_l
#define _tcstok_s wcstok_s
#define _tcstok_s_l _wcstok_s_l
#define _tcserror_s _wcserror_s
#define __tcserror_s __wcserror_s

#define _tcsnset_s _wcsnset_s
#define _tcsnset_s_l _wcsnset_s_l
#define _tcsset_s _wcsset_s
#define _tcsset_s_l _wcsset_s_l

#define _tasctime_s _wasctime_s
#define _tctime_s _wctime_s
#define _tctime32_s _wctime32_s
#define _tctime64_s _wctime64_s
#define _tstrdate_s _wstrdate_s
#define _tstrtime_s _wstrtime_s

#define _tgetenv_s _wgetenv_s
#define _tdupenv_s _wdupenv_s
#define _tmakepath_s _wmakepath_s
#define _tputenv_s _wputenv_s
#define _tsearchenv_s _wsearchenv_s
#define _tsplitpath_s _wsplitpath_s

#define _tfopen_s _wfopen_s
#define _tfreopen_s _wfreopen_s
#define _ttmpnam_s _wtmpnam_s
#define _taccess_s _waccess_s
#define _tmktemp_s _wmktemp_s

#define _tcsnccat_s wcsncat_s
#define _tcsnccat_s_l _wcsncat_s_l
#define _tcsnccpy_s wcsncpy_s
#define _tcsnccpy_s_l _wcsncpy_s_l

#define _tcslwr_s _wcslwr_s
#define _tcslwr_s_l _wcslwr_s_l
#define _tcsupr_s _wcsupr_s
#define _tcsupr_s_l _wcsupr_s_l

#define _wcstok_s_l(_String,_Delimiters,_Current_position,_Locale) (wcstok_s(_String,_Delimiters,_Current_position))
#define _wcsnset_s_l(_Destination,_Destination_size_chars,_Value,_Count,_Locale) (_wcsnset_s(_Destination,_Destination_size_chars,_Value,_Count))
#define _wcsset_s_l(_Destination,_Destination_size_chars,_Value,_Locale) (_wcsset_s(_Destination,_Destination_size_chars,_Value))

#else

#define _tprintf_s printf_s
#define _tprintf_s_l _printf_s_l
#define _tcprintf_s _cprintf_s
#define _tcprintf_s_l _cprintf_s_l
#define _vtcprintf_s _vcprintf_s
#define _vtcprintf_s_l _vcprintf_s_l
#define _ftprintf_s fprintf_s
#define _ftprintf_s_l _fprintf_s_l
#define _stprintf_s sprintf_s
#define _stprintf_s_l _sprintf_s_l
#define _sntprintf_s _snprintf_s
#define _sntprintf_s_l _snprintf_s_l
#define _vtprintf_s vprintf_s
#define _vtprintf_s_l _vprintf_s_l
#define _vftprintf_s vfprintf_s
#define _vftprintf_s_l _vfprintf_s_l
#define _vstprintf_s vsprintf_s
#define _vstprintf_s_l _vsprintf_s_l
#define _vsntprintf_s _vsnprintf_s
#define _vsntprintf_s_l _vsnprintf_s_l
#define _tscanf_s scanf_s
#define _tscanf_s_l _scanf_s_l
#define _tcscanf_s _cscanf_s
#define _tcscanf_s_l _cscanf_s_l
#define _ftscanf_s fscanf_s
#define _ftscanf_s_l _fscanf_s_l
#define _stscanf_s sscanf_s
#define _stscanf_s_l _sscanf_s_l
#define _sntscanf_s _snscanf_s
#define _sntscanf_s_l _snscanf_s_l
#define _vtscanf_s vscanf_s
#define _vftscanf_s vfscanf_s
#define _vstscanf_s vsscanf_s

#define _getts_s gets_s
#define _cgetts_s _cgets_s
#define _itot_s _itoa_s
#define _ltot_s _ltoa_s
#define _ultot_s _ultoa_s
#define _i64tot_s _i64toa_s
#define _ui64tot_s _ui64toa_s

#define _tcscat_s strcat_s
#define _tcscpy_s strcpy_s
#define _tcserror_s strerror_s
#define __tcserror_s _strerror_s

#define _tasctime_s asctime_s
#define _tctime_s ctime_s
#define _tctime32_s _ctime32_s
#define _tctime64_s _ctime64_s
#define _tstrdate_s _strdate_s
#define _tstrtime_s _strtime_s

#define _tgetenv_s getenv_s
#define _tdupenv_s _dupenv_s
#define _tmakepath_s _makepath_s
#define _tputenv_s _putenv_s
#define _tsearchenv_s _searchenv_s
#define _tsplitpath_s _splitpath_s

#define _tfopen_s fopen_s
#define _tfreopen_s freopen_s
#define _ttmpnam_s tmpnam_s
#define _tmktemp_s _mktemp_s

#ifndef _POSIX_
#define _taccess_s _access_s
#endif

#define _tsopen_s _sopen_s

#ifdef _MBCS

#ifdef _MB_MAP_DIRECT

#define _tcsncat_s _mbsnbcat_s
#define _tcsncat_s_l _mbsnbcat_s_l
#define _tcsncpy_s _mbsnbcpy_s
#define _tcsncpy_s_l _mbsnbcpy_s_l
#define _tcstok_s _mbstok_s
#define _tcstok_s_l _mbstok_s_l

#define _tcsnset_s _mbsnbset_s
#define _tcsnset_s_l _mbsnbset_s_l
#define _tcsset_s _mbsset_s
#define _tcsset_s_l _mbsset_s_l

#define _tcsnccat_s _mbsncat_s
#define _tcsnccat_s_l _mbsncat_s_l
#define _tcsnccpy_s _mbsncpy_s
#define _tcsnccpy_s_l _mbsncpy_s_l
#define _tcsncset_s _mbsnset_s
#define _tcsncset_s_l _mbsnset_s_l

#define _tcslwr_s _mbslwr_s
#define _tcslwr_s_l _mbslwr_s_l
#define _tcsupr_s _mbsupr_s
#define _tcsupr_s_l _mbsupr_s_l

#define _tccpy_s _mbccpy_s
#define _tccpy_s_l _mbccpy_s_l
#else

  _CRTIMP char *__cdecl _tcsncat_s(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsncat_s_l(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsncpy_s(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsncpy_s_l(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcstok_s(char *_Str,const char *_Delim,char **_Context);
  _CRTIMP char *__cdecl _tcstok_s_l(char *_Str,const char *_Delim,char **_Context,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _tcsset_s(char *_Str,size_t _SizeInChars,unsigned int _Val);
  _CRTIMP errno_t __cdecl _tcsset_s_l(char *_Str,size_t _SizeInChars,unsigned int,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsnccat_s(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsnccat_s_l(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsnccpy_s(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsnccpy_s_l(char *_Dst,size_t _DstSizeInChars,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcslwr_s(char *_Str,size_t _SizeInChars);
  _CRTIMP char *__cdecl _tcslwr_s_l(char *_Str,size_t _SizeInChars,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsupr_s(char *_Str,size_t _SizeInChars);
  _CRTIMP char *__cdecl _tcsupr_s_l(char *_Str,size_t _SizeInChars,_locale_t _Locale);

#endif

#else

#define _tcsncat_s strncat_s
#define _tcsncat_s_l _strncat_s_l
#define _tcsncpy_s strncpy_s
#define _tcsncpy_s_l _strncpy_s_l
#define _tcstok_s strtok_s
#define _tcstok_s_l _strtok_s_l

#define _tcsnset_s _strnset_s
#define _tcsnset_s_l _strnset_s_l
#define _tcsset_s _strset_s
#define _tcsset_s _strset_s
#define _tcsset_s_l _strset_s_l

#define _tcsnccat_s strncat_s
#define _tcsnccat_s_l _strncat_s_l
#define _tcsnccpy_s strncpy_s
#define _tcsnccpy_s_l _strncpy_s_l

#define _tcslwr_s _strlwr_s
#define _tcslwr_s_l _strlwr_s_l
#define _tcsupr_s _strupr_s
#define _tcsupr_s_l _strupr_s_l

#define _strnset_s_l(_Destination,_Destination_size_chars,_Value,_Count,_Locale) (_strnset_s(_Destination,_Destination_size_chars,_Value,_Count))
#define _strset_s_l(_Destination,_Destination_size_chars,_Value,_Locale) (_strset_s(_Destination,_Destination_size_chars,_Value))
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
