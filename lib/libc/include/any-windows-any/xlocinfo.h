/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _XLOCINFO
#define _XLOCINFO
#include <ctype.h>
#include <locale.h>
#include <wchar.h>
#include <yvals.h>

#pragma pack(push,_CRT_PACKING)

_C_STD_BEGIN
_C_LIB_DECL

#define _XA 0x100
#define _XS 0x000
#define _BB _CONTROL
#define _CN _SPACE
#define _DI _DIGIT
#define _LO _LOWER
#define _PU _PUNCT
#define _SP _BLANK
#define _UP _UPPER
#define _XD _HEX

#define _X_ALL LC_ALL
#define _X_COLLATE LC_COLLATE
#define _X_CTYPE LC_CTYPE
#define _X_MONETARY LC_MONETARY
#define _X_NUMERIC LC_NUMERIC
#define _X_TIME LC_TIME
#define _X_MAX LC_MAX
#define _X_MESSAGES 6
#define _NCAT 7

#define _CATMASK(n) ((1 << (n)) >> 1)
#define _M_COLLATE _CATMASK(_X_COLLATE)
#define _M_CTYPE _CATMASK(_X_CTYPE)
#define _M_MONETARY _CATMASK(_X_MONETARY)
#define _M_NUMERIC _CATMASK(_X_NUMERIC)
#define _M_TIME _CATMASK(_X_TIME)
#define _M_MESSAGES _CATMASK(_X_MESSAGES)
#define _M_ALL (_CATMASK(_NCAT) - 1)

typedef struct _Collvec {
  unsigned long _Hand;
  unsigned int _Page;
} _Collvec;

typedef struct _Ctypevec {
  unsigned long _Hand;
  unsigned int _Page;
  const short *_Table;
  int _Delfl;
} _Ctypevec;

typedef struct _Cvtvec {
  unsigned long _Hand;
  unsigned int _Page;
} _Cvtvec;

_CRTIMP _Collvec __cdecl _Getcoll();
_CRTIMP _Ctypevec __cdecl _Getctype();
_CRTIMP _Cvtvec __cdecl _Getcvt();
_CRTIMP int __cdecl _Getdateorder();
_CRTIMP int __cdecl _Mbrtowc(wchar_t *,const char *,size_t,mbstate_t *,const _Cvtvec *);
_CRTIMP float __cdecl _Stof(const char *,char **,long);
_CRTIMP double __cdecl _Stod(const char *,char **,long);
_CRTIMP long double __cdecl _Stold(const char *,char **,long);
_CRTIMP int __cdecl _Strcoll(const char *,const char *,const char *,const char *,const _Collvec *);
_CRTIMP size_t __cdecl _Strxfrm(char *_String1,char *_End1,const char *,const char *,const _Collvec *);
_CRTIMP int __cdecl _Tolower(int,const _Ctypevec *);
_CRTIMP int __cdecl _Toupper(int,const _Ctypevec *);
_CRTIMP int __cdecl _Wcrtomb(char *,wchar_t,mbstate_t *,const _Cvtvec *);
_CRTIMP int __cdecl _Wcscoll(const wchar_t *,const wchar_t *,const wchar_t *,const wchar_t *,const _Collvec *);
_CRTIMP size_t __cdecl _Wcsxfrm(wchar_t *_String1,wchar_t *_End1,const wchar_t *,const wchar_t *,const _Collvec *);
_CRTIMP short __cdecl _Getwctype(wchar_t,const _Ctypevec *);
_CRTIMP const wchar_t *__cdecl _Getwctypes(const wchar_t *,const wchar_t *,short*,const _Ctypevec*);
_CRTIMP wchar_t __cdecl _Towlower(wchar_t,const _Ctypevec *);
_CRTIMP wchar_t __cdecl _Towupper(wchar_t,const _Ctypevec *);
_END_C_LIB_DECL
_C_STD_END

_C_LIB_DECL
_CRTIMP void *__cdecl _Gettnames();
_CRTIMP char *__cdecl _Getdays();
_CRTIMP char *__cdecl _Getmonths();
_CRTIMP size_t __cdecl _Strftime(char *,size_t _Maxsize,const char *,const struct tm *,void *);
_END_C_LIB_DECL

_C_LIB_DECL
_locale_t __cdecl _GetLocaleForCP(unsigned int);
_END_C_LIB_DECL

#pragma pack(pop)
#endif
