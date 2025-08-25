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

#ifndef __msdaosp_h__
#define __msdaosp_h__

#ifndef __DataSourceObject_FWD_DEFINED__
#define __DataSourceObject_FWD_DEFINED__
typedef struct DataSourceObject DataSourceObject;
#endif

#include "oaidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include "msdatsrc.h"
#include "simpdata.h"
#ifdef DBINITCONSTANTS
  extern const GUID CLSID_MSDAOSP = {0xdfc8bdc0,0xe378,0x11d0,{0x9b,0x30,0x0,0x80,0xc7,0xe9,0xfe,0x95}};
  extern const GUID DBPROPSET_PWROWSET = {0xe6e478db,0xf226,0x11d0,{0x94,0xee,0x0,0xc0,0x4f,0xb6,0x6a,0x50}};
#else
  extern const GUID CLSID_MSDAOSP;
  extern const GUID DBPROPSET_PWROWSET;
#endif
#define PWPROP_OSPVALUE 2

  extern RPC_IF_HANDLE __MIDL_itf_msdaosp_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdaosp_0000_v0_0_s_ifspec;

#ifndef __MSDAOSPT_LIBRARY_DEFINED__
#define __MSDAOSPT_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_MSDAOSPT;
#ifndef __DataSourceObject_DISPINTERFACE_DEFINED__
#define __DataSourceObject_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_DataSourceObject;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DataSourceObject : public IDispatch {
  };
#else
  typedef struct DataSourceObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DataSourceObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DataSourceObject *This);
      ULONG (WINAPI *Release)(DataSourceObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(DataSourceObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(DataSourceObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(DataSourceObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(DataSourceObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } DataSourceObjectVtbl;
  struct DataSourceObject {
    CONST_VTBL struct DataSourceObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DataSourceObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DataSourceObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DataSourceObject_Release(This) (This)->lpVtbl->Release(This)
#define DataSourceObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define DataSourceObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define DataSourceObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define DataSourceObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
