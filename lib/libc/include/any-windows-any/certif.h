/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error this stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __certif_h__
#define __certif_h__

#ifndef __ICertServerPolicy_FWD_DEFINED__
#define __ICertServerPolicy_FWD_DEFINED__
typedef struct ICertServerPolicy ICertServerPolicy;
#endif

#ifndef __ICertServerExit_FWD_DEFINED__
#define __ICertServerExit_FWD_DEFINED__
typedef struct ICertServerExit ICertServerExit;
#endif

#include "wtypes.h"
#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define ENUMEXT_OBJECTID (0x1)

  extern RPC_IF_HANDLE __MIDL_itf_certif_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certif_0000_v0_0_s_ifspec;

#ifndef __ICertServerPolicy_INTERFACE_DEFINED__
#define __ICertServerPolicy_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertServerPolicy;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertServerPolicy : public IDispatch {
  public:
    virtual HRESULT WINAPI SetContext(LONG Context) = 0;
    virtual HRESULT WINAPI GetRequestProperty(const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetRequestAttribute(const BSTR strAttributeName,BSTR *pstrAttributeValue) = 0;
    virtual HRESULT WINAPI GetCertificateProperty(const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI SetCertificateProperty(const BSTR strPropertyName,LONG PropertyType,const VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetCertificateExtension(const BSTR strExtensionName,LONG Type,VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI GetCertificateExtensionFlags(LONG *pExtFlags) = 0;
    virtual HRESULT WINAPI SetCertificateExtension(const BSTR strExtensionName,LONG Type,LONG ExtFlags,const VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI EnumerateExtensionsSetup(LONG Flags) = 0;
    virtual HRESULT WINAPI EnumerateExtensions(BSTR *pstrExtensionName) = 0;
    virtual HRESULT WINAPI EnumerateExtensionsClose(void) = 0;
    virtual HRESULT WINAPI EnumerateAttributesSetup(LONG Flags) = 0;
    virtual HRESULT WINAPI EnumerateAttributes(BSTR *pstrAttributeName) = 0;
    virtual HRESULT WINAPI EnumerateAttributesClose(void) = 0;
  };
#else
  typedef struct ICertServerPolicyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertServerPolicy *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertServerPolicy *This);
      ULONG (WINAPI *Release)(ICertServerPolicy *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertServerPolicy *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertServerPolicy *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertServerPolicy *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertServerPolicy *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetContext)(ICertServerPolicy *This,LONG Context);
      HRESULT (WINAPI *GetRequestProperty)(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetRequestAttribute)(ICertServerPolicy *This,const BSTR strAttributeName,BSTR *pstrAttributeValue);
      HRESULT (WINAPI *GetCertificateProperty)(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *SetCertificateProperty)(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,const VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetCertificateExtension)(ICertServerPolicy *This,const BSTR strExtensionName,LONG Type,VARIANT *pvarValue);
      HRESULT (WINAPI *GetCertificateExtensionFlags)(ICertServerPolicy *This,LONG *pExtFlags);
      HRESULT (WINAPI *SetCertificateExtension)(ICertServerPolicy *This,const BSTR strExtensionName,LONG Type,LONG ExtFlags,const VARIANT *pvarValue);
      HRESULT (WINAPI *EnumerateExtensionsSetup)(ICertServerPolicy *This,LONG Flags);
      HRESULT (WINAPI *EnumerateExtensions)(ICertServerPolicy *This,BSTR *pstrExtensionName);
      HRESULT (WINAPI *EnumerateExtensionsClose)(ICertServerPolicy *This);
      HRESULT (WINAPI *EnumerateAttributesSetup)(ICertServerPolicy *This,LONG Flags);
      HRESULT (WINAPI *EnumerateAttributes)(ICertServerPolicy *This,BSTR *pstrAttributeName);
      HRESULT (WINAPI *EnumerateAttributesClose)(ICertServerPolicy *This);
    END_INTERFACE
  } ICertServerPolicyVtbl;
  struct ICertServerPolicy {
    CONST_VTBL struct ICertServerPolicyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertServerPolicy_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertServerPolicy_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertServerPolicy_Release(This) (This)->lpVtbl->Release(This)
#define ICertServerPolicy_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertServerPolicy_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertServerPolicy_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertServerPolicy_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertServerPolicy_SetContext(This,Context) (This)->lpVtbl->SetContext(This,Context)
#define ICertServerPolicy_GetRequestProperty(This,strPropertyName,PropertyType,pvarPropertyValue) (This)->lpVtbl->GetRequestProperty(This,strPropertyName,PropertyType,pvarPropertyValue)
#define ICertServerPolicy_GetRequestAttribute(This,strAttributeName,pstrAttributeValue) (This)->lpVtbl->GetRequestAttribute(This,strAttributeName,pstrAttributeValue)
#define ICertServerPolicy_GetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue) (This)->lpVtbl->GetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue)
#define ICertServerPolicy_SetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue) (This)->lpVtbl->SetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue)
#define ICertServerPolicy_GetCertificateExtension(This,strExtensionName,Type,pvarValue) (This)->lpVtbl->GetCertificateExtension(This,strExtensionName,Type,pvarValue)
#define ICertServerPolicy_GetCertificateExtensionFlags(This,pExtFlags) (This)->lpVtbl->GetCertificateExtensionFlags(This,pExtFlags)
#define ICertServerPolicy_SetCertificateExtension(This,strExtensionName,Type,ExtFlags,pvarValue) (This)->lpVtbl->SetCertificateExtension(This,strExtensionName,Type,ExtFlags,pvarValue)
#define ICertServerPolicy_EnumerateExtensionsSetup(This,Flags) (This)->lpVtbl->EnumerateExtensionsSetup(This,Flags)
#define ICertServerPolicy_EnumerateExtensions(This,pstrExtensionName) (This)->lpVtbl->EnumerateExtensions(This,pstrExtensionName)
#define ICertServerPolicy_EnumerateExtensionsClose(This) (This)->lpVtbl->EnumerateExtensionsClose(This)
#define ICertServerPolicy_EnumerateAttributesSetup(This,Flags) (This)->lpVtbl->EnumerateAttributesSetup(This,Flags)
#define ICertServerPolicy_EnumerateAttributes(This,pstrAttributeName) (This)->lpVtbl->EnumerateAttributes(This,pstrAttributeName)
#define ICertServerPolicy_EnumerateAttributesClose(This) (This)->lpVtbl->EnumerateAttributesClose(This)
#endif
#endif
  HRESULT WINAPI ICertServerPolicy_SetContext_Proxy(ICertServerPolicy *This,LONG Context);
  void __RPC_STUB ICertServerPolicy_SetContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_GetRequestProperty_Proxy(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertServerPolicy_GetRequestProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_GetRequestAttribute_Proxy(ICertServerPolicy *This,const BSTR strAttributeName,BSTR *pstrAttributeValue);
  void __RPC_STUB ICertServerPolicy_GetRequestAttribute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_GetCertificateProperty_Proxy(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertServerPolicy_GetCertificateProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_SetCertificateProperty_Proxy(ICertServerPolicy *This,const BSTR strPropertyName,LONG PropertyType,const VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertServerPolicy_SetCertificateProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_GetCertificateExtension_Proxy(ICertServerPolicy *This,const BSTR strExtensionName,LONG Type,VARIANT *pvarValue);
  void __RPC_STUB ICertServerPolicy_GetCertificateExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_GetCertificateExtensionFlags_Proxy(ICertServerPolicy *This,LONG *pExtFlags);
  void __RPC_STUB ICertServerPolicy_GetCertificateExtensionFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_SetCertificateExtension_Proxy(ICertServerPolicy *This,const BSTR strExtensionName,LONG Type,LONG ExtFlags,const VARIANT *pvarValue);
  void __RPC_STUB ICertServerPolicy_SetCertificateExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateExtensionsSetup_Proxy(ICertServerPolicy *This,LONG Flags);
  void __RPC_STUB ICertServerPolicy_EnumerateExtensionsSetup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateExtensions_Proxy(ICertServerPolicy *This,BSTR *pstrExtensionName);
  void __RPC_STUB ICertServerPolicy_EnumerateExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateExtensionsClose_Proxy(ICertServerPolicy *This);
  void __RPC_STUB ICertServerPolicy_EnumerateExtensionsClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateAttributesSetup_Proxy(ICertServerPolicy *This,LONG Flags);
  void __RPC_STUB ICertServerPolicy_EnumerateAttributesSetup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateAttributes_Proxy(ICertServerPolicy *This,BSTR *pstrAttributeName);
  void __RPC_STUB ICertServerPolicy_EnumerateAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerPolicy_EnumerateAttributesClose_Proxy(ICertServerPolicy *This);
  void __RPC_STUB ICertServerPolicy_EnumerateAttributesClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertServerExit_INTERFACE_DEFINED__
#define __ICertServerExit_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertServerExit;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertServerExit : public IDispatch {
  public:
    virtual HRESULT WINAPI SetContext(LONG Context) = 0;
    virtual HRESULT WINAPI GetRequestProperty(const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetRequestAttribute(const BSTR strAttributeName,BSTR *pstrAttributeValue) = 0;
    virtual HRESULT WINAPI GetCertificateProperty(const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetCertificateExtension(const BSTR strExtensionName,LONG Type,VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI GetCertificateExtensionFlags(LONG *pExtFlags) = 0;
    virtual HRESULT WINAPI EnumerateExtensionsSetup(LONG Flags) = 0;
    virtual HRESULT WINAPI EnumerateExtensions(BSTR *pstrExtensionName) = 0;
    virtual HRESULT WINAPI EnumerateExtensionsClose(void) = 0;
    virtual HRESULT WINAPI EnumerateAttributesSetup(LONG Flags) = 0;
    virtual HRESULT WINAPI EnumerateAttributes(BSTR *pstrAttributeName) = 0;
    virtual HRESULT WINAPI EnumerateAttributesClose(void) = 0;
  };
#else
  typedef struct ICertServerExitVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertServerExit *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertServerExit *This);
      ULONG (WINAPI *Release)(ICertServerExit *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertServerExit *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertServerExit *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertServerExit *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertServerExit *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *SetContext)(ICertServerExit *This,LONG Context);
      HRESULT (WINAPI *GetRequestProperty)(ICertServerExit *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetRequestAttribute)(ICertServerExit *This,const BSTR strAttributeName,BSTR *pstrAttributeValue);
      HRESULT (WINAPI *GetCertificateProperty)(ICertServerExit *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetCertificateExtension)(ICertServerExit *This,const BSTR strExtensionName,LONG Type,VARIANT *pvarValue);
      HRESULT (WINAPI *GetCertificateExtensionFlags)(ICertServerExit *This,LONG *pExtFlags);
      HRESULT (WINAPI *EnumerateExtensionsSetup)(ICertServerExit *This,LONG Flags);
      HRESULT (WINAPI *EnumerateExtensions)(ICertServerExit *This,BSTR *pstrExtensionName);
      HRESULT (WINAPI *EnumerateExtensionsClose)(ICertServerExit *This);
      HRESULT (WINAPI *EnumerateAttributesSetup)(ICertServerExit *This,LONG Flags);
      HRESULT (WINAPI *EnumerateAttributes)(ICertServerExit *This,BSTR *pstrAttributeName);
      HRESULT (WINAPI *EnumerateAttributesClose)(ICertServerExit *This);
    END_INTERFACE
  } ICertServerExitVtbl;
  struct ICertServerExit {
    CONST_VTBL struct ICertServerExitVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertServerExit_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertServerExit_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertServerExit_Release(This) (This)->lpVtbl->Release(This)
#define ICertServerExit_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertServerExit_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertServerExit_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertServerExit_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertServerExit_SetContext(This,Context) (This)->lpVtbl->SetContext(This,Context)
#define ICertServerExit_GetRequestProperty(This,strPropertyName,PropertyType,pvarPropertyValue) (This)->lpVtbl->GetRequestProperty(This,strPropertyName,PropertyType,pvarPropertyValue)
#define ICertServerExit_GetRequestAttribute(This,strAttributeName,pstrAttributeValue) (This)->lpVtbl->GetRequestAttribute(This,strAttributeName,pstrAttributeValue)
#define ICertServerExit_GetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue) (This)->lpVtbl->GetCertificateProperty(This,strPropertyName,PropertyType,pvarPropertyValue)
#define ICertServerExit_GetCertificateExtension(This,strExtensionName,Type,pvarValue) (This)->lpVtbl->GetCertificateExtension(This,strExtensionName,Type,pvarValue)
#define ICertServerExit_GetCertificateExtensionFlags(This,pExtFlags) (This)->lpVtbl->GetCertificateExtensionFlags(This,pExtFlags)
#define ICertServerExit_EnumerateExtensionsSetup(This,Flags) (This)->lpVtbl->EnumerateExtensionsSetup(This,Flags)
#define ICertServerExit_EnumerateExtensions(This,pstrExtensionName) (This)->lpVtbl->EnumerateExtensions(This,pstrExtensionName)
#define ICertServerExit_EnumerateExtensionsClose(This) (This)->lpVtbl->EnumerateExtensionsClose(This)
#define ICertServerExit_EnumerateAttributesSetup(This,Flags) (This)->lpVtbl->EnumerateAttributesSetup(This,Flags)
#define ICertServerExit_EnumerateAttributes(This,pstrAttributeName) (This)->lpVtbl->EnumerateAttributes(This,pstrAttributeName)
#define ICertServerExit_EnumerateAttributesClose(This) (This)->lpVtbl->EnumerateAttributesClose(This)
#endif
#endif
  HRESULT WINAPI ICertServerExit_SetContext_Proxy(ICertServerExit *This,LONG Context);
  void __RPC_STUB ICertServerExit_SetContext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_GetRequestProperty_Proxy(ICertServerExit *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertServerExit_GetRequestProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_GetRequestAttribute_Proxy(ICertServerExit *This,const BSTR strAttributeName,BSTR *pstrAttributeValue);
  void __RPC_STUB ICertServerExit_GetRequestAttribute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_GetCertificateProperty_Proxy(ICertServerExit *This,const BSTR strPropertyName,LONG PropertyType,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertServerExit_GetCertificateProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_GetCertificateExtension_Proxy(ICertServerExit *This,const BSTR strExtensionName,LONG Type,VARIANT *pvarValue);
  void __RPC_STUB ICertServerExit_GetCertificateExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_GetCertificateExtensionFlags_Proxy(ICertServerExit *This,LONG *pExtFlags);
  void __RPC_STUB ICertServerExit_GetCertificateExtensionFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateExtensionsSetup_Proxy(ICertServerExit *This,LONG Flags);
  void __RPC_STUB ICertServerExit_EnumerateExtensionsSetup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateExtensions_Proxy(ICertServerExit *This,BSTR *pstrExtensionName);
  void __RPC_STUB ICertServerExit_EnumerateExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateExtensionsClose_Proxy(ICertServerExit *This);
  void __RPC_STUB ICertServerExit_EnumerateExtensionsClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateAttributesSetup_Proxy(ICertServerExit *This,LONG Flags);
  void __RPC_STUB ICertServerExit_EnumerateAttributesSetup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateAttributes_Proxy(ICertServerExit *This,BSTR *pstrAttributeName);
  void __RPC_STUB ICertServerExit_EnumerateAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertServerExit_EnumerateAttributesClose_Proxy(ICertServerExit *This);
  void __RPC_STUB ICertServerExit_EnumerateAttributesClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);
  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
