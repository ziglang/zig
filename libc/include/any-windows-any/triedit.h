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

#ifndef __RPCNDR_H_VERSION__
#error This stub requires an updated version of <rpcndr.h>
#endif

#ifndef COM_NO_WINDOWS_H
#include "windows.h"
#include "ole2.h"
#endif

#ifndef __triedit_h__
#define __triedit_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __ITriEditDocument_FWD_DEFINED__
#define __ITriEditDocument_FWD_DEFINED__
  typedef struct ITriEditDocument ITriEditDocument;
#endif

#ifndef __TriEditDocument_FWD_DEFINED__
#define __TriEditDocument_FWD_DEFINED__
#ifdef __cplusplus
  typedef class TriEditDocument TriEditDocument;
#else
  typedef struct TriEditDocument TriEditDocument;
#endif
#endif

#ifndef __IDocHostDragDropHandler_FWD_DEFINED__
#define __IDocHostDragDropHandler_FWD_DEFINED__
  typedef struct IDocHostDragDropHandler IDocHostDragDropHandler;
#endif

#include "oaidl.h"
#include "ocidl.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define dwFilterDefaults 0x00000000
#define dwFilterNone 0x00000001
#define dwFilterDTCs 0x00000002
#define dwFilterDTCsWithoutMetaTags 0x00000004
#define dwFilterServerSideScripts 0x00000008
#define dwPreserveSourceCode 0x00000010
#define dwFilterSourceCode 0x00000020
#define dwFilterMultiByteStream 0x10000000
#define dwFilterUsePstmNew 0x20000000

#define E_FILTER_FRAMESET 0x80100001
#define E_FILTER_SERVERSCRIPT 0x80100002
#define E_FILTER_MULTIPLETAGS 0x80100004
#define E_FILTER_SCRIPTLISTING 0x80100008
#define E_FILTER_SCRIPTLABEL 0x80100010
#define E_FILTER_SCRIPTTEXTAREA 0x80100020
#define E_FILTER_SCRIPTSELECT 0x80100040

  extern RPC_IF_HANDLE __MIDL_itf_triedit_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_triedit_0000_v0_0_s_ifspec;
#ifndef __ITriEditDocument_INTERFACE_DEFINED__
#define __ITriEditDocument_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITriEditDocument;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITriEditDocument : public IDispatch {
  public:
    virtual HRESULT WINAPI FilterIn(IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL) = 0;
    virtual HRESULT WINAPI FilterOut(IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL) = 0;
  };
#else
  typedef struct ITriEditDocumentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITriEditDocument *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITriEditDocument *This);
      ULONG (WINAPI *Release)(ITriEditDocument *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ITriEditDocument *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ITriEditDocument *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ITriEditDocument *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ITriEditDocument *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *FilterIn)(ITriEditDocument *This,IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL);
      HRESULT (WINAPI *FilterOut)(ITriEditDocument *This,IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL);
    END_INTERFACE
  } ITriEditDocumentVtbl;
  struct ITriEditDocument {
    CONST_VTBL struct ITriEditDocumentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITriEditDocument_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITriEditDocument_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITriEditDocument_Release(This) (This)->lpVtbl->Release(This)
#define ITriEditDocument_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ITriEditDocument_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ITriEditDocument_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ITriEditDocument_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ITriEditDocument_FilterIn(This,pStmOld,ppStmNew,dwFlags,bstrBaseURL) (This)->lpVtbl->FilterIn(This,pStmOld,ppStmNew,dwFlags,bstrBaseURL)
#define ITriEditDocument_FilterOut(This,pStmOld,ppStmNew,dwFlags,bstrBaseURL) (This)->lpVtbl->FilterOut(This,pStmOld,ppStmNew,dwFlags,bstrBaseURL)
#endif
#endif
  HRESULT WINAPI ITriEditDocument_FilterIn_Proxy(ITriEditDocument *This,IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL);
  void __RPC_STUB ITriEditDocument_FilterIn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITriEditDocument_FilterOut_Proxy(ITriEditDocument *This,IUnknown *pStmOld,IUnknown **ppStmNew,DWORD dwFlags,BSTR bstrBaseURL);
  void __RPC_STUB ITriEditDocument_FilterOut_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __TRIEDITLib_LIBRARY_DEFINED__
#define __TRIEDITLib_LIBRARY_DEFINED__
  EXTERN_C const IID LIBID_TRIEDITLib;
  EXTERN_C const CLSID CLSID_TriEditDocument;
#ifdef __cplusplus
  class TriEditDocument;
#endif
#endif

#ifndef __IDocHostDragDropHandler_INTERFACE_DEFINED__
#define __IDocHostDragDropHandler_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDocHostDragDropHandler;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDocHostDragDropHandler : public IUnknown {
  public:
    virtual HRESULT WINAPI DrawDragFeedback(RECT *pRect) = 0;
  };
#else
  typedef struct IDocHostDragDropHandlerVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDocHostDragDropHandler *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDocHostDragDropHandler *This);
      ULONG (WINAPI *Release)(IDocHostDragDropHandler *This);
      HRESULT (WINAPI *DrawDragFeedback)(IDocHostDragDropHandler *This,RECT *pRect);
    END_INTERFACE
  } IDocHostDragDropHandlerVtbl;
  struct IDocHostDragDropHandler {
    CONST_VTBL struct IDocHostDragDropHandlerVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDocHostDragDropHandler_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDocHostDragDropHandler_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDocHostDragDropHandler_Release(This) (This)->lpVtbl->Release(This)
#define IDocHostDragDropHandler_DrawDragFeedback(This,pRect) (This)->lpVtbl->DrawDragFeedback(This,pRect)
#endif
#endif
  HRESULT WINAPI IDocHostDragDropHandler_DrawDragFeedback_Proxy(IDocHostDragDropHandler *This,RECT *pRect);
  void __RPC_STUB IDocHostDragDropHandler_DrawDragFeedback_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  ULONG __RPC_API BSTR_UserSize(ULONG *,ULONG,BSTR *);
  unsigned char *__RPC_API BSTR_UserMarshal(ULONG *,unsigned char *,BSTR *);
  unsigned char *__RPC_API BSTR_UserUnmarshal(ULONG *,unsigned char *,BSTR *);
  void __RPC_API BSTR_UserFree(ULONG *,BSTR *);

#ifdef __cplusplus
}
#endif
#endif
