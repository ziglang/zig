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

#ifndef __certview_h__
#define __certview_h__

#ifndef __IEnumCERTVIEWCOLUMN_FWD_DEFINED__
#define __IEnumCERTVIEWCOLUMN_FWD_DEFINED__
typedef struct IEnumCERTVIEWCOLUMN IEnumCERTVIEWCOLUMN;
#endif

#ifndef __IEnumCERTVIEWATTRIBUTE_FWD_DEFINED__
#define __IEnumCERTVIEWATTRIBUTE_FWD_DEFINED__
typedef struct IEnumCERTVIEWATTRIBUTE IEnumCERTVIEWATTRIBUTE;
#endif

#ifndef __IEnumCERTVIEWEXTENSION_FWD_DEFINED__
#define __IEnumCERTVIEWEXTENSION_FWD_DEFINED__
typedef struct IEnumCERTVIEWEXTENSION IEnumCERTVIEWEXTENSION;
#endif

#ifndef __IEnumCERTVIEWROW_FWD_DEFINED__
#define __IEnumCERTVIEWROW_FWD_DEFINED__
typedef struct IEnumCERTVIEWROW IEnumCERTVIEWROW;
#endif

#ifndef __ICertView_FWD_DEFINED__
#define __ICertView_FWD_DEFINED__
typedef struct ICertView ICertView;
#endif

#ifndef __ICertView2_FWD_DEFINED__
#define __ICertView2_FWD_DEFINED__
typedef struct ICertView2 ICertView2;
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

#define CV_OUT_BASE64HEADER (0)
#define CV_OUT_BASE64 (0x1)
#define CV_OUT_BINARY (0x2)
#define CV_OUT_BASE64REQUESTHEADER (0x3)
#define CV_OUT_HEX (0x4)
#define CV_OUT_HEXASCII (0x5)
#define CV_OUT_BASE64X509CRLHEADER (0x9)
#define CV_OUT_HEXADDR (0xa)
#define CV_OUT_HEXASCIIADDR (0xb)
#define CV_OUT_ENCODEMASK (0xff)

#define CVR_SEEK_NONE (0)
#define CVR_SEEK_EQ (0x1)
#define CVR_SEEK_LT (0x2)
#define CVR_SEEK_LE (0x4)
#define CVR_SEEK_GE (0x8)
#define CVR_SEEK_GT (0x10)

#define CVR_SEEK_MASK (0xff)

#define CVR_SEEK_NODELTA (0x1000)

#define CVR_SORT_NONE (0)
#define CVR_SORT_ASCEND (0x1)
#define CVR_SORT_DESCEND (0x2)

#define CV_COLUMN_QUEUE_DEFAULT (-1)
#define CV_COLUMN_LOG_DEFAULT (-2)
#define CV_COLUMN_LOG_FAILED_DEFAULT (-3)
#define CV_COLUMN_EXTENSION_DEFAULT (-4)
#define CV_COLUMN_ATTRIBUTE_DEFAULT (-5)
#define CV_COLUMN_CRL_DEFAULT (-6)
#define CV_COLUMN_LOG_REVOKED_DEFAULT (-7)

#define CVRC_COLUMN_SCHEMA (0)
#define CVRC_COLUMN_RESULT (0x1)
#define CVRC_COLUMN_VALUE (0x2)
#define CVRC_COLUMN_MASK (0xfff)

#define CVRC_TABLE_REQCERT (0)
#define CVRC_TABLE_EXTENSIONS (0x3000)
#define CVRC_TABLE_ATTRIBUTES (0x4000)
#define CVRC_TABLE_CRL (0x5000)
#define CVRC_TABLE_MASK (0xf000)

#define CVRC_TABLE_SHIFT (12)

  extern RPC_IF_HANDLE __MIDL_itf_certview_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certview_0000_v0_0_s_ifspec;

#ifndef __IEnumCERTVIEWCOLUMN_INTERFACE_DEFINED__
#define __IEnumCERTVIEWCOLUMN_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCERTVIEWCOLUMN;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCERTVIEWCOLUMN : public IDispatch {
  public:
    virtual HRESULT WINAPI Next(LONG *pIndex) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI GetDisplayName(BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI GetType(LONG *pType) = 0;
    virtual HRESULT WINAPI IsIndexed(LONG *pIndexed) = 0;
    virtual HRESULT WINAPI GetMaxLength(LONG *pMaxLength) = 0;
    virtual HRESULT WINAPI GetValue(LONG Flags,VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI Skip(LONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumCERTVIEWCOLUMN **ppenum) = 0;
  };
#else
  typedef struct IEnumCERTVIEWCOLUMNVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCERTVIEWCOLUMN *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCERTVIEWCOLUMN *This);
      ULONG (WINAPI *Release)(IEnumCERTVIEWCOLUMN *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEnumCERTVIEWCOLUMN *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEnumCERTVIEWCOLUMN *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEnumCERTVIEWCOLUMN *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEnumCERTVIEWCOLUMN *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Next)(IEnumCERTVIEWCOLUMN *This,LONG *pIndex);
      HRESULT (WINAPI *GetName)(IEnumCERTVIEWCOLUMN *This,BSTR *pstrOut);
      HRESULT (WINAPI *GetDisplayName)(IEnumCERTVIEWCOLUMN *This,BSTR *pstrOut);
      HRESULT (WINAPI *GetType)(IEnumCERTVIEWCOLUMN *This,LONG *pType);
      HRESULT (WINAPI *IsIndexed)(IEnumCERTVIEWCOLUMN *This,LONG *pIndexed);
      HRESULT (WINAPI *GetMaxLength)(IEnumCERTVIEWCOLUMN *This,LONG *pMaxLength);
      HRESULT (WINAPI *GetValue)(IEnumCERTVIEWCOLUMN *This,LONG Flags,VARIANT *pvarValue);
      HRESULT (WINAPI *Skip)(IEnumCERTVIEWCOLUMN *This,LONG celt);
      HRESULT (WINAPI *Reset)(IEnumCERTVIEWCOLUMN *This);
      HRESULT (WINAPI *Clone)(IEnumCERTVIEWCOLUMN *This,IEnumCERTVIEWCOLUMN **ppenum);
    END_INTERFACE
  } IEnumCERTVIEWCOLUMNVtbl;
  struct IEnumCERTVIEWCOLUMN {
    CONST_VTBL struct IEnumCERTVIEWCOLUMNVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCERTVIEWCOLUMN_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCERTVIEWCOLUMN_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCERTVIEWCOLUMN_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCERTVIEWCOLUMN_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEnumCERTVIEWCOLUMN_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEnumCERTVIEWCOLUMN_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEnumCERTVIEWCOLUMN_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEnumCERTVIEWCOLUMN_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define IEnumCERTVIEWCOLUMN_GetName(This,pstrOut) (This)->lpVtbl->GetName(This,pstrOut)
#define IEnumCERTVIEWCOLUMN_GetDisplayName(This,pstrOut) (This)->lpVtbl->GetDisplayName(This,pstrOut)
#define IEnumCERTVIEWCOLUMN_GetType(This,pType) (This)->lpVtbl->GetType(This,pType)
#define IEnumCERTVIEWCOLUMN_IsIndexed(This,pIndexed) (This)->lpVtbl->IsIndexed(This,pIndexed)
#define IEnumCERTVIEWCOLUMN_GetMaxLength(This,pMaxLength) (This)->lpVtbl->GetMaxLength(This,pMaxLength)
#define IEnumCERTVIEWCOLUMN_GetValue(This,Flags,pvarValue) (This)->lpVtbl->GetValue(This,Flags,pvarValue)
#define IEnumCERTVIEWCOLUMN_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCERTVIEWCOLUMN_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCERTVIEWCOLUMN_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_Next_Proxy(IEnumCERTVIEWCOLUMN *This,LONG *pIndex);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_GetName_Proxy(IEnumCERTVIEWCOLUMN *This,BSTR *pstrOut);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_GetDisplayName_Proxy(IEnumCERTVIEWCOLUMN *This,BSTR *pstrOut);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_GetDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_GetType_Proxy(IEnumCERTVIEWCOLUMN *This,LONG *pType);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_GetType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_IsIndexed_Proxy(IEnumCERTVIEWCOLUMN *This,LONG *pIndexed);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_IsIndexed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_GetMaxLength_Proxy(IEnumCERTVIEWCOLUMN *This,LONG *pMaxLength);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_GetMaxLength_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_GetValue_Proxy(IEnumCERTVIEWCOLUMN *This,LONG Flags,VARIANT *pvarValue);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_Skip_Proxy(IEnumCERTVIEWCOLUMN *This,LONG celt);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_Reset_Proxy(IEnumCERTVIEWCOLUMN *This);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWCOLUMN_Clone_Proxy(IEnumCERTVIEWCOLUMN *This,IEnumCERTVIEWCOLUMN **ppenum);
  void __RPC_STUB IEnumCERTVIEWCOLUMN_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCERTVIEWATTRIBUTE_INTERFACE_DEFINED__
#define __IEnumCERTVIEWATTRIBUTE_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCERTVIEWATTRIBUTE;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCERTVIEWATTRIBUTE : public IDispatch {
  public:
    virtual HRESULT WINAPI Next(LONG *pIndex) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI GetValue(BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI Skip(LONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumCERTVIEWATTRIBUTE **ppenum) = 0;
  };
#else
  typedef struct IEnumCERTVIEWATTRIBUTEVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCERTVIEWATTRIBUTE *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCERTVIEWATTRIBUTE *This);
      ULONG (WINAPI *Release)(IEnumCERTVIEWATTRIBUTE *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEnumCERTVIEWATTRIBUTE *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEnumCERTVIEWATTRIBUTE *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEnumCERTVIEWATTRIBUTE *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEnumCERTVIEWATTRIBUTE *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Next)(IEnumCERTVIEWATTRIBUTE *This,LONG *pIndex);
      HRESULT (WINAPI *GetName)(IEnumCERTVIEWATTRIBUTE *This,BSTR *pstrOut);
      HRESULT (WINAPI *GetValue)(IEnumCERTVIEWATTRIBUTE *This,BSTR *pstrOut);
      HRESULT (WINAPI *Skip)(IEnumCERTVIEWATTRIBUTE *This,LONG celt);
      HRESULT (WINAPI *Reset)(IEnumCERTVIEWATTRIBUTE *This);
      HRESULT (WINAPI *Clone)(IEnumCERTVIEWATTRIBUTE *This,IEnumCERTVIEWATTRIBUTE **ppenum);
    END_INTERFACE
  } IEnumCERTVIEWATTRIBUTEVtbl;
  struct IEnumCERTVIEWATTRIBUTE {
    CONST_VTBL struct IEnumCERTVIEWATTRIBUTEVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCERTVIEWATTRIBUTE_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCERTVIEWATTRIBUTE_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCERTVIEWATTRIBUTE_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCERTVIEWATTRIBUTE_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEnumCERTVIEWATTRIBUTE_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEnumCERTVIEWATTRIBUTE_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEnumCERTVIEWATTRIBUTE_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEnumCERTVIEWATTRIBUTE_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define IEnumCERTVIEWATTRIBUTE_GetName(This,pstrOut) (This)->lpVtbl->GetName(This,pstrOut)
#define IEnumCERTVIEWATTRIBUTE_GetValue(This,pstrOut) (This)->lpVtbl->GetValue(This,pstrOut)
#define IEnumCERTVIEWATTRIBUTE_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCERTVIEWATTRIBUTE_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCERTVIEWATTRIBUTE_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_Next_Proxy(IEnumCERTVIEWATTRIBUTE *This,LONG *pIndex);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_GetName_Proxy(IEnumCERTVIEWATTRIBUTE *This,BSTR *pstrOut);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_GetValue_Proxy(IEnumCERTVIEWATTRIBUTE *This,BSTR *pstrOut);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_Skip_Proxy(IEnumCERTVIEWATTRIBUTE *This,LONG celt);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_Reset_Proxy(IEnumCERTVIEWATTRIBUTE *This);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWATTRIBUTE_Clone_Proxy(IEnumCERTVIEWATTRIBUTE *This,IEnumCERTVIEWATTRIBUTE **ppenum);
  void __RPC_STUB IEnumCERTVIEWATTRIBUTE_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCERTVIEWEXTENSION_INTERFACE_DEFINED__
#define __IEnumCERTVIEWEXTENSION_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCERTVIEWEXTENSION;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCERTVIEWEXTENSION : public IDispatch {
  public:
    virtual HRESULT WINAPI Next(LONG *pIndex) = 0;
    virtual HRESULT WINAPI GetName(BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI GetFlags(LONG *pFlags) = 0;
    virtual HRESULT WINAPI GetValue(LONG Type,LONG Flags,VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI Skip(LONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumCERTVIEWEXTENSION **ppenum) = 0;
  };
#else
  typedef struct IEnumCERTVIEWEXTENSIONVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCERTVIEWEXTENSION *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCERTVIEWEXTENSION *This);
      ULONG (WINAPI *Release)(IEnumCERTVIEWEXTENSION *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEnumCERTVIEWEXTENSION *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEnumCERTVIEWEXTENSION *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEnumCERTVIEWEXTENSION *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEnumCERTVIEWEXTENSION *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Next)(IEnumCERTVIEWEXTENSION *This,LONG *pIndex);
      HRESULT (WINAPI *GetName)(IEnumCERTVIEWEXTENSION *This,BSTR *pstrOut);
      HRESULT (WINAPI *GetFlags)(IEnumCERTVIEWEXTENSION *This,LONG *pFlags);
      HRESULT (WINAPI *GetValue)(IEnumCERTVIEWEXTENSION *This,LONG Type,LONG Flags,VARIANT *pvarValue);
      HRESULT (WINAPI *Skip)(IEnumCERTVIEWEXTENSION *This,LONG celt);
      HRESULT (WINAPI *Reset)(IEnumCERTVIEWEXTENSION *This);
      HRESULT (WINAPI *Clone)(IEnumCERTVIEWEXTENSION *This,IEnumCERTVIEWEXTENSION **ppenum);
    END_INTERFACE
  } IEnumCERTVIEWEXTENSIONVtbl;
  struct IEnumCERTVIEWEXTENSION {
    CONST_VTBL struct IEnumCERTVIEWEXTENSIONVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCERTVIEWEXTENSION_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCERTVIEWEXTENSION_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCERTVIEWEXTENSION_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCERTVIEWEXTENSION_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEnumCERTVIEWEXTENSION_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEnumCERTVIEWEXTENSION_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEnumCERTVIEWEXTENSION_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEnumCERTVIEWEXTENSION_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define IEnumCERTVIEWEXTENSION_GetName(This,pstrOut) (This)->lpVtbl->GetName(This,pstrOut)
#define IEnumCERTVIEWEXTENSION_GetFlags(This,pFlags) (This)->lpVtbl->GetFlags(This,pFlags)
#define IEnumCERTVIEWEXTENSION_GetValue(This,Type,Flags,pvarValue) (This)->lpVtbl->GetValue(This,Type,Flags,pvarValue)
#define IEnumCERTVIEWEXTENSION_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCERTVIEWEXTENSION_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCERTVIEWEXTENSION_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_Next_Proxy(IEnumCERTVIEWEXTENSION *This,LONG *pIndex);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_GetName_Proxy(IEnumCERTVIEWEXTENSION *This,BSTR *pstrOut);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_GetFlags_Proxy(IEnumCERTVIEWEXTENSION *This,LONG *pFlags);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_GetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_GetValue_Proxy(IEnumCERTVIEWEXTENSION *This,LONG Type,LONG Flags,VARIANT *pvarValue);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_Skip_Proxy(IEnumCERTVIEWEXTENSION *This,LONG celt);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_Reset_Proxy(IEnumCERTVIEWEXTENSION *This);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWEXTENSION_Clone_Proxy(IEnumCERTVIEWEXTENSION *This,IEnumCERTVIEWEXTENSION **ppenum);
  void __RPC_STUB IEnumCERTVIEWEXTENSION_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumCERTVIEWROW_INTERFACE_DEFINED__
#define __IEnumCERTVIEWROW_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumCERTVIEWROW;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumCERTVIEWROW : public IDispatch {
  public:
    virtual HRESULT WINAPI Next(LONG *pIndex) = 0;
    virtual HRESULT WINAPI EnumCertViewColumn(IEnumCERTVIEWCOLUMN **ppenum) = 0;
    virtual HRESULT WINAPI EnumCertViewAttribute(LONG Flags,IEnumCERTVIEWATTRIBUTE **ppenum) = 0;
    virtual HRESULT WINAPI EnumCertViewExtension(LONG Flags,IEnumCERTVIEWEXTENSION **ppenum) = 0;
    virtual HRESULT WINAPI Skip(LONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumCERTVIEWROW **ppenum) = 0;
    virtual HRESULT WINAPI GetMaxIndex(LONG *pIndex) = 0;
  };
#else
  typedef struct IEnumCERTVIEWROWVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumCERTVIEWROW *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumCERTVIEWROW *This);
      ULONG (WINAPI *Release)(IEnumCERTVIEWROW *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IEnumCERTVIEWROW *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IEnumCERTVIEWROW *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IEnumCERTVIEWROW *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IEnumCERTVIEWROW *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Next)(IEnumCERTVIEWROW *This,LONG *pIndex);
      HRESULT (WINAPI *EnumCertViewColumn)(IEnumCERTVIEWROW *This,IEnumCERTVIEWCOLUMN **ppenum);
      HRESULT (WINAPI *EnumCertViewAttribute)(IEnumCERTVIEWROW *This,LONG Flags,IEnumCERTVIEWATTRIBUTE **ppenum);
      HRESULT (WINAPI *EnumCertViewExtension)(IEnumCERTVIEWROW *This,LONG Flags,IEnumCERTVIEWEXTENSION **ppenum);
      HRESULT (WINAPI *Skip)(IEnumCERTVIEWROW *This,LONG celt);
      HRESULT (WINAPI *Reset)(IEnumCERTVIEWROW *This);
      HRESULT (WINAPI *Clone)(IEnumCERTVIEWROW *This,IEnumCERTVIEWROW **ppenum);
      HRESULT (WINAPI *GetMaxIndex)(IEnumCERTVIEWROW *This,LONG *pIndex);
    END_INTERFACE
  } IEnumCERTVIEWROWVtbl;
  struct IEnumCERTVIEWROW {
    CONST_VTBL struct IEnumCERTVIEWROWVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumCERTVIEWROW_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumCERTVIEWROW_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumCERTVIEWROW_Release(This) (This)->lpVtbl->Release(This)
#define IEnumCERTVIEWROW_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IEnumCERTVIEWROW_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IEnumCERTVIEWROW_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IEnumCERTVIEWROW_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IEnumCERTVIEWROW_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define IEnumCERTVIEWROW_EnumCertViewColumn(This,ppenum) (This)->lpVtbl->EnumCertViewColumn(This,ppenum)
#define IEnumCERTVIEWROW_EnumCertViewAttribute(This,Flags,ppenum) (This)->lpVtbl->EnumCertViewAttribute(This,Flags,ppenum)
#define IEnumCERTVIEWROW_EnumCertViewExtension(This,Flags,ppenum) (This)->lpVtbl->EnumCertViewExtension(This,Flags,ppenum)
#define IEnumCERTVIEWROW_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumCERTVIEWROW_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumCERTVIEWROW_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumCERTVIEWROW_GetMaxIndex(This,pIndex) (This)->lpVtbl->GetMaxIndex(This,pIndex)
#endif
#endif
  HRESULT WINAPI IEnumCERTVIEWROW_Next_Proxy(IEnumCERTVIEWROW *This,LONG *pIndex);
  void __RPC_STUB IEnumCERTVIEWROW_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_EnumCertViewColumn_Proxy(IEnumCERTVIEWROW *This,IEnumCERTVIEWCOLUMN **ppenum);
  void __RPC_STUB IEnumCERTVIEWROW_EnumCertViewColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_EnumCertViewAttribute_Proxy(IEnumCERTVIEWROW *This,LONG Flags,IEnumCERTVIEWATTRIBUTE **ppenum);
  void __RPC_STUB IEnumCERTVIEWROW_EnumCertViewAttribute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_EnumCertViewExtension_Proxy(IEnumCERTVIEWROW *This,LONG Flags,IEnumCERTVIEWEXTENSION **ppenum);
  void __RPC_STUB IEnumCERTVIEWROW_EnumCertViewExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_Skip_Proxy(IEnumCERTVIEWROW *This,LONG celt);
  void __RPC_STUB IEnumCERTVIEWROW_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_Reset_Proxy(IEnumCERTVIEWROW *This);
  void __RPC_STUB IEnumCERTVIEWROW_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_Clone_Proxy(IEnumCERTVIEWROW *This,IEnumCERTVIEWROW **ppenum);
  void __RPC_STUB IEnumCERTVIEWROW_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumCERTVIEWROW_GetMaxIndex_Proxy(IEnumCERTVIEWROW *This,LONG *pIndex);
  void __RPC_STUB IEnumCERTVIEWROW_GetMaxIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertView_INTERFACE_DEFINED__
#define __ICertView_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertView;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertView : public IDispatch {
  public:
    virtual HRESULT WINAPI OpenConnection(const BSTR strConfig) = 0;
    virtual HRESULT WINAPI EnumCertViewColumn(LONG fResultColumn,IEnumCERTVIEWCOLUMN **ppenum) = 0;
    virtual HRESULT WINAPI GetColumnCount(LONG fResultColumn,LONG *pcColumn) = 0;
    virtual HRESULT WINAPI GetColumnIndex(LONG fResultColumn,const BSTR strColumnName,LONG *pColumnIndex) = 0;
    virtual HRESULT WINAPI SetResultColumnCount(LONG cResultColumn) = 0;
    virtual HRESULT WINAPI SetResultColumn(LONG ColumnIndex) = 0;
    virtual HRESULT WINAPI SetRestriction(LONG ColumnIndex,LONG SeekOperator,LONG SortOrder,const VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI OpenView(IEnumCERTVIEWROW **ppenum) = 0;
  };
#else
  typedef struct ICertViewVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertView *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertView *This);
      ULONG (WINAPI *Release)(ICertView *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertView *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertView *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertView *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertView *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OpenConnection)(ICertView *This,const BSTR strConfig);
      HRESULT (WINAPI *EnumCertViewColumn)(ICertView *This,LONG fResultColumn,IEnumCERTVIEWCOLUMN **ppenum);
      HRESULT (WINAPI *GetColumnCount)(ICertView *This,LONG fResultColumn,LONG *pcColumn);
      HRESULT (WINAPI *GetColumnIndex)(ICertView *This,LONG fResultColumn,const BSTR strColumnName,LONG *pColumnIndex);
      HRESULT (WINAPI *SetResultColumnCount)(ICertView *This,LONG cResultColumn);
      HRESULT (WINAPI *SetResultColumn)(ICertView *This,LONG ColumnIndex);
      HRESULT (WINAPI *SetRestriction)(ICertView *This,LONG ColumnIndex,LONG SeekOperator,LONG SortOrder,const VARIANT *pvarValue);
      HRESULT (WINAPI *OpenView)(ICertView *This,IEnumCERTVIEWROW **ppenum);
    END_INTERFACE
  } ICertViewVtbl;
  struct ICertView {
    CONST_VTBL struct ICertViewVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertView_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertView_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertView_Release(This) (This)->lpVtbl->Release(This)
#define ICertView_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertView_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertView_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertView_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertView_OpenConnection(This,strConfig) (This)->lpVtbl->OpenConnection(This,strConfig)
#define ICertView_EnumCertViewColumn(This,fResultColumn,ppenum) (This)->lpVtbl->EnumCertViewColumn(This,fResultColumn,ppenum)
#define ICertView_GetColumnCount(This,fResultColumn,pcColumn) (This)->lpVtbl->GetColumnCount(This,fResultColumn,pcColumn)
#define ICertView_GetColumnIndex(This,fResultColumn,strColumnName,pColumnIndex) (This)->lpVtbl->GetColumnIndex(This,fResultColumn,strColumnName,pColumnIndex)
#define ICertView_SetResultColumnCount(This,cResultColumn) (This)->lpVtbl->SetResultColumnCount(This,cResultColumn)
#define ICertView_SetResultColumn(This,ColumnIndex) (This)->lpVtbl->SetResultColumn(This,ColumnIndex)
#define ICertView_SetRestriction(This,ColumnIndex,SeekOperator,SortOrder,pvarValue) (This)->lpVtbl->SetRestriction(This,ColumnIndex,SeekOperator,SortOrder,pvarValue)
#define ICertView_OpenView(This,ppenum) (This)->lpVtbl->OpenView(This,ppenum)
#endif
#endif
  HRESULT WINAPI ICertView_OpenConnection_Proxy(ICertView *This,const BSTR strConfig);
  void __RPC_STUB ICertView_OpenConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_EnumCertViewColumn_Proxy(ICertView *This,LONG fResultColumn,IEnumCERTVIEWCOLUMN **ppenum);
  void __RPC_STUB ICertView_EnumCertViewColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_GetColumnCount_Proxy(ICertView *This,LONG fResultColumn,LONG *pcColumn);
  void __RPC_STUB ICertView_GetColumnCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_GetColumnIndex_Proxy(ICertView *This,LONG fResultColumn,const BSTR strColumnName,LONG *pColumnIndex);
  void __RPC_STUB ICertView_GetColumnIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_SetResultColumnCount_Proxy(ICertView *This,LONG cResultColumn);
  void __RPC_STUB ICertView_SetResultColumnCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_SetResultColumn_Proxy(ICertView *This,LONG ColumnIndex);
  void __RPC_STUB ICertView_SetResultColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_SetRestriction_Proxy(ICertView *This,LONG ColumnIndex,LONG SeekOperator,LONG SortOrder,const VARIANT *pvarValue);
  void __RPC_STUB ICertView_SetRestriction_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertView_OpenView_Proxy(ICertView *This,IEnumCERTVIEWROW **ppenum);
  void __RPC_STUB ICertView_OpenView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertView2_INTERFACE_DEFINED__
#define __ICertView2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertView2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertView2 : public ICertView {
  public:
    virtual HRESULT WINAPI SetTable(LONG Table) = 0;
  };
#else
  typedef struct ICertView2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertView2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertView2 *This);
      ULONG (WINAPI *Release)(ICertView2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertView2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertView2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertView2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertView2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OpenConnection)(ICertView2 *This,const BSTR strConfig);
      HRESULT (WINAPI *EnumCertViewColumn)(ICertView2 *This,LONG fResultColumn,IEnumCERTVIEWCOLUMN **ppenum);
      HRESULT (WINAPI *GetColumnCount)(ICertView2 *This,LONG fResultColumn,LONG *pcColumn);
      HRESULT (WINAPI *GetColumnIndex)(ICertView2 *This,LONG fResultColumn,const BSTR strColumnName,LONG *pColumnIndex);
      HRESULT (WINAPI *SetResultColumnCount)(ICertView2 *This,LONG cResultColumn);
      HRESULT (WINAPI *SetResultColumn)(ICertView2 *This,LONG ColumnIndex);
      HRESULT (WINAPI *SetRestriction)(ICertView2 *This,LONG ColumnIndex,LONG SeekOperator,LONG SortOrder,const VARIANT *pvarValue);
      HRESULT (WINAPI *OpenView)(ICertView2 *This,IEnumCERTVIEWROW **ppenum);
      HRESULT (WINAPI *SetTable)(ICertView2 *This,LONG Table);
    END_INTERFACE
  } ICertView2Vtbl;
  struct ICertView2 {
    CONST_VTBL struct ICertView2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertView2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertView2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertView2_Release(This) (This)->lpVtbl->Release(This)
#define ICertView2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertView2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertView2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertView2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertView2_OpenConnection(This,strConfig) (This)->lpVtbl->OpenConnection(This,strConfig)
#define ICertView2_EnumCertViewColumn(This,fResultColumn,ppenum) (This)->lpVtbl->EnumCertViewColumn(This,fResultColumn,ppenum)
#define ICertView2_GetColumnCount(This,fResultColumn,pcColumn) (This)->lpVtbl->GetColumnCount(This,fResultColumn,pcColumn)
#define ICertView2_GetColumnIndex(This,fResultColumn,strColumnName,pColumnIndex) (This)->lpVtbl->GetColumnIndex(This,fResultColumn,strColumnName,pColumnIndex)
#define ICertView2_SetResultColumnCount(This,cResultColumn) (This)->lpVtbl->SetResultColumnCount(This,cResultColumn)
#define ICertView2_SetResultColumn(This,ColumnIndex) (This)->lpVtbl->SetResultColumn(This,ColumnIndex)
#define ICertView2_SetRestriction(This,ColumnIndex,SeekOperator,SortOrder,pvarValue) (This)->lpVtbl->SetRestriction(This,ColumnIndex,SeekOperator,SortOrder,pvarValue)
#define ICertView2_OpenView(This,ppenum) (This)->lpVtbl->OpenView(This,ppenum)
#define ICertView2_SetTable(This,Table) (This)->lpVtbl->SetTable(This,Table)
#endif
#endif
  HRESULT WINAPI ICertView2_SetTable_Proxy(ICertView2 *This,LONG Table);
  void __RPC_STUB ICertView2_SetTable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
