/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __dbgautoattach_h__
#define __dbgautoattach_h__

#ifndef __IDebugAutoAttach_FWD_DEFINED__
#define __IDebugAutoAttach_FWD_DEFINED__
typedef struct IDebugAutoAttach IDebugAutoAttach;
#endif

#include "ocidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  DEFINE_GUID(CLSID_DebugAutoAttach,0x70f65411,0xfe8c,0x4248,0xbc,0xff,0x70,0x1c,0x8b,0x2f,0x45,0x29);
  extern RPC_IF_HANDLE __MIDL_itf_dbgautoattach_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_dbgautoattach_0000_v0_0_s_ifspec;

#ifndef __IDebugAutoAttach_INTERFACE_DEFINED__
#define __IDebugAutoAttach_INTERFACE_DEFINED__
  enum __MIDL_IDebugAutoAttach_0001 {
    AUTOATTACH_PROGRAM_WIN32 = 0x1,AUTOATTACH_PROGRAM_COMPLUS = 0x2
  };
  typedef DWORD AUTOATTACH_PROGRAM_TYPE;

  EXTERN_C const IID IID_IDebugAutoAttach;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDebugAutoAttach : public IUnknown {
  public:
    virtual HRESULT WINAPI AutoAttach(REFGUID guidPort,DWORD dwPid,AUTOATTACH_PROGRAM_TYPE dwProgramType,DWORD dwProgramId,LPCWSTR pszSessionId) = 0;
  };
#else
  typedef struct IDebugAutoAttachVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDebugAutoAttach *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDebugAutoAttach *This);
      ULONG (WINAPI *Release)(IDebugAutoAttach *This);
      HRESULT (WINAPI *AutoAttach)(IDebugAutoAttach *This,REFGUID guidPort,DWORD dwPid,AUTOATTACH_PROGRAM_TYPE dwProgramType,DWORD dwProgramId,LPCWSTR pszSessionId);
    END_INTERFACE
  } IDebugAutoAttachVtbl;
  struct IDebugAutoAttach {
    CONST_VTBL struct IDebugAutoAttachVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDebugAutoAttach_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDebugAutoAttach_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDebugAutoAttach_Release(This) (This)->lpVtbl->Release(This)
#define IDebugAutoAttach_AutoAttach(This,guidPort,dwPid,dwProgramType,dwProgramId,pszSessionId) (This)->lpVtbl->AutoAttach(This,guidPort,dwPid,dwProgramType,dwProgramId,pszSessionId)
#endif
#endif
  HRESULT WINAPI IDebugAutoAttach_AutoAttach_Proxy(IDebugAutoAttach *This,REFGUID guidPort,DWORD dwPid,AUTOATTACH_PROGRAM_TYPE dwProgramType,DWORD dwProgramId,LPCWSTR pszSessionId);
  void __RPC_STUB IDebugAutoAttach_AutoAttach_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
