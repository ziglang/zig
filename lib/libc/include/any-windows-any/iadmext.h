/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __iadmext_h__
#define __iadmext_h__

#ifdef __cplusplus
extern "C"{
#endif

#include "unknwn.h"
#include "objidl.h"
#include "ocidl.h"

  DEFINE_GUID(IID_IADMEXT,0x51dfe970,0xf6f2,0x11d0,0xb9,0xbd,0x0,0xa0,0xc9,0x22,0xe7,0x50);

#define IISADMIN_EXTENSIONS_REG_KEYA "SOFTWARE\\Microsoft\\InetStp\\Extensions"
#define IISADMIN_EXTENSIONS_REG_KEYW L"SOFTWARE\\Microsoft\\InetStp\\Extensions"
#define IISADMIN_EXTENSIONS_REG_KEY TEXT("SOFTWARE\\Microsoft\\InetStp\\Extensions")
#define IISADMIN_EXTENSIONS_CLSID_MD_KEYA "LM/IISADMIN/EXTENSIONS/DCOMCLSIDS"
#define IISADMIN_EXTENSIONS_CLSID_MD_KEYW L"LM/IISADMIN/EXTENSIONS/DCOMCLSIDS"
#define IISADMIN_EXTENSIONS_CLSID_MD_KEY TEXT("LM/IISADMIN/EXTENSIONS/DCOMCLSIDS")
#define IISADMIN_EXTENSIONS_CLSID_MD_ID MD_IISADMIN_EXTENSIONS

#ifndef __IADMEXT_INTERFACE_DEFINED__
#define __IADMEXT_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IADMEXT;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IADMEXT : public IUnknown {
public:
  virtual HRESULT WINAPI Initialize(void) = 0;
  virtual HRESULT WINAPI EnumDcomCLSIDs(CLSID *pclsidDcom,DWORD dwEnumIndex) = 0;
  virtual HRESULT WINAPI Terminate(void) = 0;
  };
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
