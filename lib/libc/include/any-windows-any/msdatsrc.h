/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __REQUIRED_RPCNDR_H_VERSION__
#define __REQUIRED_RPCNDR_H_VERSION__ 440
#endif

#include "rpc.h"
#include "rpcndr.h"

#ifndef __msdatsrc_h__
#define __msdatsrc_h__

#ifndef __DataSourceListener_FWD_DEFINED__
#define __DataSourceListener_FWD_DEFINED__
typedef struct DataSourceListener DataSourceListener;
#endif

#ifndef __DataSource_FWD_DEFINED__
#define __DataSource_FWD_DEFINED__
typedef struct DataSource DataSource;
#endif

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define IDataSource DataSource
#define IDataSourceListener DataSourceListener

  EXTERN_C const IID CATID_DataSource;
  EXTERN_C const IID CATID_DataConsumer;

  extern RPC_IF_HANDLE __MIDL_itf_msdatsrc_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_msdatsrc_0000_v0_0_s_ifspec;

#ifndef __MSDATASRC_LIBRARY_DEFINED__
#define __MSDATASRC_LIBRARY_DEFINED__
  typedef BSTR DataMember;

  EXTERN_C const IID LIBID_MSDATASRC;
#ifndef __DataSourceListener_INTERFACE_DEFINED__
#define __DataSourceListener_INTERFACE_DEFINED__
  EXTERN_C const IID IID_DataSourceListener;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DataSourceListener : public IUnknown {
  public:
    virtual HRESULT WINAPI dataMemberChanged(DataMember bstrDM) = 0;
    virtual HRESULT WINAPI dataMemberAdded(DataMember bstrDM) = 0;
    virtual HRESULT WINAPI dataMemberRemoved(DataMember bstrDM) = 0;
  };
#else
  typedef struct DataSourceListenerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DataSourceListener *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DataSourceListener *This);
      ULONG (WINAPI *Release)(DataSourceListener *This);
      HRESULT (WINAPI *dataMemberChanged)(DataSourceListener *This,DataMember bstrDM);
      HRESULT (WINAPI *dataMemberAdded)(DataSourceListener *This,DataMember bstrDM);
      HRESULT (WINAPI *dataMemberRemoved)(DataSourceListener *This,DataMember bstrDM);
    END_INTERFACE
  } DataSourceListenerVtbl;
  struct DataSourceListener {
    CONST_VTBL struct DataSourceListenerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DataSourceListener_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DataSourceListener_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DataSourceListener_Release(This) (This)->lpVtbl->Release(This)
#define DataSourceListener_dataMemberChanged(This,bstrDM) (This)->lpVtbl->dataMemberChanged(This,bstrDM)
#define DataSourceListener_dataMemberAdded(This,bstrDM) (This)->lpVtbl->dataMemberAdded(This,bstrDM)
#define DataSourceListener_dataMemberRemoved(This,bstrDM) (This)->lpVtbl->dataMemberRemoved(This,bstrDM)
#endif
#endif
  HRESULT WINAPI DataSourceListener_dataMemberChanged_Proxy(DataSourceListener *This,DataMember bstrDM);
  void __RPC_STUB DataSourceListener_dataMemberChanged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSourceListener_dataMemberAdded_Proxy(DataSourceListener *This,DataMember bstrDM);
  void __RPC_STUB DataSourceListener_dataMemberAdded_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSourceListener_dataMemberRemoved_Proxy(DataSourceListener *This,DataMember bstrDM);
  void __RPC_STUB DataSourceListener_dataMemberRemoved_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __DataSource_INTERFACE_DEFINED__
#define __DataSource_INTERFACE_DEFINED__
  EXTERN_C const IID IID_DataSource;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct DataSource : public IUnknown {
  public:
    virtual HRESULT WINAPI getDataMember(DataMember bstrDM,REFIID riid,IUnknown **ppunk) = 0;
    virtual HRESULT WINAPI getDataMemberName(__LONG32 lIndex,DataMember *pbstrDM) = 0;
    virtual HRESULT WINAPI getDataMemberCount(__LONG32 *plCount) = 0;
    virtual HRESULT WINAPI addDataSourceListener(DataSourceListener *pDSL) = 0;
    virtual HRESULT WINAPI removeDataSourceListener(DataSourceListener *pDSL) = 0;
  };
#else
  typedef struct DataSourceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(DataSource *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(DataSource *This);
      ULONG (WINAPI *Release)(DataSource *This);
      HRESULT (WINAPI *getDataMember)(DataSource *This,DataMember bstrDM,REFIID riid,IUnknown **ppunk);
      HRESULT (WINAPI *getDataMemberName)(DataSource *This,__LONG32 lIndex,DataMember *pbstrDM);
      HRESULT (WINAPI *getDataMemberCount)(DataSource *This,__LONG32 *plCount);
      HRESULT (WINAPI *addDataSourceListener)(DataSource *This,DataSourceListener *pDSL);
      HRESULT (WINAPI *removeDataSourceListener)(DataSource *This,DataSourceListener *pDSL);
    END_INTERFACE
  } DataSourceVtbl;
  struct DataSource {
    CONST_VTBL struct DataSourceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define DataSource_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define DataSource_AddRef(This) (This)->lpVtbl->AddRef(This)
#define DataSource_Release(This) (This)->lpVtbl->Release(This)
#define DataSource_getDataMember(This,bstrDM,riid,ppunk) (This)->lpVtbl->getDataMember(This,bstrDM,riid,ppunk)
#define DataSource_getDataMemberName(This,lIndex,pbstrDM) (This)->lpVtbl->getDataMemberName(This,lIndex,pbstrDM)
#define DataSource_getDataMemberCount(This,plCount) (This)->lpVtbl->getDataMemberCount(This,plCount)
#define DataSource_addDataSourceListener(This,pDSL) (This)->lpVtbl->addDataSourceListener(This,pDSL)
#define DataSource_removeDataSourceListener(This,pDSL) (This)->lpVtbl->removeDataSourceListener(This,pDSL)
#endif
#endif
  HRESULT WINAPI DataSource_getDataMember_Proxy(DataSource *This,DataMember bstrDM,REFIID riid,IUnknown **ppunk);
  void __RPC_STUB DataSource_getDataMember_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSource_getDataMemberName_Proxy(DataSource *This,__LONG32 lIndex,DataMember *pbstrDM);
  void __RPC_STUB DataSource_getDataMemberName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSource_getDataMemberCount_Proxy(DataSource *This,__LONG32 *plCount);
  void __RPC_STUB DataSource_getDataMemberCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSource_addDataSourceListener_Proxy(DataSource *This,DataSourceListener *pDSL);
  void __RPC_STUB DataSource_addDataSourceListener_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI DataSource_removeDataSourceListener_Proxy(DataSource *This,DataSourceListener *pDSL);
  void __RPC_STUB DataSource_removeDataSourceListener_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
