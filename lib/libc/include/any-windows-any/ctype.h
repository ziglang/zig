/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CTYPE
#define _INC_CTYPE

#include <corecrt_wctype.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WEOF
#define WEOF (wint_t)(0xFFFF)
#endif

  /* CRT stuff */
#if 1
  extern const unsigned char __newclmap[];
  extern const unsigned char __newcumap[];
  extern pthreadlocinfo __ptlocinfo;
  extern pthreadmbcinfo __ptmbcinfo;
  extern int __globallocalestatus;
  extern int __locale_changed;
  extern struct threadlocaleinfostruct __initiallocinfo;
  extern _locale_tstruct __initiallocalestructinfo;
  pthreadlocinfo __cdecl __updatetlocinfo(void);
  pthreadmbcinfo __cdecl __updatetmbcinfo(void);
#endif

#ifndef _CTYPE_DEFINED
#define _CTYPE_DEFINED

  _CRTIMP int __cdecl isalpha(int _C);
  _CRTIMP int __cdecl isupper(int _C);
  _CRTIMP int __cdecl islower(int _C);
  _CRTIMP int __cdecl isdigit(int _C);
  _CRTIMP int __cdecl isxdigit(int _C);
  _CRTIMP int __cdecl isspace(int _C);
  _CRTIMP int __cdecl ispunct(int _C);
  _CRTIMP int __cdecl isalnum(int _C);
  _CRTIMP int __cdecl isprint(int _C);
  _CRTIMP int __cdecl isgraph(int _C);
  _CRTIMP int __cdecl iscntrl(int _C);
  _CRTIMP int __cdecl toupper(int _C);
  _CRTIMP int __cdecl _toupper(int _C);
  _CRTIMP int __cdecl tolower(int _C);
  _CRTIMP int __cdecl _tolower(int _C);
  _CRTIMP int __cdecl _tolower_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isctype(int _C,int _Type);
  _CRTIMP int __cdecl isblank(int _C);
  _CRTIMP int __cdecl _isalpha_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isupper_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _islower_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isdigit_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isxdigit_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isspace_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ispunct_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isalnum_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isprint_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isgraph_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _iscntrl_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _toupper_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _isctype_l(int _C,int _Type,_locale_t _Locale);
  _CRTIMP int __cdecl _isblank_l(int _C,_locale_t _Locale);
  _CRTIMP int __cdecl __isascii(int _C);
  _CRTIMP int __cdecl __toascii(int _C);
  _CRTIMP int __cdecl __iscsymf(int _C);
  _CRTIMP int __cdecl __iscsym(int _C);
#endif

#ifndef _CTYPE_DISABLE_MACROS

#ifndef MB_CUR_MAX
#define MB_CUR_MAX ___mb_cur_max_func()
#ifndef __mb_cur_max
#define __mb_cur_max	(___mb_cur_max_func())
#endif
_CRTIMP int __cdecl ___mb_cur_max_func(void);
#endif

#define __chvalidchk(a,b) (__PCTYPE_FUNC[(unsigned char)(a)] & (b))
#ifdef _UCRT
#define _chvalidchk_l(_Char,_Flag,_Locale) (!_Locale ? __chvalidchk(_Char,_Flag) : ((_locale_t)_Locale)->locinfo->_locale_pctype[(unsigned char)(_Char)] & (_Flag))
#define _ischartype_l(_Char,_Flag,_Locale) (((_Locale)!=NULL && (((_locale_t)(_Locale))->locinfo->_locale_mb_cur_max) > 1) ? _isctype_l(_Char,(_Flag),_Locale) : _chvalidchk_l(_Char,_Flag,_Locale))
#else
#define _chvalidchk_l(_Char,_Flag,_Locale) (!_Locale ? __chvalidchk(_Char,_Flag) : ((_locale_t)_Locale)->locinfo->pctype[(unsigned char)(_Char)] & (_Flag))
#define _ischartype_l(_Char,_Flag,_Locale) (((_Locale)!=NULL && (((_locale_t)(_Locale))->locinfo->mb_cur_max) > 1) ? _isctype_l(_Char,(_Flag),_Locale) : _chvalidchk_l(_Char,_Flag,_Locale))
#endif
#define _isalpha_l(_Char,_Locale) _ischartype_l(_Char,_ALPHA,_Locale)
#define _isupper_l(_Char,_Locale) _ischartype_l(_Char,_UPPER,_Locale)
#define _islower_l(_Char,_Locale) _ischartype_l(_Char,_LOWER,_Locale)
#define _isdigit_l(_Char,_Locale) _ischartype_l(_Char,_DIGIT,_Locale)
#define _isxdigit_l(_Char,_Locale) _ischartype_l(_Char,_HEX,_Locale)
#define _isspace_l(_Char,_Locale) _ischartype_l(_Char,_SPACE,_Locale)
#define _ispunct_l(_Char,_Locale) _ischartype_l(_Char,_PUNCT,_Locale)
#define _isalnum_l(_Char,_Locale) _ischartype_l(_Char,_ALPHA|_DIGIT,_Locale)
#define _isprint_l(_Char,_Locale) _ischartype_l(_Char,_BLANK|_PUNCT|_ALPHA|_DIGIT,_Locale)
#define _isgraph_l(_Char,_Locale) _ischartype_l(_Char,_PUNCT|_ALPHA|_DIGIT,_Locale)
#define _iscntrl_l(_Char,_Locale) _ischartype_l(_Char,_CONTROL,_Locale)
#define _isblank_l(_Char,_Locale) (((_Char) == '\t') || _ischartype_l(_Char,_BLANK,_Locale))
#define _tolower(_Char) ((_Char)-'A'+'a')
#define _toupper(_Char) ((_Char)-'a'+'A')
#define __isascii(_Char) ((unsigned)(_Char) < 0x80)
#define __toascii(_Char) ((_Char) & 0x7f)

#define __iscsymf(_c) (isalpha(_c) || ((_c)=='_'))
#define __iscsym(_c) (isalnum(_c) || ((_c)=='_'))
#define __iswcsymf(_c) (iswalpha(_c) || ((_c)=='_'))
#define __iswcsym(_c) (iswalnum(_c) || ((_c)=='_'))
#define _iscsymf_l(_c,_p) (_isalpha_l(_c,_p) || ((_c)=='_'))
#define _iscsym_l(_c,_p) (_isalnum_l(_c,_p) || ((_c)=='_'))
#define _iswcsymf_l(_c,_p) (_iswalpha_l(_c,_p) || ((_c)=='_'))
#define _iswcsym_l(_c,_p) (_iswalnum_l(_c,_p) || ((_c)=='_'))
#endif

#ifndef	NO_OLDNAMES
#ifndef _CTYPE_DEFINED
  _CRTIMP int __cdecl isascii(int _C) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl toascii(int _C) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl iscsymf(int _C) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
  _CRTIMP int __cdecl iscsym(int _C) __MINGW_ATTRIB_DEPRECATED_MSVC2005;
#else
#define isascii __isascii
#define toascii __toascii
#define iscsymf __iscsymf
#define iscsym __iscsym
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
