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
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __sdpblb_h__
#define __sdpblb_h__

#ifndef __ITConferenceBlob_FWD_DEFINED__
#define __ITConferenceBlob_FWD_DEFINED__
typedef struct ITConferenceBlob ITConferenceBlob;
#endif

#ifndef __ITMedia_FWD_DEFINED__
#define __ITMedia_FWD_DEFINED__
typedef struct ITMedia ITMedia;
#endif

#ifndef __IEnumMedia_FWD_DEFINED__
#define __IEnumMedia_FWD_DEFINED__
typedef struct IEnumMedia IEnumMedia;
#endif

#ifndef __ITMediaCollection_FWD_DEFINED__
#define __ITMediaCollection_FWD_DEFINED__
typedef struct ITMediaCollection ITMediaCollection;
#endif

#ifndef __ITTime_FWD_DEFINED__
#define __ITTime_FWD_DEFINED__
typedef struct ITTime ITTime;
#endif

#ifndef __IEnumTime_FWD_DEFINED__
#define __IEnumTime_FWD_DEFINED__
typedef struct IEnumTime IEnumTime;
#endif

#ifndef __ITTimeCollection_FWD_DEFINED__
#define __ITTimeCollection_FWD_DEFINED__
typedef struct ITTimeCollection ITTimeCollection;
#endif

#ifndef __ITSdp_FWD_DEFINED__
#define __ITSdp_FWD_DEFINED__
typedef struct ITSdp ITSdp;
#endif

#ifndef __ITConnection_FWD_DEFINED__
#define __ITConnection_FWD_DEFINED__
typedef struct ITConnection ITConnection;
#endif

#ifndef __ITAttributeList_FWD_DEFINED__
#define __ITAttributeList_FWD_DEFINED__
typedef struct ITAttributeList ITAttributeList;
#endif

#ifndef __ITMedia_FWD_DEFINED__
#define __ITMedia_FWD_DEFINED__
typedef struct ITMedia ITMedia;
#endif

#ifndef __ITTime_FWD_DEFINED__
#define __ITTime_FWD_DEFINED__
typedef struct ITTime ITTime;
#endif

#ifndef __ITConnection_FWD_DEFINED__
#define __ITConnection_FWD_DEFINED__
typedef struct ITConnection ITConnection;
#endif

#ifndef __ITAttributeList_FWD_DEFINED__
#define __ITAttributeList_FWD_DEFINED__
typedef struct ITAttributeList ITAttributeList;
#endif

#ifndef __SdpConferenceBlob_FWD_DEFINED__
#define __SdpConferenceBlob_FWD_DEFINED__
#ifdef __cplusplus
typedef class SdpConferenceBlob SdpConferenceBlob;
#else
typedef struct SdpConferenceBlob SdpConferenceBlob;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define IDISPCONFBLOB (0x10000)
#define IDISPSDP (0x20000)
#define IDISPCONNECTION (0x30000)
#define IDISPATTRLIST (0x40000)
#define IDISPMEDIA (0x50000)

  typedef enum BLOB_CHARACTER_SET {
    BCS_ASCII = 1,BCS_UTF7 = 2,BCS_UTF8 = 3
  } BLOB_CHARACTER_SET;

  extern RPC_IF_HANDLE __MIDL_itf_sdpblb_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_sdpblb_0000_v0_0_s_ifspec;

#ifndef __ITConferenceBlob_INTERFACE_DEFINED__
#define __ITConferenceBlob_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITConferenceBlob;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITConferenceBlob : public IDispatch {
  public:
    virtual HRESULT WINAPI Init(BSTR pName,BLOB_CHARACTER_SET CharacterSet,BSTR pBlob) = 0;
    virtual HRESULT WINAPI get_CharacterSet(BLOB_CHARACTER_SET *pCharacterSet) = 0;
    virtual HRESULT WINAPI get_ConferenceBlob(BSTR *ppBlob) = 0;
    virtual HRESULT WINAPI SetConferenceBlob(BLOB_CHARACTER_SET CharacterSet,BSTR pBlob) = 0;
  };
#else
  typedef struct ITConferenceBlobVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITConferenceBlob *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITConferenceBlob *This);
      ULONG (WINAPI *Release)(ITConferenceBlob *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITConferenceBlob *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITConferenceBlob *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITConferenceBlob *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITConferenceBlob *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Init)(ITConferenceBlob *This,BSTR pName,BLOB_CHARACTER_SET CharacterSet,BSTR pBlob);
      HRESULT (WINAPI *get_CharacterSet)(ITConferenceBlob *This,BLOB_CHARACTER_SET *pCharacterSet);
      HRESULT (WINAPI *get_ConferenceBlob)(ITConferenceBlob *This,BSTR *ppBlob);
      HRESULT (WINAPI *SetConferenceBlob)(ITConferenceBlob *This,BLOB_CHARACTER_SET CharacterSet,BSTR pBlob);
    END_INTERFACE
  } ITConferenceBlobVtbl;
  struct ITConferenceBlob {
    CONST_VTBL struct ITConferenceBlobVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITConferenceBlob_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITConferenceBlob_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITConferenceBlob_Release(This) (This)->lpVtbl->Release(This)
#define ITConferenceBlob_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITConferenceBlob_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITConferenceBlob_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITConferenceBlob_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITConferenceBlob_Init(This,pName,CharacterSet,pBlob) (This)->lpVtbl->Init(This,pName,CharacterSet,pBlob)
#define ITConferenceBlob_get_CharacterSet(This,pCharacterSet) (This)->lpVtbl->get_CharacterSet(This,pCharacterSet)
#define ITConferenceBlob_get_ConferenceBlob(This,ppBlob) (This)->lpVtbl->get_ConferenceBlob(This,ppBlob)
#define ITConferenceBlob_SetConferenceBlob(This,CharacterSet,pBlob) (This)->lpVtbl->SetConferenceBlob(This,CharacterSet,pBlob)
#endif
#endif
  HRESULT WINAPI ITConferenceBlob_Init_Proxy(ITConferenceBlob *This,BSTR pName,BLOB_CHARACTER_SET CharacterSet,BSTR pBlob);
  void __RPC_STUB ITConferenceBlob_Init_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConferenceBlob_get_CharacterSet_Proxy(ITConferenceBlob *This,BLOB_CHARACTER_SET *pCharacterSet);
  void __RPC_STUB ITConferenceBlob_get_CharacterSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConferenceBlob_get_ConferenceBlob_Proxy(ITConferenceBlob *This,BSTR *ppBlob);
  void __RPC_STUB ITConferenceBlob_get_ConferenceBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConferenceBlob_SetConferenceBlob_Proxy(ITConferenceBlob *This,BLOB_CHARACTER_SET CharacterSet,BSTR pBlob);
  void __RPC_STUB ITConferenceBlob_SetConferenceBlob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMedia_INTERFACE_DEFINED__
#define __ITMedia_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMedia;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMedia : public IDispatch {
  public:
    virtual HRESULT WINAPI get_MediaName(BSTR *ppMediaName) = 0;
    virtual HRESULT WINAPI put_MediaName(BSTR pMediaName) = 0;
    virtual HRESULT WINAPI get_StartPort(LONG *pStartPort) = 0;
    virtual HRESULT WINAPI get_NumPorts(LONG *pNumPorts) = 0;
    virtual HRESULT WINAPI get_TransportProtocol(BSTR *ppProtocol) = 0;
    virtual HRESULT WINAPI put_TransportProtocol(BSTR pProtocol) = 0;
    virtual HRESULT WINAPI get_FormatCodes(VARIANT *pVal) = 0;
    virtual HRESULT WINAPI put_FormatCodes(VARIANT NewVal) = 0;
    virtual HRESULT WINAPI get_MediaTitle(BSTR *ppMediaTitle) = 0;
    virtual HRESULT WINAPI put_MediaTitle(BSTR pMediaTitle) = 0;
    virtual HRESULT WINAPI SetPortInfo(LONG StartPort,LONG NumPorts) = 0;
  };
#else
  typedef struct ITMediaVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMedia *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMedia *This);
      ULONG (WINAPI *Release)(ITMedia *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMedia *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMedia *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMedia *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMedia *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_MediaName)(ITMedia *This,BSTR *ppMediaName);
      HRESULT (WINAPI *put_MediaName)(ITMedia *This,BSTR pMediaName);
      HRESULT (WINAPI *get_StartPort)(ITMedia *This,LONG *pStartPort);
      HRESULT (WINAPI *get_NumPorts)(ITMedia *This,LONG *pNumPorts);
      HRESULT (WINAPI *get_TransportProtocol)(ITMedia *This,BSTR *ppProtocol);
      HRESULT (WINAPI *put_TransportProtocol)(ITMedia *This,BSTR pProtocol);
      HRESULT (WINAPI *get_FormatCodes)(ITMedia *This,VARIANT *pVal);
      HRESULT (WINAPI *put_FormatCodes)(ITMedia *This,VARIANT NewVal);
      HRESULT (WINAPI *get_MediaTitle)(ITMedia *This,BSTR *ppMediaTitle);
      HRESULT (WINAPI *put_MediaTitle)(ITMedia *This,BSTR pMediaTitle);
      HRESULT (WINAPI *SetPortInfo)(ITMedia *This,LONG StartPort,LONG NumPorts);
    END_INTERFACE
  } ITMediaVtbl;
  struct ITMedia {
    CONST_VTBL struct ITMediaVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMedia_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMedia_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMedia_Release(This) (This)->lpVtbl->Release(This)
#define ITMedia_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMedia_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMedia_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMedia_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMedia_get_MediaName(This,ppMediaName) (This)->lpVtbl->get_MediaName(This,ppMediaName)
#define ITMedia_put_MediaName(This,pMediaName) (This)->lpVtbl->put_MediaName(This,pMediaName)
#define ITMedia_get_StartPort(This,pStartPort) (This)->lpVtbl->get_StartPort(This,pStartPort)
#define ITMedia_get_NumPorts(This,pNumPorts) (This)->lpVtbl->get_NumPorts(This,pNumPorts)
#define ITMedia_get_TransportProtocol(This,ppProtocol) (This)->lpVtbl->get_TransportProtocol(This,ppProtocol)
#define ITMedia_put_TransportProtocol(This,pProtocol) (This)->lpVtbl->put_TransportProtocol(This,pProtocol)
#define ITMedia_get_FormatCodes(This,pVal) (This)->lpVtbl->get_FormatCodes(This,pVal)
#define ITMedia_put_FormatCodes(This,NewVal) (This)->lpVtbl->put_FormatCodes(This,NewVal)
#define ITMedia_get_MediaTitle(This,ppMediaTitle) (This)->lpVtbl->get_MediaTitle(This,ppMediaTitle)
#define ITMedia_put_MediaTitle(This,pMediaTitle) (This)->lpVtbl->put_MediaTitle(This,pMediaTitle)
#define ITMedia_SetPortInfo(This,StartPort,NumPorts) (This)->lpVtbl->SetPortInfo(This,StartPort,NumPorts)
#endif
#endif
  HRESULT WINAPI ITMedia_get_MediaName_Proxy(ITMedia *This,BSTR *ppMediaName);
  void __RPC_STUB ITMedia_get_MediaName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_put_MediaName_Proxy(ITMedia *This,BSTR pMediaName);
  void __RPC_STUB ITMedia_put_MediaName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_get_StartPort_Proxy(ITMedia *This,LONG *pStartPort);
  void __RPC_STUB ITMedia_get_StartPort_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_get_NumPorts_Proxy(ITMedia *This,LONG *pNumPorts);
  void __RPC_STUB ITMedia_get_NumPorts_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_get_TransportProtocol_Proxy(ITMedia *This,BSTR *ppProtocol);
  void __RPC_STUB ITMedia_get_TransportProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_put_TransportProtocol_Proxy(ITMedia *This,BSTR pProtocol);
  void __RPC_STUB ITMedia_put_TransportProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_get_FormatCodes_Proxy(ITMedia *This,VARIANT *pVal);
  void __RPC_STUB ITMedia_get_FormatCodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_put_FormatCodes_Proxy(ITMedia *This,VARIANT NewVal);
  void __RPC_STUB ITMedia_put_FormatCodes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_get_MediaTitle_Proxy(ITMedia *This,BSTR *ppMediaTitle);
  void __RPC_STUB ITMedia_get_MediaTitle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_put_MediaTitle_Proxy(ITMedia *This,BSTR pMediaTitle);
  void __RPC_STUB ITMedia_put_MediaTitle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMedia_SetPortInfo_Proxy(ITMedia *This,LONG StartPort,LONG NumPorts);
  void __RPC_STUB ITMedia_SetPortInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumMedia_INTERFACE_DEFINED__
#define __IEnumMedia_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumMedia;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumMedia : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITMedia **pVal,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumMedia **ppEnum) = 0;
  };
#else
  typedef struct IEnumMediaVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumMedia *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumMedia *This);
      ULONG (WINAPI *Release)(IEnumMedia *This);
      HRESULT (WINAPI *Next)(IEnumMedia *This,ULONG celt,ITMedia **pVal,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumMedia *This);
      HRESULT (WINAPI *Skip)(IEnumMedia *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumMedia *This,IEnumMedia **ppEnum);
    END_INTERFACE
  } IEnumMediaVtbl;
  struct IEnumMedia {
    CONST_VTBL struct IEnumMediaVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumMedia_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumMedia_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumMedia_Release(This) (This)->lpVtbl->Release(This)
#define IEnumMedia_Next(This,celt,pVal,pceltFetched) (This)->lpVtbl->Next(This,celt,pVal,pceltFetched)
#define IEnumMedia_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumMedia_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumMedia_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumMedia_Next_Proxy(IEnumMedia *This,ULONG celt,ITMedia **pVal,ULONG *pceltFetched);
  void __RPC_STUB IEnumMedia_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMedia_Reset_Proxy(IEnumMedia *This);
  void __RPC_STUB IEnumMedia_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMedia_Skip_Proxy(IEnumMedia *This,ULONG celt);
  void __RPC_STUB IEnumMedia_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumMedia_Clone_Proxy(IEnumMedia *This,IEnumMedia **ppEnum);
  void __RPC_STUB IEnumMedia_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITMediaCollection_INTERFACE_DEFINED__
#define __ITMediaCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITMediaCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITMediaCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(LONG *pVal) = 0;
    virtual HRESULT WINAPI get_Item(LONG Index,ITMedia **pVal) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_EnumerationIf(IEnumMedia **pVal) = 0;
    virtual HRESULT WINAPI Create(LONG Index,ITMedia **ppMedia) = 0;
    virtual HRESULT WINAPI Delete(LONG Index) = 0;
  };
#else
  typedef struct ITMediaCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITMediaCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITMediaCollection *This);
      ULONG (WINAPI *Release)(ITMediaCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITMediaCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITMediaCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITMediaCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITMediaCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ITMediaCollection *This,LONG *pVal);
      HRESULT (WINAPI *get_Item)(ITMediaCollection *This,LONG Index,ITMedia **pVal);
      HRESULT (WINAPI *get__NewEnum)(ITMediaCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_EnumerationIf)(ITMediaCollection *This,IEnumMedia **pVal);
      HRESULT (WINAPI *Create)(ITMediaCollection *This,LONG Index,ITMedia **ppMedia);
      HRESULT (WINAPI *Delete)(ITMediaCollection *This,LONG Index);
    END_INTERFACE
  } ITMediaCollectionVtbl;
  struct ITMediaCollection {
    CONST_VTBL struct ITMediaCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITMediaCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITMediaCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITMediaCollection_Release(This) (This)->lpVtbl->Release(This)
#define ITMediaCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITMediaCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITMediaCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITMediaCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITMediaCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define ITMediaCollection_get_Item(This,Index,pVal) (This)->lpVtbl->get_Item(This,Index,pVal)
#define ITMediaCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define ITMediaCollection_get_EnumerationIf(This,pVal) (This)->lpVtbl->get_EnumerationIf(This,pVal)
#define ITMediaCollection_Create(This,Index,ppMedia) (This)->lpVtbl->Create(This,Index,ppMedia)
#define ITMediaCollection_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#endif
#endif
  HRESULT WINAPI ITMediaCollection_get_Count_Proxy(ITMediaCollection *This,LONG *pVal);
  void __RPC_STUB ITMediaCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaCollection_get_Item_Proxy(ITMediaCollection *This,LONG Index,ITMedia **pVal);
  void __RPC_STUB ITMediaCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaCollection_get__NewEnum_Proxy(ITMediaCollection *This,IUnknown **pVal);
  void __RPC_STUB ITMediaCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaCollection_get_EnumerationIf_Proxy(ITMediaCollection *This,IEnumMedia **pVal);
  void __RPC_STUB ITMediaCollection_get_EnumerationIf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaCollection_Create_Proxy(ITMediaCollection *This,LONG Index,ITMedia **ppMedia);
  void __RPC_STUB ITMediaCollection_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITMediaCollection_Delete_Proxy(ITMediaCollection *This,LONG Index);
  void __RPC_STUB ITMediaCollection_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTime_INTERFACE_DEFINED__
#define __ITTime_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTime;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTime : public IDispatch {
  public:
    virtual HRESULT WINAPI get_StartTime(DOUBLE *pTime) = 0;
    virtual HRESULT WINAPI put_StartTime(DOUBLE Time) = 0;
    virtual HRESULT WINAPI get_StopTime(DOUBLE *pTime) = 0;
    virtual HRESULT WINAPI put_StopTime(DOUBLE Time) = 0;
  };
#else
  typedef struct ITTimeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTime *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTime *This);
      ULONG (WINAPI *Release)(ITTime *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTime *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTime *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTime *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTime *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_StartTime)(ITTime *This,DOUBLE *pTime);
      HRESULT (WINAPI *put_StartTime)(ITTime *This,DOUBLE Time);
      HRESULT (WINAPI *get_StopTime)(ITTime *This,DOUBLE *pTime);
      HRESULT (WINAPI *put_StopTime)(ITTime *This,DOUBLE Time);
    END_INTERFACE
  } ITTimeVtbl;
  struct ITTime {
    CONST_VTBL struct ITTimeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTime_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTime_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTime_Release(This) (This)->lpVtbl->Release(This)
#define ITTime_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTime_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTime_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTime_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTime_get_StartTime(This,pTime) (This)->lpVtbl->get_StartTime(This,pTime)
#define ITTime_put_StartTime(This,Time) (This)->lpVtbl->put_StartTime(This,Time)
#define ITTime_get_StopTime(This,pTime) (This)->lpVtbl->get_StopTime(This,pTime)
#define ITTime_put_StopTime(This,Time) (This)->lpVtbl->put_StopTime(This,Time)
#endif
#endif
  HRESULT WINAPI ITTime_get_StartTime_Proxy(ITTime *This,DOUBLE *pTime);
  void __RPC_STUB ITTime_get_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTime_put_StartTime_Proxy(ITTime *This,DOUBLE Time);
  void __RPC_STUB ITTime_put_StartTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTime_get_StopTime_Proxy(ITTime *This,DOUBLE *pTime);
  void __RPC_STUB ITTime_get_StopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTime_put_StopTime_Proxy(ITTime *This,DOUBLE Time);
  void __RPC_STUB ITTime_put_StopTime_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumTime_INTERFACE_DEFINED__
#define __IEnumTime_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumTime;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumTime : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,ITTime **pVal,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Clone(IEnumTime **ppEnum) = 0;
  };
#else
  typedef struct IEnumTimeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumTime *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumTime *This);
      ULONG (WINAPI *Release)(IEnumTime *This);
      HRESULT (WINAPI *Next)(IEnumTime *This,ULONG celt,ITTime **pVal,ULONG *pceltFetched);
      HRESULT (WINAPI *Reset)(IEnumTime *This);
      HRESULT (WINAPI *Skip)(IEnumTime *This,ULONG celt);
      HRESULT (WINAPI *Clone)(IEnumTime *This,IEnumTime **ppEnum);
    END_INTERFACE
  } IEnumTimeVtbl;
  struct IEnumTime {
    CONST_VTBL struct IEnumTimeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumTime_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumTime_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumTime_Release(This) (This)->lpVtbl->Release(This)
#define IEnumTime_Next(This,celt,pVal,pceltFetched) (This)->lpVtbl->Next(This,celt,pVal,pceltFetched)
#define IEnumTime_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumTime_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumTime_Clone(This,ppEnum) (This)->lpVtbl->Clone(This,ppEnum)
#endif
#endif
  HRESULT WINAPI IEnumTime_Next_Proxy(IEnumTime *This,ULONG celt,ITTime **pVal,ULONG *pceltFetched);
  void __RPC_STUB IEnumTime_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTime_Reset_Proxy(IEnumTime *This);
  void __RPC_STUB IEnumTime_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTime_Skip_Proxy(IEnumTime *This,ULONG celt);
  void __RPC_STUB IEnumTime_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumTime_Clone_Proxy(IEnumTime *This,IEnumTime **ppEnum);
  void __RPC_STUB IEnumTime_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITTimeCollection_INTERFACE_DEFINED__
#define __ITTimeCollection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITTimeCollection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITTimeCollection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(LONG *pVal) = 0;
    virtual HRESULT WINAPI get_Item(LONG Index,ITTime **pVal) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI get_EnumerationIf(IEnumTime **pVal) = 0;
    virtual HRESULT WINAPI Create(LONG Index,ITTime **ppTime) = 0;
    virtual HRESULT WINAPI Delete(LONG Index) = 0;
  };
#else
  typedef struct ITTimeCollectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITTimeCollection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITTimeCollection *This);
      ULONG (WINAPI *Release)(ITTimeCollection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITTimeCollection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITTimeCollection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITTimeCollection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITTimeCollection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ITTimeCollection *This,LONG *pVal);
      HRESULT (WINAPI *get_Item)(ITTimeCollection *This,LONG Index,ITTime **pVal);
      HRESULT (WINAPI *get__NewEnum)(ITTimeCollection *This,IUnknown **pVal);
      HRESULT (WINAPI *get_EnumerationIf)(ITTimeCollection *This,IEnumTime **pVal);
      HRESULT (WINAPI *Create)(ITTimeCollection *This,LONG Index,ITTime **ppTime);
      HRESULT (WINAPI *Delete)(ITTimeCollection *This,LONG Index);
    END_INTERFACE
  } ITTimeCollectionVtbl;
  struct ITTimeCollection {
    CONST_VTBL struct ITTimeCollectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITTimeCollection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITTimeCollection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITTimeCollection_Release(This) (This)->lpVtbl->Release(This)
#define ITTimeCollection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITTimeCollection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITTimeCollection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITTimeCollection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITTimeCollection_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define ITTimeCollection_get_Item(This,Index,pVal) (This)->lpVtbl->get_Item(This,Index,pVal)
#define ITTimeCollection_get__NewEnum(This,pVal) (This)->lpVtbl->get__NewEnum(This,pVal)
#define ITTimeCollection_get_EnumerationIf(This,pVal) (This)->lpVtbl->get_EnumerationIf(This,pVal)
#define ITTimeCollection_Create(This,Index,ppTime) (This)->lpVtbl->Create(This,Index,ppTime)
#define ITTimeCollection_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#endif
#endif
  HRESULT WINAPI ITTimeCollection_get_Count_Proxy(ITTimeCollection *This,LONG *pVal);
  void __RPC_STUB ITTimeCollection_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTimeCollection_get_Item_Proxy(ITTimeCollection *This,LONG Index,ITTime **pVal);
  void __RPC_STUB ITTimeCollection_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTimeCollection_get__NewEnum_Proxy(ITTimeCollection *This,IUnknown **pVal);
  void __RPC_STUB ITTimeCollection_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTimeCollection_get_EnumerationIf_Proxy(ITTimeCollection *This,IEnumTime **pVal);
  void __RPC_STUB ITTimeCollection_get_EnumerationIf_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTimeCollection_Create_Proxy(ITTimeCollection *This,LONG Index,ITTime **ppTime);
  void __RPC_STUB ITTimeCollection_Create_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITTimeCollection_Delete_Proxy(ITTimeCollection *This,LONG Index);
  void __RPC_STUB ITTimeCollection_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITSdp_INTERFACE_DEFINED__
#define __ITSdp_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITSdp;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITSdp : public IDispatch {
  public:
    virtual HRESULT WINAPI get_IsValid(VARIANT_BOOL *pfIsValid) = 0;
    virtual HRESULT WINAPI get_ProtocolVersion(unsigned char *pProtocolVersion) = 0;
    virtual HRESULT WINAPI get_SessionId(DOUBLE *pSessionId) = 0;
    virtual HRESULT WINAPI get_SessionVersion(DOUBLE *pSessionVersion) = 0;
    virtual HRESULT WINAPI put_SessionVersion(DOUBLE SessionVersion) = 0;
    virtual HRESULT WINAPI get_MachineAddress(BSTR *ppMachineAddress) = 0;
    virtual HRESULT WINAPI put_MachineAddress(BSTR pMachineAddress) = 0;
    virtual HRESULT WINAPI get_Name(BSTR *ppName) = 0;
    virtual HRESULT WINAPI put_Name(BSTR pName) = 0;
    virtual HRESULT WINAPI get_Description(BSTR *ppDescription) = 0;
    virtual HRESULT WINAPI put_Description(BSTR pDescription) = 0;
    virtual HRESULT WINAPI get_Url(BSTR *ppUrl) = 0;
    virtual HRESULT WINAPI put_Url(BSTR pUrl) = 0;
    virtual HRESULT WINAPI GetEmailNames(VARIANT *pAddresses,VARIANT *pNames) = 0;
    virtual HRESULT WINAPI SetEmailNames(VARIANT Addresses,VARIANT Names) = 0;
    virtual HRESULT WINAPI GetPhoneNumbers(VARIANT *pNumbers,VARIANT *pNames) = 0;
    virtual HRESULT WINAPI SetPhoneNumbers(VARIANT Numbers,VARIANT Names) = 0;
    virtual HRESULT WINAPI get_Originator(BSTR *ppOriginator) = 0;
    virtual HRESULT WINAPI put_Originator(BSTR pOriginator) = 0;
    virtual HRESULT WINAPI get_MediaCollection(ITMediaCollection **ppMediaCollection) = 0;
    virtual HRESULT WINAPI get_TimeCollection(ITTimeCollection **ppTimeCollection) = 0;
  };
#else
  typedef struct ITSdpVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITSdp *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITSdp *This);
      ULONG (WINAPI *Release)(ITSdp *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITSdp *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITSdp *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITSdp *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITSdp *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_IsValid)(ITSdp *This,VARIANT_BOOL *pfIsValid);
      HRESULT (WINAPI *get_ProtocolVersion)(ITSdp *This,unsigned char *pProtocolVersion);
      HRESULT (WINAPI *get_SessionId)(ITSdp *This,DOUBLE *pSessionId);
      HRESULT (WINAPI *get_SessionVersion)(ITSdp *This,DOUBLE *pSessionVersion);
      HRESULT (WINAPI *put_SessionVersion)(ITSdp *This,DOUBLE SessionVersion);
      HRESULT (WINAPI *get_MachineAddress)(ITSdp *This,BSTR *ppMachineAddress);
      HRESULT (WINAPI *put_MachineAddress)(ITSdp *This,BSTR pMachineAddress);
      HRESULT (WINAPI *get_Name)(ITSdp *This,BSTR *ppName);
      HRESULT (WINAPI *put_Name)(ITSdp *This,BSTR pName);
      HRESULT (WINAPI *get_Description)(ITSdp *This,BSTR *ppDescription);
      HRESULT (WINAPI *put_Description)(ITSdp *This,BSTR pDescription);
      HRESULT (WINAPI *get_Url)(ITSdp *This,BSTR *ppUrl);
      HRESULT (WINAPI *put_Url)(ITSdp *This,BSTR pUrl);
      HRESULT (WINAPI *GetEmailNames)(ITSdp *This,VARIANT *pAddresses,VARIANT *pNames);
      HRESULT (WINAPI *SetEmailNames)(ITSdp *This,VARIANT Addresses,VARIANT Names);
      HRESULT (WINAPI *GetPhoneNumbers)(ITSdp *This,VARIANT *pNumbers,VARIANT *pNames);
      HRESULT (WINAPI *SetPhoneNumbers)(ITSdp *This,VARIANT Numbers,VARIANT Names);
      HRESULT (WINAPI *get_Originator)(ITSdp *This,BSTR *ppOriginator);
      HRESULT (WINAPI *put_Originator)(ITSdp *This,BSTR pOriginator);
      HRESULT (WINAPI *get_MediaCollection)(ITSdp *This,ITMediaCollection **ppMediaCollection);
      HRESULT (WINAPI *get_TimeCollection)(ITSdp *This,ITTimeCollection **ppTimeCollection);
    END_INTERFACE
  } ITSdpVtbl;
  struct ITSdp {
    CONST_VTBL struct ITSdpVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITSdp_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITSdp_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITSdp_Release(This) (This)->lpVtbl->Release(This)
#define ITSdp_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITSdp_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITSdp_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITSdp_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITSdp_get_IsValid(This,pfIsValid) (This)->lpVtbl->get_IsValid(This,pfIsValid)
#define ITSdp_get_ProtocolVersion(This,pProtocolVersion) (This)->lpVtbl->get_ProtocolVersion(This,pProtocolVersion)
#define ITSdp_get_SessionId(This,pSessionId) (This)->lpVtbl->get_SessionId(This,pSessionId)
#define ITSdp_get_SessionVersion(This,pSessionVersion) (This)->lpVtbl->get_SessionVersion(This,pSessionVersion)
#define ITSdp_put_SessionVersion(This,SessionVersion) (This)->lpVtbl->put_SessionVersion(This,SessionVersion)
#define ITSdp_get_MachineAddress(This,ppMachineAddress) (This)->lpVtbl->get_MachineAddress(This,ppMachineAddress)
#define ITSdp_put_MachineAddress(This,pMachineAddress) (This)->lpVtbl->put_MachineAddress(This,pMachineAddress)
#define ITSdp_get_Name(This,ppName) (This)->lpVtbl->get_Name(This,ppName)
#define ITSdp_put_Name(This,pName) (This)->lpVtbl->put_Name(This,pName)
#define ITSdp_get_Description(This,ppDescription) (This)->lpVtbl->get_Description(This,ppDescription)
#define ITSdp_put_Description(This,pDescription) (This)->lpVtbl->put_Description(This,pDescription)
#define ITSdp_get_Url(This,ppUrl) (This)->lpVtbl->get_Url(This,ppUrl)
#define ITSdp_put_Url(This,pUrl) (This)->lpVtbl->put_Url(This,pUrl)
#define ITSdp_GetEmailNames(This,pAddresses,pNames) (This)->lpVtbl->GetEmailNames(This,pAddresses,pNames)
#define ITSdp_SetEmailNames(This,Addresses,Names) (This)->lpVtbl->SetEmailNames(This,Addresses,Names)
#define ITSdp_GetPhoneNumbers(This,pNumbers,pNames) (This)->lpVtbl->GetPhoneNumbers(This,pNumbers,pNames)
#define ITSdp_SetPhoneNumbers(This,Numbers,Names) (This)->lpVtbl->SetPhoneNumbers(This,Numbers,Names)
#define ITSdp_get_Originator(This,ppOriginator) (This)->lpVtbl->get_Originator(This,ppOriginator)
#define ITSdp_put_Originator(This,pOriginator) (This)->lpVtbl->put_Originator(This,pOriginator)
#define ITSdp_get_MediaCollection(This,ppMediaCollection) (This)->lpVtbl->get_MediaCollection(This,ppMediaCollection)
#define ITSdp_get_TimeCollection(This,ppTimeCollection) (This)->lpVtbl->get_TimeCollection(This,ppTimeCollection)
#endif
#endif
  HRESULT WINAPI ITSdp_get_IsValid_Proxy(ITSdp *This,VARIANT_BOOL *pfIsValid);
  void __RPC_STUB ITSdp_get_IsValid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_ProtocolVersion_Proxy(ITSdp *This,unsigned char *pProtocolVersion);
  void __RPC_STUB ITSdp_get_ProtocolVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_SessionId_Proxy(ITSdp *This,DOUBLE *pSessionId);
  void __RPC_STUB ITSdp_get_SessionId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_SessionVersion_Proxy(ITSdp *This,DOUBLE *pSessionVersion);
  void __RPC_STUB ITSdp_get_SessionVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_SessionVersion_Proxy(ITSdp *This,DOUBLE SessionVersion);
  void __RPC_STUB ITSdp_put_SessionVersion_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_MachineAddress_Proxy(ITSdp *This,BSTR *ppMachineAddress);
  void __RPC_STUB ITSdp_get_MachineAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_MachineAddress_Proxy(ITSdp *This,BSTR pMachineAddress);
  void __RPC_STUB ITSdp_put_MachineAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_Name_Proxy(ITSdp *This,BSTR *ppName);
  void __RPC_STUB ITSdp_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_Name_Proxy(ITSdp *This,BSTR pName);
  void __RPC_STUB ITSdp_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_Description_Proxy(ITSdp *This,BSTR *ppDescription);
  void __RPC_STUB ITSdp_get_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_Description_Proxy(ITSdp *This,BSTR pDescription);
  void __RPC_STUB ITSdp_put_Description_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_Url_Proxy(ITSdp *This,BSTR *ppUrl);
  void __RPC_STUB ITSdp_get_Url_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_Url_Proxy(ITSdp *This,BSTR pUrl);
  void __RPC_STUB ITSdp_put_Url_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_GetEmailNames_Proxy(ITSdp *This,VARIANT *pAddresses,VARIANT *pNames);
  void __RPC_STUB ITSdp_GetEmailNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_SetEmailNames_Proxy(ITSdp *This,VARIANT Addresses,VARIANT Names);
  void __RPC_STUB ITSdp_SetEmailNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_GetPhoneNumbers_Proxy(ITSdp *This,VARIANT *pNumbers,VARIANT *pNames);
  void __RPC_STUB ITSdp_GetPhoneNumbers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_SetPhoneNumbers_Proxy(ITSdp *This,VARIANT Numbers,VARIANT Names);
  void __RPC_STUB ITSdp_SetPhoneNumbers_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_Originator_Proxy(ITSdp *This,BSTR *ppOriginator);
  void __RPC_STUB ITSdp_get_Originator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_put_Originator_Proxy(ITSdp *This,BSTR pOriginator);
  void __RPC_STUB ITSdp_put_Originator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_MediaCollection_Proxy(ITSdp *This,ITMediaCollection **ppMediaCollection);
  void __RPC_STUB ITSdp_get_MediaCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITSdp_get_TimeCollection_Proxy(ITSdp *This,ITTimeCollection **ppTimeCollection);
  void __RPC_STUB ITSdp_get_TimeCollection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITConnection_INTERFACE_DEFINED__
#define __ITConnection_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITConnection;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITConnection : public IDispatch {
  public:
    virtual HRESULT WINAPI get_NetworkType(BSTR *ppNetworkType) = 0;
    virtual HRESULT WINAPI put_NetworkType(BSTR pNetworkType) = 0;
    virtual HRESULT WINAPI get_AddressType(BSTR *ppAddressType) = 0;
    virtual HRESULT WINAPI put_AddressType(BSTR pAddressType) = 0;
    virtual HRESULT WINAPI get_StartAddress(BSTR *ppStartAddress) = 0;
    virtual HRESULT WINAPI get_NumAddresses(LONG *pNumAddresses) = 0;
    virtual HRESULT WINAPI get_Ttl(unsigned char *pTtl) = 0;
    virtual HRESULT WINAPI get_BandwidthModifier(BSTR *ppModifier) = 0;
    virtual HRESULT WINAPI get_Bandwidth(DOUBLE *pBandwidth) = 0;
    virtual HRESULT WINAPI SetAddressInfo(BSTR pStartAddress,LONG NumAddresses,unsigned char Ttl) = 0;
    virtual HRESULT WINAPI SetBandwidthInfo(BSTR pModifier,DOUBLE Bandwidth) = 0;
    virtual HRESULT WINAPI SetEncryptionKey(BSTR pKeyType,BSTR *ppKeyData) = 0;
    virtual HRESULT WINAPI GetEncryptionKey(BSTR *ppKeyType,VARIANT_BOOL *pfValidKeyData,BSTR *ppKeyData) = 0;
  };
#else
  typedef struct ITConnectionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITConnection *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITConnection *This);
      ULONG (WINAPI *Release)(ITConnection *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITConnection *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITConnection *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITConnection *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITConnection *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_NetworkType)(ITConnection *This,BSTR *ppNetworkType);
      HRESULT (WINAPI *put_NetworkType)(ITConnection *This,BSTR pNetworkType);
      HRESULT (WINAPI *get_AddressType)(ITConnection *This,BSTR *ppAddressType);
      HRESULT (WINAPI *put_AddressType)(ITConnection *This,BSTR pAddressType);
      HRESULT (WINAPI *get_StartAddress)(ITConnection *This,BSTR *ppStartAddress);
      HRESULT (WINAPI *get_NumAddresses)(ITConnection *This,LONG *pNumAddresses);
      HRESULT (WINAPI *get_Ttl)(ITConnection *This,unsigned char *pTtl);
      HRESULT (WINAPI *get_BandwidthModifier)(ITConnection *This,BSTR *ppModifier);
      HRESULT (WINAPI *get_Bandwidth)(ITConnection *This,DOUBLE *pBandwidth);
      HRESULT (WINAPI *SetAddressInfo)(ITConnection *This,BSTR pStartAddress,LONG NumAddresses,unsigned char Ttl);
      HRESULT (WINAPI *SetBandwidthInfo)(ITConnection *This,BSTR pModifier,DOUBLE Bandwidth);
      HRESULT (WINAPI *SetEncryptionKey)(ITConnection *This,BSTR pKeyType,BSTR *ppKeyData);
      HRESULT (WINAPI *GetEncryptionKey)(ITConnection *This,BSTR *ppKeyType,VARIANT_BOOL *pfValidKeyData,BSTR *ppKeyData);
    END_INTERFACE
  } ITConnectionVtbl;
  struct ITConnection {
    CONST_VTBL struct ITConnectionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITConnection_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITConnection_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITConnection_Release(This) (This)->lpVtbl->Release(This)
#define ITConnection_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITConnection_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITConnection_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITConnection_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITConnection_get_NetworkType(This,ppNetworkType) (This)->lpVtbl->get_NetworkType(This,ppNetworkType)
#define ITConnection_put_NetworkType(This,pNetworkType) (This)->lpVtbl->put_NetworkType(This,pNetworkType)
#define ITConnection_get_AddressType(This,ppAddressType) (This)->lpVtbl->get_AddressType(This,ppAddressType)
#define ITConnection_put_AddressType(This,pAddressType) (This)->lpVtbl->put_AddressType(This,pAddressType)
#define ITConnection_get_StartAddress(This,ppStartAddress) (This)->lpVtbl->get_StartAddress(This,ppStartAddress)
#define ITConnection_get_NumAddresses(This,pNumAddresses) (This)->lpVtbl->get_NumAddresses(This,pNumAddresses)
#define ITConnection_get_Ttl(This,pTtl) (This)->lpVtbl->get_Ttl(This,pTtl)
#define ITConnection_get_BandwidthModifier(This,ppModifier) (This)->lpVtbl->get_BandwidthModifier(This,ppModifier)
#define ITConnection_get_Bandwidth(This,pBandwidth) (This)->lpVtbl->get_Bandwidth(This,pBandwidth)
#define ITConnection_SetAddressInfo(This,pStartAddress,NumAddresses,Ttl) (This)->lpVtbl->SetAddressInfo(This,pStartAddress,NumAddresses,Ttl)
#define ITConnection_SetBandwidthInfo(This,pModifier,Bandwidth) (This)->lpVtbl->SetBandwidthInfo(This,pModifier,Bandwidth)
#define ITConnection_SetEncryptionKey(This,pKeyType,ppKeyData) (This)->lpVtbl->SetEncryptionKey(This,pKeyType,ppKeyData)
#define ITConnection_GetEncryptionKey(This,ppKeyType,pfValidKeyData,ppKeyData) (This)->lpVtbl->GetEncryptionKey(This,ppKeyType,pfValidKeyData,ppKeyData)
#endif
#endif
  HRESULT WINAPI ITConnection_get_NetworkType_Proxy(ITConnection *This,BSTR *ppNetworkType);
  void __RPC_STUB ITConnection_get_NetworkType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_put_NetworkType_Proxy(ITConnection *This,BSTR pNetworkType);
  void __RPC_STUB ITConnection_put_NetworkType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_AddressType_Proxy(ITConnection *This,BSTR *ppAddressType);
  void __RPC_STUB ITConnection_get_AddressType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_put_AddressType_Proxy(ITConnection *This,BSTR pAddressType);
  void __RPC_STUB ITConnection_put_AddressType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_StartAddress_Proxy(ITConnection *This,BSTR *ppStartAddress);
  void __RPC_STUB ITConnection_get_StartAddress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_NumAddresses_Proxy(ITConnection *This,LONG *pNumAddresses);
  void __RPC_STUB ITConnection_get_NumAddresses_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_Ttl_Proxy(ITConnection *This,unsigned char *pTtl);
  void __RPC_STUB ITConnection_get_Ttl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_BandwidthModifier_Proxy(ITConnection *This,BSTR *ppModifier);
  void __RPC_STUB ITConnection_get_BandwidthModifier_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_get_Bandwidth_Proxy(ITConnection *This,DOUBLE *pBandwidth);
  void __RPC_STUB ITConnection_get_Bandwidth_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_SetAddressInfo_Proxy(ITConnection *This,BSTR pStartAddress,LONG NumAddresses,unsigned char Ttl);
  void __RPC_STUB ITConnection_SetAddressInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_SetBandwidthInfo_Proxy(ITConnection *This,BSTR pModifier,DOUBLE Bandwidth);
  void __RPC_STUB ITConnection_SetBandwidthInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_SetEncryptionKey_Proxy(ITConnection *This,BSTR pKeyType,BSTR *ppKeyData);
  void __RPC_STUB ITConnection_SetEncryptionKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITConnection_GetEncryptionKey_Proxy(ITConnection *This,BSTR *ppKeyType,VARIANT_BOOL *pfValidKeyData,BSTR *ppKeyData);
  void __RPC_STUB ITConnection_GetEncryptionKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITAttributeList_INTERFACE_DEFINED__
#define __ITAttributeList_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITAttributeList;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITAttributeList : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Count(LONG *pVal) = 0;
    virtual HRESULT WINAPI get_Item(LONG Index,BSTR *pVal) = 0;
    virtual HRESULT WINAPI Add(LONG Index,BSTR pAttribute) = 0;
    virtual HRESULT WINAPI Delete(LONG Index) = 0;
    virtual HRESULT WINAPI get_AttributeList(VARIANT *pVal) = 0;
    virtual HRESULT WINAPI put_AttributeList(VARIANT newVal) = 0;
  };
#else
  typedef struct ITAttributeListVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITAttributeList *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITAttributeList *This);
      ULONG (WINAPI *Release)(ITAttributeList *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITAttributeList *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITAttributeList *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITAttributeList *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITAttributeList *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Count)(ITAttributeList *This,LONG *pVal);
      HRESULT (WINAPI *get_Item)(ITAttributeList *This,LONG Index,BSTR *pVal);
      HRESULT (WINAPI *Add)(ITAttributeList *This,LONG Index,BSTR pAttribute);
      HRESULT (WINAPI *Delete)(ITAttributeList *This,LONG Index);
      HRESULT (WINAPI *get_AttributeList)(ITAttributeList *This,VARIANT *pVal);
      HRESULT (WINAPI *put_AttributeList)(ITAttributeList *This,VARIANT newVal);
    END_INTERFACE
  } ITAttributeListVtbl;
  struct ITAttributeList {
    CONST_VTBL struct ITAttributeListVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITAttributeList_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITAttributeList_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITAttributeList_Release(This) (This)->lpVtbl->Release(This)
#define ITAttributeList_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITAttributeList_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITAttributeList_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITAttributeList_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITAttributeList_get_Count(This,pVal) (This)->lpVtbl->get_Count(This,pVal)
#define ITAttributeList_get_Item(This,Index,pVal) (This)->lpVtbl->get_Item(This,Index,pVal)
#define ITAttributeList_Add(This,Index,pAttribute) (This)->lpVtbl->Add(This,Index,pAttribute)
#define ITAttributeList_Delete(This,Index) (This)->lpVtbl->Delete(This,Index)
#define ITAttributeList_get_AttributeList(This,pVal) (This)->lpVtbl->get_AttributeList(This,pVal)
#define ITAttributeList_put_AttributeList(This,newVal) (This)->lpVtbl->put_AttributeList(This,newVal)
#endif
#endif
  HRESULT WINAPI ITAttributeList_get_Count_Proxy(ITAttributeList *This,LONG *pVal);
  void __RPC_STUB ITAttributeList_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAttributeList_get_Item_Proxy(ITAttributeList *This,LONG Index,BSTR *pVal);
  void __RPC_STUB ITAttributeList_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAttributeList_Add_Proxy(ITAttributeList *This,LONG Index,BSTR pAttribute);
  void __RPC_STUB ITAttributeList_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAttributeList_Delete_Proxy(ITAttributeList *This,LONG Index);
  void __RPC_STUB ITAttributeList_Delete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAttributeList_get_AttributeList_Proxy(ITAttributeList *This,VARIANT *pVal);
  void __RPC_STUB ITAttributeList_get_AttributeList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITAttributeList_put_AttributeList_Proxy(ITAttributeList *This,VARIANT newVal);
  void __RPC_STUB ITAttributeList_put_AttributeList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __SDPBLBLib_LIBRARY_DEFINED__
#define __SDPBLBLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_SDPBLBLib;
  EXTERN_C const CLSID CLSID_SdpConferenceBlob;
#ifdef __cplusplus
  class SdpConferenceBlob;
#endif
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
