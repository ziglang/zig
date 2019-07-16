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

#ifndef __bits1_5_h__
#define __bits1_5_h__

#ifndef __IBackgroundCopyJob2_FWD_DEFINED__
#define __IBackgroundCopyJob2_FWD_DEFINED__
typedef struct IBackgroundCopyJob2 IBackgroundCopyJob2;
#endif

#ifndef __BackgroundCopyManager1_5_FWD_DEFINED__
#define __BackgroundCopyManager1_5_FWD_DEFINED__
#ifdef __cplusplus
typedef class BackgroundCopyManager1_5 BackgroundCopyManager1_5;
#else
typedef struct BackgroundCopyManager1_5 BackgroundCopyManager1_5;
#endif
#endif

#ifndef __IBackgroundCopyJob2_FWD_DEFINED__
#define __IBackgroundCopyJob2_FWD_DEFINED__
typedef struct IBackgroundCopyJob2 IBackgroundCopyJob2;
#endif

#include "bits.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#ifndef __IBackgroundCopyJob2_INTERFACE_DEFINED__
#define __IBackgroundCopyJob2_INTERFACE_DEFINED__

  typedef struct _BG_JOB_REPLY_PROGRESS {
    UINT64 BytesTotal;
    UINT64 BytesTransferred;
  } BG_JOB_REPLY_PROGRESS;

  typedef enum __MIDL_IBackgroundCopyJob2_0001 {
    BG_AUTH_TARGET_SERVER = 1,BG_AUTH_TARGET_PROXY = BG_AUTH_TARGET_SERVER + 1
  } BG_AUTH_TARGET;

  typedef enum __MIDL_IBackgroundCopyJob2_0002 {
    BG_AUTH_SCHEME_BASIC = 1,BG_AUTH_SCHEME_DIGEST,BG_AUTH_SCHEME_NTLM,
    BG_AUTH_SCHEME_NEGOTIATE,BG_AUTH_SCHEME_PASSPORT
  } BG_AUTH_SCHEME;

  typedef struct __MIDL_IBackgroundCopyJob2_0003 {
    LPWSTR UserName;
    LPWSTR Password;
  } BG_BASIC_CREDENTIALS;

  typedef BG_BASIC_CREDENTIALS *PBG_BASIC_CREDENTIALS;

  typedef union __MIDL_IBackgroundCopyJob2_0004 {
    BG_BASIC_CREDENTIALS Basic;
  } BG_AUTH_CREDENTIALS_UNION;

  typedef struct __MIDL_IBackgroundCopyJob2_0005 {
    BG_AUTH_TARGET Target;
    BG_AUTH_SCHEME Scheme;
    BG_AUTH_CREDENTIALS_UNION Credentials;
  } BG_AUTH_CREDENTIALS;

  typedef BG_AUTH_CREDENTIALS *PBG_AUTH_CREDENTIALS;

  EXTERN_C const IID IID_IBackgroundCopyJob2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBackgroundCopyJob2 : public IBackgroundCopyJob {
  public:
    virtual HRESULT WINAPI SetNotifyCmdLine(LPCWSTR Program,LPCWSTR Parameters) = 0;
    virtual HRESULT WINAPI GetNotifyCmdLine(LPWSTR *pProgram,LPWSTR *pParameters) = 0;
    virtual HRESULT WINAPI GetReplyProgress(BG_JOB_REPLY_PROGRESS *pProgress) = 0;
    virtual HRESULT WINAPI GetReplyData(byte **ppBuffer,UINT64 *pLength) = 0;
    virtual HRESULT WINAPI SetReplyFileName(LPCWSTR ReplyFileName) = 0;
    virtual HRESULT WINAPI GetReplyFileName(LPWSTR *pReplyFileName) = 0;
    virtual HRESULT WINAPI SetCredentials(BG_AUTH_CREDENTIALS *credentials) = 0;
    virtual HRESULT WINAPI RemoveCredentials(BG_AUTH_TARGET Target,BG_AUTH_SCHEME Scheme) = 0;
  };
#else
  typedef struct IBackgroundCopyJob2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBackgroundCopyJob2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBackgroundCopyJob2 *This);
      ULONG (WINAPI *Release)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *AddFileSet)(IBackgroundCopyJob2 *This,ULONG cFileCount,BG_FILE_INFO *pFileSet);
      HRESULT (WINAPI *AddFile)(IBackgroundCopyJob2 *This,LPCWSTR RemoteUrl,LPCWSTR LocalName);
      HRESULT (WINAPI *EnumFiles)(IBackgroundCopyJob2 *This,IEnumBackgroundCopyFiles **pEnum);
      HRESULT (WINAPI *Suspend)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *Resume)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *Cancel)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *Complete)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *GetId)(IBackgroundCopyJob2 *This,GUID *pVal);
      HRESULT (WINAPI *GetType)(IBackgroundCopyJob2 *This,BG_JOB_TYPE *pVal);
      HRESULT (WINAPI *GetProgress)(IBackgroundCopyJob2 *This,BG_JOB_PROGRESS *pVal);
      HRESULT (WINAPI *GetTimes)(IBackgroundCopyJob2 *This,BG_JOB_TIMES *pVal);
      HRESULT (WINAPI *GetState)(IBackgroundCopyJob2 *This,BG_JOB_STATE *pVal);
      HRESULT (WINAPI *GetError)(IBackgroundCopyJob2 *This,IBackgroundCopyError **ppError);
      HRESULT (WINAPI *GetOwner)(IBackgroundCopyJob2 *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetDisplayName)(IBackgroundCopyJob2 *This,LPCWSTR Val);
      HRESULT (WINAPI *GetDisplayName)(IBackgroundCopyJob2 *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetDescription)(IBackgroundCopyJob2 *This,LPCWSTR Val);
      HRESULT (WINAPI *GetDescription)(IBackgroundCopyJob2 *This,LPWSTR *pVal);
      HRESULT (WINAPI *SetPriority)(IBackgroundCopyJob2 *This,BG_JOB_PRIORITY Val);
      HRESULT (WINAPI *GetPriority)(IBackgroundCopyJob2 *This,BG_JOB_PRIORITY *pVal);
      HRESULT (WINAPI *SetNotifyFlags)(IBackgroundCopyJob2 *This,ULONG Val);
      HRESULT (WINAPI *GetNotifyFlags)(IBackgroundCopyJob2 *This,ULONG *pVal);
      HRESULT (WINAPI *SetNotifyInterface)(IBackgroundCopyJob2 *This,IUnknown *Val);
      HRESULT (WINAPI *GetNotifyInterface)(IBackgroundCopyJob2 *This,IUnknown **pVal);
      HRESULT (WINAPI *SetMinimumRetryDelay)(IBackgroundCopyJob2 *This,ULONG Seconds);
      HRESULT (WINAPI *GetMinimumRetryDelay)(IBackgroundCopyJob2 *This,ULONG *Seconds);
      HRESULT (WINAPI *SetNoProgressTimeout)(IBackgroundCopyJob2 *This,ULONG Seconds);
      HRESULT (WINAPI *GetNoProgressTimeout)(IBackgroundCopyJob2 *This,ULONG *Seconds);
      HRESULT (WINAPI *GetErrorCount)(IBackgroundCopyJob2 *This,ULONG *Errors);
      HRESULT (WINAPI *SetProxySettings)(IBackgroundCopyJob2 *This,BG_JOB_PROXY_USAGE ProxyUsage,const WCHAR *ProxyList,const WCHAR *ProxyBypassList);
      HRESULT (WINAPI *GetProxySettings)(IBackgroundCopyJob2 *This,BG_JOB_PROXY_USAGE *pProxyUsage,LPWSTR *pProxyList,LPWSTR *pProxyBypassList);
      HRESULT (WINAPI *TakeOwnership)(IBackgroundCopyJob2 *This);
      HRESULT (WINAPI *SetNotifyCmdLine)(IBackgroundCopyJob2 *This,LPCWSTR Program,LPCWSTR Parameters);
      HRESULT (WINAPI *GetNotifyCmdLine)(IBackgroundCopyJob2 *This,LPWSTR *pProgram,LPWSTR *pParameters);
      HRESULT (WINAPI *GetReplyProgress)(IBackgroundCopyJob2 *This,BG_JOB_REPLY_PROGRESS *pProgress);
      HRESULT (WINAPI *GetReplyData)(IBackgroundCopyJob2 *This,byte **ppBuffer,UINT64 *pLength);
      HRESULT (WINAPI *SetReplyFileName)(IBackgroundCopyJob2 *This,LPCWSTR ReplyFileName);
      HRESULT (WINAPI *GetReplyFileName)(IBackgroundCopyJob2 *This,LPWSTR *pReplyFileName);
      HRESULT (WINAPI *SetCredentials)(IBackgroundCopyJob2 *This,BG_AUTH_CREDENTIALS *credentials);
      HRESULT (WINAPI *RemoveCredentials)(IBackgroundCopyJob2 *This,BG_AUTH_TARGET Target,BG_AUTH_SCHEME Scheme);
    END_INTERFACE
  } IBackgroundCopyJob2Vtbl;
  struct IBackgroundCopyJob2 {
    CONST_VTBL struct IBackgroundCopyJob2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBackgroundCopyJob2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBackgroundCopyJob2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBackgroundCopyJob2_Release(This) (This)->lpVtbl->Release(This)
#define IBackgroundCopyJob2_AddFileSet(This,cFileCount,pFileSet) (This)->lpVtbl->AddFileSet(This,cFileCount,pFileSet)
#define IBackgroundCopyJob2_AddFile(This,RemoteUrl,LocalName) (This)->lpVtbl->AddFile(This,RemoteUrl,LocalName)
#define IBackgroundCopyJob2_EnumFiles(This,pEnum) (This)->lpVtbl->EnumFiles(This,pEnum)
#define IBackgroundCopyJob2_Suspend(This) (This)->lpVtbl->Suspend(This)
#define IBackgroundCopyJob2_Resume(This) (This)->lpVtbl->Resume(This)
#define IBackgroundCopyJob2_Cancel(This) (This)->lpVtbl->Cancel(This)
#define IBackgroundCopyJob2_Complete(This) (This)->lpVtbl->Complete(This)
#define IBackgroundCopyJob2_GetId(This,pVal) (This)->lpVtbl->GetId(This,pVal)
#define IBackgroundCopyJob2_GetType(This,pVal) (This)->lpVtbl->GetType(This,pVal)
#define IBackgroundCopyJob2_GetProgress(This,pVal) (This)->lpVtbl->GetProgress(This,pVal)
#define IBackgroundCopyJob2_GetTimes(This,pVal) (This)->lpVtbl->GetTimes(This,pVal)
#define IBackgroundCopyJob2_GetState(This,pVal) (This)->lpVtbl->GetState(This,pVal)
#define IBackgroundCopyJob2_GetError(This,ppError) (This)->lpVtbl->GetError(This,ppError)
#define IBackgroundCopyJob2_GetOwner(This,pVal) (This)->lpVtbl->GetOwner(This,pVal)
#define IBackgroundCopyJob2_SetDisplayName(This,Val) (This)->lpVtbl->SetDisplayName(This,Val)
#define IBackgroundCopyJob2_GetDisplayName(This,pVal) (This)->lpVtbl->GetDisplayName(This,pVal)
#define IBackgroundCopyJob2_SetDescription(This,Val) (This)->lpVtbl->SetDescription(This,Val)
#define IBackgroundCopyJob2_GetDescription(This,pVal) (This)->lpVtbl->GetDescription(This,pVal)
#define IBackgroundCopyJob2_SetPriority(This,Val) (This)->lpVtbl->SetPriority(This,Val)
#define IBackgroundCopyJob2_GetPriority(This,pVal) (This)->lpVtbl->GetPriority(This,pVal)
#define IBackgroundCopyJob2_SetNotifyFlags(This,Val) (This)->lpVtbl->SetNotifyFlags(This,Val)
#define IBackgroundCopyJob2_GetNotifyFlags(This,pVal) (This)->lpVtbl->GetNotifyFlags(This,pVal)
#define IBackgroundCopyJob2_SetNotifyInterface(This,Val) (This)->lpVtbl->SetNotifyInterface(This,Val)
#define IBackgroundCopyJob2_GetNotifyInterface(This,pVal) (This)->lpVtbl->GetNotifyInterface(This,pVal)
#define IBackgroundCopyJob2_SetMinimumRetryDelay(This,Seconds) (This)->lpVtbl->SetMinimumRetryDelay(This,Seconds)
#define IBackgroundCopyJob2_GetMinimumRetryDelay(This,Seconds) (This)->lpVtbl->GetMinimumRetryDelay(This,Seconds)
#define IBackgroundCopyJob2_SetNoProgressTimeout(This,Seconds) (This)->lpVtbl->SetNoProgressTimeout(This,Seconds)
#define IBackgroundCopyJob2_GetNoProgressTimeout(This,Seconds) (This)->lpVtbl->GetNoProgressTimeout(This,Seconds)
#define IBackgroundCopyJob2_GetErrorCount(This,Errors) (This)->lpVtbl->GetErrorCount(This,Errors)
#define IBackgroundCopyJob2_SetProxySettings(This,ProxyUsage,ProxyList,ProxyBypassList) (This)->lpVtbl->SetProxySettings(This,ProxyUsage,ProxyList,ProxyBypassList)
#define IBackgroundCopyJob2_GetProxySettings(This,pProxyUsage,pProxyList,pProxyBypassList) (This)->lpVtbl->GetProxySettings(This,pProxyUsage,pProxyList,pProxyBypassList)
#define IBackgroundCopyJob2_TakeOwnership(This) (This)->lpVtbl->TakeOwnership(This)
#define IBackgroundCopyJob2_SetNotifyCmdLine(This,Program,Parameters) (This)->lpVtbl->SetNotifyCmdLine(This,Program,Parameters)
#define IBackgroundCopyJob2_GetNotifyCmdLine(This,pProgram,pParameters) (This)->lpVtbl->GetNotifyCmdLine(This,pProgram,pParameters)
#define IBackgroundCopyJob2_GetReplyProgress(This,pProgress) (This)->lpVtbl->GetReplyProgress(This,pProgress)
#define IBackgroundCopyJob2_GetReplyData(This,ppBuffer,pLength) (This)->lpVtbl->GetReplyData(This,ppBuffer,pLength)
#define IBackgroundCopyJob2_SetReplyFileName(This,ReplyFileName) (This)->lpVtbl->SetReplyFileName(This,ReplyFileName)
#define IBackgroundCopyJob2_GetReplyFileName(This,pReplyFileName) (This)->lpVtbl->GetReplyFileName(This,pReplyFileName)
#define IBackgroundCopyJob2_SetCredentials(This,credentials) (This)->lpVtbl->SetCredentials(This,credentials)
#define IBackgroundCopyJob2_RemoveCredentials(This,Target,Scheme) (This)->lpVtbl->RemoveCredentials(This,Target,Scheme)
#endif
#endif
  HRESULT WINAPI IBackgroundCopyJob2_SetNotifyCmdLine_Proxy(IBackgroundCopyJob2 *This,LPCWSTR Program,LPCWSTR Parameters);
  void __RPC_STUB IBackgroundCopyJob2_SetNotifyCmdLine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_GetNotifyCmdLine_Proxy(IBackgroundCopyJob2 *This,LPWSTR *pProgram,LPWSTR *pParameters);
  void __RPC_STUB IBackgroundCopyJob2_GetNotifyCmdLine_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_GetReplyProgress_Proxy(IBackgroundCopyJob2 *This,BG_JOB_REPLY_PROGRESS *pProgress);
  void __RPC_STUB IBackgroundCopyJob2_GetReplyProgress_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_GetReplyData_Proxy(IBackgroundCopyJob2 *This,byte **ppBuffer,UINT64 *pLength);
  void __RPC_STUB IBackgroundCopyJob2_GetReplyData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_SetReplyFileName_Proxy(IBackgroundCopyJob2 *This,LPCWSTR ReplyFileName);
  void __RPC_STUB IBackgroundCopyJob2_SetReplyFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_GetReplyFileName_Proxy(IBackgroundCopyJob2 *This,LPWSTR *pReplyFileName);
  void __RPC_STUB IBackgroundCopyJob2_GetReplyFileName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_SetCredentials_Proxy(IBackgroundCopyJob2 *This,BG_AUTH_CREDENTIALS *credentials);
  void __RPC_STUB IBackgroundCopyJob2_SetCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBackgroundCopyJob2_RemoveCredentials_Proxy(IBackgroundCopyJob2 *This,BG_AUTH_TARGET Target,BG_AUTH_SCHEME Scheme);
  void __RPC_STUB IBackgroundCopyJob2_RemoveCredentials_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __BackgroundCopyManager1_5_LIBRARY_DEFINED__
#define __BackgroundCopyManager1_5_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_BackgroundCopyManager1_5;
  EXTERN_C const CLSID CLSID_BackgroundCopyManager1_5;
#ifdef __cplusplus
  class BackgroundCopyManager1_5;
#endif
#endif

#include "bits2_0.h"

  extern RPC_IF_HANDLE __MIDL_itf_bits1_5_0124_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_bits1_5_0124_v0_0_s_ifspec;

#ifdef __cplusplus
}
#endif
#endif
