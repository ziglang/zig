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

#ifndef __qmgr_h__
#define __qmgr_h__

#ifndef __IBackgroundCopyJob1_FWD_DEFINED__
#define __IBackgroundCopyJob1_FWD_DEFINED__
typedef struct IBackgroundCopyJob1 IBackgroundCopyJob1;
#endif

#ifndef __IEnumBackgroundCopyJobs1_FWD_DEFINED__
#define __IEnumBackgroundCopyJobs1_FWD_DEFINED__
typedef struct IEnumBackgroundCopyJobs1 IEnumBackgroundCopyJobs1;
#endif

#ifndef __IBackgroundCopyGroup_FWD_DEFINED__
#define __IBackgroundCopyGroup_FWD_DEFINED__
typedef struct IBackgroundCopyGroup IBackgroundCopyGroup;
#endif

#ifndef __IEnumBackgroundCopyGroups_FWD_DEFINED__
#define __IEnumBackgroundCopyGroups_FWD_DEFINED__
typedef struct IEnumBackgroundCopyGroups IEnumBackgroundCopyGroups;
#endif

#ifndef __IBackgroundCopyCallback1_FWD_DEFINED__
#define __IBackgroundCopyCallback1_FWD_DEFINED__
typedef struct IBackgroundCopyCallback1 IBackgroundCopyCallback1;
#endif

#ifndef __IBackgroundCopyQMgr_FWD_DEFINED__
#define __IBackgroundCopyQMgr_FWD_DEFINED__
typedef struct IBackgroundCopyQMgr IBackgroundCopyQMgr;
#endif

#ifndef __BackgroundCopyQMgr_FWD_DEFINED__
#define __BackgroundCopyQMgr_FWD_DEFINED__
#ifdef __cplusplus
typedef class BackgroundCopyQMgr BackgroundCopyQMgr;
#else
typedef struct BackgroundCopyQMgr BackgroundCopyQMgr;
#endif
#endif

#include "unknwn.h"
#include "ocidl.h"
#include "docobj.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define QM_NOTIFY_FILE_DONE 0x00000001
#define QM_NOTIFY_JOB_DONE 0x00000002
#define QM_NOTIFY_GROUP_DONE 0x00000004
#define QM_NOTIFY_DISABLE_NOTIFY 0x00000040
#define QM_NOTIFY_USE_PROGRESSEX 0x00000080
#define QM_STATUS_FILE_COMPLETE 0x00000001
#define QM_STATUS_FILE_INCOMPLETE 0x00000002
#define QM_STATUS_JOB_COMPLETE 0x00000004
#define QM_STATUS_JOB_INCOMPLETE 0x00000008
#define QM_STATUS_JOB_ERROR 0x00000010
#define QM_STATUS_JOB_FOREGROUND 0x00000020
#define QM_STATUS_GROUP_COMPLETE 0x00000040
#define QM_STATUS_GROUP_INCOMPLETE 0x00000080
#define QM_STATUS_GROUP_SUSPENDED 0x00000100
#define QM_STATUS_GROUP_ERROR 0x00000200
#define QM_STATUS_GROUP_FOREGROUND 0x00000400
#define QM_PROTOCOL_HTTP 1
#define QM_PROTOCOL_FTP 2
#define QM_PROTOCOL_SMB 3
#define QM_PROTOCOL_CUSTOM 4
#define QM_PROGRESS_PERCENT_DONE 1
#define QM_PROGRESS_TIME_DONE 2
#define QM_PROGRESS_SIZE_DONE 3
#define QM_E_INVALID_STATE 0x81001001
#define QM_E_SERVICE_UNAVAILABLE 0x81001002
#define QM_E_DOWNLOADER_UNAVAILABLE 0x81001003
#define QM_E_ITEM_NOT_FOUND 0x81001004

  extern RPC_IF_HANDLE __MIDL_itf_qmgr_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_qmgr_0000_v0_0_s_ifspec;

#ifndef __IBackgroundCopyJob1_INTERFACE_DEFINED__
#define __IBackgroundCopyJob1_INTERFACE_DEFINED__

  typedef struct _FILESETINFO {
    BSTR bstrRemoteFile;
    BSTR bstrLocalFile;
    DWORD dwSizeHint;
  } FILESETINFO;

  EXTERN_C const IID IID_IBackgroundCopyJob1;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyJob1 : public IUnknown {
  public:
    virtual HRESULT WINAPI CancelJob(void) = 0;
    virtual HRESULT WINAPI GetProgress(DWORD dwFlags,DWORD *pdwProgress) = 0;
    virtual HRESULT WINAPI GetStatus(DWORD *pdwStatus,DWORD *pdwWin32Result,DWORD *pdwTransportResult,DWORD *pdwNumOfRetries) = 0;
    virtual HRESULT WINAPI AddFiles(ULONG cFileCount,FILESETINFO **ppFileSet) = 0;
    virtual HRESULT WINAPI GetFile(ULONG cFileIndex,FILESETINFO *pFileInfo) = 0;
    virtual HRESULT WINAPI GetFileCount(DWORD *pdwFileCount) = 0;
    virtual HRESULT WINAPI SwitchToForeground(void) = 0;
    virtual HRESULT WINAPI get_JobID(GUID *pguidJobID) = 0;
  };
#else
  typedef struct IBackgroundCopyJob1Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyJob1 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyJob1 *This);
      ULONG (WINAPI *Release)(IBackgroundCopyJob1 *This);
      HRESULT (WINAPI *CancelJob)(IBackgroundCopyJob1 *This);
      HRESULT (WINAPI *GetProgress)(IBackgroundCopyJob1 *This,DWORD dwFlags,DWORD *pdwProgress);
      HRESULT (WINAPI *GetStatus)(IBackgroundCopyJob1 *This,DWORD *pdwStatus,DWORD *pdwWin32Result,DWORD *pdwTransportResult,DWORD *pdwNumOfRetries);
      HRESULT (WINAPI *AddFiles)(IBackgroundCopyJob1 *This,ULONG cFileCount,FILESETINFO **ppFileSet);
      HRESULT (WINAPI *GetFile)(IBackgroundCopyJob1 *This,ULONG cFileIndex,FILESETINFO *pFileInfo);
      HRESULT (WINAPI *GetFileCount)(IBackgroundCopyJob1 *This,DWORD *pdwFileCount);
      HRESULT (WINAPI *SwitchToForeground)(IBackgroundCopyJob1 *This);
      HRESULT (WINAPI *get_JobID)(IBackgroundCopyJob1 *This,GUID *pguidJobID);
    END_INTERFACE
  } IBackgroundCopyJob1Vtbl;
  struct IBackgroundCopyJob1 {
    CONST_VTBL struct IBackgroundCopyJob1Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyJob1_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyJob1_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyJob1_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyJob1_CancelJob(This) (This)->lpVtbl->CancelJob(This)
#define IBackgroundCopyJob1_GetProgress(This,dwFlags,pdwProgress) (This)->lpVtbl->GetProgress(This,dwFlags,pdwProgress)
#define IBackgroundCopyJob1_GetStatus(This,pdwStatus,pdwWin32Result,pdwTransportResult,pdwNumOfRetries) (This)->lpVtbl->GetStatus(This,pdwStatus,pdwWin32Result,pdwTransportResult,pdwNumOfRetries)
#define IBackgroundCopyJob1_AddFiles(This,cFileCount,ppFileSet) (This)->lpVtbl->AddFiles(This,cFileCount,ppFileSet)
#define IBackgroundCopyJob1_GetFile(This,cFileIndex,pFileInfo) (This)->lpVtbl->GetFile(This,cFileIndex,pFileInfo)
#define IBackgroundCopyJob1_GetFileCount(This,pdwFileCount) (This)->lpVtbl->GetFileCount(This,pdwFileCount)
#define IBackgroundCopyJob1_SwitchToForeground(This) (This)->lpVtbl->SwitchToForeground(This)
#define IBackgroundCopyJob1_get_JobID(This,pguidJobID) (This)->lpVtbl->get_JobID(This,pguidJobID)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyJob1_CancelJob_Proxy(IBackgroundCopyJob1 *This);
  void __RPC_STUB IBackgroundCopyJob1_CancelJob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_GetProgress_Proxy(IBackgroundCopyJob1 *This,DWORD dwFlags,DWORD *pdwProgress);
  void __RPC_STUB IBackgroundCopyJob1_GetProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_GetStatus_Proxy(IBackgroundCopyJob1 *This,DWORD *pdwStatus,DWORD *pdwWin32Result,DWORD *pdwTransportResult,DWORD *pdwNumOfRetries);
  void __RPC_STUB IBackgroundCopyJob1_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_AddFiles_Proxy(IBackgroundCopyJob1 *This,ULONG cFileCount,FILESETINFO **ppFileSet);
  void __RPC_STUB IBackgroundCopyJob1_AddFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_GetFile_Proxy(IBackgroundCopyJob1 *This,ULONG cFileIndex,FILESETINFO *pFileInfo);
  void __RPC_STUB IBackgroundCopyJob1_GetFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_GetFileCount_Proxy(IBackgroundCopyJob1 *This,DWORD *pdwFileCount);
  void __RPC_STUB IBackgroundCopyJob1_GetFileCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_SwitchToForeground_Proxy(IBackgroundCopyJob1 *This);
  void __RPC_STUB IBackgroundCopyJob1_SwitchToForeground_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob1_get_JobID_Proxy(IBackgroundCopyJob1 *This,GUID *pguidJobID);
  void __RPC_STUB IBackgroundCopyJob1_get_JobID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumBackgroundCopyJobs1_INTERFACE_DEFINED__
#define __IEnumBackgroundCopyJobs1_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumBackgroundCopyJobs1;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumBackgroundCopyJobs1 : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,GUID *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumBackgroundCopyJobs1 **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *puCount) = 0;
  };
#else
  typedef struct IEnumBackgroundCopyJobs1Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumBackgroundCopyJobs1 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumBackgroundCopyJobs1 *This);
      ULONG (WINAPI *Release)(IEnumBackgroundCopyJobs1 *This);
      HRESULT (WINAPI *Next)(IEnumBackgroundCopyJobs1 *This,ULONG celt,GUID *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumBackgroundCopyJobs1 *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumBackgroundCopyJobs1 *This);
      HRESULT (WINAPI *Clone)(IEnumBackgroundCopyJobs1 *This,IEnumBackgroundCopyJobs1 **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumBackgroundCopyJobs1 *This,ULONG *puCount);
    END_INTERFACE
  } IEnumBackgroundCopyJobs1Vtbl;
  struct IEnumBackgroundCopyJobs1 {
    CONST_VTBL struct IEnumBackgroundCopyJobs1Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumBackgroundCopyJobs1_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumBackgroundCopyJobs1_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumBackgroundCopyJobs1_Release(This) (This)->lpVtbl->Release(This)
#define IEnumBackgroundCopyJobs1_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumBackgroundCopyJobs1_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumBackgroundCopyJobs1_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumBackgroundCopyJobs1_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumBackgroundCopyJobs1_GetCount(This,puCount) (This)->lpVtbl->GetCount(This,puCount)
#endif
#endif
  HRESULT WINAPI IEnumBackgroundCopyJobs1_Next_Proxy(IEnumBackgroundCopyJobs1 *This,ULONG celt,GUID *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumBackgroundCopyJobs1_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs1_Skip_Proxy(IEnumBackgroundCopyJobs1 *This,ULONG celt);
  void __RPC_STUB IEnumBackgroundCopyJobs1_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs1_Reset_Proxy(IEnumBackgroundCopyJobs1 *This);
  void __RPC_STUB IEnumBackgroundCopyJobs1_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs1_Clone_Proxy(IEnumBackgroundCopyJobs1 *This,IEnumBackgroundCopyJobs1 **ppenum);
  void __RPC_STUB IEnumBackgroundCopyJobs1_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs1_GetCount_Proxy(IEnumBackgroundCopyJobs1 *This,ULONG *puCount);
  void __RPC_STUB IEnumBackgroundCopyJobs1_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyGroup_INTERFACE_DEFINED__
#define __IBackgroundCopyGroup_INTERFACE_DEFINED__
  typedef enum GROUPPROP {
    GROUPPROP_PRIORITY = 0,GROUPPROP_REMOTEUSERID = 1,GROUPPROP_REMOTEUSERPWD = 2,GROUPPROP_LOCALUSERID = 3,GROUPPROP_LOCALUSERPWD = 4,
    GROUPPROP_PROTOCOLFLAGS = 5,GROUPPROP_NOTIFYFLAGS = 6,GROUPPROP_NOTIFYCLSID = 7,GROUPPROP_PROGRESSSIZE = 8,GROUPPROP_PROGRESSPERCENT = 9,
    GROUPPROP_PROGRESSTIME = 10,GROUPPROP_DISPLAYNAME = 11,GROUPPROP_DESCRIPTION = 12
  } GROUPPROP;

  EXTERN_C const IID IID_IBackgroundCopyGroup;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyGroup : public IUnknown {
  public:
    virtual HRESULT WINAPI GetProp(GROUPPROP propID,VARIANT *pvarVal) = 0;
    virtual HRESULT WINAPI SetProp(GROUPPROP propID,VARIANT *pvarVal) = 0;
    virtual HRESULT WINAPI GetProgress(DWORD dwFlags,DWORD *pdwProgress) = 0;
    virtual HRESULT WINAPI GetStatus(DWORD *pdwStatus,DWORD *pdwJobIndex) = 0;
    virtual HRESULT WINAPI GetJob(GUID jobID,IBackgroundCopyJob1 **ppJob) = 0;
    virtual HRESULT WINAPI SuspendGroup(void) = 0;
    virtual HRESULT WINAPI ResumeGroup(void) = 0;
    virtual HRESULT WINAPI CancelGroup(void) = 0;
    virtual HRESULT WINAPI get_Size(DWORD *pdwSize) = 0;
    virtual HRESULT WINAPI get_GroupID(GUID *pguidGroupID) = 0;
    virtual HRESULT WINAPI CreateJob(GUID guidJobID,IBackgroundCopyJob1 **ppJob) = 0;
    virtual HRESULT WINAPI EnumJobs(DWORD dwFlags,IEnumBackgroundCopyJobs1 **ppEnumJobs) = 0;
    virtual HRESULT WINAPI SwitchToForeground(void) = 0;
    virtual HRESULT WINAPI QueryNewJobInterface(REFIID iid,IUnknown **pUnk) = 0;
    virtual HRESULT WINAPI SetNotificationPointer(REFIID iid,IUnknown *pUnk) = 0;
  };
#else
  typedef struct IBackgroundCopyGroupVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyGroup *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyGroup *This);
      ULONG (WINAPI *Release)(IBackgroundCopyGroup *This);
      HRESULT (WINAPI *GetProp)(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);
      HRESULT (WINAPI *SetProp)(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);
      HRESULT (WINAPI *GetProgress)(IBackgroundCopyGroup *This,DWORD dwFlags,DWORD *pdwProgress);
      HRESULT (WINAPI *GetStatus)(IBackgroundCopyGroup *This,DWORD *pdwStatus,DWORD *pdwJobIndex);
      HRESULT (WINAPI *GetJob)(IBackgroundCopyGroup *This,GUID jobID,IBackgroundCopyJob1 **ppJob);
      HRESULT (WINAPI *SuspendGroup)(IBackgroundCopyGroup *This);
      HRESULT (WINAPI *ResumeGroup)(IBackgroundCopyGroup *This);
      HRESULT (WINAPI *CancelGroup)(IBackgroundCopyGroup *This);
      HRESULT (WINAPI *get_Size)(IBackgroundCopyGroup *This,DWORD *pdwSize);
      HRESULT (WINAPI *get_GroupID)(IBackgroundCopyGroup *This,GUID *pguidGroupID);
      HRESULT (WINAPI *CreateJob)(IBackgroundCopyGroup *This,GUID guidJobID,IBackgroundCopyJob1 **ppJob);
      HRESULT (WINAPI *EnumJobs)(IBackgroundCopyGroup *This,DWORD dwFlags,IEnumBackgroundCopyJobs1 **ppEnumJobs);
      HRESULT (WINAPI *SwitchToForeground)(IBackgroundCopyGroup *This);
      HRESULT (WINAPI *QueryNewJobInterface)(IBackgroundCopyGroup *This,REFIID iid,IUnknown **pUnk);
      HRESULT (WINAPI *SetNotificationPointer)(IBackgroundCopyGroup *This,REFIID iid,IUnknown *pUnk);
    END_INTERFACE
  } IBackgroundCopyGroupVtbl;
  struct IBackgroundCopyGroup {
    CONST_VTBL struct IBackgroundCopyGroupVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyGroup_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyGroup_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyGroup_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyGroup_GetProp(This,propID,pvarVal) (This)->lpVtbl->GetProp(This,propID,pvarVal)
#define IBackgroundCopyGroup_SetProp(This,propID,pvarVal) (This)->lpVtbl->SetProp(This,propID,pvarVal)
#define IBackgroundCopyGroup_GetProgress(This,dwFlags,pdwProgress) (This)->lpVtbl->GetProgress(This,dwFlags,pdwProgress)
#define IBackgroundCopyGroup_GetStatus(This,pdwStatus,pdwJobIndex) (This)->lpVtbl->GetStatus(This,pdwStatus,pdwJobIndex)
#define IBackgroundCopyGroup_GetJob(This,jobID,ppJob) (This)->lpVtbl->GetJob(This,jobID,ppJob)
#define IBackgroundCopyGroup_SuspendGroup(This) (This)->lpVtbl->SuspendGroup(This)
#define IBackgroundCopyGroup_ResumeGroup(This) (This)->lpVtbl->ResumeGroup(This)
#define IBackgroundCopyGroup_CancelGroup(This) (This)->lpVtbl->CancelGroup(This)
#define IBackgroundCopyGroup_get_Size(This,pdwSize) (This)->lpVtbl->get_Size(This,pdwSize)
#define IBackgroundCopyGroup_get_GroupID(This,pguidGroupID) (This)->lpVtbl->get_GroupID(This,pguidGroupID)
#define IBackgroundCopyGroup_CreateJob(This,guidJobID,ppJob) (This)->lpVtbl->CreateJob(This,guidJobID,ppJob)
#define IBackgroundCopyGroup_EnumJobs(This,dwFlags,ppEnumJobs) (This)->lpVtbl->EnumJobs(This,dwFlags,ppEnumJobs)
#define IBackgroundCopyGroup_SwitchToForeground(This) (This)->lpVtbl->SwitchToForeground(This)
#define IBackgroundCopyGroup_QueryNewJobInterface(This,iid,pUnk) (This)->lpVtbl->QueryNewJobInterface(This,iid,pUnk)
#define IBackgroundCopyGroup_SetNotificationPointer(This,iid,pUnk) (This)->lpVtbl->SetNotificationPointer(This,iid,pUnk)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyGroup_GetProp_Proxy(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);
  void __RPC_STUB IBackgroundCopyGroup_GetProp_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_InternalSetProp_Proxy(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);
  void __RPC_STUB IBackgroundCopyGroup_InternalSetProp_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_GetProgress_Proxy(IBackgroundCopyGroup *This,DWORD dwFlags,DWORD *pdwProgress);
  void __RPC_STUB IBackgroundCopyGroup_GetProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_GetStatus_Proxy(IBackgroundCopyGroup *This,DWORD *pdwStatus,DWORD *pdwJobIndex);
  void __RPC_STUB IBackgroundCopyGroup_GetStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_GetJob_Proxy(IBackgroundCopyGroup *This,GUID jobID,IBackgroundCopyJob1 **ppJob);
  void __RPC_STUB IBackgroundCopyGroup_GetJob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_SuspendGroup_Proxy(IBackgroundCopyGroup *This);
  void __RPC_STUB IBackgroundCopyGroup_SuspendGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_ResumeGroup_Proxy(IBackgroundCopyGroup *This);
  void __RPC_STUB IBackgroundCopyGroup_ResumeGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_CancelGroup_Proxy(IBackgroundCopyGroup *This);
  void __RPC_STUB IBackgroundCopyGroup_CancelGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_get_Size_Proxy(IBackgroundCopyGroup *This,DWORD *pdwSize);
  void __RPC_STUB IBackgroundCopyGroup_get_Size_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_get_GroupID_Proxy(IBackgroundCopyGroup *This,GUID *pguidGroupID);
  void __RPC_STUB IBackgroundCopyGroup_get_GroupID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_CreateJob_Proxy(IBackgroundCopyGroup *This,GUID guidJobID,IBackgroundCopyJob1 **ppJob);
  void __RPC_STUB IBackgroundCopyGroup_CreateJob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_EnumJobs_Proxy(IBackgroundCopyGroup *This,DWORD dwFlags,IEnumBackgroundCopyJobs1 **ppEnumJobs);
  void __RPC_STUB IBackgroundCopyGroup_EnumJobs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_SwitchToForeground_Proxy(IBackgroundCopyGroup *This);
  void __RPC_STUB IBackgroundCopyGroup_SwitchToForeground_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_QueryNewJobInterface_Proxy(IBackgroundCopyGroup *This,REFIID iid,IUnknown **pUnk);
  void __RPC_STUB IBackgroundCopyGroup_QueryNewJobInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyGroup_SetNotificationPointer_Proxy(IBackgroundCopyGroup *This,REFIID iid,IUnknown *pUnk);
  void __RPC_STUB IBackgroundCopyGroup_SetNotificationPointer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumBackgroundCopyGroups_INTERFACE_DEFINED__
#define __IEnumBackgroundCopyGroups_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumBackgroundCopyGroups;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumBackgroundCopyGroups : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,GUID *rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumBackgroundCopyGroups **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *puCount) = 0;
  };
#else
  typedef struct IEnumBackgroundCopyGroupsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumBackgroundCopyGroups *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumBackgroundCopyGroups *This);
      ULONG (WINAPI *Release)(IEnumBackgroundCopyGroups *This);
      HRESULT (WINAPI *Next)(IEnumBackgroundCopyGroups *This,ULONG celt,GUID *rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumBackgroundCopyGroups *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumBackgroundCopyGroups *This);
      HRESULT (WINAPI *Clone)(IEnumBackgroundCopyGroups *This,IEnumBackgroundCopyGroups **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumBackgroundCopyGroups *This,ULONG *puCount);
    END_INTERFACE
  } IEnumBackgroundCopyGroupsVtbl;
  struct IEnumBackgroundCopyGroups {
    CONST_VTBL struct IEnumBackgroundCopyGroupsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumBackgroundCopyGroups_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumBackgroundCopyGroups_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumBackgroundCopyGroups_Release(This) (This)->lpVtbl->Release(This)
#define IEnumBackgroundCopyGroups_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumBackgroundCopyGroups_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumBackgroundCopyGroups_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumBackgroundCopyGroups_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumBackgroundCopyGroups_GetCount(This,puCount) (This)->lpVtbl->GetCount(This,puCount)
#endif
#endif
  HRESULT WINAPI IEnumBackgroundCopyGroups_Next_Proxy(IEnumBackgroundCopyGroups *This,ULONG celt,GUID *rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumBackgroundCopyGroups_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyGroups_Skip_Proxy(IEnumBackgroundCopyGroups *This,ULONG celt);
  void __RPC_STUB IEnumBackgroundCopyGroups_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyGroups_Reset_Proxy(IEnumBackgroundCopyGroups *This);
  void __RPC_STUB IEnumBackgroundCopyGroups_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyGroups_Clone_Proxy(IEnumBackgroundCopyGroups *This,IEnumBackgroundCopyGroups **ppenum);
  void __RPC_STUB IEnumBackgroundCopyGroups_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyGroups_GetCount_Proxy(IEnumBackgroundCopyGroups *This,ULONG *puCount);
  void __RPC_STUB IEnumBackgroundCopyGroups_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyCallback1_INTERFACE_DEFINED__
#define __IBackgroundCopyCallback1_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBackgroundCopyCallback1;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyCallback1 : public IUnknown {
  public:
    virtual HRESULT WINAPI OnStatus(IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwStatus,DWORD dwNumOfRetries,DWORD dwWin32Result,DWORD dwTransportResult) = 0;
    virtual HRESULT WINAPI OnProgress(DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue) = 0;
    virtual HRESULT WINAPI OnProgressEx(DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue,DWORD dwByteArraySize,BYTE *pByte) = 0;
  };
#else
  typedef struct IBackgroundCopyCallback1Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyCallback1 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyCallback1 *This);
      ULONG (WINAPI *Release)(IBackgroundCopyCallback1 *This);
      HRESULT (WINAPI *OnStatus)(IBackgroundCopyCallback1 *This,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwStatus,DWORD dwNumOfRetries,DWORD dwWin32Result,DWORD dwTransportResult);
      HRESULT (WINAPI *OnProgress)(IBackgroundCopyCallback1 *This,DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue);
      HRESULT (WINAPI *OnProgressEx)(IBackgroundCopyCallback1 *This,DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue,DWORD dwByteArraySize,BYTE *pByte);
    END_INTERFACE
  } IBackgroundCopyCallback1Vtbl;
  struct IBackgroundCopyCallback1 {
    CONST_VTBL struct IBackgroundCopyCallback1Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyCallback1_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyCallback1_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyCallback1_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyCallback1_OnStatus(This,pGroup,pJob,dwFileIndex,dwStatus,dwNumOfRetries,dwWin32Result,dwTransportResult) (This)->lpVtbl->OnStatus(This,pGroup,pJob,dwFileIndex,dwStatus,dwNumOfRetries,dwWin32Result,dwTransportResult)
#define IBackgroundCopyCallback1_OnProgress(This,ProgressType,pGroup,pJob,dwFileIndex,dwProgressValue) (This)->lpVtbl->OnProgress(This,ProgressType,pGroup,pJob,dwFileIndex,dwProgressValue)
#define IBackgroundCopyCallback1_OnProgressEx(This,ProgressType,pGroup,pJob,dwFileIndex,dwProgressValue,dwByteArraySize,pByte) (This)->lpVtbl->OnProgressEx(This,ProgressType,pGroup,pJob,dwFileIndex,dwProgressValue,dwByteArraySize,pByte)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyCallback1_OnStatus_Proxy(IBackgroundCopyCallback1 *This,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwStatus,DWORD dwNumOfRetries,DWORD dwWin32Result,DWORD dwTransportResult);
  void __RPC_STUB IBackgroundCopyCallback1_OnStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyCallback1_OnProgress_Proxy(IBackgroundCopyCallback1 *This,DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue);
  void __RPC_STUB IBackgroundCopyCallback1_OnProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyCallback1_OnProgressEx_Proxy(IBackgroundCopyCallback1 *This,DWORD ProgressType,IBackgroundCopyGroup *pGroup,IBackgroundCopyJob1 *pJob,DWORD dwFileIndex,DWORD dwProgressValue,DWORD dwByteArraySize,BYTE *pByte);
  void __RPC_STUB IBackgroundCopyCallback1_OnProgressEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyQMgr_INTERFACE_DEFINED__
#define __IBackgroundCopyQMgr_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBackgroundCopyQMgr;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyQMgr : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateGroup(GUID guidGroupID,IBackgroundCopyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI GetGroup(GUID groupID,IBackgroundCopyGroup **ppGroup) = 0;
    virtual HRESULT WINAPI EnumGroups(DWORD dwFlags,IEnumBackgroundCopyGroups **ppEnumGroups) = 0;
  };
#else
  typedef struct IBackgroundCopyQMgrVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyQMgr *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyQMgr *This);
      ULONG (WINAPI *Release)(IBackgroundCopyQMgr *This);
      HRESULT (WINAPI *CreateGroup)(IBackgroundCopyQMgr *This,GUID guidGroupID,IBackgroundCopyGroup **ppGroup);
      HRESULT (WINAPI *GetGroup)(IBackgroundCopyQMgr *This,GUID groupID,IBackgroundCopyGroup **ppGroup);
      HRESULT (WINAPI *EnumGroups)(IBackgroundCopyQMgr *This,DWORD dwFlags,IEnumBackgroundCopyGroups **ppEnumGroups);
    END_INTERFACE
  } IBackgroundCopyQMgrVtbl;
  struct IBackgroundCopyQMgr {
    CONST_VTBL struct IBackgroundCopyQMgrVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyQMgr_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyQMgr_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyQMgr_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyQMgr_CreateGroup(This,guidGroupID,ppGroup) (This)->lpVtbl->CreateGroup(This,guidGroupID,ppGroup)
#define IBackgroundCopyQMgr_GetGroup(This,groupID,ppGroup) (This)->lpVtbl->GetGroup(This,groupID,ppGroup)
#define IBackgroundCopyQMgr_EnumGroups(This,dwFlags,ppEnumGroups) (This)->lpVtbl->EnumGroups(This,dwFlags,ppEnumGroups)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyQMgr_CreateGroup_Proxy(IBackgroundCopyQMgr *This,GUID guidGroupID,IBackgroundCopyGroup **ppGroup);
  void __RPC_STUB IBackgroundCopyQMgr_CreateGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyQMgr_GetGroup_Proxy(IBackgroundCopyQMgr *This,GUID groupID,IBackgroundCopyGroup **ppGroup);
  void __RPC_STUB IBackgroundCopyQMgr_GetGroup_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyQMgr_EnumGroups_Proxy(IBackgroundCopyQMgr *This,DWORD dwFlags,IEnumBackgroundCopyGroups **ppEnumGroups);
  void __RPC_STUB IBackgroundCopyQMgr_EnumGroups_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __BackgroundCopyQMgr_LIBRARY_DEFINED__
#define __BackgroundCopyQMgr_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_BackgroundCopyQMgr;
  EXTERN_C const CLSID CLSID_BackgroundCopyQMgr;
#ifdef __cplusplus
  class BackgroundCopyQMgr;
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

  HRESULT WINAPI IBackgroundCopyGroup_SetProp_Proxy(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);
  HRESULT WINAPI IBackgroundCopyGroup_SetProp_Stub(IBackgroundCopyGroup *This,GROUPPROP propID,VARIANT *pvarVal);

#ifdef __cplusplus
}
#endif
#endif
