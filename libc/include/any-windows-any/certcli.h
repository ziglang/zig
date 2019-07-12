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

#ifndef __certcli_h__
#define __certcli_h__

#ifndef __ICertGetConfig_FWD_DEFINED__
#define __ICertGetConfig_FWD_DEFINED__
typedef struct ICertGetConfig ICertGetConfig;
#endif

#ifndef __ICertConfig_FWD_DEFINED__
#define __ICertConfig_FWD_DEFINED__
typedef struct ICertConfig ICertConfig;
#endif

#ifndef __ICertConfig2_FWD_DEFINED__
#define __ICertConfig2_FWD_DEFINED__
typedef struct ICertConfig2 ICertConfig2;
#endif

#ifndef __ICertRequest_FWD_DEFINED__
#define __ICertRequest_FWD_DEFINED__
typedef struct ICertRequest ICertRequest;
#endif

#ifndef __ICertRequest2_FWD_DEFINED__
#define __ICertRequest2_FWD_DEFINED__
typedef struct ICertRequest2 ICertRequest2;
#endif

#ifndef __CCertGetConfig_FWD_DEFINED__
#define __CCertGetConfig_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertGetConfig CCertGetConfig;
#else
typedef struct CCertGetConfig CCertGetConfig;
#endif
#endif

#ifndef __CCertConfig_FWD_DEFINED__
#define __CCertConfig_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertConfig CCertConfig;
#else
typedef struct CCertConfig CCertConfig;
#endif
#endif

#ifndef __CCertRequest_FWD_DEFINED__
#define __CCertRequest_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertRequest CCertRequest;
#else
typedef struct CCertRequest CCertRequest;
#endif
#endif

#ifndef __CCertServerPolicy_FWD_DEFINED__
#define __CCertServerPolicy_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertServerPolicy CCertServerPolicy;
#else
typedef struct CCertServerPolicy CCertServerPolicy;
#endif
#endif

#ifndef __CCertServerExit_FWD_DEFINED__
#define __CCertServerExit_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertServerExit CCertServerExit;
#else
typedef struct CCertServerExit CCertServerExit;
#endif
#endif

#include "wtypes.h"
#include "certif.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __ICertGetConfig_INTERFACE_DEFINED__
#define __ICertGetConfig_INTERFACE_DEFINED__

  EXTERN_C const IID IID_ICertGetConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertGetConfig : public IDispatch {
  public:
    virtual HRESULT WINAPI GetConfig(LONG Flags,BSTR *pstrOut) = 0;
  };
#else
  typedef struct ICertGetConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertGetConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertGetConfig *This);
      ULONG (WINAPI *Release)(ICertGetConfig *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertGetConfig *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertGetConfig *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertGetConfig *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertGetConfig *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetConfig)(ICertGetConfig *This,LONG Flags,BSTR *pstrOut);
    END_INTERFACE
  } ICertGetConfigVtbl;
  struct ICertGetConfig {
    CONST_VTBL struct ICertGetConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertGetConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertGetConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertGetConfig_Release(This) (This)->lpVtbl->Release(This)
#define ICertGetConfig_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertGetConfig_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertGetConfig_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertGetConfig_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertGetConfig_GetConfig(This,Flags,pstrOut) (This)->lpVtbl->GetConfig(This,Flags,pstrOut)
#endif
#endif
  HRESULT WINAPI ICertGetConfig_GetConfig_Proxy(ICertGetConfig *This,LONG Flags,BSTR *pstrOut);
  void __RPC_STUB ICertGetConfig_GetConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define wszCONFIG_COMMONNAME L"CommonName"
#define wszCONFIG_ORGUNIT L"OrgUnit"
#define wszCONFIG_ORGANIZATION L"Organization"
#define wszCONFIG_LOCALITY L"Locality"
#define wszCONFIG_STATE L"State"
#define wszCONFIG_COUNTRY L"Country"
#define wszCONFIG_CONFIG L"Config"
#define wszCONFIG_EXCHANGECERTIFICATE L"ExchangeCertificate"
#define wszCONFIG_SIGNATURECERTIFICATE L"SignatureCertificate"
#define wszCONFIG_DESCRIPTION L"Description"
#define wszCONFIG_COMMENT L"Comment"
#define wszCONFIG_SERVER L"Server"
#define wszCONFIG_AUTHORITY L"Authority"
#define wszCONFIG_SANITIZEDNAME L"SanitizedName"
#define wszCONFIG_SHORTNAME L"ShortName"
#define wszCONFIG_SANITIZEDSHORTNAME L"SanitizedShortName"
#define wszCONFIG_FLAGS L"Flags"

#define CAIF_DSENTRY (0x1)
#define CAIF_SHAREDFOLDERENTRY (0x2)
#define CAIF_REGISTRY (0x4)
#define CAIF_LOCAL (0x8)
#define CAIF_REGISTRYPARENT (0x10)

  extern RPC_IF_HANDLE __MIDL_itf_certcli_0122_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certcli_0122_v0_0_s_ifspec;

#ifndef __ICertConfig_INTERFACE_DEFINED__
#define __ICertConfig_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertConfig;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertConfig : public IDispatch {
  public:
    virtual HRESULT WINAPI Reset(LONG Index,LONG *pCount) = 0;
    virtual HRESULT WINAPI Next(LONG *pIndex) = 0;
    virtual HRESULT WINAPI GetField(const BSTR strFieldName,BSTR *pstrOut) = 0;
    virtual HRESULT WINAPI GetConfig(LONG Flags,BSTR *pstrOut) = 0;
  };
#else
  typedef struct ICertConfigVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertConfig *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertConfig *This);
      ULONG (WINAPI *Release)(ICertConfig *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertConfig *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertConfig *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertConfig *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertConfig *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Reset)(ICertConfig *This,LONG Index,LONG *pCount);
      HRESULT (WINAPI *Next)(ICertConfig *This,LONG *pIndex);
      HRESULT (WINAPI *GetField)(ICertConfig *This,const BSTR strFieldName,BSTR *pstrOut);
      HRESULT (WINAPI *GetConfig)(ICertConfig *This,LONG Flags,BSTR *pstrOut);
    END_INTERFACE
  } ICertConfigVtbl;
  struct ICertConfig {
    CONST_VTBL struct ICertConfigVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertConfig_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertConfig_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertConfig_Release(This) (This)->lpVtbl->Release(This)
#define ICertConfig_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertConfig_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertConfig_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertConfig_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertConfig_Reset(This,Index,pCount) (This)->lpVtbl->Reset(This,Index,pCount)
#define ICertConfig_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define ICertConfig_GetField(This,strFieldName,pstrOut) (This)->lpVtbl->GetField(This,strFieldName,pstrOut)
#define ICertConfig_GetConfig(This,Flags,pstrOut) (This)->lpVtbl->GetConfig(This,Flags,pstrOut)
#endif
#endif
  HRESULT WINAPI ICertConfig_Reset_Proxy(ICertConfig *This,LONG Index,LONG *pCount);
  void __RPC_STUB ICertConfig_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertConfig_Next_Proxy(ICertConfig *This,LONG *pIndex);
  void __RPC_STUB ICertConfig_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertConfig_GetField_Proxy(ICertConfig *This,const BSTR strFieldName,BSTR *pstrOut);
  void __RPC_STUB ICertConfig_GetField_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertConfig_GetConfig_Proxy(ICertConfig *This,LONG Flags,BSTR *pstrOut);
  void __RPC_STUB ICertConfig_GetConfig_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertConfig2_INTERFACE_DEFINED__
#define __ICertConfig2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertConfig2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertConfig2 : public ICertConfig {
  public:
    virtual HRESULT WINAPI SetSharedFolder(const BSTR strSharedFolder) = 0;
  };
#else
  typedef struct ICertConfig2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertConfig2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertConfig2 *This);
      ULONG (WINAPI *Release)(ICertConfig2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertConfig2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertConfig2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertConfig2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertConfig2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Reset)(ICertConfig2 *This,LONG Index,LONG *pCount);
      HRESULT (WINAPI *Next)(ICertConfig2 *This,LONG *pIndex);
      HRESULT (WINAPI *GetField)(ICertConfig2 *This,const BSTR strFieldName,BSTR *pstrOut);
      HRESULT (WINAPI *GetConfig)(ICertConfig2 *This,LONG Flags,BSTR *pstrOut);
      HRESULT (WINAPI *SetSharedFolder)(ICertConfig2 *This,const BSTR strSharedFolder);
    END_INTERFACE
  } ICertConfig2Vtbl;
  struct ICertConfig2 {
    CONST_VTBL struct ICertConfig2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertConfig2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertConfig2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertConfig2_Release(This) (This)->lpVtbl->Release(This)
#define ICertConfig2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertConfig2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertConfig2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertConfig2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertConfig2_Reset(This,Index,pCount) (This)->lpVtbl->Reset(This,Index,pCount)
#define ICertConfig2_Next(This,pIndex) (This)->lpVtbl->Next(This,pIndex)
#define ICertConfig2_GetField(This,strFieldName,pstrOut) (This)->lpVtbl->GetField(This,strFieldName,pstrOut)
#define ICertConfig2_GetConfig(This,Flags,pstrOut) (This)->lpVtbl->GetConfig(This,Flags,pstrOut)
#define ICertConfig2_SetSharedFolder(This,strSharedFolder) (This)->lpVtbl->SetSharedFolder(This,strSharedFolder)
#endif
#endif
  HRESULT WINAPI ICertConfig2_SetSharedFolder_Proxy(ICertConfig2 *This,const BSTR strSharedFolder);
  void __RPC_STUB ICertConfig2_SetSharedFolder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define CR_IN_BASE64HEADER (0)
#define CR_IN_BASE64 (0x1)
#define CR_IN_BINARY (0x2)
#define CR_IN_ENCODEANY (0xff)
#define CR_IN_ENCODEMASK (0xff)

#define CR_IN_FORMATANY (0)
#define CR_IN_PKCS10 (0x100)
#define CR_IN_KEYGEN (0x200)
#define CR_IN_PKCS7 (0x300)
#define CR_IN_CMC (0x400)

#define CR_IN_FORMATMASK (0xff00)

#define CR_IN_RPC (0x20000)
#define CR_IN_FULLRESPONSE (0x40000)
#define CR_IN_CRLS (0x80000)

#define CC_DEFAULTCONFIG (0)
#define CC_UIPICKCONFIG (0x1)
#define CC_FIRSTCONFIG (0x2)
#define CC_LOCALCONFIG (0x3)
#define CC_LOCALACTIVECONFIG (0x4)
#define CC_UIPICKCONFIGSKIPLOCALCA (0x5)

#define CR_DISP_INCOMPLETE (0)
#define CR_DISP_ERROR (0x1)
#define CR_DISP_DENIED (0x2)
#define CR_DISP_ISSUED (0x3)
#define CR_DISP_ISSUED_OUT_OF_BAND (0x4)
#define CR_DISP_UNDER_SUBMISSION (0x5)
#define CR_DISP_REVOKED (0x6)

#define CR_OUT_BASE64HEADER (0)
#define CR_OUT_BASE64 (0x1)
#define CR_OUT_BINARY (0x2)
#define CR_OUT_ENCODEMASK (0xff)

#define CR_OUT_CHAIN (0x100)
#define CR_OUT_CRLS (0x200)

#define CR_GEMT_HRESULT_STRING (0x1)

#define CR_PROP_NONE 0
#define CR_PROP_FILEVERSION 1
#define CR_PROP_PRODUCTVERSION 2
#define CR_PROP_EXITCOUNT 3
#define CR_PROP_EXITDESCRIPTION 4
#define CR_PROP_POLICYDESCRIPTION 5
#define CR_PROP_CANAME 6
#define CR_PROP_SANITIZEDCANAME 7
#define CR_PROP_SHAREDFOLDER 8
#define CR_PROP_PARENTCA 9
#define CR_PROP_CATYPE 10
#define CR_PROP_CASIGCERTCOUNT 11
#define CR_PROP_CASIGCERT 12
#define CR_PROP_CASIGCERTCHAIN 13
#define CR_PROP_CAXCHGCERTCOUNT 14
#define CR_PROP_CAXCHGCERT 15
#define CR_PROP_CAXCHGCERTCHAIN 16
#define CR_PROP_BASECRL 17
#define CR_PROP_DELTACRL 18
#define CR_PROP_CACERTSTATE 19
#define CR_PROP_CRLSTATE 20
#define CR_PROP_CAPROPIDMAX 21
#define CR_PROP_DNSNAME 22
#define CR_PROP_ROLESEPARATIONENABLED 23
#define CR_PROP_KRACERTUSEDCOUNT 24
#define CR_PROP_KRACERTCOUNT 25
#define CR_PROP_KRACERT 26
#define CR_PROP_KRACERTSTATE 27
#define CR_PROP_ADVANCEDSERVER 28
#define CR_PROP_TEMPLATES 29
#define CR_PROP_BASECRLPUBLISHSTATUS 30
#define CR_PROP_DELTACRLPUBLISHSTATUS 31
#define CR_PROP_CASIGCERTCRLCHAIN 32
#define CR_PROP_CAXCHGCERTCRLCHAIN 33
#define CR_PROP_CACERTSTATUSCODE 34
#define CR_PROP_CAFORWARDCROSSCERT 35
#define CR_PROP_CABACKWARDCROSSCERT 36
#define CR_PROP_CAFORWARDCROSSCERTSTATE 37
#define CR_PROP_CABACKWARDCROSSCERTSTATE 38
#define CR_PROP_CACERTVERSION 39
#define CR_PROP_SANITIZEDCASHORTNAME 40

#define FR_PROP_NONE 0
#define FR_PROP_FULLRESPONSE 1
#define FR_PROP_STATUSINFOCOUNT 2
#define FR_PROP_BODYPARTSTRING 3
#define FR_PROP_STATUS 4
#define FR_PROP_STATUSSTRING 5
#define FR_PROP_OTHERINFOCHOICE 6
#define FR_PROP_FAILINFO 7
#define FR_PROP_PENDINFOTOKEN 8
#define FR_PROP_PENDINFOTIME 9
#define FR_PROP_ISSUEDCERTIFICATEHASH 10
#define FR_PROP_ISSUEDCERTIFICATE 11
#define FR_PROP_ISSUEDCERTIFICATECHAIN 12
#define FR_PROP_ISSUEDCERTIFICATECRLCHAIN 13
#define FR_PROP_ENCRYPTEDKEYHASH 14
#define FR_PROP_FULLRESPONSENOPKCS7 15

  extern RPC_IF_HANDLE __MIDL_itf_certcli_0124_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certcli_0124_v0_0_s_ifspec;

#ifndef __ICertRequest_INTERFACE_DEFINED__
#define __ICertRequest_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertRequest;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertRequest : public IDispatch {
  public:
    virtual HRESULT WINAPI Submit(LONG Flags,const BSTR strRequest,const BSTR strAttributes,const BSTR strConfig,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI RetrievePending(LONG RequestId,const BSTR strConfig,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI GetLastStatus(LONG *pStatus) = 0;
    virtual HRESULT WINAPI GetRequestId(LONG *pRequestId) = 0;
    virtual HRESULT WINAPI GetDispositionMessage(BSTR *pstrDispositionMessage) = 0;
    virtual HRESULT WINAPI GetCACertificate(LONG fExchangeCertificate,const BSTR strConfig,LONG Flags,BSTR *pstrCertificate) = 0;
    virtual HRESULT WINAPI GetCertificate(LONG Flags,BSTR *pstrCertificate) = 0;
  };
#else
  typedef struct ICertRequestVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertRequest *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertRequest *This);
      ULONG (WINAPI *Release)(ICertRequest *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertRequest *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertRequest *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertRequest *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertRequest *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Submit)(ICertRequest *This,LONG Flags,const BSTR strRequest,const BSTR strAttributes,const BSTR strConfig,LONG *pDisposition);
      HRESULT (WINAPI *RetrievePending)(ICertRequest *This,LONG RequestId,const BSTR strConfig,LONG *pDisposition);
      HRESULT (WINAPI *GetLastStatus)(ICertRequest *This,LONG *pStatus);
      HRESULT (WINAPI *GetRequestId)(ICertRequest *This,LONG *pRequestId);
      HRESULT (WINAPI *GetDispositionMessage)(ICertRequest *This,BSTR *pstrDispositionMessage);
      HRESULT (WINAPI *GetCACertificate)(ICertRequest *This,LONG fExchangeCertificate,const BSTR strConfig,LONG Flags,BSTR *pstrCertificate);
      HRESULT (WINAPI *GetCertificate)(ICertRequest *This,LONG Flags,BSTR *pstrCertificate);
    END_INTERFACE
  } ICertRequestVtbl;
  struct ICertRequest {
    CONST_VTBL struct ICertRequestVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertRequest_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertRequest_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertRequest_Release(This) (This)->lpVtbl->Release(This)
#define ICertRequest_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertRequest_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertRequest_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertRequest_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertRequest_Submit(This,Flags,strRequest,strAttributes,strConfig,pDisposition) (This)->lpVtbl->Submit(This,Flags,strRequest,strAttributes,strConfig,pDisposition)
#define ICertRequest_RetrievePending(This,RequestId,strConfig,pDisposition) (This)->lpVtbl->RetrievePending(This,RequestId,strConfig,pDisposition)
#define ICertRequest_GetLastStatus(This,pStatus) (This)->lpVtbl->GetLastStatus(This,pStatus)
#define ICertRequest_GetRequestId(This,pRequestId) (This)->lpVtbl->GetRequestId(This,pRequestId)
#define ICertRequest_GetDispositionMessage(This,pstrDispositionMessage) (This)->lpVtbl->GetDispositionMessage(This,pstrDispositionMessage)
#define ICertRequest_GetCACertificate(This,fExchangeCertificate,strConfig,Flags,pstrCertificate) (This)->lpVtbl->GetCACertificate(This,fExchangeCertificate,strConfig,Flags,pstrCertificate)
#define ICertRequest_GetCertificate(This,Flags,pstrCertificate) (This)->lpVtbl->GetCertificate(This,Flags,pstrCertificate)
#endif
#endif
  HRESULT WINAPI ICertRequest_Submit_Proxy(ICertRequest *This,LONG Flags,const BSTR strRequest,const BSTR strAttributes,const BSTR strConfig,LONG *pDisposition);
  void __RPC_STUB ICertRequest_Submit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_RetrievePending_Proxy(ICertRequest *This,LONG RequestId,const BSTR strConfig,LONG *pDisposition);
  void __RPC_STUB ICertRequest_RetrievePending_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_GetLastStatus_Proxy(ICertRequest *This,LONG *pStatus);
  void __RPC_STUB ICertRequest_GetLastStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_GetRequestId_Proxy(ICertRequest *This,LONG *pRequestId);
  void __RPC_STUB ICertRequest_GetRequestId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_GetDispositionMessage_Proxy(ICertRequest *This,BSTR *pstrDispositionMessage);
  void __RPC_STUB ICertRequest_GetDispositionMessage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_GetCACertificate_Proxy(ICertRequest *This,LONG fExchangeCertificate,const BSTR strConfig,LONG Flags,BSTR *pstrCertificate);
  void __RPC_STUB ICertRequest_GetCACertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest_GetCertificate_Proxy(ICertRequest *This,LONG Flags,BSTR *pstrCertificate);
  void __RPC_STUB ICertRequest_GetCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICertRequest2_INTERFACE_DEFINED__
#define __ICertRequest2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertRequest2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertRequest2 : public ICertRequest {
  public:
    virtual HRESULT WINAPI GetIssuedCertificate(const BSTR strConfig,LONG RequestId,const BSTR strSerialNumber,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI GetErrorMessageText(LONG hrMessage,LONG Flags,BSTR *pstrErrorMessageText) = 0;
    virtual HRESULT WINAPI GetCAProperty(const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetCAPropertyFlags(const BSTR strConfig,LONG PropId,LONG *pPropFlags) = 0;
    virtual HRESULT WINAPI GetCAPropertyDisplayName(const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName) = 0;
    virtual HRESULT WINAPI GetFullResponseProperty(LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue) = 0;
  };
#else
  typedef struct ICertRequest2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertRequest2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertRequest2 *This);
      ULONG (WINAPI *Release)(ICertRequest2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertRequest2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertRequest2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertRequest2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertRequest2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Submit)(ICertRequest2 *This,LONG Flags,const BSTR strRequest,const BSTR strAttributes,const BSTR strConfig,LONG *pDisposition);
      HRESULT (WINAPI *RetrievePending)(ICertRequest2 *This,LONG RequestId,const BSTR strConfig,LONG *pDisposition);
      HRESULT (WINAPI *GetLastStatus)(ICertRequest2 *This,LONG *pStatus);
      HRESULT (WINAPI *GetRequestId)(ICertRequest2 *This,LONG *pRequestId);
      HRESULT (WINAPI *GetDispositionMessage)(ICertRequest2 *This,BSTR *pstrDispositionMessage);
      HRESULT (WINAPI *GetCACertificate)(ICertRequest2 *This,LONG fExchangeCertificate,const BSTR strConfig,LONG Flags,BSTR *pstrCertificate);
      HRESULT (WINAPI *GetCertificate)(ICertRequest2 *This,LONG Flags,BSTR *pstrCertificate);
      HRESULT (WINAPI *GetIssuedCertificate)(ICertRequest2 *This,const BSTR strConfig,LONG RequestId,const BSTR strSerialNumber,LONG *pDisposition);
      HRESULT (WINAPI *GetErrorMessageText)(ICertRequest2 *This,LONG hrMessage,LONG Flags,BSTR *pstrErrorMessageText);
      HRESULT (WINAPI *GetCAProperty)(ICertRequest2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetCAPropertyFlags)(ICertRequest2 *This,const BSTR strConfig,LONG PropId,LONG *pPropFlags);
      HRESULT (WINAPI *GetCAPropertyDisplayName)(ICertRequest2 *This,const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName);
      HRESULT (WINAPI *GetFullResponseProperty)(ICertRequest2 *This,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
    END_INTERFACE
  } ICertRequest2Vtbl;
  struct ICertRequest2 {
    CONST_VTBL struct ICertRequest2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertRequest2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertRequest2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertRequest2_Release(This) (This)->lpVtbl->Release(This)
#define ICertRequest2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertRequest2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertRequest2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertRequest2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertRequest2_Submit(This,Flags,strRequest,strAttributes,strConfig,pDisposition) (This)->lpVtbl->Submit(This,Flags,strRequest,strAttributes,strConfig,pDisposition)
#define ICertRequest2_RetrievePending(This,RequestId,strConfig,pDisposition) (This)->lpVtbl->RetrievePending(This,RequestId,strConfig,pDisposition)
#define ICertRequest2_GetLastStatus(This,pStatus) (This)->lpVtbl->GetLastStatus(This,pStatus)
#define ICertRequest2_GetRequestId(This,pRequestId) (This)->lpVtbl->GetRequestId(This,pRequestId)
#define ICertRequest2_GetDispositionMessage(This,pstrDispositionMessage) (This)->lpVtbl->GetDispositionMessage(This,pstrDispositionMessage)
#define ICertRequest2_GetCACertificate(This,fExchangeCertificate,strConfig,Flags,pstrCertificate) (This)->lpVtbl->GetCACertificate(This,fExchangeCertificate,strConfig,Flags,pstrCertificate)
#define ICertRequest2_GetCertificate(This,Flags,pstrCertificate) (This)->lpVtbl->GetCertificate(This,Flags,pstrCertificate)
#define ICertRequest2_GetIssuedCertificate(This,strConfig,RequestId,strSerialNumber,pDisposition) (This)->lpVtbl->GetIssuedCertificate(This,strConfig,RequestId,strSerialNumber,pDisposition)
#define ICertRequest2_GetErrorMessageText(This,hrMessage,Flags,pstrErrorMessageText) (This)->lpVtbl->GetErrorMessageText(This,hrMessage,Flags,pstrErrorMessageText)
#define ICertRequest2_GetCAProperty(This,strConfig,PropId,PropIndex,PropType,Flags,pvarPropertyValue) (This)->lpVtbl->GetCAProperty(This,strConfig,PropId,PropIndex,PropType,Flags,pvarPropertyValue)
#define ICertRequest2_GetCAPropertyFlags(This,strConfig,PropId,pPropFlags) (This)->lpVtbl->GetCAPropertyFlags(This,strConfig,PropId,pPropFlags)
#define ICertRequest2_GetCAPropertyDisplayName(This,strConfig,PropId,pstrDisplayName) (This)->lpVtbl->GetCAPropertyDisplayName(This,strConfig,PropId,pstrDisplayName)
#define ICertRequest2_GetFullResponseProperty(This,PropId,PropIndex,PropType,Flags,pvarPropertyValue) (This)->lpVtbl->GetFullResponseProperty(This,PropId,PropIndex,PropType,Flags,pvarPropertyValue)
#endif
#endif
  HRESULT WINAPI ICertRequest2_GetIssuedCertificate_Proxy(ICertRequest2 *This,const BSTR strConfig,LONG RequestId,const BSTR strSerialNumber,LONG *pDisposition);
  void __RPC_STUB ICertRequest2_GetIssuedCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest2_GetErrorMessageText_Proxy(ICertRequest2 *This,LONG hrMessage,LONG Flags,BSTR *pstrErrorMessageText);
  void __RPC_STUB ICertRequest2_GetErrorMessageText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest2_GetCAProperty_Proxy(ICertRequest2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertRequest2_GetCAProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest2_GetCAPropertyFlags_Proxy(ICertRequest2 *This,const BSTR strConfig,LONG PropId,LONG *pPropFlags);
  void __RPC_STUB ICertRequest2_GetCAPropertyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest2_GetCAPropertyDisplayName_Proxy(ICertRequest2 *This,const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName);
  void __RPC_STUB ICertRequest2_GetCAPropertyDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertRequest2_GetFullResponseProperty_Proxy(ICertRequest2 *This,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertRequest2_GetFullResponseProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __CERTCLIENTLib_LIBRARY_DEFINED__
#define __CERTCLIENTLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CERTCLIENTLib;
  EXTERN_C const CLSID CLSID_CCertGetConfig;
#ifdef __cplusplus
  class CCertGetConfig;
#endif
  EXTERN_C const CLSID CLSID_CCertConfig;
#ifdef __cplusplus
  class CCertConfig;
#endif
  EXTERN_C const CLSID CLSID_CCertRequest;
#ifdef __cplusplus
  class CCertRequest;
#endif
  EXTERN_C const CLSID CLSID_CCertServerPolicy;
#ifdef __cplusplus
  class CCertServerPolicy;
#endif
  EXTERN_C const CLSID CLSID_CCertServerExit;
#ifdef __cplusplus
  class CCertServerExit;
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
