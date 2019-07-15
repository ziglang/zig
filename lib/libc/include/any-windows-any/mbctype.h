/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MBCTYPE
#define _INC_MBCTYPE

#include <crtdefs.h>
#include <ctype.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _mbctype
#ifdef _MSVCRT_
  extern unsigned char _mbctype[257];
#else
  extern unsigned char ** __MINGW_IMP_SYMBOL(_mbctype);
#define _mbctype (* __MINGW_IMP_SYMBOL(_mbctype))
#endif
#endif
#ifndef _mbcasemap
#ifdef _MSVCRT_
  extern unsigned char *_mbcasemap;
#else
  extern unsigned char ** __MINGW_IMP_SYMBOL(_mbcasemap);
#define _mbcasemap (* __MINGW_IMP_SYMBOL(_mbcasemap))
#endif
#endif

  extern pthreadmbcinfo __ptmbcinfo;
  extern int __globallocalestatus;
  extern int __locale_changed;
  extern struct threadmbcinfostruct __initialmbcinfo;
  pthreadmbcinfo __cdecl __updatetmbcinfo(void);

#define _MS 0x01
#define _MP 0x02
#define _M1 0x04
#define _M2 0x08

#define _SBUP 0x10
#define _SBLOW 0x20

#define _MBC_SINGLE 0
#define _MBC_LEAD 1
#define _MBC_TRAIL 2
#define _MBC_ILLEGAL (-1)

#define _KANJI_CP 932

#define _MB_CP_SBCS 0
#define _MB_CP_OEM -2
#define _MB_CP_ANSI -3
#define _MB_CP_LOCALE -4

#ifndef _MBCTYPE_DEFINED
#define _MBCTYPE_DEFINED

  _CRTIMP int __cdecl _setmbcp(int _CodePage);
  _CRTIMP int __cdecl _getmbcp(void);
  _CRTIMP int __cdecl _ismbbkalnum(unsigned int _C);
  _CRTIMP int __cdecl _ismbbkalnum_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbkana(unsigned int _C);
  _CRTIMP int __cdecl _ismbbkana_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbkpunct(unsigned int _C);
  _CRTIMP int __cdecl _ismbbkpunct_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbkprint(unsigned int _C);
  _CRTIMP int __cdecl _ismbbkprint_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbalpha(unsigned int _C);
  _CRTIMP int __cdecl _ismbbalpha_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbpunct(unsigned int _C);
  _CRTIMP int __cdecl _ismbbpunct_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbalnum(unsigned int _C);
  _CRTIMP int __cdecl _ismbbalnum_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbprint(unsigned int _C);
  _CRTIMP int __cdecl _ismbbprint_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbgraph(unsigned int _C);
  _CRTIMP int __cdecl _ismbbgraph_l(unsigned int _C,_locale_t _Locale);
#ifndef _MBLEADTRAIL_DEFINED
#define _MBLEADTRAIL_DEFINED
  _CRTIMP int __cdecl _ismbblead(unsigned int _C);
  _CRTIMP int __cdecl _ismbblead_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbbtrail(unsigned int _C);
  _CRTIMP int __cdecl _ismbbtrail_l(unsigned int _C,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbslead(const unsigned char *_Str,const unsigned char *_Pos);
  _CRTIMP int __cdecl _ismbslead_l(const unsigned char *_Str,const unsigned char *_Pos,_locale_t _Locale);
  _CRTIMP int __cdecl _ismbstrail(const unsigned char *_Str,const unsigned char *_Pos);
  _CRTIMP int __cdecl _ismbstrail_l(const unsigned char *_Str,const unsigned char *_Pos,_locale_t _Locale);
#endif
#endif

_CRTIMP void __cdecl _mbccpy (unsigned char *dest, const unsigned char *src) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;
_CRTIMP void __cdecl _mbccpy_l(unsigned char *dest,const unsigned char *src,_locale_t locale) __MINGW_ATTRIB_DEPRECATED_SEC_WARN;

#ifdef __cplusplus
}
#endif
#endif
