/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_RTCAPI
#define _INC_RTCAPI

#include <crtdefs.h>

#pragma pack(push,_CRT_PACKING)

#define _RTCINTERNAL_DEPRECATED

#ifdef __cplusplus
extern "C" {
#endif

  typedef enum _RTC_ErrorNumber {
    _RTC_CHKSTK = 0,_RTC_CVRT_LOSS_INFO,_RTC_CORRUPT_STACK,_RTC_UNINIT_LOCAL_USE,_RTC_CORRUPTED_ALLOCA,_RTC_ILLEGAL
  } _RTC_ErrorNumber;

#define _RTC_ERRTYPE_IGNORE -1
#define _RTC_ERRTYPE_ASK -2

#ifndef _WCHAR_T_DEFINED
#define _WCHAR_T_DEFINED
  typedef unsigned short wchar_t;
#endif

  typedef int (__cdecl *_RTC_error_fn)(int,const char *,int,const char *,const char *,...);
  typedef int (__cdecl *_RTC_error_fnW)(int,const wchar_t *,int,const wchar_t *,const wchar_t *,...);

  int __cdecl _RTC_NumErrors(void);
  const char *__cdecl _RTC_GetErrDesc(_RTC_ErrorNumber _Errnum);
  int __cdecl _RTC_SetErrorType(_RTC_ErrorNumber _Errnum,int _ErrType);
  _RTC_error_fn __cdecl _RTC_SetErrorFunc(_RTC_error_fn);
  _RTC_error_fnW __cdecl _RTC_SetErrorFuncW(_RTC_error_fnW);
  void __cdecl _RTC_Initialize(void);
  void __cdecl _RTC_Terminate(void);
  _RTC_error_fn __cdecl _CRT_RTC_INIT(void *_Res0,void **_Res1,int _Res2,int _Res3,int _Res4);
  _RTC_error_fnW __cdecl _CRT_RTC_INITW(void *_Res0,void **_Res1,int _Res2,int _Res3,int _Res4);

  typedef struct _RTC_vardesc {
    int addr;
    int size;
    char *name;
  } _RTC_vardesc;

  typedef struct _RTC_framedesc {
    int varCount;
    _RTC_vardesc *variables;
  } _RTC_framedesc;

#pragma pack(push,1)

  typedef struct _RTC_ALLOCA_NODE {
    __int32 guard1;
    struct _RTC_ALLOCA_NODE *next;
#if (defined(_X86_) && !defined(__x86_64))
    __int32 dummypad;
#endif
    size_t allocaSize;
#if (defined(_X86_) && !defined(__x86_64))
    __int32 dummypad2;
#endif
    __int32 guard2[3];
  } _RTC_ALLOCA_NODE;
#pragma pack(pop)

  char __fastcall _RTC_Check_2_to_1(short _Src);
  char __fastcall _RTC_Check_4_to_1(int _Src);
  char __fastcall _RTC_Check_8_to_1(__int64 _Src);
  short __fastcall _RTC_Check_4_to_2(int _Src);
  short __fastcall _RTC_Check_8_to_2(__int64 _Src);
  int __fastcall _RTC_Check_8_to_4(__int64 _Src);

#if (defined(_X86_) && !defined(__x86_64))
  void __cdecl _RTC_CheckEsp();
#endif
  void __fastcall _RTC_CheckStackVars(void *_Esp,_RTC_framedesc *_Fd);
  void __fastcall _RTC_CheckStackVars2(void *_Esp,_RTC_framedesc *_Fd,_RTC_ALLOCA_NODE *_AllocaList);
  void __fastcall _RTC_AllocaHelper(_RTC_ALLOCA_NODE *_PAllocaBase,size_t _CbSize,_RTC_ALLOCA_NODE **_PAllocaInfoList);
  void __cdecl _RTC_UninitUse(const char *_Varname);
  void __cdecl _RTC_Shutdown(void);
  void __cdecl _RTC_InitBase(void);
#ifdef __cplusplus
  void *_ReturnAddress();
}
#endif

#pragma pack(pop)
#endif
