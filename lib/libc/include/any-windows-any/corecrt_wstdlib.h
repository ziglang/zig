/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CORECRT_WSTDLIB
#define _INC_CORECRT_WSTDLIB

#include <corecrt.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma push_macro("_wdupenv_s")
#undef _wdupenv_s
#endif
  _CRTIMP errno_t __cdecl _wdupenv_s(wchar_t **_Buffer,size_t *_BufferSizeInWords,const wchar_t *_VarName);
#if defined(_DEBUG) && defined(_CRTDBG_MAP_ALLOC)
#pragma pop_macro("_wdupenv_s")
#endif

  _CRTIMP errno_t __cdecl _itow_s (int _Val,wchar_t *_DstBuf,size_t _SizeInWords,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t,_itow_s,int,_Val,wchar_t,_DstBuf,int,_Radix)

  _CRTIMP errno_t __cdecl _ltow_s (long _Val,wchar_t *_DstBuf,size_t _SizeInWords,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t,_ltow_s,long,_Val,wchar_t,_DstBuf,int,_Radix)

  _CRTIMP errno_t __cdecl _ultow_s (unsigned long _Val,wchar_t *_DstBuf,size_t _SizeInWords,int _Radix);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t,_ultow_s,unsigned long,_Val,wchar_t,_DstBuf,int,_Radix)

  _CRTIMP errno_t __cdecl _wgetenv_s(size_t *_ReturnSize,wchar_t *_DstBuf,size_t _DstSizeInWords,const wchar_t *_VarName);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_1_1(errno_t,_wgetenv_s,size_t*,_ReturnSize,wchar_t,_DstBuf,const wchar_t*,_VarName)

  _CRTIMP errno_t __cdecl _i64tow_s(__int64 _Val,wchar_t *_DstBuf,size_t _SizeInWords,int _Radix);
  _CRTIMP errno_t __cdecl _ui64tow_s(unsigned __int64 _Val,wchar_t *_DstBuf,size_t _SizeInWords,int _Radix);

  _CRTIMP errno_t __cdecl _wmakepath_s(wchar_t *_PathResult,size_t _SizeInWords,const wchar_t *_Drive,const wchar_t *_Dir,const wchar_t *_Filename,const wchar_t *_Ext);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_0_4(errno_t,_wmakepath_s,wchar_t,_PathResult,const wchar_t*,_Drive,const wchar_t*,_Dir,const wchar_t*,_Filename,const wchar_t*,_Ext)

  _CRTIMP errno_t __cdecl _wputenv_s(const wchar_t *_Name,const wchar_t *_Value);

  _CRTIMP errno_t __cdecl _wsearchenv_s(const wchar_t *_Filename,const wchar_t *_EnvVar,wchar_t *_ResultPath,size_t _SizeInWords);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_2_0(errno_t,_wsearchenv_s,const wchar_t*,_Filename,const wchar_t*,_EnvVar,wchar_t,_ResultPath)

  _CRTIMP errno_t __cdecl _wsplitpath_s(const wchar_t *_FullPath,wchar_t *_Drive,size_t _DriveSizeInWords,wchar_t *_Dir,size_t _DirSizeInWords,wchar_t *_Filename,size_t _FilenameSizeInWords,wchar_t *_Ext,size_t _ExtSizeInWords);
  __DEFINE_CPP_OVERLOAD_SECURE_FUNC_SPLITPATH(errno_t,_wsplitpath_s,wchar_t,_Dest)

#ifdef __cplusplus
}
#endif
#endif /* _INC_CORECRT_WSTDLIB */

