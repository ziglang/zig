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

#ifndef ___asptlb_h__
#define ___asptlb_h__

#ifndef __IStringList_FWD_DEFINED__
#define __IStringList_FWD_DEFINED__
typedef struct IStringList IStringList;
#endif

#ifndef __IRequestDictionary_FWD_DEFINED__
#define __IRequestDictionary_FWD_DEFINED__
typedef struct IRequestDictionary IRequestDictionary;
#endif

#ifndef __IRequest_FWD_DEFINED__
#define __IRequest_FWD_DEFINED__
typedef struct IRequest IRequest;
#endif

#ifndef __Request_FWD_DEFINED__
#define __Request_FWD_DEFINED__
#ifdef __cplusplus
typedef class Request Request;
#else
typedef struct Request Request;
#endif
#endif

#ifndef __IReadCookie_FWD_DEFINED__
#define __IReadCookie_FWD_DEFINED__
typedef struct IReadCookie IReadCookie;
#endif

#ifndef __IWriteCookie_FWD_DEFINED__
#define __IWriteCookie_FWD_DEFINED__
typedef struct IWriteCookie IWriteCookie;
#endif

#ifndef __IResponse_FWD_DEFINED__
#define __IResponse_FWD_DEFINED__
typedef struct IResponse IResponse;
#endif

#ifndef __Response_FWD_DEFINED__
#define __Response_FWD_DEFINED__
#ifdef __cplusplus
typedef class Response Response;
#else
typedef struct Response Response;
#endif
#endif

#ifndef __IVariantDictionary_FWD_DEFINED__
#define __IVariantDictionary_FWD_DEFINED__
typedef struct IVariantDictionary IVariantDictionary;
#endif

#ifndef __ISessionObject_FWD_DEFINED__
#define __ISessionObject_FWD_DEFINED__
typedef struct ISessionObject ISessionObject;
#endif

#ifndef __Session_FWD_DEFINED__
#define __Session_FWD_DEFINED__
#ifdef __cplusplus
typedef class Session Session;
#else
typedef struct Session Session;
#endif
#endif

#ifndef __IApplicationObject_FWD_DEFINED__
#define __IApplicationObject_FWD_DEFINED__
typedef struct IApplicationObject IApplicationObject;
#endif

#ifndef __Application_FWD_DEFINED__
#define __Application_FWD_DEFINED__
#ifdef __cplusplus
typedef class Application Application;
#else
typedef struct Application Application;
#endif
#endif

#ifndef __IASPError_FWD_DEFINED__
#define __IASPError_FWD_DEFINED__
typedef struct IASPError IASPError;
#endif

#ifndef __IServer_FWD_DEFINED__
#define __IServer_FWD_DEFINED__
typedef struct IServer IServer;
#endif

#ifndef __Server_FWD_DEFINED__
#define __Server_FWD_DEFINED__
#ifdef __cplusplus
typedef class Server Server;
#else
typedef struct Server Server;
#endif
#endif

#ifndef __IScriptingContext_FWD_DEFINED__
#define __IScriptingContext_FWD_DEFINED__
typedef struct IScriptingContext IScriptingContext;
#endif

#ifndef __ScriptingContext_FWD_DEFINED__
#define __ScriptingContext_FWD_DEFINED__
#ifdef __cplusplus
typedef class ScriptingContext ScriptingContext;
#else
typedef struct ScriptingContext ScriptingContext;
#endif
#endif

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ASPTypeLibrary_LIBRARY_DEFINED__
#define __ASPTypeLibrary_LIBRARY_DEFINED__
  DEFINE_GUID(LIBID_ASPTypeLibrary,0xD97A6DA0,0xA85C,0x11cf,0x83,0xAE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);

#ifndef __IStringList_INTERFACE_DEFINED__
#define __IStringList_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IStringList,0xD97A6DA0,0xA85D,0x11cf,0x83,0xAE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IStringList : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(VARIANT i,VARIANT *pVariantReturn) = 0;
    virtual HRESULT WINAPI get_Count(int *cStrRet) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumReturn) = 0;
  };
#else
  typedef struct IStringListVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IStringList *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IStringList *This);
      ULONG (WINAPI *Release)(IStringList *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IStringList *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IStringList *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IStringList *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IStringList *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IStringList *This,VARIANT i,VARIANT *pVariantReturn);
      HRESULT (WINAPI *get_Count)(IStringList *This,int *cStrRet);
      HRESULT (WINAPI *get__NewEnum)(IStringList *This,IUnknown **ppEnumReturn);
    END_INTERFACE
  } IStringListVtbl;
  struct IStringList {
    CONST_VTBL struct IStringListVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IStringList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IStringList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IStringList_Release(This) (This)->lpVtbl->Release(This)
#define IStringList_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IStringList_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IStringList_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IStringList_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IStringList_get_Item(This,i,pVariantReturn) (This)->lpVtbl->get_Item(This,i,pVariantReturn)
#define IStringList_get_Count(This,cStrRet) (This)->lpVtbl->get_Count(This,cStrRet)
#define IStringList_get__NewEnum(This,ppEnumReturn) (This)->lpVtbl->get__NewEnum(This,ppEnumReturn)
#endif
#endif
  HRESULT WINAPI IStringList_get_Item_Proxy(IStringList *This,VARIANT i,VARIANT *pVariantReturn);
  void __RPC_STUB IStringList_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStringList_get_Count_Proxy(IStringList *This,int *cStrRet);
  void __RPC_STUB IStringList_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IStringList_get__NewEnum_Proxy(IStringList *This,IUnknown **ppEnumReturn);
  void __RPC_STUB IStringList_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRequestDictionary_INTERFACE_DEFINED__
#define __IRequestDictionary_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IRequestDictionary,0xD97A6DA0,0xA85F,0x11df,0x83,0xAE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRequestDictionary : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(VARIANT Var,VARIANT *pVariantReturn) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumReturn) = 0;
    virtual HRESULT WINAPI get_Count(int *cStrRet) = 0;
    virtual HRESULT WINAPI get_Key(VARIANT VarKey,VARIANT *pvar) = 0;
  };
#else
  typedef struct IRequestDictionaryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRequestDictionary *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRequestDictionary *This);
      ULONG (WINAPI *Release)(IRequestDictionary *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRequestDictionary *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRequestDictionary *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRequestDictionary *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRequestDictionary *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IRequestDictionary *This,VARIANT Var,VARIANT *pVariantReturn);
      HRESULT (WINAPI *get__NewEnum)(IRequestDictionary *This,IUnknown **ppEnumReturn);
      HRESULT (WINAPI *get_Count)(IRequestDictionary *This,int *cStrRet);
      HRESULT (WINAPI *get_Key)(IRequestDictionary *This,VARIANT VarKey,VARIANT *pvar);
    END_INTERFACE
  } IRequestDictionaryVtbl;
  struct IRequestDictionary {
    CONST_VTBL struct IRequestDictionaryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRequestDictionary_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRequestDictionary_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRequestDictionary_Release(This) (This)->lpVtbl->Release(This)
#define IRequestDictionary_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRequestDictionary_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRequestDictionary_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRequestDictionary_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRequestDictionary_get_Item(This,Var,pVariantReturn) (This)->lpVtbl->get_Item(This,Var,pVariantReturn)
#define IRequestDictionary_get__NewEnum(This,ppEnumReturn) (This)->lpVtbl->get__NewEnum(This,ppEnumReturn)
#define IRequestDictionary_get_Count(This,cStrRet) (This)->lpVtbl->get_Count(This,cStrRet)
#define IRequestDictionary_get_Key(This,VarKey,pvar) (This)->lpVtbl->get_Key(This,VarKey,pvar)
#endif
#endif
  HRESULT WINAPI IRequestDictionary_get_Item_Proxy(IRequestDictionary *This,VARIANT Var,VARIANT *pVariantReturn);
  void __RPC_STUB IRequestDictionary_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequestDictionary_get__NewEnum_Proxy(IRequestDictionary *This,IUnknown **ppEnumReturn);
  void __RPC_STUB IRequestDictionary_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequestDictionary_get_Count_Proxy(IRequestDictionary *This,int *cStrRet);
  void __RPC_STUB IRequestDictionary_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequestDictionary_get_Key_Proxy(IRequestDictionary *This,VARIANT VarKey,VARIANT *pvar);
  void __RPC_STUB IRequestDictionary_get_Key_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IRequest_INTERFACE_DEFINED__
#define __IRequest_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IRequest,0xD97A6DA0,0xA861,0x11cf,0x93,0xAE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IRequest : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(BSTR bstrVar,IDispatch **ppObjReturn) = 0;
    virtual HRESULT WINAPI get_QueryString(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_Form(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_Body(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_ServerVariables(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_ClientCertificate(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_Cookies(IRequestDictionary **ppDictReturn) = 0;
    virtual HRESULT WINAPI get_TotalBytes(__LONG32 *pcbTotal) = 0;
    virtual HRESULT WINAPI BinaryRead(VARIANT *pvarCountToRead,VARIANT *pvarReturn) = 0;
  };
#else
  typedef struct IRequestVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IRequest *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IRequest *This);
      ULONG (WINAPI *Release)(IRequest *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IRequest *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IRequest *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IRequest *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IRequest *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IRequest *This,BSTR bstrVar,IDispatch **ppObjReturn);
      HRESULT (WINAPI *get_QueryString)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_Form)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_Body)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_ServerVariables)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_ClientCertificate)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_Cookies)(IRequest *This,IRequestDictionary **ppDictReturn);
      HRESULT (WINAPI *get_TotalBytes)(IRequest *This,__LONG32 *pcbTotal);
      HRESULT (WINAPI *BinaryRead)(IRequest *This,VARIANT *pvarCountToRead,VARIANT *pvarReturn);
    END_INTERFACE
  } IRequestVtbl;
  struct IRequest {
    CONST_VTBL struct IRequestVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IRequest_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IRequest_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IRequest_Release(This) (This)->lpVtbl->Release(This)
#define IRequest_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IRequest_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IRequest_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IRequest_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IRequest_get_Item(This,bstrVar,ppObjReturn) (This)->lpVtbl->get_Item(This,bstrVar,ppObjReturn)
#define IRequest_get_QueryString(This,ppDictReturn) (This)->lpVtbl->get_QueryString(This,ppDictReturn)
#define IRequest_get_Form(This,ppDictReturn) (This)->lpVtbl->get_Form(This,ppDictReturn)
#define IRequest_get_Body(This,ppDictReturn) (This)->lpVtbl->get_Body(This,ppDictReturn)
#define IRequest_get_ServerVariables(This,ppDictReturn) (This)->lpVtbl->get_ServerVariables(This,ppDictReturn)
#define IRequest_get_ClientCertificate(This,ppDictReturn) (This)->lpVtbl->get_ClientCertificate(This,ppDictReturn)
#define IRequest_get_Cookies(This,ppDictReturn) (This)->lpVtbl->get_Cookies(This,ppDictReturn)
#define IRequest_get_TotalBytes(This,pcbTotal) (This)->lpVtbl->get_TotalBytes(This,pcbTotal)
#define IRequest_BinaryRead(This,pvarCountToRead,pvarReturn) (This)->lpVtbl->BinaryRead(This,pvarCountToRead,pvarReturn)
#endif
#endif
  HRESULT WINAPI IRequest_get_Item_Proxy(IRequest *This,BSTR bstrVar,IDispatch **ppObjReturn);
  void __RPC_STUB IRequest_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_QueryString_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_QueryString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_Form_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_Form_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_Body_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_Body_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_ServerVariables_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_ServerVariables_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_ClientCertificate_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_ClientCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_Cookies_Proxy(IRequest *This,IRequestDictionary **ppDictReturn);
  void __RPC_STUB IRequest_get_Cookies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_get_TotalBytes_Proxy(IRequest *This,__LONG32 *pcbTotal);
  void __RPC_STUB IRequest_get_TotalBytes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IRequest_BinaryRead_Proxy(IRequest *This,VARIANT *pvarCountToRead,VARIANT *pvarReturn);
  void __RPC_STUB IRequest_BinaryRead_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_Request,0x920c25d0,0x25d9,0x11d0,0xa5,0x5f,0x00,0xa0,0xc9,0x0c,0x20,0x91);
#ifdef __cplusplus
  class Request;
#endif

#ifndef __IReadCookie_INTERFACE_DEFINED__
#define __IReadCookie_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IReadCookie,0x71EAF260,0x0CE0,0x11D0,0xA5,0x3E,0x00,0xA0,0xC9,0x0C,0x20,0x91);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IReadCookie : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(VARIANT Var,VARIANT *pVariantReturn) = 0;
    virtual HRESULT WINAPI get_HasKeys(VARIANT_BOOL *pfHasKeys) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumReturn) = 0;
    virtual HRESULT WINAPI get_Count(int *cStrRet) = 0;
    virtual HRESULT WINAPI get_Key(VARIANT VarKey,VARIANT *pvar) = 0;
  };
#else
  typedef struct IReadCookieVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IReadCookie *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IReadCookie *This);
      ULONG (WINAPI *Release)(IReadCookie *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IReadCookie *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IReadCookie *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IReadCookie *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IReadCookie *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IReadCookie *This,VARIANT Var,VARIANT *pVariantReturn);
      HRESULT (WINAPI *get_HasKeys)(IReadCookie *This,VARIANT_BOOL *pfHasKeys);
      HRESULT (WINAPI *get__NewEnum)(IReadCookie *This,IUnknown **ppEnumReturn);
      HRESULT (WINAPI *get_Count)(IReadCookie *This,int *cStrRet);
      HRESULT (WINAPI *get_Key)(IReadCookie *This,VARIANT VarKey,VARIANT *pvar);
    END_INTERFACE
  } IReadCookieVtbl;
  struct IReadCookie {
    CONST_VTBL struct IReadCookieVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IReadCookie_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IReadCookie_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IReadCookie_Release(This) (This)->lpVtbl->Release(This)
#define IReadCookie_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IReadCookie_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IReadCookie_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IReadCookie_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IReadCookie_get_Item(This,Var,pVariantReturn) (This)->lpVtbl->get_Item(This,Var,pVariantReturn)
#define IReadCookie_get_HasKeys(This,pfHasKeys) (This)->lpVtbl->get_HasKeys(This,pfHasKeys)
#define IReadCookie_get__NewEnum(This,ppEnumReturn) (This)->lpVtbl->get__NewEnum(This,ppEnumReturn)
#define IReadCookie_get_Count(This,cStrRet) (This)->lpVtbl->get_Count(This,cStrRet)
#define IReadCookie_get_Key(This,VarKey,pvar) (This)->lpVtbl->get_Key(This,VarKey,pvar)
#endif
#endif
  HRESULT WINAPI IReadCookie_get_Item_Proxy(IReadCookie *This,VARIANT Var,VARIANT *pVariantReturn);
  void __RPC_STUB IReadCookie_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IReadCookie_get_HasKeys_Proxy(IReadCookie *This,VARIANT_BOOL *pfHasKeys);
  void __RPC_STUB IReadCookie_get_HasKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IReadCookie_get__NewEnum_Proxy(IReadCookie *This,IUnknown **ppEnumReturn);
  void __RPC_STUB IReadCookie_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IReadCookie_get_Count_Proxy(IReadCookie *This,int *cStrRet);
  void __RPC_STUB IReadCookie_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IReadCookie_get_Key_Proxy(IReadCookie *This,VARIANT VarKey,VARIANT *pvar);
  void __RPC_STUB IReadCookie_get_Key_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IWriteCookie_INTERFACE_DEFINED__
#define __IWriteCookie_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IWriteCookie,0xD97A6DA0,0xA862,0x11cf,0x84,0xAE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IWriteCookie : public IDispatch {
  public:
    virtual HRESULT WINAPI put_Item(VARIANT key,BSTR bstrValue) = 0;
    virtual HRESULT WINAPI put_Expires(DATE dtExpires) = 0;
    virtual HRESULT WINAPI put_Domain(BSTR bstrDomain) = 0;
    virtual HRESULT WINAPI put_Path(BSTR bstrPath) = 0;
    virtual HRESULT WINAPI put_Secure(VARIANT_BOOL fSecure) = 0;
    virtual HRESULT WINAPI get_HasKeys(VARIANT_BOOL *pfHasKeys) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumReturn) = 0;
  };
#else
  typedef struct IWriteCookieVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IWriteCookie *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IWriteCookie *This);
      ULONG (WINAPI *Release)(IWriteCookie *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IWriteCookie *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IWriteCookie *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IWriteCookie *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IWriteCookie *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *put_Item)(IWriteCookie *This,VARIANT key,BSTR bstrValue);
      HRESULT (WINAPI *put_Expires)(IWriteCookie *This,DATE dtExpires);
      HRESULT (WINAPI *put_Domain)(IWriteCookie *This,BSTR bstrDomain);
      HRESULT (WINAPI *put_Path)(IWriteCookie *This,BSTR bstrPath);
      HRESULT (WINAPI *put_Secure)(IWriteCookie *This,VARIANT_BOOL fSecure);
      HRESULT (WINAPI *get_HasKeys)(IWriteCookie *This,VARIANT_BOOL *pfHasKeys);
      HRESULT (WINAPI *get__NewEnum)(IWriteCookie *This,IUnknown **ppEnumReturn);
    END_INTERFACE
  } IWriteCookieVtbl;
  struct IWriteCookie {
    CONST_VTBL struct IWriteCookieVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IWriteCookie_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IWriteCookie_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IWriteCookie_Release(This) (This)->lpVtbl->Release(This)
#define IWriteCookie_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IWriteCookie_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IWriteCookie_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IWriteCookie_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IWriteCookie_put_Item(This,key,bstrValue) (This)->lpVtbl->put_Item(This,key,bstrValue)
#define IWriteCookie_put_Expires(This,dtExpires) (This)->lpVtbl->put_Expires(This,dtExpires)
#define IWriteCookie_put_Domain(This,bstrDomain) (This)->lpVtbl->put_Domain(This,bstrDomain)
#define IWriteCookie_put_Path(This,bstrPath) (This)->lpVtbl->put_Path(This,bstrPath)
#define IWriteCookie_put_Secure(This,fSecure) (This)->lpVtbl->put_Secure(This,fSecure)
#define IWriteCookie_get_HasKeys(This,pfHasKeys) (This)->lpVtbl->get_HasKeys(This,pfHasKeys)
#define IWriteCookie_get__NewEnum(This,ppEnumReturn) (This)->lpVtbl->get__NewEnum(This,ppEnumReturn)
#endif
#endif
  HRESULT WINAPI IWriteCookie_put_Item_Proxy(IWriteCookie *This,VARIANT key,BSTR bstrValue);
  void __RPC_STUB IWriteCookie_put_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_put_Expires_Proxy(IWriteCookie *This,DATE dtExpires);
  void __RPC_STUB IWriteCookie_put_Expires_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_put_Domain_Proxy(IWriteCookie *This,BSTR bstrDomain);
  void __RPC_STUB IWriteCookie_put_Domain_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_put_Path_Proxy(IWriteCookie *This,BSTR bstrPath);
  void __RPC_STUB IWriteCookie_put_Path_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_put_Secure_Proxy(IWriteCookie *This,VARIANT_BOOL fSecure);
  void __RPC_STUB IWriteCookie_put_Secure_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_get_HasKeys_Proxy(IWriteCookie *This,VARIANT_BOOL *pfHasKeys);
  void __RPC_STUB IWriteCookie_get_HasKeys_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IWriteCookie_get__NewEnum_Proxy(IWriteCookie *This,IUnknown **ppEnumReturn);
  void __RPC_STUB IWriteCookie_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IResponse_INTERFACE_DEFINED__
#define __IResponse_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IResponse,0xD97A6DA0,0xA864,0x11cf,0x83,0xBE,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IResponse : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Buffer(VARIANT_BOOL *fIsBuffering) = 0;
    virtual HRESULT WINAPI put_Buffer(VARIANT_BOOL fIsBuffering) = 0;
    virtual HRESULT WINAPI get_ContentType(BSTR *pbstrContentTypeRet) = 0;
    virtual HRESULT WINAPI put_ContentType(BSTR bstrContentType) = 0;
    virtual HRESULT WINAPI get_Expires(VARIANT *pvarExpiresMinutesRet) = 0;
    virtual HRESULT WINAPI put_Expires(__LONG32 lExpiresMinutes) = 0;
    virtual HRESULT WINAPI get_ExpiresAbsolute(VARIANT *pvarExpiresRet) = 0;
    virtual HRESULT WINAPI put_ExpiresAbsolute(DATE dtExpires) = 0;
    virtual HRESULT WINAPI get_Cookies(IRequestDictionary **ppCookies) = 0;
    virtual HRESULT WINAPI get_Status(BSTR *pbstrStatusRet) = 0;
    virtual HRESULT WINAPI put_Status(BSTR bstrStatus) = 0;
    virtual HRESULT WINAPI Add(BSTR bstrHeaderValue,BSTR bstrHeaderName) = 0;
    virtual HRESULT WINAPI AddHeader(BSTR bstrHeaderName,BSTR bstrHeaderValue) = 0;
    virtual HRESULT WINAPI AppendToLog(BSTR bstrLogEntry) = 0;
    virtual HRESULT WINAPI BinaryWrite(VARIANT varInput) = 0;
    virtual HRESULT WINAPI Clear(void) = 0;
    virtual HRESULT WINAPI End(void) = 0;
    virtual HRESULT WINAPI Flush(void) = 0;
    virtual HRESULT WINAPI Redirect(BSTR bstrURL) = 0;
    virtual HRESULT WINAPI Write(VARIANT varText) = 0;
    virtual HRESULT WINAPI WriteBlock(short iBlockNumber) = 0;
    virtual HRESULT WINAPI IsClientConnected(VARIANT_BOOL *pfIsClientConnected) = 0;
    virtual HRESULT WINAPI get_CharSet(BSTR *pbstrCharSetRet) = 0;
    virtual HRESULT WINAPI put_CharSet(BSTR bstrCharSet) = 0;
    virtual HRESULT WINAPI Pics(BSTR bstrHeaderValue) = 0;
    virtual HRESULT WINAPI get_CacheControl(BSTR *pbstrCacheControl) = 0;
    virtual HRESULT WINAPI put_CacheControl(BSTR bstrCacheControl) = 0;
  };
#else
  typedef struct IResponseVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IResponse *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IResponse *This);
      ULONG (WINAPI *Release)(IResponse *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IResponse *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IResponse *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IResponse *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IResponse *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Buffer)(IResponse *This,VARIANT_BOOL *fIsBuffering);
      HRESULT (WINAPI *put_Buffer)(IResponse *This,VARIANT_BOOL fIsBuffering);
      HRESULT (WINAPI *get_ContentType)(IResponse *This,BSTR *pbstrContentTypeRet);
      HRESULT (WINAPI *put_ContentType)(IResponse *This,BSTR bstrContentType);
      HRESULT (WINAPI *get_Expires)(IResponse *This,VARIANT *pvarExpiresMinutesRet);
      HRESULT (WINAPI *put_Expires)(IResponse *This,__LONG32 lExpiresMinutes);
      HRESULT (WINAPI *get_ExpiresAbsolute)(IResponse *This,VARIANT *pvarExpiresRet);
      HRESULT (WINAPI *put_ExpiresAbsolute)(IResponse *This,DATE dtExpires);
      HRESULT (WINAPI *get_Cookies)(IResponse *This,IRequestDictionary **ppCookies);
      HRESULT (WINAPI *get_Status)(IResponse *This,BSTR *pbstrStatusRet);
      HRESULT (WINAPI *put_Status)(IResponse *This,BSTR bstrStatus);
      HRESULT (WINAPI *Add)(IResponse *This,BSTR bstrHeaderValue,BSTR bstrHeaderName);
      HRESULT (WINAPI *AddHeader)(IResponse *This,BSTR bstrHeaderName,BSTR bstrHeaderValue);
      HRESULT (WINAPI *AppendToLog)(IResponse *This,BSTR bstrLogEntry);
      HRESULT (WINAPI *BinaryWrite)(IResponse *This,VARIANT varInput);
      HRESULT (WINAPI *Clear)(IResponse *This);
      HRESULT (WINAPI *End)(IResponse *This);
      HRESULT (WINAPI *Flush)(IResponse *This);
      HRESULT (WINAPI *Redirect)(IResponse *This,BSTR bstrURL);
      HRESULT (WINAPI *Write)(IResponse *This,VARIANT varText);
      HRESULT (WINAPI *WriteBlock)(IResponse *This,short iBlockNumber);
      HRESULT (WINAPI *IsClientConnected)(IResponse *This,VARIANT_BOOL *pfIsClientConnected);
      HRESULT (WINAPI *get_CharSet)(IResponse *This,BSTR *pbstrCharSetRet);
      HRESULT (WINAPI *put_CharSet)(IResponse *This,BSTR bstrCharSet);
      HRESULT (WINAPI *Pics)(IResponse *This,BSTR bstrHeaderValue);
      HRESULT (WINAPI *get_CacheControl)(IResponse *This,BSTR *pbstrCacheControl);
      HRESULT (WINAPI *put_CacheControl)(IResponse *This,BSTR bstrCacheControl);
    END_INTERFACE
  } IResponseVtbl;
  struct IResponse {
    CONST_VTBL struct IResponseVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IResponse_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IResponse_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IResponse_Release(This) (This)->lpVtbl->Release(This)
#define IResponse_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IResponse_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IResponse_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IResponse_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IResponse_get_Buffer(This,fIsBuffering) (This)->lpVtbl->get_Buffer(This,fIsBuffering)
#define IResponse_put_Buffer(This,fIsBuffering) (This)->lpVtbl->put_Buffer(This,fIsBuffering)
#define IResponse_get_ContentType(This,pbstrContentTypeRet) (This)->lpVtbl->get_ContentType(This,pbstrContentTypeRet)
#define IResponse_put_ContentType(This,bstrContentType) (This)->lpVtbl->put_ContentType(This,bstrContentType)
#define IResponse_get_Expires(This,pvarExpiresMinutesRet) (This)->lpVtbl->get_Expires(This,pvarExpiresMinutesRet)
#define IResponse_put_Expires(This,lExpiresMinutes) (This)->lpVtbl->put_Expires(This,lExpiresMinutes)
#define IResponse_get_ExpiresAbsolute(This,pvarExpiresRet) (This)->lpVtbl->get_ExpiresAbsolute(This,pvarExpiresRet)
#define IResponse_put_ExpiresAbsolute(This,dtExpires) (This)->lpVtbl->put_ExpiresAbsolute(This,dtExpires)
#define IResponse_get_Cookies(This,ppCookies) (This)->lpVtbl->get_Cookies(This,ppCookies)
#define IResponse_get_Status(This,pbstrStatusRet) (This)->lpVtbl->get_Status(This,pbstrStatusRet)
#define IResponse_put_Status(This,bstrStatus) (This)->lpVtbl->put_Status(This,bstrStatus)
#define IResponse_Add(This,bstrHeaderValue,bstrHeaderName) (This)->lpVtbl->Add(This,bstrHeaderValue,bstrHeaderName)
#define IResponse_AddHeader(This,bstrHeaderName,bstrHeaderValue) (This)->lpVtbl->AddHeader(This,bstrHeaderName,bstrHeaderValue)
#define IResponse_AppendToLog(This,bstrLogEntry) (This)->lpVtbl->AppendToLog(This,bstrLogEntry)
#define IResponse_BinaryWrite(This,varInput) (This)->lpVtbl->BinaryWrite(This,varInput)
#define IResponse_Clear(This) (This)->lpVtbl->Clear(This)
#define IResponse_End(This) (This)->lpVtbl->End(This)
#define IResponse_Flush(This) (This)->lpVtbl->Flush(This)
#define IResponse_Redirect(This,bstrURL) (This)->lpVtbl->Redirect(This,bstrURL)
#define IResponse_Write(This,varText) (This)->lpVtbl->Write(This,varText)
#define IResponse_WriteBlock(This,iBlockNumber) (This)->lpVtbl->WriteBlock(This,iBlockNumber)
#define IResponse_IsClientConnected(This,pfIsClientConnected) (This)->lpVtbl->IsClientConnected(This,pfIsClientConnected)
#define IResponse_get_CharSet(This,pbstrCharSetRet) (This)->lpVtbl->get_CharSet(This,pbstrCharSetRet)
#define IResponse_put_CharSet(This,bstrCharSet) (This)->lpVtbl->put_CharSet(This,bstrCharSet)
#define IResponse_Pics(This,bstrHeaderValue) (This)->lpVtbl->Pics(This,bstrHeaderValue)
#define IResponse_get_CacheControl(This,pbstrCacheControl) (This)->lpVtbl->get_CacheControl(This,pbstrCacheControl)
#define IResponse_put_CacheControl(This,bstrCacheControl) (This)->lpVtbl->put_CacheControl(This,bstrCacheControl)
#endif
#endif
  HRESULT WINAPI IResponse_get_Buffer_Proxy(IResponse *This,VARIANT_BOOL *fIsBuffering);
  void __RPC_STUB IResponse_get_Buffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_Buffer_Proxy(IResponse *This,VARIANT_BOOL fIsBuffering);
  void __RPC_STUB IResponse_put_Buffer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_ContentType_Proxy(IResponse *This,BSTR *pbstrContentTypeRet);
  void __RPC_STUB IResponse_get_ContentType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_ContentType_Proxy(IResponse *This,BSTR bstrContentType);
  void __RPC_STUB IResponse_put_ContentType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_Expires_Proxy(IResponse *This,VARIANT *pvarExpiresMinutesRet);
  void __RPC_STUB IResponse_get_Expires_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_Expires_Proxy(IResponse *This,__LONG32 lExpiresMinutes);
  void __RPC_STUB IResponse_put_Expires_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_ExpiresAbsolute_Proxy(IResponse *This,VARIANT *pvarExpiresRet);
  void __RPC_STUB IResponse_get_ExpiresAbsolute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_ExpiresAbsolute_Proxy(IResponse *This,DATE dtExpires);
  void __RPC_STUB IResponse_put_ExpiresAbsolute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_Cookies_Proxy(IResponse *This,IRequestDictionary **ppCookies);
  void __RPC_STUB IResponse_get_Cookies_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_Status_Proxy(IResponse *This,BSTR *pbstrStatusRet);
  void __RPC_STUB IResponse_get_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_Status_Proxy(IResponse *This,BSTR bstrStatus);
  void __RPC_STUB IResponse_put_Status_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Add_Proxy(IResponse *This,BSTR bstrHeaderValue,BSTR bstrHeaderName);
  void __RPC_STUB IResponse_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_AddHeader_Proxy(IResponse *This,BSTR bstrHeaderName,BSTR bstrHeaderValue);
  void __RPC_STUB IResponse_AddHeader_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_AppendToLog_Proxy(IResponse *This,BSTR bstrLogEntry);
  void __RPC_STUB IResponse_AppendToLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_BinaryWrite_Proxy(IResponse *This,VARIANT varInput);
  void __RPC_STUB IResponse_BinaryWrite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Clear_Proxy(IResponse *This);
  void __RPC_STUB IResponse_Clear_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_End_Proxy(IResponse *This);
  void __RPC_STUB IResponse_End_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Flush_Proxy(IResponse *This);
  void __RPC_STUB IResponse_Flush_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Redirect_Proxy(IResponse *This,BSTR bstrURL);
  void __RPC_STUB IResponse_Redirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Write_Proxy(IResponse *This,VARIANT varText);
  void __RPC_STUB IResponse_Write_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_WriteBlock_Proxy(IResponse *This,short iBlockNumber);
  void __RPC_STUB IResponse_WriteBlock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_IsClientConnected_Proxy(IResponse *This,VARIANT_BOOL *pfIsClientConnected);
  void __RPC_STUB IResponse_IsClientConnected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_CharSet_Proxy(IResponse *This,BSTR *pbstrCharSetRet);
  void __RPC_STUB IResponse_get_CharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_CharSet_Proxy(IResponse *This,BSTR bstrCharSet);
  void __RPC_STUB IResponse_put_CharSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_Pics_Proxy(IResponse *This,BSTR bstrHeaderValue);
  void __RPC_STUB IResponse_Pics_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_get_CacheControl_Proxy(IResponse *This,BSTR *pbstrCacheControl);
  void __RPC_STUB IResponse_get_CacheControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IResponse_put_CacheControl_Proxy(IResponse *This,BSTR bstrCacheControl);
  void __RPC_STUB IResponse_put_CacheControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_Response,0x46E19BA0,0x25DD,0x11D0,0xA5,0x5F,0x00,0xA0,0xC9,0x0C,0x20,0x91);
#ifdef __cplusplus
  class Response;
#endif

#ifndef __IVariantDictionary_INTERFACE_DEFINED__
#define __IVariantDictionary_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IVariantDictionary,0x4a7deb90,0xb069,0x11d0,0xb3,0x73,0x00,0xa0,0xc9,0x0c,0x2b,0xd8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IVariantDictionary : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Item(VARIANT VarKey,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI put_Item(VARIANT VarKey,VARIANT var) = 0;
    virtual HRESULT WINAPI putref_Item(VARIANT VarKey,VARIANT var) = 0;
    virtual HRESULT WINAPI get_Key(VARIANT VarKey,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI get_Count(int *cStrRet) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **ppEnumReturn) = 0;
    virtual HRESULT WINAPI Remove(VARIANT VarKey) = 0;
    virtual HRESULT WINAPI RemoveAll(void) = 0;
  };
#else
  typedef struct IVariantDictionaryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IVariantDictionary *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IVariantDictionary *This);
      ULONG (WINAPI *Release)(IVariantDictionary *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IVariantDictionary *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IVariantDictionary *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IVariantDictionary *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IVariantDictionary *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Item)(IVariantDictionary *This,VARIANT VarKey,VARIANT *pvar);
      HRESULT (WINAPI *put_Item)(IVariantDictionary *This,VARIANT VarKey,VARIANT var);
      HRESULT (WINAPI *putref_Item)(IVariantDictionary *This,VARIANT VarKey,VARIANT var);
      HRESULT (WINAPI *get_Key)(IVariantDictionary *This,VARIANT VarKey,VARIANT *pvar);
      HRESULT (WINAPI *get_Count)(IVariantDictionary *This,int *cStrRet);
      HRESULT (WINAPI *get__NewEnum)(IVariantDictionary *This,IUnknown **ppEnumReturn);
      HRESULT (WINAPI *Remove)(IVariantDictionary *This,VARIANT VarKey);
      HRESULT (WINAPI *RemoveAll)(IVariantDictionary *This);
    END_INTERFACE
  } IVariantDictionaryVtbl;
  struct IVariantDictionary {
    CONST_VTBL struct IVariantDictionaryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IVariantDictionary_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IVariantDictionary_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IVariantDictionary_Release(This) (This)->lpVtbl->Release(This)
#define IVariantDictionary_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IVariantDictionary_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IVariantDictionary_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IVariantDictionary_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IVariantDictionary_get_Item(This,VarKey,pvar) (This)->lpVtbl->get_Item(This,VarKey,pvar)
#define IVariantDictionary_put_Item(This,VarKey,var) (This)->lpVtbl->put_Item(This,VarKey,var)
#define IVariantDictionary_putref_Item(This,VarKey,var) (This)->lpVtbl->putref_Item(This,VarKey,var)
#define IVariantDictionary_get_Key(This,VarKey,pvar) (This)->lpVtbl->get_Key(This,VarKey,pvar)
#define IVariantDictionary_get_Count(This,cStrRet) (This)->lpVtbl->get_Count(This,cStrRet)
#define IVariantDictionary_get__NewEnum(This,ppEnumReturn) (This)->lpVtbl->get__NewEnum(This,ppEnumReturn)
#define IVariantDictionary_Remove(This,VarKey) (This)->lpVtbl->Remove(This,VarKey)
#define IVariantDictionary_RemoveAll(This) (This)->lpVtbl->RemoveAll(This)
#endif
#endif
  HRESULT WINAPI IVariantDictionary_get_Item_Proxy(IVariantDictionary *This,VARIANT VarKey,VARIANT *pvar);
  void __RPC_STUB IVariantDictionary_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_put_Item_Proxy(IVariantDictionary *This,VARIANT VarKey,VARIANT var);
  void __RPC_STUB IVariantDictionary_put_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_putref_Item_Proxy(IVariantDictionary *This,VARIANT VarKey,VARIANT var);
  void __RPC_STUB IVariantDictionary_putref_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_get_Key_Proxy(IVariantDictionary *This,VARIANT VarKey,VARIANT *pvar);
  void __RPC_STUB IVariantDictionary_get_Key_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_get_Count_Proxy(IVariantDictionary *This,int *cStrRet);
  void __RPC_STUB IVariantDictionary_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_get__NewEnum_Proxy(IVariantDictionary *This,IUnknown **ppEnumReturn);
  void __RPC_STUB IVariantDictionary_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_Remove_Proxy(IVariantDictionary *This,VARIANT VarKey);
  void __RPC_STUB IVariantDictionary_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IVariantDictionary_RemoveAll_Proxy(IVariantDictionary *This);
  void __RPC_STUB IVariantDictionary_RemoveAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISessionObject_INTERFACE_DEFINED__
#define __ISessionObject_INTERFACE_DEFINED__
  DEFINE_GUID(IID_ISessionObject,0xD97A6DA0,0xA865,0x11cf,0x83,0xAF,0x00,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISessionObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_SessionID(BSTR *pbstrRet) = 0;
    virtual HRESULT WINAPI get_Value(BSTR bstrValue,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI put_Value(BSTR bstrValue,VARIANT var) = 0;
    virtual HRESULT WINAPI putref_Value(BSTR bstrValue,VARIANT var) = 0;
    virtual HRESULT WINAPI get_Timeout(__LONG32 *plvar) = 0;
    virtual HRESULT WINAPI put_Timeout(__LONG32 lvar) = 0;
    virtual HRESULT WINAPI Abandon(void) = 0;
    virtual HRESULT WINAPI get_CodePage(__LONG32 *plvar) = 0;
    virtual HRESULT WINAPI put_CodePage(__LONG32 lvar) = 0;
    virtual HRESULT WINAPI get_LCID(__LONG32 *plvar) = 0;
    virtual HRESULT WINAPI put_LCID(__LONG32 lvar) = 0;
    virtual HRESULT WINAPI get_StaticObjects(IVariantDictionary **ppTaggedObjects) = 0;
    virtual HRESULT WINAPI get_Contents(IVariantDictionary **ppProperties) = 0;
  };
#else
  typedef struct ISessionObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISessionObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISessionObject *This);
      ULONG (WINAPI *Release)(ISessionObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ISessionObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ISessionObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ISessionObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ISessionObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_SessionID)(ISessionObject *This,BSTR *pbstrRet);
      HRESULT (WINAPI *get_Value)(ISessionObject *This,BSTR bstrValue,VARIANT *pvar);
      HRESULT (WINAPI *put_Value)(ISessionObject *This,BSTR bstrValue,VARIANT var);
      HRESULT (WINAPI *putref_Value)(ISessionObject *This,BSTR bstrValue,VARIANT var);
      HRESULT (WINAPI *get_Timeout)(ISessionObject *This,__LONG32 *plvar);
      HRESULT (WINAPI *put_Timeout)(ISessionObject *This,__LONG32 lvar);
      HRESULT (WINAPI *Abandon)(ISessionObject *This);
      HRESULT (WINAPI *get_CodePage)(ISessionObject *This,__LONG32 *plvar);
      HRESULT (WINAPI *put_CodePage)(ISessionObject *This,__LONG32 lvar);
      HRESULT (WINAPI *get_LCID)(ISessionObject *This,__LONG32 *plvar);
      HRESULT (WINAPI *put_LCID)(ISessionObject *This,__LONG32 lvar);
      HRESULT (WINAPI *get_StaticObjects)(ISessionObject *This,IVariantDictionary **ppTaggedObjects);
      HRESULT (WINAPI *get_Contents)(ISessionObject *This,IVariantDictionary **ppProperties);
    END_INTERFACE
  } ISessionObjectVtbl;
  struct ISessionObject {
    CONST_VTBL struct ISessionObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISessionObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISessionObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISessionObject_Release(This) (This)->lpVtbl->Release(This)
#define ISessionObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ISessionObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ISessionObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ISessionObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ISessionObject_get_SessionID(This,pbstrRet) (This)->lpVtbl->get_SessionID(This,pbstrRet)
#define ISessionObject_get_Value(This,bstrValue,pvar) (This)->lpVtbl->get_Value(This,bstrValue,pvar)
#define ISessionObject_put_Value(This,bstrValue,var) (This)->lpVtbl->put_Value(This,bstrValue,var)
#define ISessionObject_putref_Value(This,bstrValue,var) (This)->lpVtbl->putref_Value(This,bstrValue,var)
#define ISessionObject_get_Timeout(This,plvar) (This)->lpVtbl->get_Timeout(This,plvar)
#define ISessionObject_put_Timeout(This,lvar) (This)->lpVtbl->put_Timeout(This,lvar)
#define ISessionObject_Abandon(This) (This)->lpVtbl->Abandon(This)
#define ISessionObject_get_CodePage(This,plvar) (This)->lpVtbl->get_CodePage(This,plvar)
#define ISessionObject_put_CodePage(This,lvar) (This)->lpVtbl->put_CodePage(This,lvar)
#define ISessionObject_get_LCID(This,plvar) (This)->lpVtbl->get_LCID(This,plvar)
#define ISessionObject_put_LCID(This,lvar) (This)->lpVtbl->put_LCID(This,lvar)
#define ISessionObject_get_StaticObjects(This,ppTaggedObjects) (This)->lpVtbl->get_StaticObjects(This,ppTaggedObjects)
#define ISessionObject_get_Contents(This,ppProperties) (This)->lpVtbl->get_Contents(This,ppProperties)
#endif
#endif
  HRESULT WINAPI ISessionObject_get_SessionID_Proxy(ISessionObject *This,BSTR *pbstrRet);
  void __RPC_STUB ISessionObject_get_SessionID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_Value_Proxy(ISessionObject *This,BSTR bstrValue,VARIANT *pvar);
  void __RPC_STUB ISessionObject_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_put_Value_Proxy(ISessionObject *This,BSTR bstrValue,VARIANT var);
  void __RPC_STUB ISessionObject_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_putref_Value_Proxy(ISessionObject *This,BSTR bstrValue,VARIANT var);
  void __RPC_STUB ISessionObject_putref_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_Timeout_Proxy(ISessionObject *This,__LONG32 *plvar);
  void __RPC_STUB ISessionObject_get_Timeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_put_Timeout_Proxy(ISessionObject *This,__LONG32 lvar);
  void __RPC_STUB ISessionObject_put_Timeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_Abandon_Proxy(ISessionObject *This);
  void __RPC_STUB ISessionObject_Abandon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_CodePage_Proxy(ISessionObject *This,__LONG32 *plvar);
  void __RPC_STUB ISessionObject_get_CodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_put_CodePage_Proxy(ISessionObject *This,__LONG32 lvar);
  void __RPC_STUB ISessionObject_put_CodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_LCID_Proxy(ISessionObject *This,__LONG32 *plvar);
  void __RPC_STUB ISessionObject_get_LCID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_put_LCID_Proxy(ISessionObject *This,__LONG32 lvar);
  void __RPC_STUB ISessionObject_put_LCID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_StaticObjects_Proxy(ISessionObject *This,IVariantDictionary **ppTaggedObjects);
  void __RPC_STUB ISessionObject_get_StaticObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISessionObject_get_Contents_Proxy(ISessionObject *This,IVariantDictionary **ppProperties);
  void __RPC_STUB ISessionObject_get_Contents_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_Session,0x509F8F20,0x25DE,0x11D0,0xA5,0x5F,0x00,0xA0,0xC9,0x0C,0x20,0x91);
#ifdef __cplusplus
  class Session;
#endif

#ifndef __IApplicationObject_INTERFACE_DEFINED__
#define __IApplicationObject_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IApplicationObject,0xD97A6DA0,0xA866,0x11cf,0x83,0xAE,0x10,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IApplicationObject : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Value(BSTR bstrValue,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI put_Value(BSTR bstrValue,VARIANT var) = 0;
    virtual HRESULT WINAPI putref_Value(BSTR bstrValue,VARIANT var) = 0;
    virtual HRESULT WINAPI Lock(void) = 0;
    virtual HRESULT WINAPI UnLock(void) = 0;
    virtual HRESULT WINAPI get_StaticObjects(IVariantDictionary **ppProperties) = 0;
    virtual HRESULT WINAPI get_Contents(IVariantDictionary **ppProperties) = 0;
  };
#else
  typedef struct IApplicationObjectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IApplicationObject *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IApplicationObject *This);
      ULONG (WINAPI *Release)(IApplicationObject *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IApplicationObject *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IApplicationObject *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IApplicationObject *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IApplicationObject *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Value)(IApplicationObject *This,BSTR bstrValue,VARIANT *pvar);
      HRESULT (WINAPI *put_Value)(IApplicationObject *This,BSTR bstrValue,VARIANT var);
      HRESULT (WINAPI *putref_Value)(IApplicationObject *This,BSTR bstrValue,VARIANT var);
      HRESULT (WINAPI *Lock)(IApplicationObject *This);
      HRESULT (WINAPI *UnLock)(IApplicationObject *This);
      HRESULT (WINAPI *get_StaticObjects)(IApplicationObject *This,IVariantDictionary **ppProperties);
      HRESULT (WINAPI *get_Contents)(IApplicationObject *This,IVariantDictionary **ppProperties);
    END_INTERFACE
  } IApplicationObjectVtbl;
  struct IApplicationObject {
    CONST_VTBL struct IApplicationObjectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IApplicationObject_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IApplicationObject_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IApplicationObject_Release(This) (This)->lpVtbl->Release(This)
#define IApplicationObject_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IApplicationObject_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IApplicationObject_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IApplicationObject_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IApplicationObject_get_Value(This,bstrValue,pvar) (This)->lpVtbl->get_Value(This,bstrValue,pvar)
#define IApplicationObject_put_Value(This,bstrValue,var) (This)->lpVtbl->put_Value(This,bstrValue,var)
#define IApplicationObject_putref_Value(This,bstrValue,var) (This)->lpVtbl->putref_Value(This,bstrValue,var)
#define IApplicationObject_Lock(This) (This)->lpVtbl->Lock(This)
#define IApplicationObject_UnLock(This) (This)->lpVtbl->UnLock(This)
#define IApplicationObject_get_StaticObjects(This,ppProperties) (This)->lpVtbl->get_StaticObjects(This,ppProperties)
#define IApplicationObject_get_Contents(This,ppProperties) (This)->lpVtbl->get_Contents(This,ppProperties)
#endif
#endif
  HRESULT WINAPI IApplicationObject_get_Value_Proxy(IApplicationObject *This,BSTR bstrValue,VARIANT *pvar);
  void __RPC_STUB IApplicationObject_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_put_Value_Proxy(IApplicationObject *This,BSTR bstrValue,VARIANT var);
  void __RPC_STUB IApplicationObject_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_putref_Value_Proxy(IApplicationObject *This,BSTR bstrValue,VARIANT var);
  void __RPC_STUB IApplicationObject_putref_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_Lock_Proxy(IApplicationObject *This);
  void __RPC_STUB IApplicationObject_Lock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_UnLock_Proxy(IApplicationObject *This);
  void __RPC_STUB IApplicationObject_UnLock_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_get_StaticObjects_Proxy(IApplicationObject *This,IVariantDictionary **ppProperties);
  void __RPC_STUB IApplicationObject_get_StaticObjects_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IApplicationObject_get_Contents_Proxy(IApplicationObject *This,IVariantDictionary **ppProperties);
  void __RPC_STUB IApplicationObject_get_Contents_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_Application,0x7C3BAF00,0x25DE,0x11D0,0xA5,0x5F,0x00,0xA0,0xC9,0x0C,0x20,0x91);
#ifdef __cplusplus
  class Application;
#endif

#ifndef __IASPError_INTERFACE_DEFINED__
#define __IASPError_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IASPError,0xF5A6893E,0xA0F5,0x11d1,0x8C,0x4B,0x00,0xC0,0x4F,0xC3,0x24,0xA4);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IASPError : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ASPCode(BSTR *pbstrASPCode) = 0;
    virtual HRESULT WINAPI get_Number(__LONG32 *plNumber) = 0;
    virtual HRESULT WINAPI get_Category(BSTR *pbstrSource) = 0;
    virtual HRESULT WINAPI get_File(BSTR *pbstrFileName) = 0;
    virtual HRESULT WINAPI get_Line(__LONG32 *plLineNumber) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI get_ASPDescription(BSTR *pbstrDescription) = 0;
    virtual HRESULT WINAPI get_Column(__LONG32 *plColumn) = 0;
    virtual HRESULT WINAPI get_Source(BSTR *pbstrLineText) = 0;
  };
#else
  typedef struct IASPErrorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IASPError *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IASPError *This);
      ULONG (WINAPI *Release)(IASPError *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IASPError *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IASPError *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IASPError *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IASPError *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ASPCode)(IASPError *This,BSTR *pbstrASPCode);
      HRESULT (WINAPI *get_Number)(IASPError *This,__LONG32 *plNumber);
      HRESULT (WINAPI *get_Category)(IASPError *This,BSTR *pbstrSource);
      HRESULT (WINAPI *get_File)(IASPError *This,BSTR *pbstrFileName);
      HRESULT (WINAPI *get_Line)(IASPError *This,__LONG32 *plLineNumber);
      HRESULT (WINAPI *get_Description)(IASPError *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *get_ASPDescription)(IASPError *This,BSTR *pbstrDescription);
      HRESULT (WINAPI *get_Column)(IASPError *This,__LONG32 *plColumn);
      HRESULT (WINAPI *get_Source)(IASPError *This,BSTR *pbstrLineText);
    END_INTERFACE
  } IASPErrorVtbl;
  struct IASPError {
    CONST_VTBL struct IASPErrorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IASPError_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IASPError_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IASPError_Release(This) (This)->lpVtbl->Release(This)
#define IASPError_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IASPError_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IASPError_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IASPError_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IASPError_get_ASPCode(This,pbstrASPCode) (This)->lpVtbl->get_ASPCode(This,pbstrASPCode)
#define IASPError_get_Number(This,plNumber) (This)->lpVtbl->get_Number(This,plNumber)
#define IASPError_get_Category(This,pbstrSource) (This)->lpVtbl->get_Category(This,pbstrSource)
#define IASPError_get_File(This,pbstrFileName) (This)->lpVtbl->get_File(This,pbstrFileName)
#define IASPError_get_Line(This,plLineNumber) (This)->lpVtbl->get_Line(This,plLineNumber)
#define IASPError_get_Description(This,pbstrDescription) (This)->lpVtbl->get_Description(This,pbstrDescription)
#define IASPError_get_ASPDescription(This,pbstrDescription) (This)->lpVtbl->get_ASPDescription(This,pbstrDescription)
#define IASPError_get_Column(This,plColumn) (This)->lpVtbl->get_Column(This,plColumn)
#define IASPError_get_Source(This,pbstrLineText) (This)->lpVtbl->get_Source(This,pbstrLineText)
#endif
#endif
  HRESULT WINAPI IASPError_get_ASPCode_Proxy(IASPError *This,BSTR *pbstrASPCode);
  void __RPC_STUB IASPError_get_ASPCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Number_Proxy(IASPError *This,__LONG32 *plNumber);
  void __RPC_STUB IASPError_get_Number_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Category_Proxy(IASPError *This,BSTR *pbstrSource);
  void __RPC_STUB IASPError_get_Category_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_File_Proxy(IASPError *This,BSTR *pbstrFileName);
  void __RPC_STUB IASPError_get_File_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Line_Proxy(IASPError *This,__LONG32 *plLineNumber);
  void __RPC_STUB IASPError_get_Line_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Description_Proxy(IASPError *This,BSTR *pbstrDescription);
  void __RPC_STUB IASPError_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_ASPDescription_Proxy(IASPError *This,BSTR *pbstrDescription);
  void __RPC_STUB IASPError_get_ASPDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Column_Proxy(IASPError *This,__LONG32 *plColumn);
  void __RPC_STUB IASPError_get_Column_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IASPError_get_Source_Proxy(IASPError *This,BSTR *pbstrLineText);
  void __RPC_STUB IASPError_get_Source_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IServer_INTERFACE_DEFINED__
#define __IServer_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IServer,0xD97A6DA0,0xA867,0x11cf,0x83,0xAE,0x01,0xA0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IServer : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ScriptTimeout(__LONG32 *plTimeoutSeconds) = 0;
    virtual HRESULT WINAPI put_ScriptTimeout(__LONG32 lTimeoutSeconds) = 0;
    virtual HRESULT WINAPI CreateObject(BSTR bstrProgID,IDispatch **ppDispObject) = 0;
    virtual HRESULT WINAPI HTMLEncode(BSTR bstrIn,BSTR *pbstrEncoded) = 0;
    virtual HRESULT WINAPI MapPath(BSTR bstrLogicalPath,BSTR *pbstrPhysicalPath) = 0;
    virtual HRESULT WINAPI URLEncode(BSTR bstrIn,BSTR *pbstrEncoded) = 0;
    virtual HRESULT WINAPI URLPathEncode(BSTR bstrIn,BSTR *pbstrEncoded) = 0;
    virtual HRESULT WINAPI Execute(BSTR bstrLogicalPath) = 0;
    virtual HRESULT WINAPI Transfer(BSTR bstrLogicalPath) = 0;
    virtual HRESULT WINAPI GetLastError(IASPError **ppASPErrorObject) = 0;
  };
#else
  typedef struct IServerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IServer *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IServer *This);
      ULONG (WINAPI *Release)(IServer *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IServer *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IServer *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IServer *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IServer *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ScriptTimeout)(IServer *This,__LONG32 *plTimeoutSeconds);
      HRESULT (WINAPI *put_ScriptTimeout)(IServer *This,__LONG32 lTimeoutSeconds);
      HRESULT (WINAPI *CreateObject)(IServer *This,BSTR bstrProgID,IDispatch **ppDispObject);
      HRESULT (WINAPI *HTMLEncode)(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
      HRESULT (WINAPI *MapPath)(IServer *This,BSTR bstrLogicalPath,BSTR *pbstrPhysicalPath);
      HRESULT (WINAPI *URLEncode)(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
      HRESULT (WINAPI *URLPathEncode)(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
      HRESULT (WINAPI *Execute)(IServer *This,BSTR bstrLogicalPath);
      HRESULT (WINAPI *Transfer)(IServer *This,BSTR bstrLogicalPath);
      HRESULT (WINAPI *GetLastError)(IServer *This,IASPError **ppASPErrorObject);
    END_INTERFACE
  } IServerVtbl;
  struct IServer {
    CONST_VTBL struct IServerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IServer_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IServer_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IServer_Release(This) (This)->lpVtbl->Release(This)
#define IServer_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IServer_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IServer_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IServer_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IServer_get_ScriptTimeout(This,plTimeoutSeconds) (This)->lpVtbl->get_ScriptTimeout(This,plTimeoutSeconds)
#define IServer_put_ScriptTimeout(This,lTimeoutSeconds) (This)->lpVtbl->put_ScriptTimeout(This,lTimeoutSeconds)
#define IServer_CreateObject(This,bstrProgID,ppDispObject) (This)->lpVtbl->CreateObject(This,bstrProgID,ppDispObject)
#define IServer_HTMLEncode(This,bstrIn,pbstrEncoded) (This)->lpVtbl->HTMLEncode(This,bstrIn,pbstrEncoded)
#define IServer_MapPath(This,bstrLogicalPath,pbstrPhysicalPath) (This)->lpVtbl->MapPath(This,bstrLogicalPath,pbstrPhysicalPath)
#define IServer_URLEncode(This,bstrIn,pbstrEncoded) (This)->lpVtbl->URLEncode(This,bstrIn,pbstrEncoded)
#define IServer_URLPathEncode(This,bstrIn,pbstrEncoded) (This)->lpVtbl->URLPathEncode(This,bstrIn,pbstrEncoded)
#define IServer_Execute(This,bstrLogicalPath) (This)->lpVtbl->Execute(This,bstrLogicalPath)
#define IServer_Transfer(This,bstrLogicalPath) (This)->lpVtbl->Transfer(This,bstrLogicalPath)
#define IServer_GetLastError(This,ppASPErrorObject) (This)->lpVtbl->GetLastError(This,ppASPErrorObject)
#endif
#endif
  HRESULT WINAPI IServer_get_ScriptTimeout_Proxy(IServer *This,__LONG32 *plTimeoutSeconds);
  void __RPC_STUB IServer_get_ScriptTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_put_ScriptTimeout_Proxy(IServer *This,__LONG32 lTimeoutSeconds);
  void __RPC_STUB IServer_put_ScriptTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_CreateObject_Proxy(IServer *This,BSTR bstrProgID,IDispatch **ppDispObject);
  void __RPC_STUB IServer_CreateObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_HTMLEncode_Proxy(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
  void __RPC_STUB IServer_HTMLEncode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_MapPath_Proxy(IServer *This,BSTR bstrLogicalPath,BSTR *pbstrPhysicalPath);
  void __RPC_STUB IServer_MapPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_URLEncode_Proxy(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
  void __RPC_STUB IServer_URLEncode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_URLPathEncode_Proxy(IServer *This,BSTR bstrIn,BSTR *pbstrEncoded);
  void __RPC_STUB IServer_URLPathEncode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_Execute_Proxy(IServer *This,BSTR bstrLogicalPath);
  void __RPC_STUB IServer_Execute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_Transfer_Proxy(IServer *This,BSTR bstrLogicalPath);
  void __RPC_STUB IServer_Transfer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IServer_GetLastError_Proxy(IServer *This,IASPError **ppASPErrorObject);
  void __RPC_STUB IServer_GetLastError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_Server,0xA506D160,0x25E0,0x11D0,0xA5,0x5F,0x00,0xA0,0xC9,0x0C,0x20,0x91);
#ifdef __cplusplus
  class Server;
#endif

#ifndef __IScriptingContext_INTERFACE_DEFINED__
#define __IScriptingContext_INTERFACE_DEFINED__
  DEFINE_GUID(IID_IScriptingContext,0xD97A6DA0,0xA868,0x11cf,0x83,0xAE,0x00,0xB0,0xC9,0x0C,0x2B,0xD8);
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IScriptingContext : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Request(IRequest **ppRequest) = 0;
    virtual HRESULT WINAPI get_Response(IResponse **ppResponse) = 0;
    virtual HRESULT WINAPI get_Server(IServer **ppServer) = 0;
    virtual HRESULT WINAPI get_Session(ISessionObject **ppSession) = 0;
    virtual HRESULT WINAPI get_Application(IApplicationObject **ppApplication) = 0;
  };
#else
  typedef struct IScriptingContextVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IScriptingContext *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IScriptingContext *This);
      ULONG (WINAPI *Release)(IScriptingContext *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IScriptingContext *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IScriptingContext *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IScriptingContext *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IScriptingContext *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Request)(IScriptingContext *This,IRequest **ppRequest);
      HRESULT (WINAPI *get_Response)(IScriptingContext *This,IResponse **ppResponse);
      HRESULT (WINAPI *get_Server)(IScriptingContext *This,IServer **ppServer);
      HRESULT (WINAPI *get_Session)(IScriptingContext *This,ISessionObject **ppSession);
      HRESULT (WINAPI *get_Application)(IScriptingContext *This,IApplicationObject **ppApplication);
    END_INTERFACE
  } IScriptingContextVtbl;
  struct IScriptingContext {
    CONST_VTBL struct IScriptingContextVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IScriptingContext_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IScriptingContext_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IScriptingContext_Release(This) (This)->lpVtbl->Release(This)
#define IScriptingContext_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IScriptingContext_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IScriptingContext_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IScriptingContext_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IScriptingContext_get_Request(This,ppRequest) (This)->lpVtbl->get_Request(This,ppRequest)
#define IScriptingContext_get_Response(This,ppResponse) (This)->lpVtbl->get_Response(This,ppResponse)
#define IScriptingContext_get_Server(This,ppServer) (This)->lpVtbl->get_Server(This,ppServer)
#define IScriptingContext_get_Session(This,ppSession) (This)->lpVtbl->get_Session(This,ppSession)
#define IScriptingContext_get_Application(This,ppApplication) (This)->lpVtbl->get_Application(This,ppApplication)
#endif
#endif
  HRESULT WINAPI IScriptingContext_get_Request_Proxy(IScriptingContext *This,IRequest **ppRequest);
  void __RPC_STUB IScriptingContext_get_Request_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScriptingContext_get_Response_Proxy(IScriptingContext *This,IResponse **ppResponse);
  void __RPC_STUB IScriptingContext_get_Response_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScriptingContext_get_Server_Proxy(IScriptingContext *This,IServer **ppServer);
  void __RPC_STUB IScriptingContext_get_Server_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScriptingContext_get_Session_Proxy(IScriptingContext *This,ISessionObject **ppSession);
  void __RPC_STUB IScriptingContext_get_Session_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IScriptingContext_get_Application_Proxy(IScriptingContext *This,IApplicationObject **ppApplication);
  void __RPC_STUB IScriptingContext_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  DEFINE_GUID(CLSID_ScriptingContext,0xD97A6DA0,0xA868,0x11cf,0x83,0xAE,0x11,0xB0,0xC9,0x0C,0x2B,0xD8);
#ifdef __cplusplus
  class ScriptingContext;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
