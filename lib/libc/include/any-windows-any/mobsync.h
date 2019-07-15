/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 475
#endif

#include <_mingw_unicode.h>
#include "rpc.h"
#include "rpcndr.h"

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __mobsync_h__
#define __mobsync_h__

#ifndef __ISyncMgrSynchronize_FWD_DEFINED__
#define __ISyncMgrSynchronize_FWD_DEFINED__
typedef struct ISyncMgrSynchronize ISyncMgrSynchronize;
#endif

#ifndef __ISyncMgrSynchronizeCallback_FWD_DEFINED__
#define __ISyncMgrSynchronizeCallback_FWD_DEFINED__
typedef struct ISyncMgrSynchronizeCallback ISyncMgrSynchronizeCallback;
#endif

#ifndef __ISyncMgrEnumItems_FWD_DEFINED__
#define __ISyncMgrEnumItems_FWD_DEFINED__
typedef struct ISyncMgrEnumItems ISyncMgrEnumItems;
#endif

#ifndef __ISyncMgrSynchronizeInvoke_FWD_DEFINED__
#define __ISyncMgrSynchronizeInvoke_FWD_DEFINED__
typedef struct ISyncMgrSynchronizeInvoke ISyncMgrSynchronizeInvoke;
#endif

#ifndef __ISyncMgrRegister_FWD_DEFINED__
#define __ISyncMgrRegister_FWD_DEFINED__
typedef struct ISyncMgrRegister ISyncMgrRegister;
#endif

#ifndef __SyncMgr_FWD_DEFINED__
#define __SyncMgr_FWD_DEFINED__

#ifdef __cplusplus
typedef class SyncMgr SyncMgr;
#else
typedef struct SyncMgr SyncMgr;
#endif
#endif

#include "objidl.h"
#include "oleidl.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  typedef GUID SYNCMGRITEMID;
  typedef REFGUID REFSYNCMGRITEMID;
  typedef GUID SYNCMGRERRORID;
  typedef REFGUID REFSYNCMGRERRORID;

  DEFINE_GUID(CLSID_SyncMgr,0x6295df27,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
  DEFINE_GUID(IID_ISyncMgrSynchronize,0x6295df40,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
  DEFINE_GUID(IID_ISyncMgrSynchronizeCallback,0x6295df41,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
  DEFINE_GUID(IID_ISyncMgrRegister,0x6295df42,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
  DEFINE_GUID(IID_ISyncMgrEnumItems,0x6295df2a,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
  DEFINE_GUID(IID_ISyncMgrSynchronizeInvoke,0x6295df2c,0x35ee,0x11d1,0x87,0x7,0x0,0xc0,0x4f,0xd9,0x33,0x27);
#define S_SYNCMGR_MISSINGITEMS MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0201)
#define S_SYNCMGR_RETRYSYNC MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0202)
#define S_SYNCMGR_CANCELITEM MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0203)
#define S_SYNCMGR_CANCELALL MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0204)
#define S_SYNCMGR_ITEMDELETED MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0210)
#define S_SYNCMGR_ENUMITEMS MAKE_SCODE(SEVERITY_SUCCESS,FACILITY_ITF,0x0211)

  extern RPC_IF_HANDLE __MIDL_itf_mobsync_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mobsync_0000_v0_0_s_ifspec;

#ifndef __ISyncMgrSynchronize_INTERFACE_DEFINED__
#define __ISyncMgrSynchronize_INTERFACE_DEFINED__
  typedef ISyncMgrSynchronize *LPSYNCMGRSYNCHRONIZE;

  typedef enum _tagSYNCMGRFLAG {
    SYNCMGRFLAG_CONNECT = 0x1,SYNCMGRFLAG_PENDINGDISCONNECT = 0x2,SYNCMGRFLAG_MANUAL = 0x3,SYNCMGRFLAG_IDLE = 0x4,SYNCMGRFLAG_INVOKE = 0x5,
    SYNCMGRFLAG_SCHEDULED = 0x6,SYNCMGRFLAG_EVENTMASK = 0xff,SYNCMGRFLAG_SETTINGS = 0x100,SYNCMGRFLAG_MAYBOTHERUSER = 0x200
  } SYNCMGRFLAG;

#define MAX_SYNCMGRHANDLERNAME (32)
#define SYNCMGRHANDLERFLAG_MASK 0x07

  typedef enum _tagSYNCMGRHANDLERFLAGS {
    SYNCMGRHANDLER_HASPROPERTIES = 0x1,SYNCMGRHANDLER_MAYESTABLISHCONNECTION = 0x2,SYNCMGRHANDLER_ALWAYSLISTHANDLER = 0x4
  } SYNCMGRHANDLERFLAGS;

  typedef struct _tagSYNCMGRHANDLERINFO {
    DWORD cbSize;
    HICON hIcon;
    DWORD SyncMgrHandlerFlags;
    WCHAR wszHandlerName[32 ];
  } SYNCMGRHANDLERINFO;

  typedef struct _tagSYNCMGRHANDLERINFO *LPSYNCMGRHANDLERINFO;

#define SYNCMGRITEMSTATE_UNCHECKED 0x0000
#define SYNCMGRITEMSTATE_CHECKED 0x0001

  typedef enum _tagSYNCMGRSTATUS {
    SYNCMGRSTATUS_STOPPED = 0,SYNCMGRSTATUS_SKIPPED = 0x1,SYNCMGRSTATUS_PENDING = 0x2,SYNCMGRSTATUS_UPDATING = 0x3,SYNCMGRSTATUS_SUCCEEDED = 0x4,
    SYNCMGRSTATUS_FAILED = 0x5,SYNCMGRSTATUS_PAUSED = 0x6,SYNCMGRSTATUS_RESUMING = 0x7,SYNCMGRSTATUS_DELETED = 0x100
  } SYNCMGRSTATUS;

  EXTERN_C const IID IID_ISyncMgrSynchronize;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISyncMgrSynchronize : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(DWORD dwReserved,DWORD dwSyncMgrFlags,DWORD cbCookie,const BYTE *lpCookie) = 0;
    virtual HRESULT WINAPI GetHandlerInfo(LPSYNCMGRHANDLERINFO *ppSyncMgrHandlerInfo) = 0;
    virtual HRESULT WINAPI EnumSyncMgrItems(ISyncMgrEnumItems **ppSyncMgrEnumItems) = 0;
    virtual HRESULT WINAPI GetItemObject(REFSYNCMGRITEMID ItemID,REFIID riid,void **ppv) = 0;
    virtual HRESULT WINAPI ShowProperties(HWND hWndParent,REFSYNCMGRITEMID ItemID) = 0;
    virtual HRESULT WINAPI SetProgressCallback(ISyncMgrSynchronizeCallback *lpCallBack) = 0;
    virtual HRESULT WINAPI PrepareForSync(ULONG cbNumItems,SYNCMGRITEMID *pItemIDs,HWND hWndParent,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI Synchronize(HWND hWndParent) = 0;
    virtual HRESULT WINAPI SetItemStatus(REFSYNCMGRITEMID pItemID,DWORD dwSyncMgrStatus) = 0;
    virtual HRESULT WINAPI ShowError(HWND hWndParent,REFSYNCMGRERRORID ErrorID) = 0;
  };
#else
  typedef struct ISyncMgrSynchronizeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISyncMgrSynchronize *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISyncMgrSynchronize *This);
      ULONG (WINAPI *Release)(ISyncMgrSynchronize *This);
      HRESULT (WINAPI *Initialize)(ISyncMgrSynchronize *This,DWORD dwReserved,DWORD dwSyncMgrFlags,DWORD cbCookie,const BYTE *lpCookie);
      HRESULT (WINAPI *GetHandlerInfo)(ISyncMgrSynchronize *This,LPSYNCMGRHANDLERINFO *ppSyncMgrHandlerInfo);
      HRESULT (WINAPI *EnumSyncMgrItems)(ISyncMgrSynchronize *This,ISyncMgrEnumItems **ppSyncMgrEnumItems);
      HRESULT (WINAPI *GetItemObject)(ISyncMgrSynchronize *This,REFSYNCMGRITEMID ItemID,REFIID riid,void **ppv);
      HRESULT (WINAPI *ShowProperties)(ISyncMgrSynchronize *This,HWND hWndParent,REFSYNCMGRITEMID ItemID);
      HRESULT (WINAPI *SetProgressCallback)(ISyncMgrSynchronize *This,ISyncMgrSynchronizeCallback *lpCallBack);
      HRESULT (WINAPI *PrepareForSync)(ISyncMgrSynchronize *This,ULONG cbNumItems,SYNCMGRITEMID *pItemIDs,HWND hWndParent,DWORD dwReserved);
      HRESULT (WINAPI *Synchronize)(ISyncMgrSynchronize *This,HWND hWndParent);
      HRESULT (WINAPI *SetItemStatus)(ISyncMgrSynchronize *This,REFSYNCMGRITEMID pItemID,DWORD dwSyncMgrStatus);
      HRESULT (WINAPI *ShowError)(ISyncMgrSynchronize *This,HWND hWndParent,REFSYNCMGRERRORID ErrorID);
    END_INTERFACE
  } ISyncMgrSynchronizeVtbl;
  struct ISyncMgrSynchronize {
    CONST_VTBL struct ISyncMgrSynchronizeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISyncMgrSynchronize_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncMgrSynchronize_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncMgrSynchronize_Release(This) (This)->lpVtbl->Release(This)
#define ISyncMgrSynchronize_Initialize(This,dwReserved,dwSyncMgrFlags,cbCookie,lpCookie) (This)->lpVtbl->Initialize(This,dwReserved,dwSyncMgrFlags,cbCookie,lpCookie)
#define ISyncMgrSynchronize_GetHandlerInfo(This,ppSyncMgrHandlerInfo) (This)->lpVtbl->GetHandlerInfo(This,ppSyncMgrHandlerInfo)
#define ISyncMgrSynchronize_EnumSyncMgrItems(This,ppSyncMgrEnumItems) (This)->lpVtbl->EnumSyncMgrItems(This,ppSyncMgrEnumItems)
#define ISyncMgrSynchronize_GetItemObject(This,ItemID,riid,ppv) (This)->lpVtbl->GetItemObject(This,ItemID,riid,ppv)
#define ISyncMgrSynchronize_ShowProperties(This,hWndParent,ItemID) (This)->lpVtbl->ShowProperties(This,hWndParent,ItemID)
#define ISyncMgrSynchronize_SetProgressCallback(This,lpCallBack) (This)->lpVtbl->SetProgressCallback(This,lpCallBack)
#define ISyncMgrSynchronize_PrepareForSync(This,cbNumItems,pItemIDs,hWndParent,dwReserved) (This)->lpVtbl->PrepareForSync(This,cbNumItems,pItemIDs,hWndParent,dwReserved)
#define ISyncMgrSynchronize_Synchronize(This,hWndParent) (This)->lpVtbl->Synchronize(This,hWndParent)
#define ISyncMgrSynchronize_SetItemStatus(This,pItemID,dwSyncMgrStatus) (This)->lpVtbl->SetItemStatus(This,pItemID,dwSyncMgrStatus)
#define ISyncMgrSynchronize_ShowError(This,hWndParent,ErrorID) (This)->lpVtbl->ShowError(This,hWndParent,ErrorID)
#endif
#endif
  HRESULT WINAPI ISyncMgrSynchronize_Initialize_Proxy(ISyncMgrSynchronize *This,DWORD dwReserved,DWORD dwSyncMgrFlags,DWORD cbCookie,const BYTE *lpCookie);
  void __RPC_STUB ISyncMgrSynchronize_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_GetHandlerInfo_Proxy(ISyncMgrSynchronize *This,LPSYNCMGRHANDLERINFO *ppSyncMgrHandlerInfo);
  void __RPC_STUB ISyncMgrSynchronize_GetHandlerInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_EnumSyncMgrItems_Proxy(ISyncMgrSynchronize *This,ISyncMgrEnumItems **ppSyncMgrEnumItems);
  void __RPC_STUB ISyncMgrSynchronize_EnumSyncMgrItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_GetItemObject_Proxy(ISyncMgrSynchronize *This,REFSYNCMGRITEMID ItemID,REFIID riid,void **ppv);
  void __RPC_STUB ISyncMgrSynchronize_GetItemObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_ShowProperties_Proxy(ISyncMgrSynchronize *This,HWND hWndParent,REFSYNCMGRITEMID ItemID);
  void __RPC_STUB ISyncMgrSynchronize_ShowProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_SetProgressCallback_Proxy(ISyncMgrSynchronize *This,ISyncMgrSynchronizeCallback *lpCallBack);
  void __RPC_STUB ISyncMgrSynchronize_SetProgressCallback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_PrepareForSync_Proxy(ISyncMgrSynchronize *This,ULONG cbNumItems,SYNCMGRITEMID *pItemIDs,HWND hWndParent,DWORD dwReserved);
  void __RPC_STUB ISyncMgrSynchronize_PrepareForSync_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_Synchronize_Proxy(ISyncMgrSynchronize *This,HWND hWndParent);
  void __RPC_STUB ISyncMgrSynchronize_Synchronize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_SetItemStatus_Proxy(ISyncMgrSynchronize *This,REFSYNCMGRITEMID pItemID,DWORD dwSyncMgrStatus);
  void __RPC_STUB ISyncMgrSynchronize_SetItemStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronize_ShowError_Proxy(ISyncMgrSynchronize *This,HWND hWndParent,REFSYNCMGRERRORID ErrorID);
  void __RPC_STUB ISyncMgrSynchronize_ShowError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISyncMgrSynchronizeCallback_INTERFACE_DEFINED__
#define __ISyncMgrSynchronizeCallback_INTERFACE_DEFINED__
  typedef ISyncMgrSynchronizeCallback *LPSYNCMGRSYNCHRONIZECALLBACK;

#define SYNCMGRPROGRESSITEM_STATUSTEXT 0x0001
#define SYNCMGRPROGRESSITEM_STATUSTYPE 0x0002
#define SYNCMGRPROGRESSITEM_PROGVALUE 0x0004
#define SYNCMGRPROGRESSITEM_MAXVALUE 0x0008

  typedef struct _tagSYNCMGRPROGRESSITEM {
    DWORD cbSize;
    UINT mask;
    LPCWSTR lpcStatusText;
    DWORD dwStatusType;
    INT iProgValue;
    INT iMaxValue;
  } SYNCMGRPROGRESSITEM;

  typedef struct _tagSYNCMGRPROGRESSITEM *LPSYNCMGRPROGRESSITEM;

  typedef enum _tagSYNCMGRLOGLEVEL {
    SYNCMGRLOGLEVEL_INFORMATION = 0x1,SYNCMGRLOGLEVEL_WARNING = 0x2,SYNCMGRLOGLEVEL_ERROR = 0x3
  } SYNCMGRLOGLEVEL;

#define SYNCMGRLOGERROR_ERRORFLAGS 0x0001
#define SYNCMGRLOGERROR_ERRORID 0x0002
#define SYNCMGRLOGERROR_ITEMID 0x0004

  typedef enum _tagSYNCMGRERRORFLAGS {
    SYNCMGRERRORFLAG_ENABLEJUMPTEXT = 0x1
  } SYNCMGRERRORFLAGS;

  typedef struct _tagSYNCMGRLOGERRORINFO {
    DWORD cbSize;
    DWORD mask;
    DWORD dwSyncMgrErrorFlags;
    SYNCMGRERRORID ErrorID;
    SYNCMGRITEMID ItemID;
  } SYNCMGRLOGERRORINFO;

  typedef struct _tagSYNCMGRLOGERRORINFO *LPSYNCMGRLOGERRORINFO;

  EXTERN_C const IID IID_ISyncMgrSynchronizeCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISyncMgrSynchronizeCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI ShowPropertiesCompleted(HRESULT hr) = 0;
    virtual HRESULT WINAPI PrepareForSyncCompleted(HRESULT hr) = 0;
    virtual HRESULT WINAPI SynchronizeCompleted(HRESULT hr) = 0;
    virtual HRESULT WINAPI ShowErrorCompleted(HRESULT hr,ULONG cbNumItems,SYNCMGRITEMID *pItemIDs) = 0;
    virtual HRESULT WINAPI EnableModeless(WINBOOL fEnable) = 0;
    virtual HRESULT WINAPI Progress(REFSYNCMGRITEMID pItemID,LPSYNCMGRPROGRESSITEM lpSyncProgressItem) = 0;
    virtual HRESULT WINAPI LogError(DWORD dwErrorLevel,LPCWSTR lpcErrorText,LPSYNCMGRLOGERRORINFO lpSyncLogError) = 0;
    virtual HRESULT WINAPI DeleteLogError(REFSYNCMGRERRORID ErrorID,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI EstablishConnection(LPCWSTR lpwszConnection,DWORD dwReserved) = 0;
  };
#else
  typedef struct ISyncMgrSynchronizeCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISyncMgrSynchronizeCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISyncMgrSynchronizeCallback *This);
      ULONG (WINAPI *Release)(ISyncMgrSynchronizeCallback *This);
      HRESULT (WINAPI *ShowPropertiesCompleted)(ISyncMgrSynchronizeCallback *This,HRESULT hr);
      HRESULT (WINAPI *PrepareForSyncCompleted)(ISyncMgrSynchronizeCallback *This,HRESULT hr);
      HRESULT (WINAPI *SynchronizeCompleted)(ISyncMgrSynchronizeCallback *This,HRESULT hr);
      HRESULT (WINAPI *ShowErrorCompleted)(ISyncMgrSynchronizeCallback *This,HRESULT hr,ULONG cbNumItems,SYNCMGRITEMID *pItemIDs);
      HRESULT (WINAPI *EnableModeless)(ISyncMgrSynchronizeCallback *This,WINBOOL fEnable);
      HRESULT (WINAPI *Progress)(ISyncMgrSynchronizeCallback *This,REFSYNCMGRITEMID pItemID,LPSYNCMGRPROGRESSITEM lpSyncProgressItem);
      HRESULT (WINAPI *LogError)(ISyncMgrSynchronizeCallback *This,DWORD dwErrorLevel,LPCWSTR lpcErrorText,LPSYNCMGRLOGERRORINFO lpSyncLogError);
      HRESULT (WINAPI *DeleteLogError)(ISyncMgrSynchronizeCallback *This,REFSYNCMGRERRORID ErrorID,DWORD dwReserved);
      HRESULT (WINAPI *EstablishConnection)(ISyncMgrSynchronizeCallback *This,LPCWSTR lpwszConnection,DWORD dwReserved);
    END_INTERFACE
  } ISyncMgrSynchronizeCallbackVtbl;
  struct ISyncMgrSynchronizeCallback {
    CONST_VTBL struct ISyncMgrSynchronizeCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISyncMgrSynchronizeCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncMgrSynchronizeCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncMgrSynchronizeCallback_Release(This) (This)->lpVtbl->Release(This)
#define ISyncMgrSynchronizeCallback_ShowPropertiesCompleted(This,hr) (This)->lpVtbl->ShowPropertiesCompleted(This,hr)
#define ISyncMgrSynchronizeCallback_PrepareForSyncCompleted(This,hr) (This)->lpVtbl->PrepareForSyncCompleted(This,hr)
#define ISyncMgrSynchronizeCallback_SynchronizeCompleted(This,hr) (This)->lpVtbl->SynchronizeCompleted(This,hr)
#define ISyncMgrSynchronizeCallback_ShowErrorCompleted(This,hr,cbNumItems,pItemIDs) (This)->lpVtbl->ShowErrorCompleted(This,hr,cbNumItems,pItemIDs)
#define ISyncMgrSynchronizeCallback_EnableModeless(This,fEnable) (This)->lpVtbl->EnableModeless(This,fEnable)
#define ISyncMgrSynchronizeCallback_Progress(This,pItemID,lpSyncProgressItem) (This)->lpVtbl->Progress(This,pItemID,lpSyncProgressItem)
#define ISyncMgrSynchronizeCallback_LogError(This,dwErrorLevel,lpcErrorText,lpSyncLogError) (This)->lpVtbl->LogError(This,dwErrorLevel,lpcErrorText,lpSyncLogError)
#define ISyncMgrSynchronizeCallback_DeleteLogError(This,ErrorID,dwReserved) (This)->lpVtbl->DeleteLogError(This,ErrorID,dwReserved)
#define ISyncMgrSynchronizeCallback_EstablishConnection(This,lpwszConnection,dwReserved) (This)->lpVtbl->EstablishConnection(This,lpwszConnection,dwReserved)
#endif
#endif
  HRESULT WINAPI ISyncMgrSynchronizeCallback_ShowPropertiesCompleted_Proxy(ISyncMgrSynchronizeCallback *This,HRESULT hr);
  void __RPC_STUB ISyncMgrSynchronizeCallback_ShowPropertiesCompleted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_PrepareForSyncCompleted_Proxy(ISyncMgrSynchronizeCallback *This,HRESULT hr);
  void __RPC_STUB ISyncMgrSynchronizeCallback_PrepareForSyncCompleted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_SynchronizeCompleted_Proxy(ISyncMgrSynchronizeCallback *This,HRESULT hr);
  void __RPC_STUB ISyncMgrSynchronizeCallback_SynchronizeCompleted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_ShowErrorCompleted_Proxy(ISyncMgrSynchronizeCallback *This,HRESULT hr,ULONG cbNumItems,SYNCMGRITEMID *pItemIDs);
  void __RPC_STUB ISyncMgrSynchronizeCallback_ShowErrorCompleted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_EnableModeless_Proxy(ISyncMgrSynchronizeCallback *This,WINBOOL fEnable);
  void __RPC_STUB ISyncMgrSynchronizeCallback_EnableModeless_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_Progress_Proxy(ISyncMgrSynchronizeCallback *This,REFSYNCMGRITEMID pItemID,LPSYNCMGRPROGRESSITEM lpSyncProgressItem);
  void __RPC_STUB ISyncMgrSynchronizeCallback_Progress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_LogError_Proxy(ISyncMgrSynchronizeCallback *This,DWORD dwErrorLevel,LPCWSTR lpcErrorText,LPSYNCMGRLOGERRORINFO lpSyncLogError);
  void __RPC_STUB ISyncMgrSynchronizeCallback_LogError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_DeleteLogError_Proxy(ISyncMgrSynchronizeCallback *This,REFSYNCMGRERRORID ErrorID,DWORD dwReserved);
  void __RPC_STUB ISyncMgrSynchronizeCallback_DeleteLogError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeCallback_EstablishConnection_Proxy(ISyncMgrSynchronizeCallback *This,LPCWSTR lpwszConnection,DWORD dwReserved);
  void __RPC_STUB ISyncMgrSynchronizeCallback_EstablishConnection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISyncMgrEnumItems_INTERFACE_DEFINED__
#define __ISyncMgrEnumItems_INTERFACE_DEFINED__
  typedef ISyncMgrEnumItems *LPSYNCMGRENUMITEMS;

#define SYNCMGRITEM_ITEMFLAGMASK 0x1F
#define MAX_SYNCMGRITEMNAME (128)

  typedef enum _tagSYNCMGRITEMFLAGS {
    SYNCMGRITEM_HASPROPERTIES = 0x1,SYNCMGRITEM_TEMPORARY = 0x2,SYNCMGRITEM_ROAMINGUSER = 0x4,SYNCMGRITEM_LASTUPDATETIME = 0x8,
    SYNCMGRITEM_MAYDELETEITEM = 0x10
  } SYNCMGRITEMFLAGS;

  typedef struct _tagSYNCMGRITEM {
    DWORD cbSize;
    DWORD dwFlags;
    SYNCMGRITEMID ItemID;
    DWORD dwItemState;
    HICON hIcon;
    WCHAR wszItemName[128 ];
    FILETIME ftLastUpdate;
  } SYNCMGRITEM;

  typedef struct _tagSYNCMGRITEM *LPSYNCMGRITEM;

  EXTERN_C const IID IID_ISyncMgrEnumItems;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISyncMgrEnumItems : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,LPSYNCMGRITEM rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(ISyncMgrEnumItems **ppenum) = 0;
  };
#else
  typedef struct ISyncMgrEnumItemsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISyncMgrEnumItems *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISyncMgrEnumItems *This);
      ULONG (WINAPI *Release)(ISyncMgrEnumItems *This);
      HRESULT (WINAPI *Next)(ISyncMgrEnumItems *This,ULONG celt,LPSYNCMGRITEM rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(ISyncMgrEnumItems *This,ULONG celt);
      HRESULT (WINAPI *Reset)(ISyncMgrEnumItems *This);
      HRESULT (WINAPI *Clone)(ISyncMgrEnumItems *This,ISyncMgrEnumItems **ppenum);
    END_INTERFACE
  } ISyncMgrEnumItemsVtbl;
  struct ISyncMgrEnumItems {
    CONST_VTBL struct ISyncMgrEnumItemsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISyncMgrEnumItems_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncMgrEnumItems_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncMgrEnumItems_Release(This) (This)->lpVtbl->Release(This)
#define ISyncMgrEnumItems_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define ISyncMgrEnumItems_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define ISyncMgrEnumItems_Reset(This) (This)->lpVtbl->Reset(This)
#define ISyncMgrEnumItems_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#endif
#endif
  HRESULT WINAPI ISyncMgrEnumItems_Next_Proxy(ISyncMgrEnumItems *This,ULONG celt,LPSYNCMGRITEM rgelt,ULONG *pceltFetched);
  void __RPC_STUB ISyncMgrEnumItems_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrEnumItems_Skip_Proxy(ISyncMgrEnumItems *This,ULONG celt);
  void __RPC_STUB ISyncMgrEnumItems_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrEnumItems_Reset_Proxy(ISyncMgrEnumItems *This);
  void __RPC_STUB ISyncMgrEnumItems_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrEnumItems_Clone_Proxy(ISyncMgrEnumItems *This,ISyncMgrEnumItems **ppenum);
  void __RPC_STUB ISyncMgrEnumItems_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISyncMgrSynchronizeInvoke_INTERFACE_DEFINED__
#define __ISyncMgrSynchronizeInvoke_INTERFACE_DEFINED__
  typedef ISyncMgrSynchronizeInvoke *LPSYNCMGRSYNCHRONIZEINVOKE;

  typedef enum _tagSYNCMGRINVOKEFLAGS {
    SYNCMGRINVOKE_STARTSYNC = 0x2,SYNCMGRINVOKE_MINIMIZED = 0x4
  } SYNCMGRINVOKEFLAGS;

  EXTERN_C const IID IID_ISyncMgrSynchronizeInvoke;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISyncMgrSynchronizeInvoke : public IUnknown {
  public:
    virtual HRESULT WINAPI UpdateItems(DWORD dwInvokeFlags,REFCLSID rclsid,DWORD cbCookie,const BYTE *lpCookie) = 0;
    virtual HRESULT WINAPI UpdateAll(void) = 0;
  };
#else
  typedef struct ISyncMgrSynchronizeInvokeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISyncMgrSynchronizeInvoke *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISyncMgrSynchronizeInvoke *This);
      ULONG (WINAPI *Release)(ISyncMgrSynchronizeInvoke *This);
      HRESULT (WINAPI *UpdateItems)(ISyncMgrSynchronizeInvoke *This,DWORD dwInvokeFlags,REFCLSID rclsid,DWORD cbCookie,const BYTE *lpCookie);
      HRESULT (WINAPI *UpdateAll)(ISyncMgrSynchronizeInvoke *This);
    END_INTERFACE
  } ISyncMgrSynchronizeInvokeVtbl;
  struct ISyncMgrSynchronizeInvoke {
    CONST_VTBL struct ISyncMgrSynchronizeInvokeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISyncMgrSynchronizeInvoke_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncMgrSynchronizeInvoke_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncMgrSynchronizeInvoke_Release(This) (This)->lpVtbl->Release(This)
#define ISyncMgrSynchronizeInvoke_UpdateItems(This,dwInvokeFlags,rclsid,cbCookie,lpCookie) (This)->lpVtbl->UpdateItems(This,dwInvokeFlags,rclsid,cbCookie,lpCookie)
#define ISyncMgrSynchronizeInvoke_UpdateAll(This) (This)->lpVtbl->UpdateAll(This)
#endif
#endif
  HRESULT WINAPI ISyncMgrSynchronizeInvoke_UpdateItems_Proxy(ISyncMgrSynchronizeInvoke *This,DWORD dwInvokeFlags,REFCLSID rclsid,DWORD cbCookie,const BYTE *lpCookie);
  void __RPC_STUB ISyncMgrSynchronizeInvoke_UpdateItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrSynchronizeInvoke_UpdateAll_Proxy(ISyncMgrSynchronizeInvoke *This);
  void __RPC_STUB ISyncMgrSynchronizeInvoke_UpdateAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISyncMgrRegister_INTERFACE_DEFINED__
#define __ISyncMgrRegister_INTERFACE_DEFINED__
  typedef ISyncMgrRegister *LPSYNCMGRREGISTER;

#define SYNCMGRREGISTERFLAGS_MASK 0x07

  typedef enum _tagSYNCMGRREGISTERFLAGS {
    SYNCMGRREGISTERFLAG_CONNECT = 0x1,SYNCMGRREGISTERFLAG_PENDINGDISCONNECT = 0x2,SYNCMGRREGISTERFLAG_IDLE = 0x4
  } SYNCMGRREGISTERFLAGS;

  EXTERN_C const IID IID_ISyncMgrRegister;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISyncMgrRegister : public IUnknown {
  public:
    virtual HRESULT WINAPI RegisterSyncMgrHandler(REFCLSID rclsidHandler,LPCWSTR pwszDescription,DWORD dwSyncMgrRegisterFlags) = 0;
    virtual HRESULT WINAPI UnregisterSyncMgrHandler(REFCLSID rclsidHandler,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI GetHandlerRegistrationInfo(REFCLSID rclsidHandler,LPDWORD pdwSyncMgrRegisterFlags) = 0;
  };
#else
  typedef struct ISyncMgrRegisterVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISyncMgrRegister *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISyncMgrRegister *This);
      ULONG (WINAPI *Release)(ISyncMgrRegister *This);
      HRESULT (WINAPI *RegisterSyncMgrHandler)(ISyncMgrRegister *This,REFCLSID rclsidHandler,LPCWSTR pwszDescription,DWORD dwSyncMgrRegisterFlags);
      HRESULT (WINAPI *UnregisterSyncMgrHandler)(ISyncMgrRegister *This,REFCLSID rclsidHandler,DWORD dwReserved);
      HRESULT (WINAPI *GetHandlerRegistrationInfo)(ISyncMgrRegister *This,REFCLSID rclsidHandler,LPDWORD pdwSyncMgrRegisterFlags);
    END_INTERFACE
  } ISyncMgrRegisterVtbl;
  struct ISyncMgrRegister {
    CONST_VTBL struct ISyncMgrRegisterVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISyncMgrRegister_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISyncMgrRegister_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISyncMgrRegister_Release(This) (This)->lpVtbl->Release(This)
#define ISyncMgrRegister_RegisterSyncMgrHandler(This,rclsidHandler,pwszDescription,dwSyncMgrRegisterFlags) (This)->lpVtbl->RegisterSyncMgrHandler(This,rclsidHandler,pwszDescription,dwSyncMgrRegisterFlags)
#define ISyncMgrRegister_UnregisterSyncMgrHandler(This,rclsidHandler,dwReserved) (This)->lpVtbl->UnregisterSyncMgrHandler(This,rclsidHandler,dwReserved)
#define ISyncMgrRegister_GetHandlerRegistrationInfo(This,rclsidHandler,pdwSyncMgrRegisterFlags) (This)->lpVtbl->GetHandlerRegistrationInfo(This,rclsidHandler,pdwSyncMgrRegisterFlags)
#endif
#endif
  HRESULT WINAPI ISyncMgrRegister_RegisterSyncMgrHandler_Proxy(ISyncMgrRegister *This,REFCLSID rclsidHandler,LPCWSTR pwszDescription,DWORD dwSyncMgrRegisterFlags);
  void __RPC_STUB ISyncMgrRegister_RegisterSyncMgrHandler_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrRegister_UnregisterSyncMgrHandler_Proxy(ISyncMgrRegister *This,REFCLSID rclsidHandler,DWORD dwReserved);
  void __RPC_STUB ISyncMgrRegister_UnregisterSyncMgrHandler_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISyncMgrRegister_GetHandlerRegistrationInfo_Proxy(ISyncMgrRegister *This,REFCLSID rclsidHandler,LPDWORD pdwSyncMgrRegisterFlags);
  void __RPC_STUB ISyncMgrRegister_GetHandlerRegistrationInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define RFCF_APPLY_ALL 0x0001

#define RFCD_NAME 0x0001
#define RFCD_KEEPBOTHICON 0x0002
#define RFCD_KEEPLOCALICON 0x0004
#define RFCD_KEEPSERVERICON 0x0008
#define RFCD_NETWORKMODIFIEDBY 0x0010
#define RFCD_NETWORKMODIFIEDON 0x0020
#define RFCD_LOCALMODIFIEDBY 0x0040
#define RFCD_LOCALMODIFIEDON 0x0080
#define RFCD_NEWNAME 0x0100
#define RFCD_LOCATION 0x0200
#define RFCD_ALL 0x03FF

#define RFCCM_VIEWLOCAL 0x0001
#define RFCCM_VIEWNETWORK 0x0002
#define RFCCM_NEEDELEMENT 0x0003

#define RFC_CANCEL 0x00
#define RFC_KEEPBOTH 0x01
#define RFC_KEEPLOCAL 0x02
#define RFC_KEEPNETWORK 0x03
#define RFC_APPLY_TO_ALL 0x10

  typedef WINBOOL (WINAPI *PFNRFCDCALLBACK)(HWND hWnd,UINT uMsg,WPARAM wParam,LPARAM lParam);

  typedef struct tagRFCDLGPARAMW {
    DWORD dwFlags;
    LPCWSTR pszFilename;
    LPCWSTR pszLocation;
    LPCWSTR pszNewName;
    LPCWSTR pszNetworkModifiedBy;
    LPCWSTR pszLocalModifiedBy;
    LPCWSTR pszNetworkModifiedOn;
    LPCWSTR pszLocalModifiedOn;
    HICON hIKeepBoth;
    HICON hIKeepLocal;
    HICON hIKeepNetwork;
    PFNRFCDCALLBACK pfnCallBack;
    LPARAM lCallerData;
  } RFCDLGPARAMW;

  typedef struct tagRFCDLGPARAMA {
    DWORD dwFlags;
    LPCSTR pszFilename;
    LPCSTR pszLocation;
    LPCSTR pszNewName;
    LPCSTR pszNetworkModifiedBy;
    LPCSTR pszLocalModifiedBy;
    LPCSTR pszNetworkModifiedOn;
    LPCSTR pszLocalModifiedOn;
    HICON hIKeepBoth;
    HICON hIKeepLocal;
    HICON hIKeepNetwork;
    PFNRFCDCALLBACK pfnCallBack;
    LPARAM lCallerData;
  } RFCDLGPARAMA;

  int WINAPI SyncMgrResolveConflictW(HWND hWndParent,RFCDLGPARAMW *pdlgParam);
  int WINAPI SyncMgrResolveConflictA(HWND hWndParent,RFCDLGPARAMA *pdlgParam);

#define SyncMgrResolveConflict __MINGW_NAME_AW(SyncMgrResolveConflict)
#define RFCDLGPARAM __MINGW_NAME_AW(RFCDLGPARAM)

  extern RPC_IF_HANDLE __MIDL_itf_mobsync_0122_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mobsync_0122_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
