/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_INVKPRXY
#define _INC_INVKPRXY 1

#ifndef WINAPI
#if defined(_ARM_)
#define WINAPI
#else
#define WINAPI __stdcall
#endif
#endif

HRESULT WINAPI _com_handle_excepinfo(EXCEPINFO& excepInfo,IErrorInfo **pperrinfo);
HRESULT __cdecl _com_invoke_helper(IDispatch *pDispatch,DISPID dwDispID,WORD wFlags,VARTYPE vtRet,void *pvRet,const wchar_t *pwParamInfo,va_list argList,IErrorInfo **pperrinfo);
HRESULT __cdecl _com_dispatch_raw_method(IDispatch *pDispatch,DISPID dwDispID,WORD wFlags,VARTYPE vtRet,void *pvRet,const wchar_t *pwParamInfo,...) throw();
HRESULT WINAPI _com_dispatch_raw_propget(IDispatch *pDispatch,DISPID dwDispID,VARTYPE vtProp,void *pvProp) throw();
HRESULT __cdecl _com_dispatch_raw_propput(IDispatch *pDispatch,DISPID dwDispID,VARTYPE vtProp,...) throw();

#endif
