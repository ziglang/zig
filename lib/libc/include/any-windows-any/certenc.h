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

#ifndef __certenc_h__
#define __certenc_h__

#ifndef __ICertEncodeStringArray_FWD_DEFINED__
#define __ICertEncodeStringArray_FWD_DEFINED__
typedef struct ICertEncodeStringArray ICertEncodeStringArray;
#endif

#ifndef __ICertEncodeLongArray_FWD_DEFINED__
#define __ICertEncodeLongArray_FWD_DEFINED__
typedef struct ICertEncodeLongArray ICertEncodeLongArray;
#endif

#ifndef __ICertEncodeDateArray_FWD_DEFINED__
#define __ICertEncodeDateArray_FWD_DEFINED__
typedef struct ICertEncodeDateArray ICertEncodeDateArray;
#endif

#ifndef __ICertEncodeCRLDistInfo_FWD_DEFINED__
#define __ICertEncodeCRLDistInfo_FWD_DEFINED__
typedef struct ICertEncodeCRLDistInfo ICertEncodeCRLDistInfo;
#endif

#ifndef __ICertEncodeAltName_FWD_DEFINED__
#define __ICertEncodeAltName_FWD_DEFINED__
typedef struct ICertEncodeAltName ICertEncodeAltName;
#endif

#ifndef __ICertEncodeBitString_FWD_DEFINED__
#define __ICertEncodeBitString_FWD_DEFINED__
typedef struct ICertEncodeBitString ICertEncodeBitString;
#endif

#ifndef __CCertEncodeStringArray_FWD_DEFINED__
#define __CCertEncodeStringArray_FWD_DEFINED__

#ifdef __cplusplus
typedef class CCertEncodeStringArray CCertEncodeStringArray;
#else
typedef struct CCertEncodeStringArray CCertEncodeStringArray;
#endif
#endif

#ifndef __CCertEncodeLongArray_FWD_DEFINED__
#define __CCertEncodeLongArray_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertEncodeLongArray CCertEncodeLongArray;
#else
typedef struct CCertEncodeLongArray CCertEncodeLongArray;
#endif
#endif

#ifndef __CCertEncodeDateArray_FWD_DEFINED__
#define __CCertEncodeDateArray_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertEncodeDateArray CCertEncodeDateArray;
#else
typedef struct CCertEncodeDateArray CCertEncodeDateArray;
#endif
#endif

#ifndef __CCertEncodeCRLDistInfo_FWD_DEFINED__
#define __CCertEncodeCRLDistInfo_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertEncodeCRLDistInfo CCertEncodeCRLDistInfo;
#else
typedef struct CCertEncodeCRLDistInfo CCertEncodeCRLDistInfo;
#endif
#endif

#ifndef __CCertEncodeAltName_FWD_DEFINED__
#define __CCertEncodeAltName_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertEncodeAltName CCertEncodeAltName;
#else
typedef struct CCertEncodeAltName CCertEncodeAltName;
#endif
#endif

#ifndef __CCertEncodeBitString_FWD_DEFINED__
#define __CCertEncodeBitString_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertEncodeBitString CCertEncodeBitString;
#else
typedef struct CCertEncodeBitString CCertEncodeBitString;
#endif
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

#ifndef __ICertEncodeStringArray_INTERFACE_DEFINED__
#define __ICertEncodeStringArray_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeStringArray;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeStringArray : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetStringType(LONG *pStringType) = 0;
    virtual HRESULT WINAPI GetCount(LONG *pCount) = 0;
    virtual HRESULT WINAPI GetValue(LONG Index,BSTR *pstr) = 0;
    virtual HRESULT WINAPI Reset(LONG Count,LONG StringType) = 0;
    virtual HRESULT WINAPI SetValue(LONG Index,const BSTR str) = 0;
    virtual HRESULT WINAPI Encode(BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeStringArrayVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeStringArray *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeStringArray *This);
      ULONG (WINAPI *Release)(ICertEncodeStringArray *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeStringArray *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeStringArray *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeStringArray *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeStringArray *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeStringArray *This,const BSTR strBinary);
      HRESULT (WINAPI *GetStringType)(ICertEncodeStringArray *This,LONG *pStringType);
      HRESULT (WINAPI *GetCount)(ICertEncodeStringArray *This,LONG *pCount);
      HRESULT (WINAPI *GetValue)(ICertEncodeStringArray *This,LONG Index,BSTR *pstr);
      HRESULT (WINAPI *Reset)(ICertEncodeStringArray *This,LONG Count,LONG StringType);
      HRESULT (WINAPI *SetValue)(ICertEncodeStringArray *This,LONG Index,const BSTR str);
      HRESULT (WINAPI *Encode)(ICertEncodeStringArray *This,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeStringArrayVtbl;
  struct ICertEncodeStringArray {
    CONST_VTBL struct ICertEncodeStringArrayVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeStringArray_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeStringArray_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeStringArray_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeStringArray_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeStringArray_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeStringArray_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeStringArray_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeStringArray_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeStringArray_GetStringType(This,pStringType) (This)->lpVtbl->GetStringType(This,pStringType)
#define ICertEncodeStringArray_GetCount(This,pCount) (This)->lpVtbl->GetCount(This,pCount)
#define ICertEncodeStringArray_GetValue(This,Index,pstr) (This)->lpVtbl->GetValue(This,Index,pstr)
#define ICertEncodeStringArray_Reset(This,Count,StringType) (This)->lpVtbl->Reset(This,Count,StringType)
#define ICertEncodeStringArray_SetValue(This,Index,str) (This)->lpVtbl->SetValue(This,Index,str)
#define ICertEncodeStringArray_Encode(This,pstrBinary) (This)->lpVtbl->Encode(This,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeStringArray_Decode_Proxy(ICertEncodeStringArray *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeStringArray_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_GetStringType_Proxy(ICertEncodeStringArray *This,LONG *pStringType);
  void __RPC_STUB ICertEncodeStringArray_GetStringType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_GetCount_Proxy(ICertEncodeStringArray *This,LONG *pCount);
  void __RPC_STUB ICertEncodeStringArray_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_GetValue_Proxy(ICertEncodeStringArray *This,LONG Index,BSTR *pstr);
  void __RPC_STUB ICertEncodeStringArray_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_Reset_Proxy(ICertEncodeStringArray *This,LONG Count,LONG StringType);
  void __RPC_STUB ICertEncodeStringArray_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_SetValue_Proxy(ICertEncodeStringArray *This,LONG Index,const BSTR str);
  void __RPC_STUB ICertEncodeStringArray_SetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeStringArray_Encode_Proxy(ICertEncodeStringArray *This,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeStringArray_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertEncodeLongArray_INTERFACE_DEFINED__
#define __ICertEncodeLongArray_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeLongArray;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeLongArray : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetCount(LONG *pCount) = 0;
    virtual HRESULT WINAPI GetValue(LONG Index,LONG *pValue) = 0;
    virtual HRESULT WINAPI Reset(LONG Count) = 0;
    virtual HRESULT WINAPI SetValue(LONG Index,LONG Value) = 0;
    virtual HRESULT WINAPI Encode(BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeLongArrayVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeLongArray *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeLongArray *This);
      ULONG (WINAPI *Release)(ICertEncodeLongArray *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeLongArray *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeLongArray *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeLongArray *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeLongArray *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeLongArray *This,const BSTR strBinary);
      HRESULT (WINAPI *GetCount)(ICertEncodeLongArray *This,LONG *pCount);
      HRESULT (WINAPI *GetValue)(ICertEncodeLongArray *This,LONG Index,LONG *pValue);
      HRESULT (WINAPI *Reset)(ICertEncodeLongArray *This,LONG Count);
      HRESULT (WINAPI *SetValue)(ICertEncodeLongArray *This,LONG Index,LONG Value);
      HRESULT (WINAPI *Encode)(ICertEncodeLongArray *This,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeLongArrayVtbl;
  struct ICertEncodeLongArray {
    CONST_VTBL struct ICertEncodeLongArrayVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeLongArray_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeLongArray_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeLongArray_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeLongArray_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeLongArray_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeLongArray_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeLongArray_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeLongArray_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeLongArray_GetCount(This,pCount) (This)->lpVtbl->GetCount(This,pCount)
#define ICertEncodeLongArray_GetValue(This,Index,pValue) (This)->lpVtbl->GetValue(This,Index,pValue)
#define ICertEncodeLongArray_Reset(This,Count) (This)->lpVtbl->Reset(This,Count)
#define ICertEncodeLongArray_SetValue(This,Index,Value) (This)->lpVtbl->SetValue(This,Index,Value)
#define ICertEncodeLongArray_Encode(This,pstrBinary) (This)->lpVtbl->Encode(This,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeLongArray_Decode_Proxy(ICertEncodeLongArray *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeLongArray_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeLongArray_GetCount_Proxy(ICertEncodeLongArray *This,LONG *pCount);
  void __RPC_STUB ICertEncodeLongArray_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeLongArray_GetValue_Proxy(ICertEncodeLongArray *This,LONG Index,LONG *pValue);
  void __RPC_STUB ICertEncodeLongArray_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeLongArray_Reset_Proxy(ICertEncodeLongArray *This,LONG Count);
  void __RPC_STUB ICertEncodeLongArray_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeLongArray_SetValue_Proxy(ICertEncodeLongArray *This,LONG Index,LONG Value);
  void __RPC_STUB ICertEncodeLongArray_SetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeLongArray_Encode_Proxy(ICertEncodeLongArray *This,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeLongArray_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertEncodeDateArray_INTERFACE_DEFINED__
#define __ICertEncodeDateArray_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeDateArray;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeDateArray : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetCount(LONG *pCount) = 0;
    virtual HRESULT WINAPI GetValue(LONG Index,DATE *pValue) = 0;
    virtual HRESULT WINAPI Reset(LONG Count) = 0;
    virtual HRESULT WINAPI SetValue(LONG Index,DATE Value) = 0;
    virtual HRESULT WINAPI Encode(BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeDateArrayVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeDateArray *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeDateArray *This);
      ULONG (WINAPI *Release)(ICertEncodeDateArray *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeDateArray *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeDateArray *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeDateArray *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeDateArray *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeDateArray *This,const BSTR strBinary);
      HRESULT (WINAPI *GetCount)(ICertEncodeDateArray *This,LONG *pCount);
      HRESULT (WINAPI *GetValue)(ICertEncodeDateArray *This,LONG Index,DATE *pValue);
      HRESULT (WINAPI *Reset)(ICertEncodeDateArray *This,LONG Count);
      HRESULT (WINAPI *SetValue)(ICertEncodeDateArray *This,LONG Index,DATE Value);
      HRESULT (WINAPI *Encode)(ICertEncodeDateArray *This,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeDateArrayVtbl;
  struct ICertEncodeDateArray {
    CONST_VTBL struct ICertEncodeDateArrayVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeDateArray_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeDateArray_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeDateArray_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeDateArray_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeDateArray_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeDateArray_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeDateArray_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeDateArray_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeDateArray_GetCount(This,pCount) (This)->lpVtbl->GetCount(This,pCount)
#define ICertEncodeDateArray_GetValue(This,Index,pValue) (This)->lpVtbl->GetValue(This,Index,pValue)
#define ICertEncodeDateArray_Reset(This,Count) (This)->lpVtbl->Reset(This,Count)
#define ICertEncodeDateArray_SetValue(This,Index,Value) (This)->lpVtbl->SetValue(This,Index,Value)
#define ICertEncodeDateArray_Encode(This,pstrBinary) (This)->lpVtbl->Encode(This,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeDateArray_Decode_Proxy(ICertEncodeDateArray *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeDateArray_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeDateArray_GetCount_Proxy(ICertEncodeDateArray *This,LONG *pCount);
  void __RPC_STUB ICertEncodeDateArray_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeDateArray_GetValue_Proxy(ICertEncodeDateArray *This,LONG Index,DATE *pValue);
  void __RPC_STUB ICertEncodeDateArray_GetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeDateArray_Reset_Proxy(ICertEncodeDateArray *This,LONG Count);
  void __RPC_STUB ICertEncodeDateArray_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeDateArray_SetValue_Proxy(ICertEncodeDateArray *This,LONG Index,DATE Value);
  void __RPC_STUB ICertEncodeDateArray_SetValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeDateArray_Encode_Proxy(ICertEncodeDateArray *This,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeDateArray_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertEncodeCRLDistInfo_INTERFACE_DEFINED__
#define __ICertEncodeCRLDistInfo_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeCRLDistInfo;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeCRLDistInfo : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetDistPointCount(LONG *pDistPointCount) = 0;
    virtual HRESULT WINAPI GetNameCount(LONG DistPointIndex,LONG *pNameCount) = 0;
    virtual HRESULT WINAPI GetNameChoice(LONG DistPointIndex,LONG NameIndex,LONG *pNameChoice) = 0;
    virtual HRESULT WINAPI GetName(LONG DistPointIndex,LONG NameIndex,BSTR *pstrName) = 0;
    virtual HRESULT WINAPI Reset(LONG DistPointCount) = 0;
    virtual HRESULT WINAPI SetNameCount(LONG DistPointIndex,LONG NameCount) = 0;
    virtual HRESULT WINAPI SetNameEntry(LONG DistPointIndex,LONG NameIndex,LONG NameChoice,const BSTR strName) = 0;
    virtual HRESULT WINAPI Encode(BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeCRLDistInfoVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeCRLDistInfo *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeCRLDistInfo *This);
      ULONG (WINAPI *Release)(ICertEncodeCRLDistInfo *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeCRLDistInfo *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeCRLDistInfo *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeCRLDistInfo *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeCRLDistInfo *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeCRLDistInfo *This,const BSTR strBinary);
      HRESULT (WINAPI *GetDistPointCount)(ICertEncodeCRLDistInfo *This,LONG *pDistPointCount);
      HRESULT (WINAPI *GetNameCount)(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG *pNameCount);
      HRESULT (WINAPI *GetNameChoice)(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,LONG *pNameChoice);
      HRESULT (WINAPI *GetName)(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,BSTR *pstrName);
      HRESULT (WINAPI *Reset)(ICertEncodeCRLDistInfo *This,LONG DistPointCount);
      HRESULT (WINAPI *SetNameCount)(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameCount);
      HRESULT (WINAPI *SetNameEntry)(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,LONG NameChoice,const BSTR strName);
      HRESULT (WINAPI *Encode)(ICertEncodeCRLDistInfo *This,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeCRLDistInfoVtbl;
  struct ICertEncodeCRLDistInfo {
    CONST_VTBL struct ICertEncodeCRLDistInfoVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeCRLDistInfo_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeCRLDistInfo_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeCRLDistInfo_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeCRLDistInfo_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeCRLDistInfo_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeCRLDistInfo_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeCRLDistInfo_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeCRLDistInfo_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeCRLDistInfo_GetDistPointCount(This,pDistPointCount) (This)->lpVtbl->GetDistPointCount(This,pDistPointCount)
#define ICertEncodeCRLDistInfo_GetNameCount(This,DistPointIndex,pNameCount) (This)->lpVtbl->GetNameCount(This,DistPointIndex,pNameCount)
#define ICertEncodeCRLDistInfo_GetNameChoice(This,DistPointIndex,NameIndex,pNameChoice) (This)->lpVtbl->GetNameChoice(This,DistPointIndex,NameIndex,pNameChoice)
#define ICertEncodeCRLDistInfo_GetName(This,DistPointIndex,NameIndex,pstrName) (This)->lpVtbl->GetName(This,DistPointIndex,NameIndex,pstrName)
#define ICertEncodeCRLDistInfo_Reset(This,DistPointCount) (This)->lpVtbl->Reset(This,DistPointCount)
#define ICertEncodeCRLDistInfo_SetNameCount(This,DistPointIndex,NameCount) (This)->lpVtbl->SetNameCount(This,DistPointIndex,NameCount)
#define ICertEncodeCRLDistInfo_SetNameEntry(This,DistPointIndex,NameIndex,NameChoice,strName) (This)->lpVtbl->SetNameEntry(This,DistPointIndex,NameIndex,NameChoice,strName)
#define ICertEncodeCRLDistInfo_Encode(This,pstrBinary) (This)->lpVtbl->Encode(This,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeCRLDistInfo_Decode_Proxy(ICertEncodeCRLDistInfo *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeCRLDistInfo_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_GetDistPointCount_Proxy(ICertEncodeCRLDistInfo *This,LONG *pDistPointCount);
  void __RPC_STUB ICertEncodeCRLDistInfo_GetDistPointCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_GetNameCount_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG *pNameCount);
  void __RPC_STUB ICertEncodeCRLDistInfo_GetNameCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_GetNameChoice_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,LONG *pNameChoice);
  void __RPC_STUB ICertEncodeCRLDistInfo_GetNameChoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_GetName_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,BSTR *pstrName);
  void __RPC_STUB ICertEncodeCRLDistInfo_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_Reset_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointCount);
  void __RPC_STUB ICertEncodeCRLDistInfo_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_SetNameCount_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameCount);
  void __RPC_STUB ICertEncodeCRLDistInfo_SetNameCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_SetNameEntry_Proxy(ICertEncodeCRLDistInfo *This,LONG DistPointIndex,LONG NameIndex,LONG NameChoice,const BSTR strName);
  void __RPC_STUB ICertEncodeCRLDistInfo_SetNameEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeCRLDistInfo_Encode_Proxy(ICertEncodeCRLDistInfo *This,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeCRLDistInfo_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define EAN_NAMEOBJECTID (0x80000000)

  extern RPC_IF_HANDLE __MIDL_itf_certenc_0122_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certenc_0122_v0_0_s_ifspec;

#ifndef __ICertEncodeAltName_INTERFACE_DEFINED__
#define __ICertEncodeAltName_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeAltName;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeAltName : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetNameCount(LONG *pNameCount) = 0;
    virtual HRESULT WINAPI GetNameChoice(LONG NameIndex,LONG *pNameChoice) = 0;
    virtual HRESULT WINAPI GetName(LONG NameIndex,BSTR *pstrName) = 0;
    virtual HRESULT WINAPI Reset(LONG NameCount) = 0;
    virtual HRESULT WINAPI SetNameEntry(LONG NameIndex,LONG NameChoice,const BSTR strName) = 0;
    virtual HRESULT WINAPI Encode(BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeAltNameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeAltName *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeAltName *This);
      ULONG (WINAPI *Release)(ICertEncodeAltName *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeAltName *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeAltName *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeAltName *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeAltName *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeAltName *This,const BSTR strBinary);
      HRESULT (WINAPI *GetNameCount)(ICertEncodeAltName *This,LONG *pNameCount);
      HRESULT (WINAPI *GetNameChoice)(ICertEncodeAltName *This,LONG NameIndex,LONG *pNameChoice);
      HRESULT (WINAPI *GetName)(ICertEncodeAltName *This,LONG NameIndex,BSTR *pstrName);
      HRESULT (WINAPI *Reset)(ICertEncodeAltName *This,LONG NameCount);
      HRESULT (WINAPI *SetNameEntry)(ICertEncodeAltName *This,LONG NameIndex,LONG NameChoice,const BSTR strName);
      HRESULT (WINAPI *Encode)(ICertEncodeAltName *This,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeAltNameVtbl;
  struct ICertEncodeAltName {
    CONST_VTBL struct ICertEncodeAltNameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeAltName_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeAltName_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeAltName_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeAltName_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeAltName_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeAltName_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeAltName_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeAltName_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeAltName_GetNameCount(This,pNameCount) (This)->lpVtbl->GetNameCount(This,pNameCount)
#define ICertEncodeAltName_GetNameChoice(This,NameIndex,pNameChoice) (This)->lpVtbl->GetNameChoice(This,NameIndex,pNameChoice)
#define ICertEncodeAltName_GetName(This,NameIndex,pstrName) (This)->lpVtbl->GetName(This,NameIndex,pstrName)
#define ICertEncodeAltName_Reset(This,NameCount) (This)->lpVtbl->Reset(This,NameCount)
#define ICertEncodeAltName_SetNameEntry(This,NameIndex,NameChoice,strName) (This)->lpVtbl->SetNameEntry(This,NameIndex,NameChoice,strName)
#define ICertEncodeAltName_Encode(This,pstrBinary) (This)->lpVtbl->Encode(This,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeAltName_Decode_Proxy(ICertEncodeAltName *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeAltName_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_GetNameCount_Proxy(ICertEncodeAltName *This,LONG *pNameCount);
  void __RPC_STUB ICertEncodeAltName_GetNameCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_GetNameChoice_Proxy(ICertEncodeAltName *This,LONG NameIndex,LONG *pNameChoice);
  void __RPC_STUB ICertEncodeAltName_GetNameChoice_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_GetName_Proxy(ICertEncodeAltName *This,LONG NameIndex,BSTR *pstrName);
  void __RPC_STUB ICertEncodeAltName_GetName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_Reset_Proxy(ICertEncodeAltName *This,LONG NameCount);
  void __RPC_STUB ICertEncodeAltName_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_SetNameEntry_Proxy(ICertEncodeAltName *This,LONG NameIndex,LONG NameChoice,const BSTR strName);
  void __RPC_STUB ICertEncodeAltName_SetNameEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeAltName_Encode_Proxy(ICertEncodeAltName *This,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeAltName_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertEncodeBitString_INTERFACE_DEFINED__
#define __ICertEncodeBitString_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertEncodeBitString;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertEncodeBitString : public IDispatch {
  public:
    virtual HRESULT WINAPI Decode(const BSTR strBinary) = 0;
    virtual HRESULT WINAPI GetBitCount(LONG *pBitCount) = 0;
    virtual HRESULT WINAPI GetBitString(BSTR *pstrBitString) = 0;
    virtual HRESULT WINAPI Encode(LONG BitCount,BSTR strBitString,BSTR *pstrBinary) = 0;
  };
#else
  typedef struct ICertEncodeBitStringVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertEncodeBitString *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertEncodeBitString *This);
      ULONG (WINAPI *Release)(ICertEncodeBitString *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertEncodeBitString *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertEncodeBitString *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertEncodeBitString *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertEncodeBitString *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Decode)(ICertEncodeBitString *This,const BSTR strBinary);
      HRESULT (WINAPI *GetBitCount)(ICertEncodeBitString *This,LONG *pBitCount);
      HRESULT (WINAPI *GetBitString)(ICertEncodeBitString *This,BSTR *pstrBitString);
      HRESULT (WINAPI *Encode)(ICertEncodeBitString *This,LONG BitCount,BSTR strBitString,BSTR *pstrBinary);
    END_INTERFACE
  } ICertEncodeBitStringVtbl;
  struct ICertEncodeBitString {
    CONST_VTBL struct ICertEncodeBitStringVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertEncodeBitString_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertEncodeBitString_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertEncodeBitString_Release(This) (This)->lpVtbl->Release(This)
#define ICertEncodeBitString_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertEncodeBitString_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertEncodeBitString_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertEncodeBitString_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertEncodeBitString_Decode(This,strBinary) (This)->lpVtbl->Decode(This,strBinary)
#define ICertEncodeBitString_GetBitCount(This,pBitCount) (This)->lpVtbl->GetBitCount(This,pBitCount)
#define ICertEncodeBitString_GetBitString(This,pstrBitString) (This)->lpVtbl->GetBitString(This,pstrBitString)
#define ICertEncodeBitString_Encode(This,BitCount,strBitString,pstrBinary) (This)->lpVtbl->Encode(This,BitCount,strBitString,pstrBinary)
#endif
#endif
  HRESULT WINAPI ICertEncodeBitString_Decode_Proxy(ICertEncodeBitString *This,const BSTR strBinary);
  void __RPC_STUB ICertEncodeBitString_Decode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeBitString_GetBitCount_Proxy(ICertEncodeBitString *This,LONG *pBitCount);
  void __RPC_STUB ICertEncodeBitString_GetBitCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeBitString_GetBitString_Proxy(ICertEncodeBitString *This,BSTR *pstrBitString);
  void __RPC_STUB ICertEncodeBitString_GetBitString_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertEncodeBitString_Encode_Proxy(ICertEncodeBitString *This,LONG BitCount,BSTR strBitString,BSTR *pstrBinary);
  void __RPC_STUB ICertEncodeBitString_Encode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __CERTENCODELib_LIBRARY_DEFINED__
#define __CERTENCODELib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CERTENCODELib;
  EXTERN_C const CLSID CLSID_CCertEncodeStringArray;
#ifdef __cplusplus
  class CCertEncodeStringArray;
#endif
  EXTERN_C const CLSID CLSID_CCertEncodeLongArray;
#ifdef __cplusplus
  class CCertEncodeLongArray;
#endif
  EXTERN_C const CLSID CLSID_CCertEncodeDateArray;
#ifdef __cplusplus
  class CCertEncodeDateArray;
#endif
  EXTERN_C const CLSID CLSID_CCertEncodeCRLDistInfo;
#ifdef __cplusplus
  class CCertEncodeCRLDistInfo;
#endif
  EXTERN_C const CLSID CLSID_CCertEncodeAltName;
#ifdef __cplusplus
  class CCertEncodeAltName;
#endif
  EXTERN_C const CLSID CLSID_CCertEncodeBitString;
#ifdef __cplusplus
  class CCertEncodeBitString;
#endif
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
