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

#ifndef __callobj_h__
#define __callobj_h__

#ifndef __ICallFrame_FWD_DEFINED__
#define __ICallFrame_FWD_DEFINED__
typedef struct ICallFrame ICallFrame;
#endif

#ifndef __ICallIndirect_FWD_DEFINED__
#define __ICallIndirect_FWD_DEFINED__
typedef struct ICallIndirect ICallIndirect;
#endif

#ifndef __ICallInterceptor_FWD_DEFINED__
#define __ICallInterceptor_FWD_DEFINED__
typedef struct ICallInterceptor ICallInterceptor;
#endif

#ifndef __ICallFrameEvents_FWD_DEFINED__
#define __ICallFrameEvents_FWD_DEFINED__
typedef struct ICallFrameEvents ICallFrameEvents;
#endif

#ifndef __ICallUnmarshal_FWD_DEFINED__
#define __ICallUnmarshal_FWD_DEFINED__
typedef struct ICallUnmarshal ICallUnmarshal;
#endif

#ifndef __ICallFrameWalker_FWD_DEFINED__
#define __ICallFrameWalker_FWD_DEFINED__
typedef struct ICallFrameWalker ICallFrameWalker;
#endif

#ifndef __IInterfaceRelated_FWD_DEFINED__
#define __IInterfaceRelated_FWD_DEFINED__
typedef struct IInterfaceRelated IInterfaceRelated;
#endif

#include "oaidl.h"

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

  extern RPC_IF_HANDLE __MIDL_itf_callobj_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_callobj_0000_v0_0_s_ifspec;

#ifndef __ICallFrame_INTERFACE_DEFINED__
#define __ICallFrame_INTERFACE_DEFINED__

  typedef struct __MIDL_ICallFrame_0001 {
    ULONG iMethod;
    WINBOOL fHasInValues;
    WINBOOL fHasInOutValues;
    WINBOOL fHasOutValues;
    WINBOOL fDerivesFromIDispatch;
    LONG cInInterfacesMax;
    LONG cInOutInterfacesMax;
    LONG cOutInterfacesMax;
    LONG cTopLevelInInterfaces;
    IID iid;
    ULONG cMethod;
    ULONG cParams;
  } CALLFRAMEINFO;

  typedef struct __MIDL_ICallFrame_0002 {
    BOOLEAN fIn;
    BOOLEAN fOut;
    ULONG stackOffset;
    ULONG cbParam;
  } CALLFRAMEPARAMINFO;

  typedef enum __MIDL_ICallFrame_0003 {
    CALLFRAME_COPY_NESTED = 1,CALLFRAME_COPY_INDEPENDENT = 2
  } CALLFRAME_COPY;

  enum CALLFRAME_FREE {
    CALLFRAME_FREE_NONE = 0,CALLFRAME_FREE_IN = 1,CALLFRAME_FREE_INOUT = 2,CALLFRAME_FREE_OUT = 4,CALLFRAME_FREE_TOP_INOUT = 8,
    CALLFRAME_FREE_TOP_OUT = 16,CALLFRAME_FREE_ALL = 31
  };

  enum CALLFRAME_NULL {
    CALLFRAME_NULL_NONE = 0,CALLFRAME_NULL_INOUT = 2,CALLFRAME_NULL_OUT = 4,CALLFRAME_NULL_ALL = 6
  };

  enum CALLFRAME_WALK {
    CALLFRAME_WALK_IN = 1,CALLFRAME_WALK_INOUT = 2,CALLFRAME_WALK_OUT = 4
  };

  typedef struct __MIDL_ICallFrame_0004 {
    BOOLEAN fIn;
    DWORD dwDestContext;
    LPVOID pvDestContext;
    IUnknown *punkReserved;
    GUID guidTransferSyntax;
  } CALLFRAME_MARSHALCONTEXT;

  EXTERN_C const IID IID_ICallFrame;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallFrame : public IUnknown {
  public:
    virtual HRESULT WINAPI GetInfo(CALLFRAMEINFO *pInfo) = 0;
    virtual HRESULT WINAPI GetIIDAndMethod(IID *pIID,ULONG *piMethod) = 0;
    virtual HRESULT WINAPI GetNames(LPWSTR *pwszInterface,LPWSTR *pwszMethod) = 0;
    virtual PVOID WINAPI GetStackLocation(void) = 0;
    virtual void WINAPI SetStackLocation(PVOID pvStack) = 0;
    virtual void WINAPI SetReturnValue(HRESULT hr) = 0;
    virtual HRESULT WINAPI GetReturnValue(void) = 0;
    virtual HRESULT WINAPI GetParamInfo(ULONG iparam,CALLFRAMEPARAMINFO *pInfo) = 0;
    virtual HRESULT WINAPI SetParam(ULONG iparam,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI GetParam(ULONG iparam,VARIANT *pvar) = 0;
    virtual HRESULT WINAPI Copy(CALLFRAME_COPY copyControl,ICallFrameWalker *pWalker,ICallFrame **ppFrame) = 0;
    virtual HRESULT WINAPI Free(ICallFrame *pframeArgsDest,ICallFrameWalker *pWalkerDestFree,ICallFrameWalker *pWalkerCopy,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags) = 0;
    virtual HRESULT WINAPI FreeParam(ULONG iparam,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags) = 0;
    virtual HRESULT WINAPI WalkFrame(DWORD walkWhat,ICallFrameWalker *pWalker) = 0;
    virtual HRESULT WINAPI GetMarshalSizeMax(CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,ULONG *pcbBufferNeeded) = 0;
    virtual HRESULT WINAPI Marshal(CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,PVOID pBuffer,ULONG cbBuffer,ULONG *pcbBufferUsed,RPCOLEDATAREP *pdataRep,ULONG *prpcFlags) = 0;
    virtual HRESULT WINAPI Unmarshal(PVOID pBuffer,ULONG cbBuffer,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled) = 0;
    virtual HRESULT WINAPI ReleaseMarshalData(PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext) = 0;
    virtual HRESULT WINAPI Invoke(void *pvReceiver,...) = 0;
  };
#else
  typedef struct ICallFrameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallFrame *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallFrame *This);
      ULONG (WINAPI *Release)(ICallFrame *This);
      HRESULT (WINAPI *GetInfo)(ICallFrame *This,CALLFRAMEINFO *pInfo);
      HRESULT (WINAPI *GetIIDAndMethod)(ICallFrame *This,IID *pIID,ULONG *piMethod);
      HRESULT (WINAPI *GetNames)(ICallFrame *This,LPWSTR *pwszInterface,LPWSTR *pwszMethod);
      PVOID (WINAPI *GetStackLocation)(ICallFrame *This);
      void (WINAPI *SetStackLocation)(ICallFrame *This,PVOID pvStack);
      void (WINAPI *SetReturnValue)(ICallFrame *This,HRESULT hr);
      HRESULT (WINAPI *GetReturnValue)(ICallFrame *This);
      HRESULT (WINAPI *GetParamInfo)(ICallFrame *This,ULONG iparam,CALLFRAMEPARAMINFO *pInfo);
      HRESULT (WINAPI *SetParam)(ICallFrame *This,ULONG iparam,VARIANT *pvar);
      HRESULT (WINAPI *GetParam)(ICallFrame *This,ULONG iparam,VARIANT *pvar);
      HRESULT (WINAPI *Copy)(ICallFrame *This,CALLFRAME_COPY copyControl,ICallFrameWalker *pWalker,ICallFrame **ppFrame);
      HRESULT (WINAPI *Free)(ICallFrame *This,ICallFrame *pframeArgsDest,ICallFrameWalker *pWalkerDestFree,ICallFrameWalker *pWalkerCopy,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags);
      HRESULT (WINAPI *FreeParam)(ICallFrame *This,ULONG iparam,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags);
      HRESULT (WINAPI *WalkFrame)(ICallFrame *This,DWORD walkWhat,ICallFrameWalker *pWalker);
      HRESULT (WINAPI *GetMarshalSizeMax)(ICallFrame *This,CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,ULONG *pcbBufferNeeded);
      HRESULT (WINAPI *Marshal)(ICallFrame *This,CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,PVOID pBuffer,ULONG cbBuffer,ULONG *pcbBufferUsed,RPCOLEDATAREP *pdataRep,ULONG *prpcFlags);
      HRESULT (WINAPI *Unmarshal)(ICallFrame *This,PVOID pBuffer,ULONG cbBuffer,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled);
      HRESULT (WINAPI *ReleaseMarshalData)(ICallFrame *This,PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext);
      HRESULT (WINAPI *Invoke)(ICallFrame *This,void *pvReceiver,...);
    END_INTERFACE
  } ICallFrameVtbl;
  struct ICallFrame {
    CONST_VTBL struct ICallFrameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallFrame_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallFrame_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallFrame_Release(This) (This)->lpVtbl->Release(This)
#define ICallFrame_GetInfo(This,pInfo) (This)->lpVtbl->GetInfo(This,pInfo)
#define ICallFrame_GetIIDAndMethod(This,pIID,piMethod) (This)->lpVtbl->GetIIDAndMethod(This,pIID,piMethod)
#define ICallFrame_GetNames(This,pwszInterface,pwszMethod) (This)->lpVtbl->GetNames(This,pwszInterface,pwszMethod)
#define ICallFrame_GetStackLocation(This) (This)->lpVtbl->GetStackLocation(This)
#define ICallFrame_SetStackLocation(This,pvStack) (This)->lpVtbl->SetStackLocation(This,pvStack)
#define ICallFrame_SetReturnValue(This,hr) (This)->lpVtbl->SetReturnValue(This,hr)
#define ICallFrame_GetReturnValue(This) (This)->lpVtbl->GetReturnValue(This)
#define ICallFrame_GetParamInfo(This,iparam,pInfo) (This)->lpVtbl->GetParamInfo(This,iparam,pInfo)
#define ICallFrame_SetParam(This,iparam,pvar) (This)->lpVtbl->SetParam(This,iparam,pvar)
#define ICallFrame_GetParam(This,iparam,pvar) (This)->lpVtbl->GetParam(This,iparam,pvar)
#define ICallFrame_Copy(This,copyControl,pWalker,ppFrame) (This)->lpVtbl->Copy(This,copyControl,pWalker,ppFrame)
#define ICallFrame_Free(This,pframeArgsDest,pWalkerDestFree,pWalkerCopy,freeFlags,pWalkerFree,nullFlags) (This)->lpVtbl->Free(This,pframeArgsDest,pWalkerDestFree,pWalkerCopy,freeFlags,pWalkerFree,nullFlags)
#define ICallFrame_FreeParam(This,iparam,freeFlags,pWalkerFree,nullFlags) (This)->lpVtbl->FreeParam(This,iparam,freeFlags,pWalkerFree,nullFlags)
#define ICallFrame_WalkFrame(This,walkWhat,pWalker) (This)->lpVtbl->WalkFrame(This,walkWhat,pWalker)
#define ICallFrame_GetMarshalSizeMax(This,pmshlContext,mshlflags,pcbBufferNeeded) (This)->lpVtbl->GetMarshalSizeMax(This,pmshlContext,mshlflags,pcbBufferNeeded)
#define ICallFrame_Marshal(This,pmshlContext,mshlflags,pBuffer,cbBuffer,pcbBufferUsed,pdataRep,prpcFlags) (This)->lpVtbl->Marshal(This,pmshlContext,mshlflags,pBuffer,cbBuffer,pcbBufferUsed,pdataRep,prpcFlags)
#define ICallFrame_Unmarshal(This,pBuffer,cbBuffer,dataRep,pcontext,pcbUnmarshalled) (This)->lpVtbl->Unmarshal(This,pBuffer,cbBuffer,dataRep,pcontext,pcbUnmarshalled)
#define ICallFrame_ReleaseMarshalData(This,pBuffer,cbBuffer,ibFirstRelease,dataRep,pcontext) (This)->lpVtbl->ReleaseMarshalData(This,pBuffer,cbBuffer,ibFirstRelease,dataRep,pcontext)
#define ICallFrame_Invoke(This,pvReceiver,...) (This)->lpVtbl->Invoke(This,pvReceiver,...)
#endif
#endif
  HRESULT WINAPI ICallFrame_GetInfo_Proxy(ICallFrame *This,CALLFRAMEINFO *pInfo);
  void __RPC_STUB ICallFrame_GetInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetIIDAndMethod_Proxy(ICallFrame *This,IID *pIID,ULONG *piMethod);
  void __RPC_STUB ICallFrame_GetIIDAndMethod_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetNames_Proxy(ICallFrame *This,LPWSTR *pwszInterface,LPWSTR *pwszMethod);
  void __RPC_STUB ICallFrame_GetNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  PVOID WINAPI ICallFrame_GetStackLocation_Proxy(ICallFrame *This);
  void __RPC_STUB ICallFrame_GetStackLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ICallFrame_SetStackLocation_Proxy(ICallFrame *This,PVOID pvStack);
  void __RPC_STUB ICallFrame_SetStackLocation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI ICallFrame_SetReturnValue_Proxy(ICallFrame *This,HRESULT hr);
  void __RPC_STUB ICallFrame_SetReturnValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetReturnValue_Proxy(ICallFrame *This);
  void __RPC_STUB ICallFrame_GetReturnValue_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetParamInfo_Proxy(ICallFrame *This,ULONG iparam,CALLFRAMEPARAMINFO *pInfo);
  void __RPC_STUB ICallFrame_GetParamInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_SetParam_Proxy(ICallFrame *This,ULONG iparam,VARIANT *pvar);
  void __RPC_STUB ICallFrame_SetParam_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetParam_Proxy(ICallFrame *This,ULONG iparam,VARIANT *pvar);
  void __RPC_STUB ICallFrame_GetParam_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_Copy_Proxy(ICallFrame *This,CALLFRAME_COPY copyControl,ICallFrameWalker *pWalker,ICallFrame **ppFrame);
  void __RPC_STUB ICallFrame_Copy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_Free_Proxy(ICallFrame *This,ICallFrame *pframeArgsDest,ICallFrameWalker *pWalkerDestFree,ICallFrameWalker *pWalkerCopy,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags);
  void __RPC_STUB ICallFrame_Free_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_FreeParam_Proxy(ICallFrame *This,ULONG iparam,DWORD freeFlags,ICallFrameWalker *pWalkerFree,DWORD nullFlags);
  void __RPC_STUB ICallFrame_FreeParam_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_WalkFrame_Proxy(ICallFrame *This,DWORD walkWhat,ICallFrameWalker *pWalker);
  void __RPC_STUB ICallFrame_WalkFrame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_GetMarshalSizeMax_Proxy(ICallFrame *This,CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,ULONG *pcbBufferNeeded);
  void __RPC_STUB ICallFrame_GetMarshalSizeMax_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_Marshal_Proxy(ICallFrame *This,CALLFRAME_MARSHALCONTEXT *pmshlContext,MSHLFLAGS mshlflags,PVOID pBuffer,ULONG cbBuffer,ULONG *pcbBufferUsed,RPCOLEDATAREP *pdataRep,ULONG *prpcFlags);
  void __RPC_STUB ICallFrame_Marshal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_Unmarshal_Proxy(ICallFrame *This,PVOID pBuffer,ULONG cbBuffer,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled);
  void __RPC_STUB ICallFrame_Unmarshal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_ReleaseMarshalData_Proxy(ICallFrame *This,PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext);
  void __RPC_STUB ICallFrame_ReleaseMarshalData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallFrame_Invoke_Proxy(ICallFrame *This,void *pvReceiver,...);
  void __RPC_STUB ICallFrame_Invoke_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICallIndirect_INTERFACE_DEFINED__
#define __ICallIndirect_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICallIndirect;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallIndirect : public IUnknown {
  public:
    virtual HRESULT WINAPI CallIndirect(HRESULT *phrReturn,ULONG iMethod,void *pvArgs,ULONG *cbArgs) = 0;
    virtual HRESULT WINAPI GetMethodInfo(ULONG iMethod,CALLFRAMEINFO *pInfo,LPWSTR *pwszMethod) = 0;
    virtual HRESULT WINAPI GetStackSize(ULONG iMethod,ULONG *cbArgs) = 0;
    virtual HRESULT WINAPI GetIID(IID *piid,WINBOOL *pfDerivesFromIDispatch,ULONG *pcMethod,LPWSTR *pwszInterface) = 0;
  };
#else
  typedef struct ICallIndirectVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallIndirect *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallIndirect *This);
      ULONG (WINAPI *Release)(ICallIndirect *This);
      HRESULT (WINAPI *CallIndirect)(ICallIndirect *This,HRESULT *phrReturn,ULONG iMethod,void *pvArgs,ULONG *cbArgs);
      HRESULT (WINAPI *GetMethodInfo)(ICallIndirect *This,ULONG iMethod,CALLFRAMEINFO *pInfo,LPWSTR *pwszMethod);
      HRESULT (WINAPI *GetStackSize)(ICallIndirect *This,ULONG iMethod,ULONG *cbArgs);
      HRESULT (WINAPI *GetIID)(ICallIndirect *This,IID *piid,WINBOOL *pfDerivesFromIDispatch,ULONG *pcMethod,LPWSTR *pwszInterface);
    END_INTERFACE
  } ICallIndirectVtbl;
  struct ICallIndirect {
    CONST_VTBL struct ICallIndirectVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallIndirect_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallIndirect_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallIndirect_Release(This) (This)->lpVtbl->Release(This)
#define ICallIndirect_CallIndirect(This,phrReturn,iMethod,pvArgs,cbArgs) (This)->lpVtbl->CallIndirect(This,phrReturn,iMethod,pvArgs,cbArgs)
#define ICallIndirect_GetMethodInfo(This,iMethod,pInfo,pwszMethod) (This)->lpVtbl->GetMethodInfo(This,iMethod,pInfo,pwszMethod)
#define ICallIndirect_GetStackSize(This,iMethod,cbArgs) (This)->lpVtbl->GetStackSize(This,iMethod,cbArgs)
#define ICallIndirect_GetIID(This,piid,pfDerivesFromIDispatch,pcMethod,pwszInterface) (This)->lpVtbl->GetIID(This,piid,pfDerivesFromIDispatch,pcMethod,pwszInterface)
#endif
#endif
  HRESULT WINAPI ICallIndirect_CallIndirect_Proxy(ICallIndirect *This,HRESULT *phrReturn,ULONG iMethod,void *pvArgs,ULONG *cbArgs);
  void __RPC_STUB ICallIndirect_CallIndirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallIndirect_GetMethodInfo_Proxy(ICallIndirect *This,ULONG iMethod,CALLFRAMEINFO *pInfo,LPWSTR *pwszMethod);
  void __RPC_STUB ICallIndirect_GetMethodInfo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallIndirect_GetStackSize_Proxy(ICallIndirect *This,ULONG iMethod,ULONG *cbArgs);
  void __RPC_STUB ICallIndirect_GetStackSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallIndirect_GetIID_Proxy(ICallIndirect *This,IID *piid,WINBOOL *pfDerivesFromIDispatch,ULONG *pcMethod,LPWSTR *pwszInterface);
  void __RPC_STUB ICallIndirect_GetIID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICallInterceptor_INTERFACE_DEFINED__
#define __ICallInterceptor_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICallInterceptor;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallInterceptor : public ICallIndirect {
  public:
    virtual HRESULT WINAPI RegisterSink(ICallFrameEvents *psink) = 0;
    virtual HRESULT WINAPI GetRegisteredSink(ICallFrameEvents **ppsink) = 0;
  };
#else
  typedef struct ICallInterceptorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallInterceptor *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallInterceptor *This);
      ULONG (WINAPI *Release)(ICallInterceptor *This);
      HRESULT (WINAPI *CallIndirect)(ICallInterceptor *This,HRESULT *phrReturn,ULONG iMethod,void *pvArgs,ULONG *cbArgs);
      HRESULT (WINAPI *GetMethodInfo)(ICallInterceptor *This,ULONG iMethod,CALLFRAMEINFO *pInfo,LPWSTR *pwszMethod);
      HRESULT (WINAPI *GetStackSize)(ICallInterceptor *This,ULONG iMethod,ULONG *cbArgs);
      HRESULT (WINAPI *GetIID)(ICallInterceptor *This,IID *piid,WINBOOL *pfDerivesFromIDispatch,ULONG *pcMethod,LPWSTR *pwszInterface);
      HRESULT (WINAPI *RegisterSink)(ICallInterceptor *This,ICallFrameEvents *psink);
      HRESULT (WINAPI *GetRegisteredSink)(ICallInterceptor *This,ICallFrameEvents **ppsink);
    END_INTERFACE
  } ICallInterceptorVtbl;
  struct ICallInterceptor {
    CONST_VTBL struct ICallInterceptorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallInterceptor_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallInterceptor_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallInterceptor_Release(This) (This)->lpVtbl->Release(This)
#define ICallInterceptor_CallIndirect(This,phrReturn,iMethod,pvArgs,cbArgs) (This)->lpVtbl->CallIndirect(This,phrReturn,iMethod,pvArgs,cbArgs)
#define ICallInterceptor_GetMethodInfo(This,iMethod,pInfo,pwszMethod) (This)->lpVtbl->GetMethodInfo(This,iMethod,pInfo,pwszMethod)
#define ICallInterceptor_GetStackSize(This,iMethod,cbArgs) (This)->lpVtbl->GetStackSize(This,iMethod,cbArgs)
#define ICallInterceptor_GetIID(This,piid,pfDerivesFromIDispatch,pcMethod,pwszInterface) (This)->lpVtbl->GetIID(This,piid,pfDerivesFromIDispatch,pcMethod,pwszInterface)
#define ICallInterceptor_RegisterSink(This,psink) (This)->lpVtbl->RegisterSink(This,psink)
#define ICallInterceptor_GetRegisteredSink(This,ppsink) (This)->lpVtbl->GetRegisteredSink(This,ppsink)
#endif
#endif
  HRESULT WINAPI ICallInterceptor_RegisterSink_Proxy(ICallInterceptor *This,ICallFrameEvents *psink);
  void __RPC_STUB ICallInterceptor_RegisterSink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallInterceptor_GetRegisteredSink_Proxy(ICallInterceptor *This,ICallFrameEvents **ppsink);
  void __RPC_STUB ICallInterceptor_GetRegisteredSink_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICallFrameEvents_INTERFACE_DEFINED__
#define __ICallFrameEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICallFrameEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallFrameEvents : public IUnknown {
  public:
    virtual HRESULT WINAPI OnCall(ICallFrame *pFrame) = 0;
  };
#else
  typedef struct ICallFrameEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallFrameEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallFrameEvents *This);
      ULONG (WINAPI *Release)(ICallFrameEvents *This);
      HRESULT (WINAPI *OnCall)(ICallFrameEvents *This,ICallFrame *pFrame);
    END_INTERFACE
  } ICallFrameEventsVtbl;
  struct ICallFrameEvents {
    CONST_VTBL struct ICallFrameEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallFrameEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallFrameEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallFrameEvents_Release(This) (This)->lpVtbl->Release(This)
#define ICallFrameEvents_OnCall(This,pFrame) (This)->lpVtbl->OnCall(This,pFrame)
#endif
#endif
  HRESULT WINAPI ICallFrameEvents_OnCall_Proxy(ICallFrameEvents *This,ICallFrame *pFrame);
  void __RPC_STUB ICallFrameEvents_OnCall_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICallUnmarshal_INTERFACE_DEFINED__
#define __ICallUnmarshal_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICallUnmarshal;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallUnmarshal : public IUnknown {
  public:
    virtual HRESULT WINAPI Unmarshal(ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,WINBOOL fForceBufferCopy,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled,ICallFrame **ppFrame) = 0;
    virtual HRESULT WINAPI ReleaseMarshalData(ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext) = 0;
  };
#else
  typedef struct ICallUnmarshalVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallUnmarshal *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallUnmarshal *This);
      ULONG (WINAPI *Release)(ICallUnmarshal *This);
      HRESULT (WINAPI *Unmarshal)(ICallUnmarshal *This,ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,WINBOOL fForceBufferCopy,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled,ICallFrame **ppFrame);
      HRESULT (WINAPI *ReleaseMarshalData)(ICallUnmarshal *This,ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext);
    END_INTERFACE
  } ICallUnmarshalVtbl;
  struct ICallUnmarshal {
    CONST_VTBL struct ICallUnmarshalVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallUnmarshal_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallUnmarshal_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallUnmarshal_Release(This) (This)->lpVtbl->Release(This)
#define ICallUnmarshal_Unmarshal(This,iMethod,pBuffer,cbBuffer,fForceBufferCopy,dataRep,pcontext,pcbUnmarshalled,ppFrame) (This)->lpVtbl->Unmarshal(This,iMethod,pBuffer,cbBuffer,fForceBufferCopy,dataRep,pcontext,pcbUnmarshalled,ppFrame)
#define ICallUnmarshal_ReleaseMarshalData(This,iMethod,pBuffer,cbBuffer,ibFirstRelease,dataRep,pcontext) (This)->lpVtbl->ReleaseMarshalData(This,iMethod,pBuffer,cbBuffer,ibFirstRelease,dataRep,pcontext)
#endif
#endif
  HRESULT WINAPI ICallUnmarshal_Unmarshal_Proxy(ICallUnmarshal *This,ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,WINBOOL fForceBufferCopy,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext,ULONG *pcbUnmarshalled,ICallFrame **ppFrame);
  void __RPC_STUB ICallUnmarshal_Unmarshal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ICallUnmarshal_ReleaseMarshalData_Proxy(ICallUnmarshal *This,ULONG iMethod,PVOID pBuffer,ULONG cbBuffer,ULONG ibFirstRelease,RPCOLEDATAREP dataRep,CALLFRAME_MARSHALCONTEXT *pcontext);
  void __RPC_STUB ICallUnmarshal_ReleaseMarshalData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ICallFrameWalker_INTERFACE_DEFINED__
#define __ICallFrameWalker_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ICallFrameWalker;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ICallFrameWalker : public IUnknown {
  public:
    virtual HRESULT WINAPI OnWalkInterface(REFIID iid,PVOID *ppvInterface,WINBOOL fIn,WINBOOL fOut) = 0;
  };
#else
  typedef struct ICallFrameWalkerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ICallFrameWalker *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ICallFrameWalker *This);
      ULONG (WINAPI *Release)(ICallFrameWalker *This);
      HRESULT (WINAPI *OnWalkInterface)(ICallFrameWalker *This,REFIID iid,PVOID *ppvInterface,WINBOOL fIn,WINBOOL fOut);
    END_INTERFACE
  } ICallFrameWalkerVtbl;
  struct ICallFrameWalker {
    CONST_VTBL struct ICallFrameWalkerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ICallFrameWalker_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ICallFrameWalker_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ICallFrameWalker_Release(This) (This)->lpVtbl->Release(This)
#define ICallFrameWalker_OnWalkInterface(This,iid,ppvInterface,fIn,fOut) (This)->lpVtbl->OnWalkInterface(This,iid,ppvInterface,fIn,fOut)
#endif
#endif
  HRESULT WINAPI ICallFrameWalker_OnWalkInterface_Proxy(ICallFrameWalker *This,REFIID iid,PVOID *ppvInterface,WINBOOL fIn,WINBOOL fOut);
  void __RPC_STUB ICallFrameWalker_OnWalkInterface_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IInterfaceRelated_INTERFACE_DEFINED__
#define __IInterfaceRelated_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IInterfaceRelated;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IInterfaceRelated : public IUnknown {
  public:
    virtual HRESULT WINAPI SetIID(REFIID iid) = 0;
    virtual HRESULT WINAPI GetIID(IID *piid) = 0;
  };
#else
  typedef struct IInterfaceRelatedVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IInterfaceRelated *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IInterfaceRelated *This);
      ULONG (WINAPI *Release)(IInterfaceRelated *This);
      HRESULT (WINAPI *SetIID)(IInterfaceRelated *This,REFIID iid);
      HRESULT (WINAPI *GetIID)(IInterfaceRelated *This,IID *piid);
    END_INTERFACE
  } IInterfaceRelatedVtbl;
  struct IInterfaceRelated {
    CONST_VTBL struct IInterfaceRelatedVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IInterfaceRelated_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IInterfaceRelated_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IInterfaceRelated_Release(This) (This)->lpVtbl->Release(This)
#define IInterfaceRelated_SetIID(This,iid) (This)->lpVtbl->SetIID(This,iid)
#define IInterfaceRelated_GetIID(This,piid) (This)->lpVtbl->GetIID(This,piid)
#endif
#endif
  HRESULT WINAPI IInterfaceRelated_SetIID_Proxy(IInterfaceRelated *This,REFIID iid);
  void __RPC_STUB IInterfaceRelated_SetIID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IInterfaceRelated_GetIID_Proxy(IInterfaceRelated *This,IID *piid);
  void __RPC_STUB IInterfaceRelated_GetIID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#define CALLFRAME_E_ALREADYINVOKED _HRESULT_TYPEDEF_(0x8004d090)
#define CALLFRAME_E_COULDNTMAKECALL _HRESULT_TYPEDEF_(0x8004d091)

  extern RPC_IF_HANDLE __MIDL_itf_callobj_0122_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_callobj_0122_v0_0_s_ifspec;

#ifndef __ICallFrameAPIs_INTERFACE_DEFINED__
#define __ICallFrameAPIs_INTERFACE_DEFINED__
  HRESULT WINAPI CoGetInterceptor(REFIID iidIntercepted,IUnknown *punkOuter,REFIID iid,void **ppv);
  HRESULT WINAPI CoGetInterceptorFromTypeInfo(REFIID iidIntercepted,IUnknown *punkOuter,ITypeInfo *typeInfo,REFIID iid,void **ppv);

  extern RPC_IF_HANDLE ICallFrameAPIs_v0_0_c_ifspec;
  extern RPC_IF_HANDLE ICallFrameAPIs_v0_0_s_ifspec;
#endif

#ifdef __cplusplus
}
#endif
#endif
