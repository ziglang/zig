/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_MBSTRING_S
#define _INC_MBSTRING_S

#include <mbstring.h>

#if defined(MINGW_HAS_SECURE_API)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _MBSTRING_S_DEFINED
#define _MBSTRING_S_DEFINED
  _CRTIMP errno_t __cdecl _mbscat_s(unsigned char *_Dst, size_t _SizeInBytes, const unsigned char *_Src);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1(errno_t, _mbscat_s, unsigned char, _Dst, const unsigned char *, _DstSizeInBytes)

  _CRTIMP errno_t __cdecl _mbscpy_s(unsigned char *_Dst, size_t _SizeInBytes, const unsigned char *_Src);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_1(errno_t, _mbscpy_s, unsigned char, _Dest, const unsigned char *, _Source)

  _CRTIMP errno_t __cdecl _mbscpy_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbslwr_s(unsigned char *_Str,size_t _SizeInBytes);
  _CRTIMP errno_t __cdecl _mbslwr_s_l(unsigned char *_Str,size_t _SizeInBytes,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsnbcat_s(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsnbcat_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsnbcpy_s(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsnbcpy_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsnbset_s(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Ch,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsnbset_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Ch,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsncat_s(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsncat_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsncpy_s(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsncpy_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,const unsigned char *_Src,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsnset_s(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Val,size_t _MaxCount);
  _CRTIMP errno_t __cdecl _mbsnset_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Val,size_t _MaxCount,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsset_s(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Val);
  _CRTIMP errno_t __cdecl _mbsset_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,unsigned int _Val,_locale_t _Locale);
  _CRTIMP unsigned char *__cdecl _mbstok_s(unsigned char *_Str,const unsigned char *_Delim,unsigned char **_Context);
  _CRTIMP unsigned char *__cdecl _mbstok_s_l(unsigned char *_Str,const unsigned char *_Delim,unsigned char **_Context,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbsupr_s(unsigned char *_Str,size_t _SizeInBytes);
  _CRTIMP errno_t __cdecl _mbsupr_s_l(unsigned char *_Str,size_t _SizeInBytes,_locale_t _Locale);
  _CRTIMP errno_t __cdecl _mbccpy_s(unsigned char *_Dst,size_t _DstSizeInBytes,int *_PCopied,const unsigned char *_Src);
  _CRTIMP errno_t __cdecl _mbccpy_s_l(unsigned char *_Dst,size_t _DstSizeInBytes,int *_PCopied,const unsigned char *_Src,_locale_t _Locale);
#endif

#ifdef __cplusplus
}
#endif

#endif
#endif
