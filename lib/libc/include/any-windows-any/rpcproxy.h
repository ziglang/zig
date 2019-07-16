/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __RPCPROXY_H_VERSION__
#define __RPCPROXY_H_VERSION__ (475)
#endif

#ifndef __RPCPROXY_H__
#define __RPCPROXY_H__
#define __midl_proxy

#ifdef __REQUIRED_RPCPROXY_H_VERSION__
#if (475 < __REQUIRED_RPCPROXY_H_VERSION__)
#error Incorrect <rpcproxy.h> version. Use the header that matches with the MIDL compiler.
#endif
#endif

#if defined(__ia64__) || defined(__x86_64)
#include <pshpack8.h>
#endif

#include <basetsd.h>

#ifndef INC_OLE2
#define INC_OLE2
#endif

#ifndef GUID_DEFINED
#include <guiddef.h>
#endif
#if defined(__cplusplus)
extern "C" {
#endif
  struct tagCInterfaceStubVtbl;
  struct tagCInterfaceProxyVtbl;

  typedef struct tagCInterfaceStubVtbl *PCInterfaceStubVtblList;
  typedef struct tagCInterfaceProxyVtbl *PCInterfaceProxyVtblList;
  typedef const char *PCInterfaceName;
  typedef int __stdcall IIDLookupRtn(const IID *pIID,int *pIndex);
  typedef IIDLookupRtn *PIIDLookup;

  typedef struct tagProxyFileInfo {
    const PCInterfaceProxyVtblList *pProxyVtblList;
    const PCInterfaceStubVtblList *pStubVtblList;
    const PCInterfaceName *pNamesArray;
    const IID **pDelegatedIIDs;
    const PIIDLookup pIIDLookupRtn;
    unsigned short TableSize;
    unsigned short TableVersion;
    const IID **pAsyncIIDLookup;
    LONG_PTR Filler2;
    LONG_PTR Filler3;
    LONG_PTR Filler4;
  } ProxyFileInfo;

  typedef ProxyFileInfo ExtendedProxyFileInfo;

#include <rpc.h>
#include <rpcndr.h>
#include <string.h>
#include <memory.h>

  typedef struct tagCInterfaceProxyHeader {
#ifdef USE_STUBLESS_PROXY
    const void *pStublessProxyInfo;
#endif
    const IID *piid;
  } CInterfaceProxyHeader;

#define CINTERFACE_PROXY_VTABLE(n) struct { CInterfaceProxyHeader header; void *Vtbl[n ]; }

  typedef struct tagCInterfaceProxyVtbl {
    CInterfaceProxyHeader header;
    void *Vtbl[];
  } CInterfaceProxyVtbl;

  typedef void (__RPC_STUB *PRPC_STUB_FUNCTION)(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *pdwStubPhase);

  typedef struct tagCInterfaceStubHeader {
    const IID *piid;
    const MIDL_SERVER_INFO *pServerInfo;
    unsigned __LONG32 DispatchTableCount;
    const PRPC_STUB_FUNCTION *pDispatchTable;
  } CInterfaceStubHeader;

  typedef struct tagCInterfaceStubVtbl {
    CInterfaceStubHeader header;
    IRpcStubBufferVtbl Vtbl;
  } CInterfaceStubVtbl;

  typedef struct tagCStdStubBuffer {
    const struct IRpcStubBufferVtbl *lpVtbl;
    __LONG32 RefCount;
    struct IUnknown *pvServerObject;
    const struct ICallFactoryVtbl *pCallFactoryVtbl;
    const IID *pAsyncIID;
    struct IPSFactoryBuffer *pPSFactory;
    const struct IReleaseMarshalBuffersVtbl *pRMBVtbl;
  } CStdStubBuffer;

  typedef struct tagCStdPSFactoryBuffer {
    const IPSFactoryBufferVtbl *lpVtbl;
    __LONG32 RefCount;
    const ProxyFileInfo **pProxyFileList;
    __LONG32 Filler1;
  } CStdPSFactoryBuffer;

  RPCRTAPI void RPC_ENTRY NdrProxyInitialize(void *This,PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,unsigned int ProcNum);
  RPCRTAPI void RPC_ENTRY NdrProxyGetBuffer(void *This,PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI void RPC_ENTRY NdrProxySendReceive(void *This,MIDL_STUB_MESSAGE *pStubMsg);
  RPCRTAPI void RPC_ENTRY NdrProxyFreeBuffer(void *This,MIDL_STUB_MESSAGE *pStubMsg);
  RPCRTAPI HRESULT RPC_ENTRY NdrProxyErrorHandler(DWORD dwExceptionCode);
  RPCRTAPI void RPC_ENTRY NdrStubInitialize(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,IRpcChannelBuffer *pRpcChannelBuffer);
  RPCRTAPI void RPC_ENTRY NdrStubInitializePartial(PRPC_MESSAGE pRpcMsg,PMIDL_STUB_MESSAGE pStubMsg,PMIDL_STUB_DESC pStubDescriptor,IRpcChannelBuffer *pRpcChannelBuffer,unsigned __LONG32 RequestedBufferSize);
  void __RPC_STUB NdrStubForwardingFunction(IRpcStubBuffer *This,IRpcChannelBuffer *pChannel,PRPC_MESSAGE pmsg,DWORD *pdwStubPhase);
  RPCRTAPI void RPC_ENTRY NdrStubGetBuffer(IRpcStubBuffer *This,IRpcChannelBuffer *pRpcChannelBuffer,PMIDL_STUB_MESSAGE pStubMsg);
  RPCRTAPI HRESULT RPC_ENTRY NdrStubErrorHandler(DWORD dwExceptionCode);
  HRESULT WINAPI CStdStubBuffer_QueryInterface(IRpcStubBuffer *This,REFIID riid,void **ppvObject);
  ULONG WINAPI CStdStubBuffer_AddRef(IRpcStubBuffer *This);
  ULONG WINAPI CStdStubBuffer_Release(IRpcStubBuffer *This);
  ULONG WINAPI NdrCStdStubBuffer_Release(IRpcStubBuffer *This,IPSFactoryBuffer *pPSF);
  HRESULT WINAPI CStdStubBuffer_Connect(IRpcStubBuffer *This,IUnknown *pUnkServer);
  void WINAPI CStdStubBuffer_Disconnect(IRpcStubBuffer *This);
  HRESULT WINAPI CStdStubBuffer_Invoke(IRpcStubBuffer *This,RPCOLEMESSAGE *pRpcMsg,IRpcChannelBuffer *pRpcChannelBuffer);
  IRpcStubBuffer *WINAPI CStdStubBuffer_IsIIDSupported(IRpcStubBuffer *This,REFIID riid);
  ULONG WINAPI CStdStubBuffer_CountRefs(IRpcStubBuffer *This);
  HRESULT WINAPI CStdStubBuffer_DebugServerQueryInterface(IRpcStubBuffer *This,void **ppv);
  void WINAPI CStdStubBuffer_DebugServerRelease(IRpcStubBuffer *This,void *pv);

#define CStdStubBuffer_METHODS CStdStubBuffer_QueryInterface,CStdStubBuffer_AddRef,CStdStubBuffer_Release,CStdStubBuffer_Connect,CStdStubBuffer_Disconnect,CStdStubBuffer_Invoke,CStdStubBuffer_IsIIDSupported,CStdStubBuffer_CountRefs,CStdStubBuffer_DebugServerQueryInterface,CStdStubBuffer_DebugServerRelease
#define CStdAsyncStubBuffer_METHODS 0,0,0,0,0,0,0,0,0,0
#define CStdAsyncStubBuffer_DELEGATING_METHODS 0,0,0,0,0,0,0,0,0,0

#define IID_GENERIC_CHECK_IID(name,pIID,index) memcmp(pIID,name##_ProxyVtblList[index ]->header.piid,16)
#define IID_BS_LOOKUP_SETUP int result,low=-1;
#define IID_BS_LOOKUP_INITIAL_TEST(name,sz,split) result = name##_CHECK_IID(split); if (result > 0) { low = sz - split; } else if (!result) { low = split; goto found_label; }
#define IID_BS_LOOKUP_NEXT_TEST(name,split) result = name##_CHECK_IID(low + split); if (result >= 0) { low = low + split; if (!result) goto found_label; }
#define IID_BS_LOOKUP_RETURN_RESULT(name,sz,index) low = low + 1; if (low >= sz) goto not_found_label; result = name##_CHECK_IID(low); if (result) goto not_found_label; found_label: (index) = low; return 1; not_found_label: return 0;

  RPCRTAPI HRESULT RPC_ENTRY NdrDllGetClassObject(REFCLSID rclsid,REFIID riid,void **ppv,const ProxyFileInfo **pProxyFileList,const CLSID *pclsid,CStdPSFactoryBuffer *pPSFactoryBuffer);
  RPCRTAPI HRESULT RPC_ENTRY NdrDllCanUnloadNow(CStdPSFactoryBuffer *pPSFactoryBuffer);

#ifndef ENTRY_PREFIX
#ifndef DllMain
#define DISABLE_THREAD_LIBRARY_CALLS(x) DisableThreadLibraryCalls(x)
#endif

#define ENTRY_PREFIX
#define DLLREGISTERSERVER_ENTRY DllRegisterServer
#define DLLUNREGISTERSERVER_ENTRY DllUnregisterServer
#define DLLMAIN_ENTRY DllMain

#define DLLGETCLASSOBJECT_ENTRY DllGetClassObject
#define DLLCANUNLOADNOW_ENTRY DllCanUnloadNow
#else
#define __rpc_macro_expand2(a,b) a##b
#define __rpc_macro_expand(a,b) __rpc_macro_expand2(a,b)
#define DLLREGISTERSERVER_ENTRY __rpc_macro_expand(ENTRY_PREFIX,DllRegisterServer)
#define DLLUNREGISTERSERVER_ENTRY __rpc_macro_expand(ENTRY_PREFIX,DllUnregisterServer)
#define DLLMAIN_ENTRY __rpc_macro_expand(ENTRY_PREFIX,DllMain)

#define DLLGETCLASSOBJECT_ENTRY __rpc_macro_expand(ENTRY_PREFIX,DllGetClassObject)
#define DLLCANUNLOADNOW_ENTRY __rpc_macro_expand(ENTRY_PREFIX,DllCanUnloadNow)
#endif

#ifndef DISABLE_THREAD_LIBRARY_CALLS
#define DISABLE_THREAD_LIBRARY_CALLS(x)
#endif

  RPCRTAPI HRESULT RPC_ENTRY NdrDllRegisterProxy(HMODULE hDll,const ProxyFileInfo **pProxyFileList,const CLSID *pclsid);
  RPCRTAPI HRESULT RPC_ENTRY NdrDllUnregisterProxy(HMODULE hDll,const ProxyFileInfo **pProxyFileList,const CLSID *pclsid);

#define REGISTER_PROXY_DLL_ROUTINES(pProxyFileList,pClsID) HINSTANCE hProxyDll = 0; WINBOOL WINAPI DLLMAIN_ENTRY(HINSTANCE hinstDLL,DWORD fdwReason,LPVOID lpvReserved) { if(fdwReason==DLL_PROCESS_ATTACH) { hProxyDll = hinstDLL; DISABLE_THREAD_LIBRARY_CALLS(hinstDLL); } return TRUE; } HRESULT WINAPI DLLREGISTERSERVER_ENTRY() { return NdrDllRegisterProxy(hProxyDll,pProxyFileList,pClsID); } HRESULT WINAPI DLLUNREGISTERSERVER_ENTRY() { return NdrDllUnregisterProxy(hProxyDll,pProxyFileList,pClsID); }
#define STUB_FORWARDING_FUNCTION NdrStubForwardingFunction

  ULONG WINAPI CStdStubBuffer2_Release(IRpcStubBuffer *This);
  ULONG WINAPI NdrCStdStubBuffer2_Release(IRpcStubBuffer *This,IPSFactoryBuffer *pPSF);

#define CStdStubBuffer_DELEGATING_METHODS 0,0,CStdStubBuffer2_Release,0,0,0,0,0,0,0

#ifdef PROXY_CLSID
#define CLSID_PSFACTORYBUFFER extern CLSID PROXY_CLSID;
#else
#ifdef PROXY_CLSID_IS
#define CLSID_PSFACTORYBUFFER const CLSID CLSID_PSFactoryBuffer = PROXY_CLSID_IS;
#define PROXY_CLSID CLSID_PSFactoryBuffer
#else
#define CLSID_PSFACTORYBUFFER
#endif
#endif

#ifndef PROXY_CLSID
#define GET_DLL_CLSID (aProxyFileList[0]->pStubVtblList[0]!=0 ? aProxyFileList[0]->pStubVtblList[0]->header.piid : 0)
#else
#define GET_DLL_CLSID &PROXY_CLSID
#endif

#define EXTERN_PROXY_FILE(name) EXTERN_C const ProxyFileInfo name##_ProxyFileInfo;
#define PROXYFILE_LIST_START const ProxyFileInfo *aProxyFileList[] = {
#define REFERENCE_PROXY_FILE(name) & name##_ProxyFileInfo
#define PROXYFILE_LIST_END 0 };
#define DLLDATA_GETPROXYDLLINFO(pPFList,pClsid) void RPC_ENTRY GetProxyDllInfo(const ProxyFileInfo***pInfo,const CLSID **pId) { *pInfo = pPFList; *pId = pClsid; }
#define DLLGETCLASSOBJECTROUTINE(pPFlist,pClsid,pFactory) HRESULT WINAPI DLLGETCLASSOBJECT_ENTRY (REFCLSID rclsid,REFIID riid,void **ppv) { return NdrDllGetClassObject(rclsid,riid,ppv,pPFlist,pClsid,pFactory); }
#define DLLCANUNLOADNOW(pFactory) HRESULT WINAPI DLLCANUNLOADNOW_ENTRY() { return NdrDllCanUnloadNow(pFactory); }
#define DLLDUMMYPURECALL void __cdecl _purecall(void) { }
#define CSTDSTUBBUFFERRELEASE(pFactory) ULONG WINAPI CStdStubBuffer_Release(IRpcStubBuffer *This) { return NdrCStdStubBuffer_Release(This,(IPSFactoryBuffer *)pFactory); }
#ifdef PROXY_DELEGATION
#define CSTDSTUBBUFFER2RELEASE(pFactory) ULONG WINAPI CStdStubBuffer2_Release(IRpcStubBuffer *This) { return NdrCStdStubBuffer2_Release(This,(IPSFactoryBuffer *)pFactory); }
#else
#define CSTDSTUBBUFFER2RELEASE(pFactory)
#endif

#ifdef REGISTER_PROXY_DLL
#define DLLREGISTRY_ROUTINES(pProxyFileList,pClsID) REGISTER_PROXY_DLL_ROUTINES(pProxyFileList,pClsID)
#else
#define DLLREGISTRY_ROUTINES(pProxyFileList,pClsID)
#endif

#define DLLDATA_ROUTINES(pProxyFileList,pClsID) CLSID_PSFACTORYBUFFER CStdPSFactoryBuffer gPFactory = {0,0,0,0}; DLLDATA_GETPROXYDLLINFO(pProxyFileList,pClsID) DLLGETCLASSOBJECTROUTINE(pProxyFileList,pClsID,&gPFactory) DLLCANUNLOADNOW(&gPFactory) CSTDSTUBBUFFERRELEASE(&gPFactory) CSTDSTUBBUFFER2RELEASE(&gPFactory) DLLDUMMYPURECALL DLLREGISTRY_ROUTINES(pProxyFileList,pClsID)
#define DLLDATA_STANDARD_ROUTINES DLLDATA_ROUTINES((const ProxyFileInfo**) pProxyFileList,&CLSID_PSFactoryBuffer)

#if defined(__cplusplus)
}
#endif

#if defined(__ia64__) || defined(__x86_64)
#include <poppack.h>
#endif
#endif
