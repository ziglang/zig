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

#ifndef __bits_h__
#define __bits_h__

#ifndef __IBackgroundCopyFile_FWD_DEFINED__
#define __IBackgroundCopyFile_FWD_DEFINED__
typedef struct IBackgroundCopyFile IBackgroundCopyFile;
#endif

#ifndef __IEnumBackgroundCopyFiles_FWD_DEFINED__
#define __IEnumBackgroundCopyFiles_FWD_DEFINED__
typedef struct IEnumBackgroundCopyFiles IEnumBackgroundCopyFiles;
#endif

#ifndef __IBackgroundCopyError_FWD_DEFINED__
#define __IBackgroundCopyError_FWD_DEFINED__
typedef struct IBackgroundCopyError IBackgroundCopyError;
#endif

#ifndef __IBackgroundCopyJob_FWD_DEFINED__
#define __IBackgroundCopyJob_FWD_DEFINED__
typedef struct IBackgroundCopyJob IBackgroundCopyJob;
#endif

#ifndef __IEnumBackgroundCopyJobs_FWD_DEFINED__
#define __IEnumBackgroundCopyJobs_FWD_DEFINED__
typedef struct IEnumBackgroundCopyJobs IEnumBackgroundCopyJobs;
#endif

#ifndef __IBackgroundCopyCallback_FWD_DEFINED__
#define __IBackgroundCopyCallback_FWD_DEFINED__
typedef struct IBackgroundCopyCallback IBackgroundCopyCallback;
#endif

#ifndef __AsyncIBackgroundCopyCallback_FWD_DEFINED__
#define __AsyncIBackgroundCopyCallback_FWD_DEFINED__
typedef struct AsyncIBackgroundCopyCallback AsyncIBackgroundCopyCallback;
#endif

#ifndef __IBackgroundCopyManager_FWD_DEFINED__
#define __IBackgroundCopyManager_FWD_DEFINED__
typedef struct IBackgroundCopyManager IBackgroundCopyManager;
#endif

#ifndef __BackgroundCopyManager_FWD_DEFINED__
#define __BackgroundCopyManager_FWD_DEFINED__

#ifdef __cplusplus
typedef class BackgroundCopyManager BackgroundCopyManager;
#else
typedef struct BackgroundCopyManager BackgroundCopyManager;
#endif
#endif

#ifndef __IBackgroundCopyCallback_FWD_DEFINED__
#define __IBackgroundCopyCallback_FWD_DEFINED__
typedef struct IBackgroundCopyCallback IBackgroundCopyCallback;
#endif

#include "unknwn.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#include "bitsmsg.h"
#define BG_SIZE_UNKNOWN (UINT64)(-1)

  extern RPC_IF_HANDLE __MIDL_itf_bits_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_bits_0000_v0_0_s_ifspec;

#ifndef __IBackgroundCopyFile_INTERFACE_DEFINED__
#define __IBackgroundCopyFile_INTERFACE_DEFINED__

  typedef struct _BG_FILE_PROGRESS {
    UINT64 BytesTotal;
    UINT64 BytesTransferred;
    WINBOOL Completed;
  } BG_FILE_PROGRESS;

  EXTERN_C const IID IID_IBackgroundCopyFile;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyFile : public IUnknown {
  public:
    virtual HRESULT WINAPI GetRemoteName(LPWSTR *pVal) = 0;
    virtual HRESULT WINAPI GetLocalName(LPWSTR *pVal) = 0;
    virtual HRESULT WINAPI GetProgress(BG_FILE_PROGRESS *pVal) = 0;
  };
#else
  typedef struct IBackgroundCopyFileVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyFile *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyFile *This);
      ULONG (WINAPI *Release)(IBackgroundCopyFile *This);
      HRESULT (WINAPI *GetRemoteName)(IBackgroundCopyFile *This,LPWSTR *pVal);
      HRESULT (WINAPI *GetLocalName)(IBackgroundCopyFile *This,LPWSTR *pVal);
      HRESULT (WINAPI *GetProgress)(IBackgroundCopyFile *This,BG_FILE_PROGRESS *pVal);
    END_INTERFACE
  } IBackgroundCopyFileVtbl;
  struct IBackgroundCopyFile {
    CONST_VTBL struct IBackgroundCopyFileVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyFile_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyFile_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyFile_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyFile_GetRemoteName(This,pVal) (This)->lpVtbl->GetRemoteName(This,pVal)
#define IBackgroundCopyFile_GetLocalName(This,pVal) (This)->lpVtbl->GetLocalName(This,pVal)
#define IBackgroundCopyFile_GetProgress(This,pVal) (This)->lpVtbl->GetProgress(This,pVal)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyFile_GetRemoteName_Proxy(IBackgroundCopyFile *This,LPWSTR *pVal);
  void __RPC_STUB IBackgroundCopyFile_GetRemoteName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyFile_GetLocalName_Proxy(IBackgroundCopyFile *This,LPWSTR *pVal);
  void __RPC_STUB IBackgroundCopyFile_GetLocalName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyFile_GetProgress_Proxy(IBackgroundCopyFile *This,BG_FILE_PROGRESS *pVal);
  void __RPC_STUB IBackgroundCopyFile_GetProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumBackgroundCopyFiles_INTERFACE_DEFINED__
#define __IEnumBackgroundCopyFiles_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumBackgroundCopyFiles;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumBackgroundCopyFiles : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IBackgroundCopyFile **rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumBackgroundCopyFiles **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *puCount) = 0;
  };
#else
  typedef struct IEnumBackgroundCopyFilesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumBackgroundCopyFiles *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumBackgroundCopyFiles *This);
      ULONG (WINAPI *Release)(IEnumBackgroundCopyFiles *This);
      HRESULT (WINAPI *Next)(IEnumBackgroundCopyFiles *This,ULONG celt,IBackgroundCopyFile **rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumBackgroundCopyFiles *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumBackgroundCopyFiles *This);
      HRESULT (WINAPI *Clone)(IEnumBackgroundCopyFiles *This,IEnumBackgroundCopyFiles **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumBackgroundCopyFiles *This,ULONG *puCount);
    END_INTERFACE
  } IEnumBackgroundCopyFilesVtbl;
  struct IEnumBackgroundCopyFiles {
    CONST_VTBL struct IEnumBackgroundCopyFilesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumBackgroundCopyFiles_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumBackgroundCopyFiles_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumBackgroundCopyFiles_Release(This) (This)->lpVtbl->Release(This)
#define IEnumBackgroundCopyFiles_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumBackgroundCopyFiles_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumBackgroundCopyFiles_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumBackgroundCopyFiles_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumBackgroundCopyFiles_GetCount(This,puCount) (This)->lpVtbl->GetCount(This,puCount)
#endif
#endif
  HRESULT WINAPI IEnumBackgroundCopyFiles_Next_Proxy(IEnumBackgroundCopyFiles *This,ULONG celt,IBackgroundCopyFile **rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumBackgroundCopyFiles_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyFiles_Skip_Proxy(IEnumBackgroundCopyFiles *This,ULONG celt);
  void __RPC_STUB IEnumBackgroundCopyFiles_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyFiles_Reset_Proxy(IEnumBackgroundCopyFiles *This);
  void __RPC_STUB IEnumBackgroundCopyFiles_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyFiles_Clone_Proxy(IEnumBackgroundCopyFiles *This,IEnumBackgroundCopyFiles **ppenum);
  void __RPC_STUB IEnumBackgroundCopyFiles_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyFiles_GetCount_Proxy(IEnumBackgroundCopyFiles *This,ULONG *puCount);
  void __RPC_STUB IEnumBackgroundCopyFiles_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyError_INTERFACE_DEFINED__
#define __IBackgroundCopyError_INTERFACE_DEFINED__
  typedef enum __MIDL_IBackgroundCopyError_0001 {
    BG_ERROR_CONTEXT_NONE = 0,BG_ERROR_CONTEXT_UNKNOWN = 1,BG_ERROR_CONTEXT_GENERAL_QUEUE_MANAGER = 2,BG_ERROR_CONTEXT_QUEUE_MANAGER_NOTIFICATION = 3,
    BG_ERROR_CONTEXT_LOCAL_FILE = 4,BG_ERROR_CONTEXT_REMOTE_FILE = 5,BG_ERROR_CONTEXT_GENERAL_TRANSPORT = 6,BG_ERROR_CONTEXT_REMOTE_APPLICATION = 7
  } BG_ERROR_CONTEXT;

  EXTERN_C const IID IID_IBackgroundCopyError;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyError : public IUnknown {
  public:
    virtual HRESULT WINAPI GetError(BG_ERROR_CONTEXT *pContext,HRESULT *pCode) = 0;
    virtual HRESULT WINAPI GetFile(IBackgroundCopyFile **pVal) = 0;
    virtual HRESULT WINAPI GetErrorDescription(DWORD LanguageId,LPWSTR *pErrorDescription) = 0;
    virtual HRESULT WINAPI GetErrorContextDescription(DWORD LanguageId,LPWSTR *pContextDescription) = 0;
    virtual HRESULT WINAPI GetProtocol(LPWSTR *pProtocol) = 0;
  };
#else
  typedef struct IBackgroundCopyErrorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyError *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyError *This);
      ULONG (WINAPI *Release)(IBackgroundCopyError *This);
      HRESULT (WINAPI *GetError)(IBackgroundCopyError *This,BG_ERROR_CONTEXT *pContext,HRESULT *pCode);
      HRESULT (WINAPI *GetFile)(IBackgroundCopyError *This,IBackgroundCopyFile **pVal);
      HRESULT (WINAPI *GetErrorDescription)(IBackgroundCopyError *This,DWORD LanguageId,LPWSTR *pErrorDescription);
      HRESULT (WINAPI *GetErrorContextDescription)(IBackgroundCopyError *This,DWORD LanguageId,LPWSTR *pContextDescription);
      HRESULT (WINAPI *GetProtocol)(IBackgroundCopyError *This,LPWSTR *pProtocol);
    END_INTERFACE
  } IBackgroundCopyErrorVtbl;
  struct IBackgroundCopyError {
    CONST_VTBL struct IBackgroundCopyErrorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyError_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyError_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyError_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyError_GetError(This,pContext,pCode) (This)->lpVtbl->GetError(This,pContext,pCode)
#define IBackgroundCopyError_GetFile(This,pVal) (This)->lpVtbl->GetFile(This,pVal)
#define IBackgroundCopyError_GetErrorDescription(This,LanguageId,pErrorDescription) (This)->lpVtbl->GetErrorDescription(This,LanguageId,pErrorDescription)
#define IBackgroundCopyError_GetErrorContextDescription(This,LanguageId,pContextDescription) (This)->lpVtbl->GetErrorContextDescription(This,LanguageId,pContextDescription)
#define IBackgroundCopyError_GetProtocol(This,pProtocol) (This)->lpVtbl->GetProtocol(This,pProtocol)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyError_GetError_Proxy(IBackgroundCopyError *This,BG_ERROR_CONTEXT *pContext,HRESULT *pCode);
  void __RPC_STUB IBackgroundCopyError_GetError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyError_GetFile_Proxy(IBackgroundCopyError *This,IBackgroundCopyFile **pVal);
  void __RPC_STUB IBackgroundCopyError_GetFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyError_GetErrorDescription_Proxy(IBackgroundCopyError *This,DWORD LanguageId,LPWSTR *pErrorDescription);
  void __RPC_STUB IBackgroundCopyError_GetErrorDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyError_GetErrorContextDescription_Proxy(IBackgroundCopyError *This,DWORD LanguageId,LPWSTR *pContextDescription);
  void __RPC_STUB IBackgroundCopyError_GetErrorContextDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyError_GetProtocol_Proxy(IBackgroundCopyError *This,LPWSTR *pProtocol);
  void __RPC_STUB IBackgroundCopyError_GetProtocol_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyJob_INTERFACE_DEFINED__
#define __IBackgroundCopyJob_INTERFACE_DEFINED__
  typedef struct _BG_FILE_INFO {
    LPWSTR RemoteName;
    LPWSTR LocalName;
  } BG_FILE_INFO;

  typedef struct _BG_JOB_PROGRESS {
    UINT64 BytesTotal;
    UINT64 BytesTransferred;
    ULONG FilesTotal;
    ULONG FilesTransferred;
  } BG_JOB_PROGRESS;

  typedef struct _BG_JOB_TIMES {
    FILETIME CreationTime;
    FILETIME ModificationTime;
    FILETIME TransferCompletionTime;
  } BG_JOB_TIMES;

  typedef enum __MIDL_IBackgroundCopyJob_0001 {
    BG_JOB_PRIORITY_FOREGROUND = 0,
    BG_JOB_PRIORITY_HIGH,BG_JOB_PRIORITY_NORMAL,BG_JOB_PRIORITY_LOW
  } BG_JOB_PRIORITY;

  typedef enum __MIDL_IBackgroundCopyJob_0002 {
    BG_JOB_STATE_QUEUED = 0,BG_JOB_STATE_CONNECTING,BG_JOB_STATE_TRANSFERRING,
    BG_JOB_STATE_SUSPENDED,BG_JOB_STATE_ERROR,BG_JOB_STATE_TRANSIENT_ERROR,
    BG_JOB_STATE_TRANSFERRED,BG_JOB_STATE_ACKNOWLEDGED,BG_JOB_STATE_CANCELLED
  } BG_JOB_STATE;

  typedef enum __MIDL_IBackgroundCopyJob_0003 {
    BG_JOB_TYPE_DOWNLOAD = 0,BG_JOB_TYPE_UPLOAD,BG_JOB_TYPE_UPLOAD_REPLY
  } BG_JOB_TYPE;

  typedef enum __MIDL_IBackgroundCopyJob_0004 {
    BG_JOB_PROXY_USAGE_PRECONFIG = 0,BG_JOB_PROXY_USAGE_NO_PROXY,
    BG_JOB_PROXY_USAGE_OVERRIDE,BG_JOB_PROXY_USAGE_AUTODETECT
  } BG_JOB_PROXY_USAGE;

  EXTERN_C const IID IID_IBackgroundCopyJob;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyJob : public IUnknown {
  public:
    virtual HRESULT WINAPI AddFileSet(ULONG cFileCount,BG_FILE_INFO *pFileSet) = 0;
    virtual HRESULT WINAPI AddFile(LPCWSTR RemoteUrl,LPCWSTR LocalName) = 0;
    virtual HRESULT WINAPI EnumFiles(IEnumBackgroundCopyFiles **pEnum) = 0;
    virtual HRESULT WINAPI Suspend(void) = 0;
    virtual HRESULT WINAPI Resume(void) = 0;
    virtual HRESULT WINAPI Cancel(void) = 0;
    virtual HRESULT WINAPI Complete(void) = 0;
    virtual HRESULT WINAPI GetId(GUID *pVal) = 0;
    virtual HRESULT WINAPI GetType(BG_JOB_TYPE *pVal) = 0;
    virtual HRESULT WINAPI GetProgress(BG_JOB_PROGRESS *pVal) = 0;
    virtual HRESULT WINAPI GetTimes(BG_JOB_TIMES *pVal) = 0;
    virtual HRESULT WINAPI GetState(BG_JOB_STATE *pVal) = 0;
    virtual HRESULT WINAPI GetError(IBackgroundCopyError **ppError) = 0;
    virtual HRESULT WINAPI GetOwner(LPWSTR *pVal) = 0;
    virtual HRESULT WINAPI SetDisplayName(LPCWSTR Val) = 0;
    virtual HRESULT WINAPI GetDisplayName(LPWSTR *pVal) = 0;
    virtual HRESULT WINAPI SetDescription(LPCWSTR Val) = 0;
    virtual HRESULT WINAPI GetDescription(LPWSTR *pVal) = 0;
    virtual HRESULT WINAPI SetPriority(BG_JOB_PRIORITY Val) = 0;
    virtual HRESULT WINAPI GetPriority(BG_JOB_PRIORITY *pVal) = 0;
    virtual HRESULT WINAPI SetNotifyFlags(ULONG Val) = 0;
    virtual HRESULT WINAPI GetNotifyFlags(ULONG *pVal) = 0;
    virtual HRESULT WINAPI SetNotifyInterface(IUnknown *Val) = 0;
    virtual HRESULT WINAPI GetNotifyInterface(IUnknown **pVal) = 0;
    virtual HRESULT WINAPI SetMinimumRetryDelay(ULONG Seconds) = 0;
    virtual HRESULT WINAPI GetMinimumRetryDelay(ULONG *Seconds) = 0;
    virtual HRESULT WINAPI SetNoProgressTimeout(ULONG Seconds) = 0;
    virtual HRESULT WINAPI GetNoProgressTimeout(ULONG *Seconds) = 0;
    virtual HRESULT WINAPI GetErrorCount(ULONG *Errors) = 0;
    virtual HRESULT WINAPI SetProxySettings(BG_JOB_PROXY_USAGE ProxyUsage,const WCHAR *ProxyList,const WCHAR *ProxyBypassList) = 0;
    virtual HRESULT WINAPI GetProxySettings(BG_JOB_PROXY_USAGE *pProxyUsage,LPWSTR *pProxyList,LPWSTR *pProxyBypassList) = 0;
    virtual HRESULT WINAPI TakeOwnership(void) = 0;
  };
#else
  typedef struct IBackgroundCopyJobVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyJob *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyJob *This);
      ULONG (WINAPI *Release)(IBackgroundCopyJob *This);
      HRESULT (WINAPI *AddFileSet)(IBackgroundCopyJob *This,ULONG cFileCount,BG_FILE_INFO *pFileSet);
      HRESULT (WINAPI *AddFile)(IBackgroundCopyJob *This,LPCWSTR RemoteUrl,LPCWSTR LocalName);
      HRESULT (WINAPI *EnumFiles)(IBackgroundCopyJob *This,IEnumBackgroundCopyFiles **pEnum);
      HRESULT (WINAPI *Suspend)(IBackgroundCopyJob *This);
      HRESULT (WINAPI *Resume)(IBackgroundCopyJob *This);
      HRESULT (WINAPI *Cancel)(IBackgroundCopyJob *This);
      HRESULT (WINAPI *Complete)(IBackgroundCopyJob *This);
      HRESULT (WINAPI *GetId)(IBackgroundCopyJob *This,GUID *pVal);
      HRESULT (WINAPI *GetType)(IBackgroundCopyJob *This,BG_JOB_TYPE *pVal);
      HRESULT (WINAPI *GetProgress)(IBackgroundCopyJob *This,BG_JOB_PROGRESS *pVal);
      HRESULT (WINAPI *GetTimes)(IBackgroundCopyJob *This,BG_JOB_TIMES *pVal);
      HRESULT (WINAPI *GetState)(IBackgroundCopyJob *This,BG_JOB_STATE *pVal);
      HRESULT (WINAPI *GetError)(IBackgroundCopyJob *This,IBackgroundCopyError **ppError);
      HRESULT (WINAPI *GetOwner)(IBackgroundCopyJob *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetDisplayName)(IBackgroundCopyJob *This,LPCWSTR Val);
      HRESULT (WINAPI *GetDisplayName)(IBackgroundCopyJob *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetDescription)(IBackgroundCopyJob *This,LPCWSTR Val);
      HRESULT (WINAPI *GetDescription)(IBackgroundCopyJob *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetPriority)(IBackgroundCopyJob *This,BG_JOB_PRIORITY Val);
      HRESULT (WINAPI *GetPriority)(IBackgroundCopyJob *This,BG_JOB_PRIORITY *pVal);
      HRESULT (WINAPI *SetNotifyFlags)(IBackgroundCopyJob *This,ULONG Val);
      HRESULT (WINAPI *GetNotifyFlags)(IBackgroundCopyJob *This,ULONG *pVal);
      HRESULT (WINAPI *SetNotifyInterface)(IBackgroundCopyJob *This,IUnknown *Val);
      HRESULT (WINAPI *GetNotifyInterface)(IBackgroundCopyJob *This,IUnknown **pVal);
      HRESULT (WINAPI *SetMinimumRetryDelay)(IBackgroundCopyJob *This,ULONG Seconds);
      HRESULT (WINAPI *GetMinimumRetryDelay)(IBackgroundCopyJob *This,ULONG *Seconds);
      HRESULT (WINAPI *SetNoProgressTimeout)(IBackgroundCopyJob *This,ULONG Seconds);
      HRESULT (WINAPI *GetNoProgressTimeout)(IBackgroundCopyJob *This,ULONG *Seconds);
      HRESULT (WINAPI *GetErrorCount)(IBackgroundCopyJob *This,ULONG *Errors);
      HRESULT (WINAPI *SetProxySettings)(IBackgroundCopyJob *This,BG_JOB_PROXY_USAGE ProxyUsage,const WCHAR *ProxyList,const WCHAR *ProxyBypassList);
      HRESULT (WINAPI *GetProxySettings)(IBackgroundCopyJob *This,BG_JOB_PROXY_USAGE *pProxyUsage,LPWSTR *pProxyList,LPWSTR *pProxyBypassList);
      HRESULT (WINAPI *TakeOwnership)(IBackgroundCopyJob *This);
    END_INTERFACE
  } IBackgroundCopyJobVtbl;
  struct IBackgroundCopyJob {
    CONST_VTBL struct IBackgroundCopyJobVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyJob_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyJob_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyJob_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyJob_AddFileSet(This,cFileCount,pFileSet) (This)->lpVtbl->AddFileSet(This,cFileCount,pFileSet)
#define IBackgroundCopyJob_AddFile(This,RemoteUrl,LocalName) (This)->lpVtbl->AddFile(This,RemoteUrl,LocalName)
#define IBackgroundCopyJob_EnumFiles(This,pEnum) (This)->lpVtbl->EnumFiles(This,pEnum)
#define IBackgroundCopyJob_Suspend(This) (This)->lpVtbl->Suspend(This)
#define IBackgroundCopyJob_Resume(This) (This)->lpVtbl->Resume(This)
#define IBackgroundCopyJob_Cancel(This) (This)->lpVtbl->Cancel(This)
#define IBackgroundCopyJob_Complete(This) (This)->lpVtbl->Complete(This)
#define IBackgroundCopyJob_GetId(This,pVal) (This)->lpVtbl->GetId(This,pVal)
#define IBackgroundCopyJob_GetType(This,pVal) (This)->lpVtbl->GetType(This,pVal)
#define IBackgroundCopyJob_GetProgress(This,pVal) (This)->lpVtbl->GetProgress(This,pVal)
#define IBackgroundCopyJob_GetTimes(This,pVal) (This)->lpVtbl->GetTimes(This,pVal)
#define IBackgroundCopyJob_GetState(This,pVal) (This)->lpVtbl->GetState(This,pVal)
#define IBackgroundCopyJob_GetError(This,ppError) (This)->lpVtbl->GetError(This,ppError)
#define IBackgroundCopyJob_GetOwner(This,pVal) (This)->lpVtbl->GetOwner(This,pVal)
#define IBackgroundCopyJob_SetDisplayName(This,Val) (This)->lpVtbl->SetDisplayName(This,Val)
#define IBackgroundCopyJob_GetDisplayName(This,pVal) (This)->lpVtbl->GetDisplayName(This,pVal)
#define IBackgroundCopyJob_SetDescription(This,Val) (This)->lpVtbl->SetDescription(This,Val)
#define IBackgroundCopyJob_GetDescription(This,pVal) (This)->lpVtbl->GetDescription(This,pVal)
#define IBackgroundCopyJob_SetPriority(This,Val) (This)->lpVtbl->SetPriority(This,Val)
#define IBackgroundCopyJob_GetPriority(This,pVal) (This)->lpVtbl->GetPriority(This,pVal)
#define IBackgroundCopyJob_SetNotifyFlags(This,Val) (This)->lpVtbl->SetNotifyFlags(This,Val)
#define IBackgroundCopyJob_GetNotifyFlags(This,pVal) (This)->lpVtbl->GetNotifyFlags(This,pVal)
#define IBackgroundCopyJob_SetNotifyInterface(This,Val) (This)->lpVtbl->SetNotifyInterface(This,Val)
#define IBackgroundCopyJob_GetNotifyInterface(This,pVal) (This)->lpVtbl->GetNotifyInterface(This,pVal)
#define IBackgroundCopyJob_SetMinimumRetryDelay(This,Seconds) (This)->lpVtbl->SetMinimumRetryDelay(This,Seconds)
#define IBackgroundCopyJob_GetMinimumRetryDelay(This,Seconds) (This)->lpVtbl->GetMinimumRetryDelay(This,Seconds)
#define IBackgroundCopyJob_SetNoProgressTimeout(This,Seconds) (This)->lpVtbl->SetNoProgressTimeout(This,Seconds)
#define IBackgroundCopyJob_GetNoProgressTimeout(This,Seconds) (This)->lpVtbl->GetNoProgressTimeout(This,Seconds)
#define IBackgroundCopyJob_GetErrorCount(This,Errors) (This)->lpVtbl->GetErrorCount(This,Errors)
#define IBackgroundCopyJob_SetProxySettings(This,ProxyUsage,ProxyList,ProxyBypassList) (This)->lpVtbl->SetProxySettings(This,ProxyUsage,ProxyList,ProxyBypassList)
#define IBackgroundCopyJob_GetProxySettings(This,pProxyUsage,pProxyList,pProxyBypassList) (This)->lpVtbl->GetProxySettings(This,pProxyUsage,pProxyList,pProxyBypassList)
#define IBackgroundCopyJob_TakeOwnership(This) (This)->lpVtbl->TakeOwnership(This)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyJob_AddFileSet_Proxy(IBackgroundCopyJob *This,ULONG cFileCount,BG_FILE_INFO *pFileSet);
  void __RPC_STUB IBackgroundCopyJob_AddFileSet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_AddFile_Proxy(IBackgroundCopyJob *This,LPCWSTR RemoteUrl,LPCWSTR LocalName);
  void __RPC_STUB IBackgroundCopyJob_AddFile_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_EnumFiles_Proxy(IBackgroundCopyJob *This,IEnumBackgroundCopyFiles **pEnum);
  void __RPC_STUB IBackgroundCopyJob_EnumFiles_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_Suspend_Proxy(IBackgroundCopyJob *This);
  void __RPC_STUB IBackgroundCopyJob_Suspend_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_Resume_Proxy(IBackgroundCopyJob *This);
  void __RPC_STUB IBackgroundCopyJob_Resume_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_Cancel_Proxy(IBackgroundCopyJob *This);
  void __RPC_STUB IBackgroundCopyJob_Cancel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_Complete_Proxy(IBackgroundCopyJob *This);
  void __RPC_STUB IBackgroundCopyJob_Complete_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetId_Proxy(IBackgroundCopyJob *This,GUID *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetId_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetType_Proxy(IBackgroundCopyJob *This,BG_JOB_TYPE *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetType_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetProgress_Proxy(IBackgroundCopyJob *This,BG_JOB_PROGRESS *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetTimes_Proxy(IBackgroundCopyJob *This,BG_JOB_TIMES *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetTimes_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetState_Proxy(IBackgroundCopyJob *This,BG_JOB_STATE *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetError_Proxy(IBackgroundCopyJob *This,IBackgroundCopyError **ppError);
  void __RPC_STUB IBackgroundCopyJob_GetError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetOwner_Proxy(IBackgroundCopyJob *This,LPWSTR *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetOwner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetDisplayName_Proxy(IBackgroundCopyJob *This,LPCWSTR Val);
  void __RPC_STUB IBackgroundCopyJob_SetDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetDisplayName_Proxy(IBackgroundCopyJob *This,LPWSTR *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetDescription_Proxy(IBackgroundCopyJob *This,LPCWSTR Val);
  void __RPC_STUB IBackgroundCopyJob_SetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetDescription_Proxy(IBackgroundCopyJob *This,LPWSTR *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetPriority_Proxy(IBackgroundCopyJob *This,BG_JOB_PRIORITY Val);
  void __RPC_STUB IBackgroundCopyJob_SetPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetPriority_Proxy(IBackgroundCopyJob *This,BG_JOB_PRIORITY *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetPriority_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetNotifyFlags_Proxy(IBackgroundCopyJob *This,ULONG Val);
  void __RPC_STUB IBackgroundCopyJob_SetNotifyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetNotifyFlags_Proxy(IBackgroundCopyJob *This,ULONG *pVal);
  void __RPC_STUB IBackgroundCopyJob_GetNotifyFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetNotifyInterface_Proxy(IBackgroundCopyJob *This,IUnknown *Val);
  void __RPC_STUB IBackgroundCopyJob_SetNotifyInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetNotifyInterface_Proxy(IBackgroundCopyJob *This,IUnknown **pVal);
  void __RPC_STUB IBackgroundCopyJob_GetNotifyInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetMinimumRetryDelay_Proxy(IBackgroundCopyJob *This,ULONG Seconds);
  void __RPC_STUB IBackgroundCopyJob_SetMinimumRetryDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetMinimumRetryDelay_Proxy(IBackgroundCopyJob *This,ULONG *Seconds);
  void __RPC_STUB IBackgroundCopyJob_GetMinimumRetryDelay_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetNoProgressTimeout_Proxy(IBackgroundCopyJob *This,ULONG Seconds);
  void __RPC_STUB IBackgroundCopyJob_SetNoProgressTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetNoProgressTimeout_Proxy(IBackgroundCopyJob *This,ULONG *Seconds);
  void __RPC_STUB IBackgroundCopyJob_GetNoProgressTimeout_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetErrorCount_Proxy(IBackgroundCopyJob *This,ULONG *Errors);
  void __RPC_STUB IBackgroundCopyJob_GetErrorCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_SetProxySettings_Proxy(IBackgroundCopyJob *This,BG_JOB_PROXY_USAGE ProxyUsage,const WCHAR *ProxyList,const WCHAR *ProxyBypassList);
  void __RPC_STUB IBackgroundCopyJob_SetProxySettings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_GetProxySettings_Proxy(IBackgroundCopyJob *This,BG_JOB_PROXY_USAGE *pProxyUsage,LPWSTR *pProxyList,LPWSTR *pProxyBypassList);
  void __RPC_STUB IBackgroundCopyJob_GetProxySettings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob_TakeOwnership_Proxy(IBackgroundCopyJob *This);
  void __RPC_STUB IBackgroundCopyJob_TakeOwnership_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IEnumBackgroundCopyJobs_INTERFACE_DEFINED__
#define __IEnumBackgroundCopyJobs_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IEnumBackgroundCopyJobs;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IEnumBackgroundCopyJobs : public IUnknown {
  public:
    virtual HRESULT WINAPI Next(ULONG celt,IBackgroundCopyJob **rgelt,ULONG *pceltFetched) = 0;
    virtual HRESULT WINAPI Skip(ULONG celt) = 0;
    virtual HRESULT WINAPI Reset(void) = 0;
    virtual HRESULT WINAPI Clone(IEnumBackgroundCopyJobs **ppenum) = 0;
    virtual HRESULT WINAPI GetCount(ULONG *puCount) = 0;
  };
#else
  typedef struct IEnumBackgroundCopyJobsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IEnumBackgroundCopyJobs *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IEnumBackgroundCopyJobs *This);
      ULONG (WINAPI *Release)(IEnumBackgroundCopyJobs *This);
      HRESULT (WINAPI *Next)(IEnumBackgroundCopyJobs *This,ULONG celt,IBackgroundCopyJob **rgelt,ULONG *pceltFetched);
      HRESULT (WINAPI *Skip)(IEnumBackgroundCopyJobs *This,ULONG celt);
      HRESULT (WINAPI *Reset)(IEnumBackgroundCopyJobs *This);
      HRESULT (WINAPI *Clone)(IEnumBackgroundCopyJobs *This,IEnumBackgroundCopyJobs **ppenum);
      HRESULT (WINAPI *GetCount)(IEnumBackgroundCopyJobs *This,ULONG *puCount);
    END_INTERFACE
  } IEnumBackgroundCopyJobsVtbl;
  struct IEnumBackgroundCopyJobs {
    CONST_VTBL struct IEnumBackgroundCopyJobsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IEnumBackgroundCopyJobs_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IEnumBackgroundCopyJobs_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IEnumBackgroundCopyJobs_Release(This) (This)->lpVtbl->Release(This)
#define IEnumBackgroundCopyJobs_Next(This,celt,rgelt,pceltFetched) (This)->lpVtbl->Next(This,celt,rgelt,pceltFetched)
#define IEnumBackgroundCopyJobs_Skip(This,celt) (This)->lpVtbl->Skip(This,celt)
#define IEnumBackgroundCopyJobs_Reset(This) (This)->lpVtbl->Reset(This)
#define IEnumBackgroundCopyJobs_Clone(This,ppenum) (This)->lpVtbl->Clone(This,ppenum)
#define IEnumBackgroundCopyJobs_GetCount(This,puCount) (This)->lpVtbl->GetCount(This,puCount)
#endif
#endif
  HRESULT WINAPI IEnumBackgroundCopyJobs_Next_Proxy(IEnumBackgroundCopyJobs *This,ULONG celt,IBackgroundCopyJob **rgelt,ULONG *pceltFetched);
  void __RPC_STUB IEnumBackgroundCopyJobs_Next_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs_Skip_Proxy(IEnumBackgroundCopyJobs *This,ULONG celt);
  void __RPC_STUB IEnumBackgroundCopyJobs_Skip_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs_Reset_Proxy(IEnumBackgroundCopyJobs *This);
  void __RPC_STUB IEnumBackgroundCopyJobs_Reset_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs_Clone_Proxy(IEnumBackgroundCopyJobs *This,IEnumBackgroundCopyJobs **ppenum);
  void __RPC_STUB IEnumBackgroundCopyJobs_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IEnumBackgroundCopyJobs_GetCount_Proxy(IEnumBackgroundCopyJobs *This,ULONG *puCount);
  void __RPC_STUB IEnumBackgroundCopyJobs_GetCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define BG_NOTIFY_JOB_TRANSFERRED 0x0001
#define BG_NOTIFY_JOB_ERROR 0x0002
#define BG_NOTIFY_DISABLE 0x0004
#define BG_NOTIFY_JOB_MODIFICATION 0x0008

  extern RPC_IF_HANDLE __MIDL_itf_bits_0013_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_bits_0013_v0_0_s_ifspec;

#ifndef __IBackgroundCopyCallback_INTERFACE_DEFINED__
#define __IBackgroundCopyCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBackgroundCopyCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI JobTransferred(IBackgroundCopyJob *pJob) = 0;
    virtual HRESULT WINAPI JobError(IBackgroundCopyJob *pJob,IBackgroundCopyError *pError) = 0;
    virtual HRESULT WINAPI JobModification(IBackgroundCopyJob *pJob,DWORD dwReserved) = 0;
  };
#else
  typedef struct IBackgroundCopyCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyCallback *This);
      ULONG (WINAPI *Release)(IBackgroundCopyCallback *This);
      HRESULT (WINAPI *JobTransferred)(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob);
      HRESULT (WINAPI *JobError)(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,IBackgroundCopyError *pError);
      HRESULT (WINAPI *JobModification)(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,DWORD dwReserved);
    END_INTERFACE
  } IBackgroundCopyCallbackVtbl;
  struct IBackgroundCopyCallback {
    CONST_VTBL struct IBackgroundCopyCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyCallback_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyCallback_JobTransferred(This,pJob) (This)->lpVtbl->JobTransferred(This,pJob)
#define IBackgroundCopyCallback_JobError(This,pJob,pError) (This)->lpVtbl->JobError(This,pJob,pError)
#define IBackgroundCopyCallback_JobModification(This,pJob,dwReserved) (This)->lpVtbl->JobModification(This,pJob,dwReserved)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyCallback_JobTransferred_Proxy(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob);
  void __RPC_STUB IBackgroundCopyCallback_JobTransferred_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyCallback_JobError_Proxy(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,IBackgroundCopyError *pError);
  void __RPC_STUB IBackgroundCopyCallback_JobError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyCallback_JobModification_Proxy(IBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,DWORD dwReserved);
  void __RPC_STUB IBackgroundCopyCallback_JobModification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AsyncIBackgroundCopyCallback_INTERFACE_DEFINED__
#define __AsyncIBackgroundCopyCallback_INTERFACE_DEFINED__
  EXTERN_C const IID IID_AsyncIBackgroundCopyCallback;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AsyncIBackgroundCopyCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI Begin_JobTransferred(IBackgroundCopyJob *pJob) = 0;
    virtual HRESULT WINAPI Finish_JobTransferred(void) = 0;
    virtual HRESULT WINAPI Begin_JobError(IBackgroundCopyJob *pJob,IBackgroundCopyError *pError) = 0;
    virtual HRESULT WINAPI Finish_JobError(void) = 0;
    virtual HRESULT WINAPI Begin_JobModification(IBackgroundCopyJob *pJob,DWORD dwReserved) = 0;
    virtual HRESULT WINAPI Finish_JobModification(void) = 0;
  };
#else
  typedef struct AsyncIBackgroundCopyCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AsyncIBackgroundCopyCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AsyncIBackgroundCopyCallback *This);
      ULONG (WINAPI *Release)(AsyncIBackgroundCopyCallback *This);
      HRESULT (WINAPI *Begin_JobTransferred)(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob);
      HRESULT (WINAPI *Finish_JobTransferred)(AsyncIBackgroundCopyCallback *This);
      HRESULT (WINAPI *Begin_JobError)(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,IBackgroundCopyError *pError);
      HRESULT (WINAPI *Finish_JobError)(AsyncIBackgroundCopyCallback *This);
      HRESULT (WINAPI *Begin_JobModification)(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,DWORD dwReserved);
      HRESULT (WINAPI *Finish_JobModification)(AsyncIBackgroundCopyCallback *This);
    END_INTERFACE
  } AsyncIBackgroundCopyCallbackVtbl;
  struct AsyncIBackgroundCopyCallback {
    CONST_VTBL struct AsyncIBackgroundCopyCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AsyncIBackgroundCopyCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AsyncIBackgroundCopyCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AsyncIBackgroundCopyCallback_Release(This) (This)->lpVtbl->Release(This)
#define AsyncIBackgroundCopyCallback_Begin_JobTransferred(This,pJob) (This)->lpVtbl->Begin_JobTransferred(This,pJob)
#define AsyncIBackgroundCopyCallback_Finish_JobTransferred(This) (This)->lpVtbl->Finish_JobTransferred(This)
#define AsyncIBackgroundCopyCallback_Begin_JobError(This,pJob,pError) (This)->lpVtbl->Begin_JobError(This,pJob,pError)
#define AsyncIBackgroundCopyCallback_Finish_JobError(This) (This)->lpVtbl->Finish_JobError(This)
#define AsyncIBackgroundCopyCallback_Begin_JobModification(This,pJob,dwReserved) (This)->lpVtbl->Begin_JobModification(This,pJob,dwReserved)
#define AsyncIBackgroundCopyCallback_Finish_JobModification(This) (This)->lpVtbl->Finish_JobModification(This)
#endif
#endif
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Begin_JobTransferred_Proxy(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Begin_JobTransferred_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Finish_JobTransferred_Proxy(AsyncIBackgroundCopyCallback *This);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Finish_JobTransferred_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Begin_JobError_Proxy(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,IBackgroundCopyError *pError);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Begin_JobError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Finish_JobError_Proxy(AsyncIBackgroundCopyCallback *This);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Finish_JobError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Begin_JobModification_Proxy(AsyncIBackgroundCopyCallback *This,IBackgroundCopyJob *pJob,DWORD dwReserved);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Begin_JobModification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI AsyncIBackgroundCopyCallback_Finish_JobModification_Proxy(AsyncIBackgroundCopyCallback *This);
  void __RPC_STUB AsyncIBackgroundCopyCallback_Finish_JobModification_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBackgroundCopyManager_INTERFACE_DEFINED__
#define __IBackgroundCopyManager_INTERFACE_DEFINED__

#define BG_JOB_ENUM_ALL_USERS 0x0001

  EXTERN_C const IID IID_IBackgroundCopyManager;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyManager : public IUnknown {
  public:
    virtual HRESULT WINAPI CreateJob(LPCWSTR DisplayName,BG_JOB_TYPE Type,GUID *pJobId,IBackgroundCopyJob **ppJob) = 0;
    virtual HRESULT WINAPI GetJob(REFGUID jobID,IBackgroundCopyJob **ppJob) = 0;
    virtual HRESULT WINAPI EnumJobs(DWORD dwFlags,IEnumBackgroundCopyJobs **ppEnum) = 0;
    virtual HRESULT WINAPI GetErrorDescription(HRESULT hResult,DWORD LanguageId,LPWSTR *pErrorDescription) = 0;
  };
#else
  typedef struct IBackgroundCopyManagerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyManager *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyManager *This);
      ULONG (WINAPI *Release)(IBackgroundCopyManager *This);
      HRESULT (WINAPI *CreateJob)(IBackgroundCopyManager *This,LPCWSTR DisplayName,BG_JOB_TYPE Type,GUID *pJobId,IBackgroundCopyJob **ppJob);
      HRESULT (WINAPI *GetJob)(IBackgroundCopyManager *This,REFGUID jobID,IBackgroundCopyJob **ppJob);
      HRESULT (WINAPI *EnumJobs)(IBackgroundCopyManager *This,DWORD dwFlags,IEnumBackgroundCopyJobs **ppEnum);
      HRESULT (WINAPI *GetErrorDescription)(IBackgroundCopyManager *This,HRESULT hResult,DWORD LanguageId,LPWSTR *pErrorDescription);
    END_INTERFACE
  } IBackgroundCopyManagerVtbl;
  struct IBackgroundCopyManager {
    CONST_VTBL struct IBackgroundCopyManagerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyManager_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyManager_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyManager_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyManager_CreateJob(This,DisplayName,Type,pJobId,ppJob) (This)->lpVtbl->CreateJob(This,DisplayName,Type,pJobId,ppJob)
#define IBackgroundCopyManager_GetJob(This,jobID,ppJob) (This)->lpVtbl->GetJob(This,jobID,ppJob)
#define IBackgroundCopyManager_EnumJobs(This,dwFlags,ppEnum) (This)->lpVtbl->EnumJobs(This,dwFlags,ppEnum)
#define IBackgroundCopyManager_GetErrorDescription(This,hResult,LanguageId,pErrorDescription) (This)->lpVtbl->GetErrorDescription(This,hResult,LanguageId,pErrorDescription)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyManager_CreateJob_Proxy(IBackgroundCopyManager *This,LPCWSTR DisplayName,BG_JOB_TYPE Type,GUID *pJobId,IBackgroundCopyJob **ppJob);
  void __RPC_STUB IBackgroundCopyManager_CreateJob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyManager_GetJob_Proxy(IBackgroundCopyManager *This,REFGUID jobID,IBackgroundCopyJob **ppJob);
  void __RPC_STUB IBackgroundCopyManager_GetJob_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyManager_EnumJobs_Proxy(IBackgroundCopyManager *This,DWORD dwFlags,IEnumBackgroundCopyJobs **ppEnum);
  void __RPC_STUB IBackgroundCopyManager_EnumJobs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyManager_GetErrorDescription_Proxy(IBackgroundCopyManager *This,HRESULT hResult,DWORD LanguageId,LPWSTR *pErrorDescription);
  void __RPC_STUB IBackgroundCopyManager_GetErrorDescription_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __BackgroundCopyManager_LIBRARY_DEFINED__
#define __BackgroundCopyManager_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_BackgroundCopyManager;
  EXTERN_C const CLSID CLSID_BackgroundCopyManager;
#ifdef __cplusplus
  class BackgroundCopyManager;
#endif
#endif

#include "bits1_5.h"

  extern RPC_IF_HANDLE __MIDL_itf_bits_0015_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_bits_0015_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
