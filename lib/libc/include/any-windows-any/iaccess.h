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

#ifndef __iaccess_h__
#define __iaccess_h__

#ifndef __IAccessControl_FWD_DEFINED__
#define __IAccessControl_FWD_DEFINED__
typedef struct IAccessControl IAccessControl;
#endif

#ifndef __IAuditControl_FWD_DEFINED__
#define __IAuditControl_FWD_DEFINED__
typedef struct IAuditControl IAuditControl;
#endif

#include "unknwn.h"
#include "accctrl.h"
#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef PACTRL_ACCESSW PACTRL_ACCESSW_ALLOCATE_ALL_NODES;
  typedef PACTRL_AUDITW PACTRL_AUDITW_ALLOCATE_ALL_NODES;

  extern RPC_IF_HANDLE __MIDL_itf_iaccess_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iaccess_0000_v0_0_s_ifspec;

#ifndef __IAccessControl_INTERFACE_DEFINED__
#define __IAccessControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAccessControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAccessControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GrantAccessRights(PACTRL_ACCESSW pAccessList) = 0;
    virtual HRESULT WINAPI SetAccessRights(PACTRL_ACCESSW pAccessList) = 0;
    virtual HRESULT WINAPI SetOwner(PTRUSTEEW pOwner,PTRUSTEEW pGroup) = 0;
    virtual HRESULT WINAPI RevokeAccessRights(LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]) = 0;
    virtual HRESULT WINAPI GetAllAccessRights(LPWSTR lpProperty,PACTRL_ACCESSW_ALLOCATE_ALL_NODES *ppAccessList,PTRUSTEEW *ppOwner,PTRUSTEEW *ppGroup) = 0;
    virtual HRESULT WINAPI IsAccessAllowed(PTRUSTEEW pTrustee,LPWSTR lpProperty,ACCESS_RIGHTS AccessRights,WINBOOL *pfAccessAllowed) = 0;
  };
#else
  typedef struct IAccessControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAccessControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAccessControl *This);
      ULONG (WINAPI *Release)(IAccessControl *This);
      HRESULT (WINAPI *GrantAccessRights)(IAccessControl *This,PACTRL_ACCESSW pAccessList);
      HRESULT (WINAPI *SetAccessRights)(IAccessControl *This,PACTRL_ACCESSW pAccessList);
      HRESULT (WINAPI *SetOwner)(IAccessControl *This,PTRUSTEEW pOwner,PTRUSTEEW pGroup);
      HRESULT (WINAPI *RevokeAccessRights)(IAccessControl *This,LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]);
      HRESULT (WINAPI *GetAllAccessRights)(IAccessControl *This,LPWSTR lpProperty,PACTRL_ACCESSW_ALLOCATE_ALL_NODES *ppAccessList,PTRUSTEEW *ppOwner,PTRUSTEEW *ppGroup);
      HRESULT (WINAPI *IsAccessAllowed)(IAccessControl *This,PTRUSTEEW pTrustee,LPWSTR lpProperty,ACCESS_RIGHTS AccessRights,WINBOOL *pfAccessAllowed);
    END_INTERFACE
  } IAccessControlVtbl;
  struct IAccessControl {
    CONST_VTBL struct IAccessControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAccessControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAccessControl_AddRef(This) (This)->lpVtbl->AddRef(This)

#define IAccessControl_Release(This) (This)->lpVtbl->Release(This)
#define IAccessControl_GrantAccessRights(This,pAccessList) (This)->lpVtbl->GrantAccessRights(This,pAccessList)
#define IAccessControl_SetAccessRights(This,pAccessList) (This)->lpVtbl->SetAccessRights(This,pAccessList)
#define IAccessControl_SetOwner(This,pOwner,pGroup) (This)->lpVtbl->SetOwner(This,pOwner,pGroup)
#define IAccessControl_RevokeAccessRights(This,lpProperty,cTrustees,prgTrustees) (This)->lpVtbl->RevokeAccessRights(This,lpProperty,cTrustees,prgTrustees)
#define IAccessControl_GetAllAccessRights(This,lpProperty,ppAccessList,ppOwner,ppGroup) (This)->lpVtbl->GetAllAccessRights(This,lpProperty,ppAccessList,ppOwner,ppGroup)
#define IAccessControl_IsAccessAllowed(This,pTrustee,lpProperty,AccessRights,pfAccessAllowed) (This)->lpVtbl->IsAccessAllowed(This,pTrustee,lpProperty,AccessRights,pfAccessAllowed)
#endif
#endif
  HRESULT WINAPI IAccessControl_GrantAccessRights_Proxy(IAccessControl *This,PACTRL_ACCESSW pAccessList);
  void __RPC_STUB IAccessControl_GrantAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessControl_SetAccessRights_Proxy(IAccessControl *This,PACTRL_ACCESSW pAccessList);
  void __RPC_STUB IAccessControl_SetAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessControl_SetOwner_Proxy(IAccessControl *This,PTRUSTEEW pOwner,PTRUSTEEW pGroup);
  void __RPC_STUB IAccessControl_SetOwner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessControl_RevokeAccessRights_Proxy(IAccessControl *This,LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]);
  void __RPC_STUB IAccessControl_RevokeAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessControl_GetAllAccessRights_Proxy(IAccessControl *This,LPWSTR lpProperty,PACTRL_ACCESSW_ALLOCATE_ALL_NODES *ppAccessList,PTRUSTEEW *ppOwner,PTRUSTEEW *ppGroup);
  void __RPC_STUB IAccessControl_GetAllAccessRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAccessControl_IsAccessAllowed_Proxy(IAccessControl *This,PTRUSTEEW pTrustee,LPWSTR lpProperty,ACCESS_RIGHTS AccessRights,WINBOOL *pfAccessAllowed);
  void __RPC_STUB IAccessControl_IsAccessAllowed_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_iaccess_0010_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_iaccess_0010_v0_0_s_ifspec;

#ifndef __IAuditControl_INTERFACE_DEFINED__
#define __IAuditControl_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IAuditControl;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IAuditControl : public IUnknown {
  public:
    virtual HRESULT WINAPI GrantAuditRights(PACTRL_AUDITW pAuditList) = 0;
    virtual HRESULT WINAPI SetAuditRights(PACTRL_AUDITW pAuditList) = 0;
    virtual HRESULT WINAPI RevokeAuditRights(LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]) = 0;
    virtual HRESULT WINAPI GetAllAuditRights(LPWSTR lpProperty,PACTRL_AUDITW *ppAuditList) = 0;
    virtual HRESULT WINAPI IsAccessAudited(PTRUSTEEW pTrustee,ACCESS_RIGHTS AuditRights,WINBOOL *pfAccessAudited) = 0;
  };
#else
  typedef struct IAuditControlVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IAuditControl *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IAuditControl *This);
      ULONG (WINAPI *Release)(IAuditControl *This);
      HRESULT (WINAPI *GrantAuditRights)(IAuditControl *This,PACTRL_AUDITW pAuditList);
      HRESULT (WINAPI *SetAuditRights)(IAuditControl *This,PACTRL_AUDITW pAuditList);
      HRESULT (WINAPI *RevokeAuditRights)(IAuditControl *This,LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]);
      HRESULT (WINAPI *GetAllAuditRights)(IAuditControl *This,LPWSTR lpProperty,PACTRL_AUDITW *ppAuditList);
      HRESULT (WINAPI *IsAccessAudited)(IAuditControl *This,PTRUSTEEW pTrustee,ACCESS_RIGHTS AuditRights,WINBOOL *pfAccessAudited);
    END_INTERFACE
  } IAuditControlVtbl;
  struct IAuditControl {
    CONST_VTBL struct IAuditControlVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IAuditControl_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IAuditControl_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IAuditControl_Release(This) (This)->lpVtbl->Release(This)
#define IAuditControl_GrantAuditRights(This,pAuditList) (This)->lpVtbl->GrantAuditRights(This,pAuditList)
#define IAuditControl_SetAuditRights(This,pAuditList) (This)->lpVtbl->SetAuditRights(This,pAuditList)
#define IAuditControl_RevokeAuditRights(This,lpProperty,cTrustees,prgTrustees) (This)->lpVtbl->RevokeAuditRights(This,lpProperty,cTrustees,prgTrustees)
#define IAuditControl_GetAllAuditRights(This,lpProperty,ppAuditList) (This)->lpVtbl->GetAllAuditRights(This,lpProperty,ppAuditList)
#define IAuditControl_IsAccessAudited(This,pTrustee,AuditRights,pfAccessAudited) (This)->lpVtbl->IsAccessAudited(This,pTrustee,AuditRights,pfAccessAudited)
#endif
#endif
  HRESULT WINAPI IAuditControl_GrantAuditRights_Proxy(IAuditControl *This,PACTRL_AUDITW pAuditList);
  void __RPC_STUB IAuditControl_GrantAuditRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuditControl_SetAuditRights_Proxy(IAuditControl *This,PACTRL_AUDITW pAuditList);
  void __RPC_STUB IAuditControl_SetAuditRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuditControl_RevokeAuditRights_Proxy(IAuditControl *This,LPWSTR lpProperty,ULONG cTrustees,TRUSTEEW prgTrustees[]);
  void __RPC_STUB IAuditControl_RevokeAuditRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuditControl_GetAllAuditRights_Proxy(IAuditControl *This,LPWSTR lpProperty,PACTRL_AUDITW *ppAuditList);
  void __RPC_STUB IAuditControl_GetAllAuditRights_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IAuditControl_IsAccessAudited_Proxy(IAuditControl *This,PTRUSTEEW pTrustee,ACCESS_RIGHTS AuditRights,WINBOOL *pfAccessAudited);
  void __RPC_STUB IAuditControl_IsAccessAudited_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
