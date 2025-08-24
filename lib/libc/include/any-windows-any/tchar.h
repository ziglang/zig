/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <crtdefs.h>

#ifndef _INC_TCHAR
#define _INC_TCHAR

#ifdef _STRSAFE_H_INCLUDED_
#error Need to include strsafe.h after tchar.h
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __CYGWIN__

#define _ftcscat _tcscat
#define _ftcschr _tcschr
#define _ftcscpy _tcscpy
#define _ftcscspn _tcscspn
#define _ftcslen _tcslen
#define _ftcsncat _tcsncat
#define _ftcsncpy _tcsncpy
#define _ftcspbrk _tcspbrk
#define _ftcsrchr _tcsrchr
#define _ftcsspn _tcsspn
#define _ftcsstr _tcsstr
#define _ftcstok _tcstok

#define _ftcsdup _tcsdup
#define _ftcsnset _tcsnset
#define _ftcsrev _tcsrev
#define _ftcsset _tcsset

#define _ftcscmp _tcscmp
#define _ftcsicmp _tcsicmp
#define _ftcsnccmp _tcsnccmp
#define _ftcsncmp _tcsncmp
#define _ftcsncicmp _tcsncicmp
#define _ftcsnicmp _tcsnicmp

#define _ftcscoll _tcscoll
#define _ftcsicoll _tcsicoll
#define _ftcsnccoll _tcsnccoll
#define _ftcsncoll _tcsncoll
#define _ftcsncicoll _tcsncicoll
#define _ftcsnicoll _tcsnicoll

#define _ftcsclen _tcsclen
#define _ftcsnccat _tcsnccat
#define _ftcsnccpy _tcsnccpy
#define _ftcsncset _tcsncset

#define _ftcsdec _tcsdec
#define _ftcsinc _tcsinc
#define _ftcsnbcnt _tcsnbcnt
#define _ftcsnccnt _tcsnccnt
#define _ftcsnextc _tcsnextc
#define _ftcsninc _tcsninc
#define _ftcsspnp _tcsspnp

#define _ftcslwr _tcslwr
#define _ftcsupr _tcsupr

#define _ftclen _tclen
#define _ftccpy _tccpy
#define _ftccmp _tccmp

#ifndef _CONST_RETURN
#ifdef __cplusplus
#define _CONST_RETURN const
#define _CRT_CONST_CORRECT_OVERLOADS
#else
#define _CONST_RETURN
#endif
#endif

#define _WConst_return _CONST_RETURN

#endif /* __CYGWIN__ */

#ifdef _UNICODE

#ifdef __cplusplus
}
#endif

#include <wchar.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __CYGWIN__

#ifndef _WCTYPE_T_DEFINED
#define _WCTYPE_T_DEFINED
  typedef unsigned short wint_t;
  typedef unsigned short wctype_t;
#endif

#endif /* __CYGWIN__ */

#ifndef __TCHAR_DEFINED
#define __TCHAR_DEFINED
  typedef wchar_t _TCHAR;
  typedef wchar_t _TSCHAR;
  typedef wchar_t _TUCHAR;
  typedef wchar_t _TXCHAR;
  typedef wint_t _TINT;
#endif

#ifndef NO_OLDNAMES
#ifndef _TCHAR_DEFINED
#define _TCHAR_DEFINED
  typedef wchar_t TCHAR,*PTCHAR;
  typedef wchar_t TBYTE,*PTBYTE;
#endif
#endif

#define _TEOF WEOF

#define __T(x) L##x

#ifndef __CYGWIN__

#define _tmain wmain
#define _tWinMain wWinMain
#define _tenviron _wenviron
#define __targv __wargv

#define _tprintf __ms_wprintf
#define _tprintf_l _wprintf_l
#define _tprintf_p _wprintf_p
#define _tprintf_p_l _wprintf_p_l
#define _tcprintf _cwprintf
#define _tcprintf_l _cwprintf_l
#define _tcprintf_p _cwprintf_p
#define _tcprintf_p_l _cwprintf_p_l
#define _vtcprintf _vcwprintf
#define _vtcprintf_l _vcwprintf_l
#define _vtcprintf_p _vcwprintf_p
#define _vtcprintf_p_l _vcwprintf_p_l
#define _ftprintf __ms_fwprintf
#define _ftprintf_l _fwprintf_l
#define _ftprintf_p _fwprintf_p
#define _ftprintf_p_l _fwprintf_p_l
#define _stprintf _swprintf
#define _stprintf_l __swprintf_l
#define _stprintf_p _swprintf_p
#define _stprintf_p_l _swprintf_p_l
#define _sctprintf _scwprintf
#define _sctprintf_l _scwprintf_l
#define _sctprintf_p _scwprintf_p
#define _sctprintf_p_l _scwprintf_p_l
#define _sntprintf _snwprintf
#define _sntprintf_l _snwprintf_l
#define _vtprintf __ms_vwprintf
#define _vtprintf_l _vwprintf_l
#define _vtprintf_p _vwprintf_p
#define _vtprintf_p_l _vwprintf_p_l
#define _vftprintf __ms_vfwprintf
#define _vftprintf_l _vfwprintf_l
#define _vftprintf_p _vfwprintf_p
#define _vftprintf_p_l _vfwprintf_p_l
#define _vstprintf _vswprintf
#define _vstprintf_l _vswprintf_l
#define _vstprintf_p _vswprintf_p
#define _vstprintf_p_l _vswprintf_p_l
#define _vsctprintf _vscwprintf
#define _vsctprintf_l _vscwprintf_l
#define _vsctprintf_p _vscwprintf_p
#define _vsctprintf_p_l _vscwprintf_p_l
#define _vsntprintf _vsnwprintf
#define _vsntprintf_l _vsnwprintf_l

#define _tscanf __ms_wscanf
#define _tscanf_l _wscanf_l
#define _tcscanf _cwscanf
#define _tcscanf_l _cwscanf_l
#define _ftscanf __ms_fwscanf
#define _ftscanf_l _fwscanf_l
#define _stscanf __ms_swscanf
#define _stscanf_l _swscanf_l
#define _sntscanf _snwscanf
#define _sntscanf_l _snwscanf_l

#define _fgettc fgetwc
#define _fgettchar _fgetwchar
#define _fgetts fgetws
#define _fputtc fputwc
#define _fputtchar _fputwchar
#define _fputts fputws
#define _cputts _cputws
#define _cgetts _cgetws
#define _gettc getwc
#define _gettch _getwch
#define _gettche _getwche
#define _gettchar getwchar
#define _getts _getws
#define _puttc putwc
#define _puttchar putwchar
#define _puttch _putwch
#define _putts _putws
#define _ungettc ungetwc
#define _ungettch _ungetwch

#define _tcstof wcstof
#define _tcstod wcstod
#define _tcstold wcstold
#define _tcstol wcstol
#define _tcstoul wcstoul
#define _tcstoll wcstoll
#define _tcstoull wcstoull
#define _tcstoi64 _wcstoi64
#define _tcstoui64 _wcstoui64
#define _tcstoimax wcstoimax
#define _tcstoumax wcstoumax
#define _tstof _wtof
#define _tstol _wtol
#define _tstoi _wtoi
#define _tstoll _wtoll
#define _tstoi64 _wtoi64
#define _tcstof_l _wcstof_l
#define _tcstod_l _wcstod_l
/* TODO: #define _tcstold_l _wcstold_l  */
#define _tcstol_l _wcstol_l
#define _tcstoul_l _wcstoul_l
#define _tcstoll_l _wcstoll_l
#define _tcstoull_l _wcstoull_l
#define _tcstoi64_l _wcstoi64_l
#define _tcstoui64_l _wcstoui64_l
#define _tcstoimax_l _wcstoimax_l
#define _tcstoumax_l _wcstoumax_l
#define _tstof_l _wtof_l
#define _tstol_l _wtol_l
#define _tstoll_l _wtoll_l
#define _tstoi_l _wtoi_l
#define _tstoi64_l _wtoi64_l

#define _itot _itow
#define _ltot _ltow
#define _ultot _ultow
#define _ttof _wtof
#define _ttoi _wtoi
#define _ttol _wtol
#define _ttoll _wtoll

#define _ttoi64 _wtoi64
#define _i64tot _i64tow
#define _ui64tot _ui64tow

#define _tcscat wcscat
#define _tcschr wcschr
#define _tcscpy wcscpy
#define _tcscspn wcscspn
#define _tcslen wcslen
#define _tcsnlen wcsnlen
#define _tcsncat wcsncat
#define _tcsncat_l _wcsncat_l
#define _tcsncpy wcsncpy
#define _tcsncpy_l _wcsncpy_l
#define _tcspbrk wcspbrk
#define _tcsrchr wcsrchr
#define _tcsspn wcsspn
#define _tcsstr wcsstr
#define _tcstok _wcstok
#define _tcstok_l _wcstok_l
#define _tcserror _wcserror
#define __tcserror __wcserror

#define _tcsdup _wcsdup
#define _tcsdup_dbg _wcsdup_dbg
#define _tcsnset _wcsnset
#define _tcsnset_l _wcsnset_l
#define _tcsrev _wcsrev
#define _tcsset _wcsset
#define _tcsset_l _wcsset_l

#define _tcscmp wcscmp
#define _tcsicmp _wcsicmp
#define _tcsicmp_l _wcsicmp_l
#define _tcsnccmp wcsncmp
#define _tcsncmp wcsncmp
#define _tcsncicmp _wcsnicmp
#define _tcsncicmp_l _wcsnicmp_l
#define _tcsnicmp _wcsnicmp
#define _tcsnicmp_l _wcsnicmp_l

#define _tcscoll wcscoll
#define _tcscoll_l _wcscoll_l
#define _tcsicoll _wcsicoll
#define _tcsicoll_l _wcsicoll_l
#define _tcsnccoll _wcsncoll
#define _tcsnccoll_l _wcsncoll_l
#define _tcsncoll _wcsncoll
#define _tcsncoll_l _wcsncoll_l
#define _tcsncicoll _wcsnicoll
#define _tcsncicoll_l _wcsnicoll_l
#define _tcsnicoll _wcsnicoll
#define _tcsnicoll_l _wcsnicoll_l

#define _texecl _wexecl
#define _texecle _wexecle
#define _texeclp _wexeclp
#define _texeclpe _wexeclpe
#define _texecv _wexecv
#define _texecve _wexecve
#define _texecvp _wexecvp
#define _texecvpe _wexecvpe

#define _tspawnl _wspawnl
#define _tspawnle _wspawnle
#define _tspawnlp _wspawnlp
#define _tspawnlpe _wspawnlpe
#define _tspawnv _wspawnv
#define _tspawnve _wspawnve
#define _tspawnvp _wspawnvp
#define _tspawnvp _wspawnvp
#define _tspawnvpe _wspawnvpe

#define _tsystem _wsystem

#define _tasctime _wasctime
#define _tctime _wctime
#define _tctime32 _wctime32
#define _tctime64 _wctime64
#define _tstrdate _wstrdate
#define _tstrtime _wstrtime
#define _tutime _wutime
#define _tutime32 _wutime32
#define _tutime64 _wutime64
#define _tcsftime wcsftime
#define _tcsftime_l _wcsftime_l

#define _tchdir _wchdir
#define _tgetcwd _wgetcwd
#define _tgetcwd_dbg _wgetcwd_dbg
#define _tgetdcwd _wgetdcwd
#define _tgetdcwd_dbg _wgetdcwd_dbg
#define _tgetdcwd_lk_dbg _wgetdcwd_lk_dbg
#define _tmkdir _wmkdir
#define _trmdir _wrmdir

#define _tfullpath _wfullpath
#define _tfullpath_dbg _wfullpath_dbg
#define _tgetenv _wgetenv
#define _tmakepath _wmakepath
#define _tpgmptr _wpgmptr
#define _get_tpgmptr _get_wpgmptr
#define _tputenv _wputenv
#define _tsearchenv _wsearchenv
#define _tsplitpath _wsplitpath

#define _tfdopen _wfdopen
#define _tfsopen _wfsopen
#define _tfopen _wfopen
#define _tfreopen _wfreopen
#define _tperror _wperror
#define _tpopen _wpopen
#define _ttempnam _wtempnam
#define _ttempnam_dbg _wtempnam_dbg
#define _ttmpnam _wtmpnam

#define _taccess _waccess
#define _tchmod _wchmod
#define _tcreat _wcreat
#define _tfindfirst _wfindfirst
#define _tfindfirst32 _wfindfirst32
#define _tfindfirst64 _wfindfirst64
#define _tfindfirsti64 _wfindfirsti64
#define _tfindfirst32i64 _wfindfirst32i64
#define _tfindfirst64i32 _wfindfirst64i32
#define _tfindnext _wfindnext
#define _tfindnext32 _wfindnext32
#define _tfindnext64 _wfindnext64
#define _tfindnexti64 _wfindnexti64
#define _tfindnext32i64 _wfindnext32i64
#define _tfindnext64i32 _wfindnext64i32
#define _tmktemp _wmktemp
#define _topen _wopen
#define _tremove _wremove
#define _trename _wrename
#define _tsopen _wsopen
#define _tunlink _wunlink

#define _tfinddata_t _wfinddata_t
#define _tfinddata32_t _wfinddata32_t
#define _tfinddata64_t _wfinddata64_t
#define _tfinddatai64_t _wfinddatai64_t
#define _tfinddata32i64_t _wfinddata32i64_t
#define _tfinddata64i32_t _wfinddata64i32_t

#define _tstat _wstat
#define _tstat32 _wstat32
#define _tstat32i64 _wstat32i64
#define _tstat64 _wstat64
#define _tstat64i32 _wstat64i32
#define _tstati64 _wstati64

#define _tsetlocale _wsetlocale

#if __MSVCRT_VERSION__ >= 0x800
#define _fgettc_nolock _fgetwc_nolock
#define _fputtc_nolock _fputwc_nolock
#define _gettc_nolock _getwc_nolock
#define _gettch_nolock _getwch_nolock
#define _gettche_nolock _getwche_nolock
#define _gettchar_nolock _getwchar_nolock
#define _puttc_nolock _putwc_nolock
#define _puttchar_nolock _putwchar_nolock
#define _puttch_nolock _putwch_nolock
#define _ungettc_nolock _ungetwc_nolock
#define _ungettch_nolock _ungetwch_nolock
#define _tgetdcwd_nolock _wgetdcwd_nolock
#endif

#define _tcsclen wcslen
#define _tcscnlen wcsnlen
#define _tcsclen_l(_String,_Locale) wcslen(_String)
#define _tcscnlen_l(_String,_Max_count,_Locale) wcsnlen_l((_String),(_Max_count))
#define _tcsnccat wcsncat
#define _tcsnccat_l _wcsncat_l
#define _tcsnccpy wcsncpy
#define _tcsnccpy_l _wcsncpy_l
#define _tcsncset _wcsnset
#define _tcsncset_l _wcsnset_l

#define _tcsdec _wcsdec
#define _tcsinc _wcsinc
#define _tcsnbcnt _wcsncnt
#define _tcsnccnt _wcsncnt
#define _tcsnextc _wcsnextc
#define _tcsninc _wcsninc
#define _tcsspnp _wcsspnp

#define _tcslwr _wcslwr
#define _tcslwr_l _wcslwr_l
#define _tcsupr _wcsupr
#define _tcsupr_l _wcsupr_l
#define _tcsxfrm wcsxfrm
#define _tcsxfrm_l _wcsxfrm_l

#define _tclen(_pc) (1)
#define _tccpy(_pc1,_cpc2) ((*(_pc1) = *(_cpc2)))
#define _tccmp(_cpc1,_cpc2) ((*(_cpc1))-(*(_cpc2)))

#define _istalnum iswalnum
#define _istalnum_l _iswalnum_l
#define _istalpha iswalpha
#define _istalpha_l _iswalpha_l
#define _istascii iswascii
#define _istcntrl iswcntrl
#define _istcntrl_l _iswcntrl_l
#define _istdigit iswdigit
#define _istdigit_l _iswdigit_l
#define _istgraph iswgraph
#define _istgraph_l _iswgraph_l
#define _istlower iswlower
#define _istlower_l _iswlower_l
#define _istprint iswprint
#define _istprint_l _iswprint_l
#define _istpunct iswpunct
#define _istpunct_l _iswpunct_l
#define _istspace iswspace
#define _istspace_l _iswspace_l
#define _istupper iswupper
#define _istupper_l _iswupper_l
#define _istxdigit iswxdigit
#define _istxdigit_l _iswxdigit_l
#define _istblank iswblank
#define _istblank_l _iswblank_l

#define _totupper towupper
#define _totupper_l _towupper_l
#define _totlower towlower
#define _totlower_l _towlower_l

#define _istlegal(_Char) (1)
#define _istlead(_Char) (0)
#define _istleadbyte(_Char) (0)
#define _istleadbyte_l(_Char,_Locale) (0)

#define _wcsdec(_cpc1,_cpc2) ((_cpc1)>=(_cpc2) ? NULL : (_cpc2)-1)
#define _wcsinc(_pc) ((_pc)+1)
#define _wcsnextc(_cpc) ((unsigned int) *(_cpc))
#define _wcsninc(_pc,_sz) (((_pc)+(_sz)))
  _CRTIMP size_t __cdecl __wcsncnt(const wchar_t *_Str,size_t _MaxCount);
#define _wcsncnt(_cpc,_sz) (__wcsncnt(_cpc,_sz))
#define _wcsspnp(_cpc1,_cpc2) (!_cpc1 ? NULL : ((*((_cpc1)+wcsspn(_cpc1,_cpc2))) ? ((_cpc1)+wcsspn(_cpc1,_cpc2)) : NULL))
#define _wcsncpy_l(_Destination,_Source,_Count,_Locale) (wcsncpy(_Destination,_Source,_Count))
#define _wcsncat_l(_Destination,_Source,_Count,_Locale) (wcsncat(_Destination,_Source,_Count))
#define _wcstok_l(_String,_Delimiters,_Locale) (_wcstok(_String,_Delimiters))
#define _wcsnset_l(_Destination,_Value,_Count,_Locale) (_wcsnset(_Destination,_Value,_Count))
#define _wcsset_l(_Destination,_Value,_Locale) (_wcsset(_Destination,_Value))

  /* dirent structures and functions */
#define _tdirent	_wdirent
#define _TDIR 		_WDIR
#define _topendir	_wopendir
#define _tclosedir	_wclosedir
#define _treaddir	_wreaddir
#define _trewinddir	_wrewinddir
#define _ttelldir	_wtelldir
#define _tseekdir	_wseekdir

#endif /* __CYGWIN__ */

#else /* _UNICODE */

#ifdef __cplusplus
}
#endif

#include <string.h>

#ifdef __cplusplus
extern "C" {
#endif

#define _TEOF EOF

#define __T(x) x

#ifndef __CYGWIN__

#define _tmain main
#define _tWinMain WinMain
#ifdef _POSIX_
#define _tenviron environ
#else
#define _tenviron _environ
#endif
#define __targv __argv

#define _tprintf __ms_printf
#define _tprintf_l _printf_l
#define _tprintf_p _printf_p
#define _tprintf_p_l _printf_p_l
#define _tcprintf _cprintf
#define _tcprintf_l _cprintf_l
#define _tcprintf_p _cprintf_p
#define _tcprintf_p_l _cprintf_p_l
#define _vtcprintf _vcprintf
#define _vtcprintf_l _vcprintf_l
#define _vtcprintf_p _vcprintf_p
#define _vtcprintf_p_l _vcprintf_p_l
#define _ftprintf __ms_fprintf
#define _ftprintf_l _fprintf_l
#define _ftprintf_p _fprintf_p
#define _ftprintf_p_l _fprintf_p_l
#define _stprintf __ms_sprintf
#define _stprintf_l _sprintf_l
#define _stprintf_p _sprintf_p
#define _stprintf_p_l _sprintf_p_l
#define _sctprintf _scprintf
#define _sctprintf_l _scprintf_l
#define _sctprintf_p _scprintf_p
#define _sctprintf_p_l _scprintf_p_l
#define _sntprintf _snprintf
#define _sntprintf_l _snprintf_l
#define _vtprintf __ms_vprintf
#define _vtprintf_l _vprintf_l
#define _vtprintf_p _vprintf_p
#define _vtprintf_p_l _vprintf_p_l
#define _vftprintf __ms_vfprintf
#define _vftprintf_l _vfprintf_l
#define _vftprintf_p _vfprintf_p
#define _vftprintf_p_l _vfprintf_p_l
#define _vstprintf __ms_vsprintf
#define _vstprintf_l _vsprintf_l
#define _vstprintf_p _vsprintf_p
#define _vstprintf_p_l _vsprintf_p_l
#define _vsctprintf _vscprintf
#define _vsctprintf_l _vscprintf_l
#define _vsctprintf_p _vscprintf_p
#define _vsctprintf_p_l _vscprintf_p_l
#define _vsntprintf _vsnprintf
#define _vsntprintf_l _vsnprintf_l

#define _tscanf __ms_scanf
#define _tscanf_l _scanf_l
#define _tcscanf _cscanf
#define _tcscanf_l _cscanf_l
#define _ftscanf __ms_fscanf
#define _ftscanf_l _fscanf_l
#define _stscanf __ms_sscanf
#define _stscanf_l _sscanf_l
#define _sntscanf _snscanf
#define _sntscanf_l _snscanf_l

#define _fgettc fgetc
#define _fgettchar _fgetchar
#define _fgetts fgets
#define _fputtc fputc
#define _fputtchar _fputchar
#define _fputts fputs
#define _cputts _cputs
#define _gettc getc
#define _gettch _getch
#define _gettche _getche
#define _gettchar getchar
#define _getts gets
#define _cgetts _cgets
#define _puttc putc
#define _puttchar putchar
#define _puttch _putch
#define _putts puts
#define _ungettc ungetc
#define _ungettch _ungetch

#define _tcstof strtof
#define _tcstod strtod
#define _tcstold strtold
#define _tcstol strtol
#define _tcstoul strtoul
#define _tcstoll strtoll
#define _tcstoull strtoull
#define _tstof atof
#define _tstol atol
#define _tstoll atoll
#define _tstoi atoi
#define _tstoi64 _atoi64
#define _tcstof_l _strtof_l
#define _tcstod_l _strtod_l
/* TODO: #define _tcstold_l _strtold_l  */
#define _tcstol_l _strtol_l
#define _tcstoul_l _strtoul_l
#define _tcstoll_l _strtoll_l
#define _tcstoull_l _strtoull_l
#define _tstof_l _atof_l
#define _tstol_l _atol_l
#define _tstoi_l _atoi_l
#define _tstoll_l _atoll_l
#define _tstoi64_l _atoi64_l

#define _itot _itoa
#define _ltot _ltoa
#define _ultot _ultoa
#define _ttof atof
#define _ttoi atoi
#define _ttol atol
#define _ttoll atoll

#define _ttoi64 _atoi64
#define _tcstoi64 _strtoi64
#define _tcstoi64_l _strtoi64_l
#define _tcstoui64 _strtoui64
#define _tcstoui64_l _strtoui64_l
#define _tcstoimax strtoimax
#define _tcstoumax strtoumax
#define _tcstoimax_l _strtoimax_l
#define _tcstoumax_l _strtoumax_l
#define _i64tot _i64toa
#define _ui64tot _ui64toa

#define _tcscat strcat
#define _tcscpy strcpy
#define _tcsdup _strdup
#define _tcsdup_dbg _strdup_dbg
#define _tcslen strlen
#define _tcsnlen strnlen
#define _tcsxfrm strxfrm
#define _tcsxfrm_l _strxfrm_l
#define _tcserror strerror
#define __tcserror _strerror

#define _texecl _execl
#define _texecle _execle
#define _texeclp _execlp
#define _texeclpe _execlpe
#define _texecv _execv
#define _texecve _execve
#define _texecvp _execvp
#define _texecvpe _execvpe

#define _tspawnl _spawnl
#define _tspawnle _spawnle
#define _tspawnlp _spawnlp
#define _tspawnlpe _spawnlpe
#define _tspawnv _spawnv
#define _tspawnve _spawnve
#define _tspawnvp _spawnvp
#define _tspawnvpe _spawnvpe

#define _tsystem system

#define _tasctime asctime
#define _tctime ctime
#define _tctime32 _ctime32
#define _tctime64 _ctime64
#define _tstrdate _strdate
#define _tstrtime _strtime
#define _tutime _utime
#define _tutime32 _utime32
#define _tutime64 _utime64
#define _tcsftime strftime
#define _tcsftime_l _strftime_l

#define _tchdir _chdir
#define _tgetcwd _getcwd
#define _tgetcwd_dbg _getcwd_dbg
#define _tgetdcwd _getdcwd
#define _tgetdcwd_dbg _getdcwd_dbg
#define _tgetdcwd_lk_dbg _getdcwd_lk_dbg
#define _tmkdir _mkdir
#define _trmdir _rmdir

#define _tfullpath _fullpath
#define _tfullpath_dbg _fullpath_dbg
#define _tgetenv getenv
#define _tmakepath _makepath
#define _tpgmptr _pgmptr
#define _get_tpgmptr _get_pgmptr
#define _tputenv _putenv
#define _tsearchenv _searchenv
#define _tsplitpath _splitpath

#ifdef _POSIX_
#define _tfdopen fdopen
#else
#define _tfdopen _fdopen
#endif
#define _tfsopen _fsopen
#define _tfopen fopen
#define _tfreopen freopen
#define _tperror perror
#define _tpopen _popen
#define _ttempnam _tempnam
#define _ttempnam_dbg _tempnam_dbg
#define _ttmpnam tmpnam

#define _tchmod _chmod
#define _tcreat _creat
#define _tfindfirst _findfirst
#define _tfindfirst32 _findfirst32
#define _tfindfirst64 _findfirst64
#define _tfindfirsti64 _findfirsti64
#define _tfindfirst32i64 _findfirst32i64
#define _tfindfirst64i32 _findfirst64i32
#define _tfindnext _findnext
#define _tfindnext32 _findnext32
#define _tfindnext64 _findnext64
#define _tfindnexti64 _findnexti64
#define _tfindnext32i64 _findnext32i64
#define _tfindnext64i32 _findnext64i32
#define _tmktemp _mktemp

#ifdef _POSIX_
#define _topen open
#define _taccess access
#else
#define _topen _open
#define _taccess _access
#endif

#define _tremove remove
#define _trename rename
#define _tsopen _sopen
#define _tunlink _unlink

#define _tfinddata_t _finddata_t
#define _tfinddata32_t _finddata32_t
#define _tfinddata64_t __finddata64_t
#define _tfinddatai64_t _finddatai64_t
#define _tfinddata32i64_t _finddata32i64_t
#define _tfinddata64i32_t _finddata64i32_t

#define _istascii __isascii
#define _istcntrl iscntrl
#define _istcntrl_l _iscntrl_l
#define _istxdigit isxdigit
#define _istxdigit_l _isxdigit_l

#define _tstat _stat
#define _tstat32 _stat32
#define _tstat32i64 _stat32i64
#define _tstat64 _stat64
#define _tstat64i32 _stat64i32
#define _tstati64 _stati64

#define _tsetlocale setlocale

#if __MSVCRT_VERSION__ >= 0x800
#define _fgettc_nolock _fgetc_nolock
#define _fputtc_nolock _fputc_nolock
#define _gettc_nolock _getc_nolock
#define _gettch_nolock _getch_nolock
#define _gettche_nolock _getche_nolock
#define _gettchar_nolock _getchar_nolock
#define _puttc_nolock _putc_nolock
#define _puttchar_nolock _putchar_nolock
#define _puttch_nolock _putch_nolock
#define _ungettc_nolock _ungetc_nolock
#define _ungettch_nolock _ungetch_nolock
#define _tgetdcwd_nolock _getdcwd_nolock
#endif

#endif /* __CYGWIN__ */

#ifdef _MBCS

#ifdef __cplusplus
}
#endif

#ifndef __CYGWIN__

#include <mbstring.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __TCHAR_DEFINED
  typedef char _TCHAR;
  typedef signed char _TSCHAR;
  typedef unsigned char _TUCHAR;
  typedef unsigned char _TXCHAR;
  typedef unsigned int _TINT;
#define __TCHAR_DEFINED
#endif

#ifndef NO_OLDNAMES
#ifndef _TCHAR_DEFINED
#define _TCHAR_DEFINED
  typedef char TCHAR,*PTCHAR;
  typedef unsigned char TBYTE,*PTBYTE;
#endif
#endif

#ifdef _MB_MAP_DIRECT

#define _tcschr _mbschr
#define _tcscspn _mbscspn
#define _tcsncat _mbsnbcat
#define _tcsncat_l _mbsnbcat_l
#define _tcsncpy _mbsnbcpy
#define _tcsncpy_l _mbsnbcpy_l
#define _tcspbrk _mbspbrk
#define _tcsrchr _mbsrchr
#define _tcsspn _mbsspn
#define _tcsstr _mbsstr
#define _tcstok _mbstok
#define _tcstok_l _mbstok_l

#define _tcsnset _mbsnbset
#define _tcsnset_l _mbsnbset_l
#define _tcsrev _mbsrev
#define _tcsset _mbsset
#define _tcsset_l _mbsset_l

#define _tcscmp _mbscmp
#define _tcsicmp _mbsicmp
#define _tcsicmp_l _mbsicmp_l
#define _tcsnccmp _mbsncmp
#define _tcsncmp _mbsnbcmp
#define _tcsncicmp _mbsnicmp
#define _tcsncicmp_l _mbsnicmp_l
#define _tcsnicmp _mbsnbicmp
#define _tcsnicmp_l _mbsnbicmp_l

#define _tcscoll _mbscoll
#define _tcscoll_l _mbscoll_l
#define _tcsicoll _mbsicoll
#define _tcsicoll_l _mbsicoll_l
#define _tcsnccoll _mbsncoll
#define _tcsnccoll_l _mbsncoll_l
#define _tcsncoll _mbsnbcoll
#define _tcsncoll_l _mbsnbcoll_l
#define _tcsncicoll _mbsnicoll
#define _tcsncicoll_l _mbsnicoll_l
#define _tcsnicoll _mbsnbicoll
#define _tcsnicoll_l _mbsnbicoll_l

#define _tcsclen _mbslen
#define _tcscnlen _mbsnlen
#define _tcsclen_l _mbslen_l
#define _tcscnlen_l _mbsnlen_l
#define _tcsnccat _mbsncat
#define _tcsnccat_l _mbsncat_l
#define _tcsnccpy _mbsncpy
#define _tcsnccpy_l _mbsncpy_l
#define _tcsncset _mbsnset
#define _tcsncset_l _mbsnset_l

#define _tcsdec _mbsdec
#define _tcsinc _mbsinc
#define _tcsnbcnt _mbsnbcnt
#define _tcsnccnt _mbsnccnt
#define _tcsnextc _mbsnextc
#define _tcsninc _mbsninc
#define _tcsspnp _mbsspnp

#define _tcslwr _mbslwr
#define _tcslwr_l _mbslwr_l
#define _tcsupr _mbsupr
#define _tcsupr_l _mbsupr_l

#define _tclen _mbclen
#define _tccpy _mbccpy
#define _tccpy_l _mbccpy_l
#else

  _CRTIMP _CONST_RETURN char *__cdecl _tcschr(const char *_Str,unsigned int _Val);
  _CRTIMP size_t __cdecl _tcscspn(const char *_Str,const char *_Control);
  _CRTIMP char *__cdecl _tcsncat(char *_Dst,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsncat_l(char *_Dst,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsncpy(char *_Dst,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsncpy_l(char *_Dst,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP _CONST_RETURN char *__cdecl _tcspbrk(const char *_Str,const char *_Control);
  _CRTIMP _CONST_RETURN char *__cdecl _tcsrchr(const char *_Str,unsigned int _Ch);
  _CRTIMP size_t __cdecl _tcsspn(const char *_Str,const char *_Control);
  _CRTIMP _CONST_RETURN char *__cdecl _tcsstr(const char *_Str,const char *_Substr);
  _CRTIMP char *__cdecl _tcstok(char *_Str,const char *_Delim);
  _CRTIMP char *__cdecl _tcstok_l(char *_Str,const char *_Delim,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsnset(char *_Str,unsigned int _Val,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsrev(char *_Str);
  _CRTIMP char *__cdecl _tcsset(char *_Str,unsigned int _Val);
  _CRTIMP char *__cdecl _tcsset_l(char *_Str,unsigned int _Val,_locale_t _Locale);
  _CRTIMP int __cdecl _tcscmp(const char *_Str1,const char *_Str);
  _CRTIMP int __cdecl _tcsicmp(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _tcsicmp_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsnccmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsncmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsncicmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsncicmp_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsnicmp(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsnicmp_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _tcscoll(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _tcscoll_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsicoll(const char *_Str1,const char *_Str2);
  _CRTIMP int __cdecl _tcsicoll_l(const char *_Str1,const char *_Str2,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsnccoll(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsnccoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsncoll(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsncoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsncicoll(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsncicoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP int __cdecl _tcsnicoll(const char *_Str1,const char *_Str2,size_t _MaxCount);
  _CRTIMP int __cdecl _tcsnicoll_l(const char *_Str1,const char *_Str2,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP size_t __cdecl _tcsclen(const char *_Str);
  _CRTIMP size_t __cdecl _tcscnlen(const char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _tcsclen_l(const char *_Str,_locale_t _Locale);
  _CRTIMP size_t __cdecl _tcscnlen_l(const char *_Str,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsnccat(char *_Dst,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsnccat_l(char *_Dst,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsnccpy(char *_Dst,const char *_Src,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsnccpy_l(char *_Dst,const char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsncset(char *_Str,unsigned int _Val,size_t _MaxCount);
  _CRTIMP char *__cdecl _tcsncset_l(char *_Str,unsigned int _Val,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsdec(const char *_Start,const char *_Pos);
  _CRTIMP char *__cdecl _tcsinc(const char *_Ptr);
  _CRTIMP size_t __cdecl _tcsnbcnt(const char *_Str,size_t _MaxCount);
  _CRTIMP size_t __cdecl _tcsnccnt(const char *_Str,size_t _MaxCount);
  _CRTIMP unsigned int __cdecl _tcsnextc (const char *_Str);
  _CRTIMP char *__cdecl _tcsninc(const char *_Ptr,size_t _Count);
  _CRTIMP char *__cdecl _tcsspnp(const char *_Str1,const char *_Str2);
  _CRTIMP char *__cdecl _tcslwr(char *_Str);
  _CRTIMP char *__cdecl _tcslwr_l(char *_Str,_locale_t _Locale);
  _CRTIMP char *__cdecl _tcsupr(char *_Str);
  _CRTIMP char *__cdecl _tcsupr_l(char *_Str,_locale_t _Locale);
  _CRTIMP size_t __cdecl _tclen(const char *_Str);
  _CRTIMP void __cdecl _tccpy(char *_DstCh,const char *_SrcCh);

#ifdef __cplusplus
#ifndef _CPP_TCHAR_INLINES_DEFINED
#define _CPP_TCHAR_INLINES_DEFINED
  extern "C++" {
    extern inline char *__cdecl _tcschr(char *_S,unsigned int _C) { return ((char *)_tcschr((const char *)_S,_C)); }
    extern inline char *__cdecl _tcspbrk(char *_S,const char *_P) { return ((char *)_tcspbrk((const char *)_S,_P)); }
    extern inline char *__cdecl _tcsrchr(char *_S,unsigned int _C) { return ((char *)_tcsrchr((const char *)_S,_C)); }
    extern inline char *__cdecl _tcsstr(char *_S,const char *_P) { return ((char *)_tcsstr((const char *)_S,_P)); }
  }
#endif
#endif
#endif

#define _tccmp(_cp1,_cp2) _tcsnccmp(_cp1,_cp2,1)

#define _istalnum _ismbcalnum
#define _istalnum_l _ismbcalnum_l
#define _istalpha _ismbcalpha
#define _istalpha_l _ismbcalpha_l
#define _istdigit _ismbcdigit
#define _istdigit_l _ismbcdigit_l
#define _istgraph _ismbcgraph
#define _istgraph_l _ismbcgraph_l
#define _istlegal _ismbclegal
#define _istlegal_l _ismbclegal_l
#define _istlower _ismbclower
#define _istlower_l _ismbclower_l
#define _istprint _ismbcprint
#define _istprint_l _ismbcprint_l
#define _istpunct _ismbcpunct
#define _istpunct_l _ismbcpunct_l
#define _istspace _ismbcspace
#define _istspace_l _ismbcspace_l
#define _istupper _ismbcupper
#define _istupper_l _ismbcupper_l
#define _istblank _ismbcblank
#define _istblank_l _ismbcblank_l

#define _totupper _mbctoupper
#define _totupper_l _mbctoupper_l
#define _totlower _mbctolower
#define _totlower_l _mbctolower_l

#define _istlead _ismbblead
#define _istleadbyte isleadbyte
#define _istleadbyte_l _isleadbyte_l

#endif /* __CYGWIN__ */

#else /* _MBCS */

#ifndef __TCHAR_DEFINED
#define __TCHAR_DEFINED
  typedef char _TCHAR;
  typedef signed char _TSCHAR;
  typedef unsigned char _TUCHAR;
  typedef char _TXCHAR;
  typedef int _TINT;
#endif

#ifndef NO_OLDNAMES
#ifndef _TCHAR_DEFINED
#define _TCHAR_DEFINED
  typedef char TCHAR,*PTCHAR;
  typedef unsigned char TBYTE,*PTBYTE;
#endif
#endif

#ifndef __CYGWIN__

#define _tcschr strchr
#define _tcscspn strcspn
#define _tcsncat strncat
#define _tcsncat_l _strncat_l
#define _tcsncpy strncpy
#define _tcsncpy_l _strncpy_l
#define _tcspbrk strpbrk
#define _tcsrchr strrchr
#define _tcsspn strspn
#define _tcsstr strstr
#define _tcstok strtok
#define _tcstok_l _strtok_l

#define _tcsnset _strnset
#define _tcsnset_l _strnset_l
#define _tcsrev _strrev
#define _tcsset _strset
#define _tcsset_l _strset_l

#define _tcscmp strcmp
#define _tcsicmp _stricmp
#define _tcsicmp_l _stricmp_l
#define _tcsnccmp strncmp
#define _tcsncmp strncmp
#define _tcsncicmp _strnicmp
#define _tcsncicmp_l _strnicmp_l
#define _tcsnicmp _strnicmp
#define _tcsnicmp_l _strnicmp_l

#define _tcscoll strcoll
#define _tcscoll_l _strcoll_l
#define _tcsicoll _stricoll
#define _tcsicoll_l _stricoll_l
#define _tcsnccoll _strncoll
#define _tcsnccoll_l _strncoll_l
#define _tcsncoll _strncoll
#define _tcsncoll_l _strncoll_l
#define _tcsncicoll _strnicoll
#define _tcsncicoll_l _strnicoll_l
#define _tcsnicoll _strnicoll
#define _tcsnicoll_l _strnicoll_l

#define _tcsclen strlen
#define _tcscnlen strnlen
#define _tcsclen_l(_String,_Locale) strlen(_String)
#define _tcscnlen_l(_String,_Max_count,_Locale) strnlen_l((_String),(_Max_count))
#define _tcsnccat strncat
#define _tcsnccat_l _strncat_l
#define _tcsnccpy strncpy
#define _tcsnccpy_l _strncpy_l
#define _tcsncset _strnset
#define _tcsncset_l _strnset_l

#define _tcsdec _strdec
#define _tcsinc _strinc
#define _tcsnbcnt _strncnt
#define _tcsnccnt _strncnt
#define _tcsnextc _strnextc
#define _tcsninc _strninc
#define _tcsspnp _strspnp

#define _tcslwr _strlwr
#define _tcslwr_l _strlwr_l
#define _tcsupr _strupr
#define _tcsupr_l _strupr_l
#define _tcsxfrm strxfrm
#define _tcsxfrm_l _strxfrm_l

#define _istlead(_Char) (0)
#define _istleadbyte(_Char) (0)
#define _istleadbyte_l(_Char,_Locale) (0)

#define _tclen(_pc) (1)
#define _tccpy(_pc1,_cpc2) (*(_pc1) = *(_cpc2))
#define _tccmp(_cpc1,_cpc2) (((unsigned char)*(_cpc1))-((unsigned char)*(_cpc2)))

  /* dirent structures and functions */
#define _tdirent	dirent
#define _TDIR 		DIR
#define _topendir	opendir
#define _tclosedir	closedir
#define _treaddir	readdir
#define _trewinddir	rewinddir
#define _ttelldir	telldir
#define _tseekdir	seekdir

#define _istalnum isalnum
#define _istalnum_l _isalnum_l
#define _istalpha isalpha
#define _istalpha_l _isalpha_l
#define _istdigit isdigit
#define _istdigit_l _isdigit_l
#define _istgraph isgraph
#define _istgraph_l _isgraph_l
#define _istlower islower
#define _istlower_l _islower_l
#define _istprint isprint
#define _istprint_l _isprint_l
#define _istpunct ispunct
#define _istpunct_l _ispunct_l
#define _istspace isspace
#define _istspace_l _isspace_l
#define _istupper isupper
#define _istupper_l _isupper_l
#define _istblank isblank
#define _istblank_l _isblank_l

#define _totupper toupper
#define _totupper_l _toupper_l
#define _totlower tolower
#define _totlower_l _tolower_l

#define _istlegal(_c) (1)

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

#define _strdec(_cpc1,_cpc2) ((_cpc1)>=(_cpc2) ? NULL : (_cpc2)-1)
#define _strinc(_pc) ((_pc)+1)
#define _strnextc(_cpc) ((unsigned int) *(const unsigned char *)(_cpc))
#define _strninc(_pc,_sz) (((_pc)+(_sz)))
  _CRTIMP size_t __cdecl __strncnt(const char *_Str,size_t _Cnt);
#define _strncnt(_cpc,_sz) (__strncnt(_cpc,_sz))
#define _strspnp(_cpc1,_cpc2) (!_cpc1 ? NULL : ((*((_cpc1)+strspn(_cpc1,_cpc2))) ? ((_cpc1)+strspn(_cpc1,_cpc2)) : NULL))

#define _strncpy_l(_Destination,_Source,_Count,_Locale) (strncpy(_Destination,_Source,_Count))
#define _strncat_l(_Destination,_Source,_Count,_Locale) (strncat(_Destination,_Source,_Count))
#define _strtok_l(_String,_Delimiters,_Locale) (strtok(_String,_Delimiters))
#define _strnset_l(_Destination,_Value,_Count,_Locale) (_strnset(_Destination,_Value,_Count))
#define _strset_l(_Destination,_Value,_Locale) (_strset(_Destination,_Value))
#endif
#endif /* _MBCS */

#endif /* _UNICODE */

#define _T(x) __T(x)
#define _TEXT(x) __T(x)

#ifdef __cplusplus
}
#endif

#ifndef __CYGWIN__
#include <sec_api/tchar_s.h>
#endif /* __CYGWIN__ */
#endif
