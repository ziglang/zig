/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_STDLIB_S
#define _INC_STDLIB_S

#include <stdlib.h>

#ifdef __cplusplus
extern "C" {
#endif

  _CRTIMP void * __cdecl bsearch_s(const void *_Key,const void *_Base,rsize_t _NumOfElements,rsize_t _SizeOfElements,int (__cdecl * _PtFuncCompare)(void *, const void *, const void *), void *_Context);
  _CRTIMP errno_t __cdecl _dupenv_s(char **_PBuffer,size_t *_PBufferSizeInBytes,const char *_VarName);
  _CRTIMP errno_t __cdecl getenv_s(size_t *_ReturnSize,char *_DstBuf,rsize_t _DstSize,const char *_VarName);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t, getenv_s, size_t *, _ReturnSize, char, _Dest, const char *, _VarName)
  _CRTIMP errno_t __cdecl _itoa_s(int _Value,char *_DstBuf,size_t _Size,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t, _itoa_s, int, _Value, char, _Dest, int, _Radix)
  _CRTIMP errno_t __cdecl _i64toa_s(__int64 _Val,char *_DstBuf,size_t _Size,int _Radix);
  _CRTIMP errno_t __cdecl _ui64toa_s(unsigned __int64 _Val,char *_DstBuf,size_t _Size,int _Radix);
  _CRTIMP errno_t __cdecl _ltoa_s(long _Val,char *_DstBuf,size_t _Size,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t, _ltoa_s, long, _Value, char, _Dest, int, _Radix)
  _CRTIMP errno_t __cdecl mbstowcs_s(size_t *_PtNumOfCharConverted,wchar_t *_DstBuf,size_t _SizeInWords,const char *_SrcBuf,size_t _MaxCount);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_2(errno_t, mbstowcs_s, size_t *, _PtNumOfCharConverted, wchar_t, _Dest, const char *, _Source, size_t, _MaxCount)
  _CRTIMP errno_t __cdecl _mbstowcs_s_l(size_t *_PtNumOfCharConverted,wchar_t *_DstBuf,size_t _SizeInWords,const char *_SrcBuf,size_t _MaxCount,_locale_t _Locale);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_3(errno_t, _mbstowcs_s_l, size_t *, _PtNumOfCharConverted, wchar_t, _Dest, const char *, _Source, size_t, _MaxCount, _locale_t, _Locale)
  _CRTIMP errno_t __cdecl _ultoa_s(unsigned long _Val,char *_DstBuf,size_t _Size,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t, _ultoa_s, unsigned long, _Value, char, _Dest, int, _Radix)
  _CRTIMP errno_t __cdecl wctomb_s(int *_SizeConverted,char *_MbCh,rsize_t _SizeInBytes,wchar_t _WCh);
  _CRTIMP errno_t __cdecl _wctomb_s_l(int *_SizeConverted,char *_MbCh,size_t _SizeInBytes,wchar_t _WCh,_locale_t _Locale);
  _CRTIMP errno_t __cdecl wcstombs_s(size_t *_PtNumOfCharConverted,char *_Dst,size_t _DstSizeInBytes,const wchar_t *_Src,size_t _MaxCountInBytes);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_2(errno_t, wcstombs_s, size_t*, _PtNumOfCharConverted, char, _Dst, const wchar_t*, _Src, size_t, _MaxCountInBytes)
  _CRTIMP errno_t __cdecl _wcstombs_s_l(size_t *_PtNumOfCharConverted,char *_Dst,size_t _DstSizeInBytes,const wchar_t *_Src,size_t _MaxCountInBytes,_locale_t _Locale);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_3(errno_t, _wcstombs_s_l, size_t*, _PtNumOfCharConverted, char, _Dst, const wchar_t*, _Src, size_t, _MaxCountInBytes, _locale_t, _Locale)

#ifndef _POSIX_
  _CRTIMP errno_t __cdecl _ecvt_s(char *_DstBuf,size_t _Size,double _Val,int _NumOfDights,int *_PtDec,int *_PtSign);
  _CRTIMP errno_t __cdecl _fcvt_s(char *_DstBuf,size_t _Size,double _Val,int _NumOfDec,int *_PtDec,int *_PtSign);
  _CRTIMP errno_t __cdecl _gcvt_s(char *_DstBuf,size_t _Size,double _Val,int _NumOfDigits);
  _CRTIMP errno_t __cdecl _makepath_s(char *_PathResult,size_t _Size,const char *_Drive,const char *_Dir,const char *_Filename,const char *_Ext);
  _CRTIMP errno_t __cdecl _putenv_s(const char *_Name,const char *_Value);
  _CRTIMP errno_t __cdecl _searchenv_s(const char *_Filename,const char *_EnvVar,char *_ResultPath,size_t _SizeInBytes);

  _CRTIMP errno_t __cdecl _splitpath_s(const char *_FullPath,char *_Drive,size_t _DriveSize,char *_Dir,size_t _DirSize,char *_Filename,size_t _FilenameSize,char *_Ext,size_t _ExtSize);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_SPLITPATH(errno_t,_splitpath_s,char,_Dest)

#ifndef _QSORT_S_DEFINED
#define _QSORT_S_DEFINED
  _CRTIMP void __cdecl qsort_s(void *_Base,size_t _NumOfElements,size_t _SizeOfElements,int (__cdecl *_PtFuncCompare)(void *,const void *,const void *),void *_Context);
#endif

#endif

#ifdef __cplusplus
}
#endif

#endif
