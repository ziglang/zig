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

#ifndef __certadm_h__
#define __certadm_h__

#ifndef __ICertAdmin_FWD_DEFINED__
#define __ICertAdmin_FWD_DEFINED__
typedef struct ICertAdmin ICertAdmin;
#endif

#ifndef __ICertAdmin2_FWD_DEFINED__
#define __ICertAdmin2_FWD_DEFINED__
typedef struct ICertAdmin2 ICertAdmin2;
#endif

#ifndef __CCertAdmin_FWD_DEFINED__
#define __CCertAdmin_FWD_DEFINED__
#ifdef __cplusplus
typedef class CCertAdmin CCertAdmin;
#else
typedef struct CCertAdmin CCertAdmin;
#endif
#endif

#ifndef __CCertView_FWD_DEFINED__
#define __CCertView_FWD_DEFINED__

#ifdef __cplusplus
typedef class CCertView CCertView;
#else
typedef struct CCertView CCertView;
#endif
#endif

#include "wtypes.h"
#include "certview.h"
#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define CA_DISP_INCOMPLETE (0)
#define CA_DISP_ERROR (0x1)
#define CA_DISP_REVOKED (0x2)
#define CA_DISP_VALID (0x3)
#define CA_DISP_INVALID (0x4)
#define CA_DISP_UNDER_SUBMISSION (0x5)

#define KRA_DISP_EXPIRED (0)
#define KRA_DISP_NOTFOUND (0x1)
#define KRA_DISP_REVOKED (0x2)
#define KRA_DISP_VALID (0x3)
#define KRA_DISP_INVALID (0x4)
#define KRA_DISP_UNTRUSTED (0x5)
#define KRA_DISP_NOTLOADED (0x6)

#define CA_ACCESS_ADMIN (0x1)
#define CA_ACCESS_OFFICER (0x2)
#define CA_ACCESS_AUDITOR (0x4)
#define CA_ACCESS_OPERATOR (0x8)

#define CA_ACCESS_MASKROLES (0xff)

#define CA_ACCESS_READ (0x100)
#define CA_ACCESS_ENROLL (0x200)

  extern RPC_IF_HANDLE __MIDL_itf_certadm_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certadm_0000_v0_0_s_ifspec;

#ifndef __ICertAdmin_INTERFACE_DEFINED__
#define __ICertAdmin_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertAdmin;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertAdmin : public IDispatch {
  public:
    virtual HRESULT WINAPI IsValidCertificate(const BSTR strConfig,const BSTR strSerialNumber,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI GetRevocationReason(LONG *pReason) = 0;
    virtual HRESULT WINAPI RevokeCertificate(const BSTR strConfig,const BSTR strSerialNumber,LONG Reason,DATE Date) = 0;
    virtual HRESULT WINAPI SetRequestAttributes(const BSTR strConfig,LONG RequestId,const BSTR strAttributes) = 0;
    virtual HRESULT WINAPI SetCertificateExtension(const BSTR strConfig,LONG RequestId,const BSTR strExtensionName,LONG Type,LONG Flags,const VARIANT *pvarValue) = 0;
    virtual HRESULT WINAPI DenyRequest(const BSTR strConfig,LONG RequestId) = 0;
    virtual HRESULT WINAPI ResubmitRequest(const BSTR strConfig,LONG RequestId,LONG *pDisposition) = 0;
    virtual HRESULT WINAPI PublishCRL(const BSTR strConfig,DATE Date) = 0;
    virtual HRESULT WINAPI GetCRL(const BSTR strConfig,LONG Flags,BSTR *pstrCRL) = 0;
    virtual HRESULT WINAPI ImportCertificate(const BSTR strConfig,const BSTR strCertificate,LONG Flags,LONG *pRequestId) = 0;
  };
#else
  typedef struct ICertAdminVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertAdmin *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertAdmin *This);
      ULONG (WINAPI *Release)(ICertAdmin *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertAdmin *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertAdmin *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertAdmin *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertAdmin *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *IsValidCertificate)(ICertAdmin *This,const BSTR strConfig,const BSTR strSerialNumber,LONG *pDisposition);
      HRESULT (WINAPI *GetRevocationReason)(ICertAdmin *This,LONG *pReason);
      HRESULT (WINAPI *RevokeCertificate)(ICertAdmin *This,const BSTR strConfig,const BSTR strSerialNumber,LONG Reason,DATE Date);
      HRESULT (WINAPI *SetRequestAttributes)(ICertAdmin *This,const BSTR strConfig,LONG RequestId,const BSTR strAttributes);
      HRESULT (WINAPI *SetCertificateExtension)(ICertAdmin *This,const BSTR strConfig,LONG RequestId,const BSTR strExtensionName,LONG Type,LONG Flags,const VARIANT *pvarValue);
      HRESULT (WINAPI *DenyRequest)(ICertAdmin *This,const BSTR strConfig,LONG RequestId);
      HRESULT (WINAPI *ResubmitRequest)(ICertAdmin *This,const BSTR strConfig,LONG RequestId,LONG *pDisposition);
      HRESULT (WINAPI *PublishCRL)(ICertAdmin *This,const BSTR strConfig,DATE Date);
      HRESULT (WINAPI *GetCRL)(ICertAdmin *This,const BSTR strConfig,LONG Flags,BSTR *pstrCRL);
      HRESULT (WINAPI *ImportCertificate)(ICertAdmin *This,const BSTR strConfig,const BSTR strCertificate,LONG Flags,LONG *pRequestId);
    END_INTERFACE
  } ICertAdminVtbl;
  struct ICertAdmin {
    CONST_VTBL struct ICertAdminVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertAdmin_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertAdmin_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertAdmin_Release(This) (This)->lpVtbl->Release(This)
#define ICertAdmin_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertAdmin_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertAdmin_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertAdmin_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertAdmin_IsValidCertificate(This,strConfig,strSerialNumber,pDisposition) (This)->lpVtbl->IsValidCertificate(This,strConfig,strSerialNumber,pDisposition)
#define ICertAdmin_GetRevocationReason(This,pReason) (This)->lpVtbl->GetRevocationReason(This,pReason)
#define ICertAdmin_RevokeCertificate(This,strConfig,strSerialNumber,Reason,Date) (This)->lpVtbl->RevokeCertificate(This,strConfig,strSerialNumber,Reason,Date)
#define ICertAdmin_SetRequestAttributes(This,strConfig,RequestId,strAttributes) (This)->lpVtbl->SetRequestAttributes(This,strConfig,RequestId,strAttributes)
#define ICertAdmin_SetCertificateExtension(This,strConfig,RequestId,strExtensionName,Type,Flags,pvarValue) (This)->lpVtbl->SetCertificateExtension(This,strConfig,RequestId,strExtensionName,Type,Flags,pvarValue)
#define ICertAdmin_DenyRequest(This,strConfig,RequestId) (This)->lpVtbl->DenyRequest(This,strConfig,RequestId)
#define ICertAdmin_ResubmitRequest(This,strConfig,RequestId,pDisposition) (This)->lpVtbl->ResubmitRequest(This,strConfig,RequestId,pDisposition)
#define ICertAdmin_PublishCRL(This,strConfig,Date) (This)->lpVtbl->PublishCRL(This,strConfig,Date)
#define ICertAdmin_GetCRL(This,strConfig,Flags,pstrCRL) (This)->lpVtbl->GetCRL(This,strConfig,Flags,pstrCRL)
#define ICertAdmin_ImportCertificate(This,strConfig,strCertificate,Flags,pRequestId) (This)->lpVtbl->ImportCertificate(This,strConfig,strCertificate,Flags,pRequestId)
#endif
#endif
  HRESULT WINAPI ICertAdmin_IsValidCertificate_Proxy(ICertAdmin *This,const BSTR strConfig,const BSTR strSerialNumber,LONG *pDisposition);
  void __RPC_STUB ICertAdmin_IsValidCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_GetRevocationReason_Proxy(ICertAdmin *This,LONG *pReason);
  void __RPC_STUB ICertAdmin_GetRevocationReason_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_RevokeCertificate_Proxy(ICertAdmin *This,const BSTR strConfig,const BSTR strSerialNumber,LONG Reason,DATE Date);
  void __RPC_STUB ICertAdmin_RevokeCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_SetRequestAttributes_Proxy(ICertAdmin *This,const BSTR strConfig,LONG RequestId,const BSTR strAttributes);
  void __RPC_STUB ICertAdmin_SetRequestAttributes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_SetCertificateExtension_Proxy(ICertAdmin *This,const BSTR strConfig,LONG RequestId,const BSTR strExtensionName,LONG Type,LONG Flags,const VARIANT *pvarValue);
  void __RPC_STUB ICertAdmin_SetCertificateExtension_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_DenyRequest_Proxy(ICertAdmin *This,const BSTR strConfig,LONG RequestId);
  void __RPC_STUB ICertAdmin_DenyRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_ResubmitRequest_Proxy(ICertAdmin *This,const BSTR strConfig,LONG RequestId,LONG *pDisposition);
  void __RPC_STUB ICertAdmin_ResubmitRequest_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_PublishCRL_Proxy(ICertAdmin *This,const BSTR strConfig,DATE Date);
  void __RPC_STUB ICertAdmin_PublishCRL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_GetCRL_Proxy(ICertAdmin *This,const BSTR strConfig,LONG Flags,BSTR *pstrCRL);
  void __RPC_STUB ICertAdmin_GetCRL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin_ImportCertificate_Proxy(ICertAdmin *This,const BSTR strConfig,const BSTR strCertificate,LONG Flags,LONG *pRequestId);
  void __RPC_STUB ICertAdmin_ImportCertificate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define CA_CRL_BASE (0x1)
#define CA_CRL_DELTA (0x2)
#define CA_CRL_REPUBLISH (0x10)
#define ICF_ALLOWFOREIGN (0x10000)
#define IKF_OVERWRITE (0x10000)

#define CDR_EXPIRED (1)
#define CDR_REQUEST_LAST_CHANGED (2)

  extern RPC_IF_HANDLE __MIDL_itf_certadm_0129_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_certadm_0129_v0_0_s_ifspec;

#ifndef __ICertAdmin2_INTERFACE_DEFINED__
#define __ICertAdmin2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICertAdmin2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICertAdmin2 : public ICertAdmin {
  public:
    virtual HRESULT WINAPI PublishCRLs(const BSTR strConfig,DATE Date,LONG CRLFlags) = 0;
    virtual HRESULT WINAPI GetCAProperty(const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI SetCAProperty(const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,VARIANT *pvarPropertyValue) = 0;
    virtual HRESULT WINAPI GetCAPropertyFlags(const BSTR strConfig,LONG PropId,LONG *pPropFlags) = 0;
    virtual HRESULT WINAPI GetCAPropertyDisplayName(const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName) = 0;
    virtual HRESULT WINAPI GetArchivedKey(const BSTR strConfig,LONG RequestId,LONG Flags,BSTR *pstrArchivedKey) = 0;
    virtual HRESULT WINAPI GetConfigEntry(const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry) = 0;
    virtual HRESULT WINAPI SetConfigEntry(const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry) = 0;
    virtual HRESULT WINAPI ImportKey(const BSTR strConfig,LONG RequestId,const BSTR strCertHash,LONG Flags,const BSTR strKey) = 0;
    virtual HRESULT WINAPI GetMyRoles(const BSTR strConfig,LONG *pRoles) = 0;
    virtual HRESULT WINAPI DeleteRow(const BSTR strConfig,LONG Flags,DATE Date,LONG Table,LONG RowId,LONG *pcDeleted) = 0;
  };
#else
  typedef struct ICertAdmin2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICertAdmin2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICertAdmin2 *This);
      ULONG (WINAPI *Release)(ICertAdmin2 *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ICertAdmin2 *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ICertAdmin2 *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ICertAdmin2 *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ICertAdmin2 *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *IsValidCertificate)(ICertAdmin2 *This,const BSTR strConfig,const BSTR strSerialNumber,LONG *pDisposition);
      HRESULT (WINAPI *GetRevocationReason)(ICertAdmin2 *This,LONG *pReason);
      HRESULT (WINAPI *RevokeCertificate)(ICertAdmin2 *This,const BSTR strConfig,const BSTR strSerialNumber,LONG Reason,DATE Date);
      HRESULT (WINAPI *SetRequestAttributes)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,const BSTR strAttributes);
      HRESULT (WINAPI *SetCertificateExtension)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,const BSTR strExtensionName,LONG Type,LONG Flags,const VARIANT *pvarValue);
      HRESULT (WINAPI *DenyRequest)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId);
      HRESULT (WINAPI *ResubmitRequest)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,LONG *pDisposition);
      HRESULT (WINAPI *PublishCRL)(ICertAdmin2 *This,const BSTR strConfig,DATE Date);
      HRESULT (WINAPI *GetCRL)(ICertAdmin2 *This,const BSTR strConfig,LONG Flags,BSTR *pstrCRL);
      HRESULT (WINAPI *ImportCertificate)(ICertAdmin2 *This,const BSTR strConfig,const BSTR strCertificate,LONG Flags,LONG *pRequestId);
      HRESULT (WINAPI *PublishCRLs)(ICertAdmin2 *This,const BSTR strConfig,DATE Date,LONG CRLFlags);
      HRESULT (WINAPI *GetCAProperty)(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *SetCAProperty)(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,VARIANT *pvarPropertyValue);
      HRESULT (WINAPI *GetCAPropertyFlags)(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG *pPropFlags);
      HRESULT (WINAPI *GetCAPropertyDisplayName)(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName);
      HRESULT (WINAPI *GetArchivedKey)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,LONG Flags,BSTR *pstrArchivedKey);
      HRESULT (WINAPI *GetConfigEntry)(ICertAdmin2 *This,const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry);
      HRESULT (WINAPI *SetConfigEntry)(ICertAdmin2 *This,const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry);
      HRESULT (WINAPI *ImportKey)(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,const BSTR strCertHash,LONG Flags,const BSTR strKey);
      HRESULT (WINAPI *GetMyRoles)(ICertAdmin2 *This,const BSTR strConfig,LONG *pRoles);
      HRESULT (WINAPI *DeleteRow)(ICertAdmin2 *This,const BSTR strConfig,LONG Flags,DATE Date,LONG Table,LONG RowId,LONG *pcDeleted);
    END_INTERFACE
  } ICertAdmin2Vtbl;
  struct ICertAdmin2 {
    CONST_VTBL struct ICertAdmin2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICertAdmin2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICertAdmin2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICertAdmin2_Release(This) (This)->lpVtbl->Release(This)
#define ICertAdmin2_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ICertAdmin2_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ICertAdmin2_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ICertAdmin2_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ICertAdmin2_IsValidCertificate(This,strConfig,strSerialNumber,pDisposition) (This)->lpVtbl->IsValidCertificate(This,strConfig,strSerialNumber,pDisposition)
#define ICertAdmin2_GetRevocationReason(This,pReason) (This)->lpVtbl->GetRevocationReason(This,pReason)
#define ICertAdmin2_RevokeCertificate(This,strConfig,strSerialNumber,Reason,Date) (This)->lpVtbl->RevokeCertificate(This,strConfig,strSerialNumber,Reason,Date)
#define ICertAdmin2_SetRequestAttributes(This,strConfig,RequestId,strAttributes) (This)->lpVtbl->SetRequestAttributes(This,strConfig,RequestId,strAttributes)
#define ICertAdmin2_SetCertificateExtension(This,strConfig,RequestId,strExtensionName,Type,Flags,pvarValue) (This)->lpVtbl->SetCertificateExtension(This,strConfig,RequestId,strExtensionName,Type,Flags,pvarValue)
#define ICertAdmin2_DenyRequest(This,strConfig,RequestId) (This)->lpVtbl->DenyRequest(This,strConfig,RequestId)
#define ICertAdmin2_ResubmitRequest(This,strConfig,RequestId,pDisposition) (This)->lpVtbl->ResubmitRequest(This,strConfig,RequestId,pDisposition)
#define ICertAdmin2_PublishCRL(This,strConfig,Date) (This)->lpVtbl->PublishCRL(This,strConfig,Date)
#define ICertAdmin2_GetCRL(This,strConfig,Flags,pstrCRL) (This)->lpVtbl->GetCRL(This,strConfig,Flags,pstrCRL)
#define ICertAdmin2_ImportCertificate(This,strConfig,strCertificate,Flags,pRequestId) (This)->lpVtbl->ImportCertificate(This,strConfig,strCertificate,Flags,pRequestId)
#define ICertAdmin2_PublishCRLs(This,strConfig,Date,CRLFlags) (This)->lpVtbl->PublishCRLs(This,strConfig,Date,CRLFlags)
#define ICertAdmin2_GetCAProperty(This,strConfig,PropId,PropIndex,PropType,Flags,pvarPropertyValue) (This)->lpVtbl->GetCAProperty(This,strConfig,PropId,PropIndex,PropType,Flags,pvarPropertyValue)
#define ICertAdmin2_SetCAProperty(This,strConfig,PropId,PropIndex,PropType,pvarPropertyValue) (This)->lpVtbl->SetCAProperty(This,strConfig,PropId,PropIndex,PropType,pvarPropertyValue)
#define ICertAdmin2_GetCAPropertyFlags(This,strConfig,PropId,pPropFlags) (This)->lpVtbl->GetCAPropertyFlags(This,strConfig,PropId,pPropFlags)
#define ICertAdmin2_GetCAPropertyDisplayName(This,strConfig,PropId,pstrDisplayName) (This)->lpVtbl->GetCAPropertyDisplayName(This,strConfig,PropId,pstrDisplayName)
#define ICertAdmin2_GetArchivedKey(This,strConfig,RequestId,Flags,pstrArchivedKey) (This)->lpVtbl->GetArchivedKey(This,strConfig,RequestId,Flags,pstrArchivedKey)
#define ICertAdmin2_GetConfigEntry(This,strConfig,strNodePath,strEntryName,pvarEntry) (This)->lpVtbl->GetConfigEntry(This,strConfig,strNodePath,strEntryName,pvarEntry)
#define ICertAdmin2_SetConfigEntry(This,strConfig,strNodePath,strEntryName,pvarEntry) (This)->lpVtbl->SetConfigEntry(This,strConfig,strNodePath,strEntryName,pvarEntry)
#define ICertAdmin2_ImportKey(This,strConfig,RequestId,strCertHash,Flags,strKey) (This)->lpVtbl->ImportKey(This,strConfig,RequestId,strCertHash,Flags,strKey)
#define ICertAdmin2_GetMyRoles(This,strConfig,pRoles) (This)->lpVtbl->GetMyRoles(This,strConfig,pRoles)
#define ICertAdmin2_DeleteRow(This,strConfig,Flags,Date,Table,RowId,pcDeleted) (This)->lpVtbl->DeleteRow(This,strConfig,Flags,Date,Table,RowId,pcDeleted)
#endif
#endif
  HRESULT WINAPI ICertAdmin2_PublishCRLs_Proxy(ICertAdmin2 *This,const BSTR strConfig,DATE Date,LONG CRLFlags);
  void __RPC_STUB ICertAdmin2_PublishCRLs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetCAProperty_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,LONG Flags,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertAdmin2_GetCAProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_SetCAProperty_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG PropIndex,LONG PropType,VARIANT *pvarPropertyValue);
  void __RPC_STUB ICertAdmin2_SetCAProperty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetCAPropertyFlags_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,LONG *pPropFlags);
  void __RPC_STUB ICertAdmin2_GetCAPropertyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetCAPropertyDisplayName_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG PropId,BSTR *pstrDisplayName);
  void __RPC_STUB ICertAdmin2_GetCAPropertyDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetArchivedKey_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,LONG Flags,BSTR *pstrArchivedKey);
  void __RPC_STUB ICertAdmin2_GetArchivedKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetConfigEntry_Proxy(ICertAdmin2 *This,const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry);
  void __RPC_STUB ICertAdmin2_GetConfigEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_SetConfigEntry_Proxy(ICertAdmin2 *This,const BSTR strConfig,const BSTR strNodePath,const BSTR strEntryName,VARIANT *pvarEntry);
  void __RPC_STUB ICertAdmin2_SetConfigEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_ImportKey_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG RequestId,const BSTR strCertHash,LONG Flags,const BSTR strKey);
  void __RPC_STUB ICertAdmin2_ImportKey_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_GetMyRoles_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG *pRoles);
  void __RPC_STUB ICertAdmin2_GetMyRoles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICertAdmin2_DeleteRow_Proxy(ICertAdmin2 *This,const BSTR strConfig,LONG Flags,DATE Date,LONG Table,LONG RowId,LONG *pcDeleted);
  void __RPC_STUB ICertAdmin2_DeleteRow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __CERTADMINLib_LIBRARY_DEFINED__
#define __CERTADMINLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_CERTADMINLib;
  EXTERN_C const CLSID CLSID_CCertAdmin;
#ifdef __cplusplus
  class CCertAdmin;
#endif
  EXTERN_C const CLSID CLSID_CCertView;
#ifdef __cplusplus
  class CCertView;
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
