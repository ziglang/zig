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

#ifndef __shdeprecated_pub_h__
#define __shdeprecated_pub_h__

#ifndef __ITravelEntry_FWD_DEFINED__
#define __ITravelEntry_FWD_DEFINED__
typedef struct ITravelEntry ITravelEntry;
#endif

#ifndef __ITravelLog_FWD_DEFINED__
#define __ITravelLog_FWD_DEFINED__
typedef struct ITravelLog ITravelLog;
#endif

#ifndef __IExpDispSupport_FWD_DEFINED__
#define __IExpDispSupport_FWD_DEFINED__
typedef struct IExpDispSupport IExpDispSupport;
#endif

#ifndef __IBrowserService_FWD_DEFINED__
#define __IBrowserService_FWD_DEFINED__
typedef struct IBrowserService IBrowserService;
#endif

#ifndef __IShellService_FWD_DEFINED__
#define __IShellService_FWD_DEFINED__
typedef struct IShellService IShellService;
#endif

#ifndef __IBrowserService2_FWD_DEFINED__
#define __IBrowserService2_FWD_DEFINED__
typedef struct IBrowserService2 IBrowserService2;
#endif

#ifndef __IBrowserService3_FWD_DEFINED__
#define __IBrowserService3_FWD_DEFINED__
typedef struct IBrowserService3 IBrowserService3;
#endif

#include "objidl.h"
#include "ocidl.h"
#include "shtypes.h"
#include "tlogstg.h"
#include "shobjidl.h"
#include "hlink.h"
#include "exdisp.h"

#ifdef __cplusplus
extern "C" {
#endif

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define TLOG_BACK -1
#define TLOG_FORE 1

#define TLMENUF_INCLUDECURRENT 0x00000001
#define TLMENUF_CHECKCURRENT (TLMENUF_INCLUDECURRENT | 0x00000002)
#define TLMENUF_BACK 0x00000010
#define TLMENUF_FORE 0x00000020
#define TLMENUF_BACKANDFORTH (TLMENUF_BACK | TLMENUF_FORE | TLMENUF_INCLUDECURRENT)

  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0000_v0_0_s_ifspec;
#ifndef __ITravelEntry_INTERFACE_DEFINED__
#define __ITravelEntry_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITravelEntry;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITravelEntry : public IUnknown {
  public:
    virtual HRESULT WINAPI Invoke(IUnknown *punk) = 0;
    virtual HRESULT WINAPI Update(IUnknown *punk,WINBOOL fIsLocalAnchor) = 0;
    virtual HRESULT WINAPI GetPidl(LPITEMIDLIST *ppidl) = 0;
  };
#else
  typedef struct ITravelEntryVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITravelEntry *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITravelEntry *This);
      ULONG (WINAPI *Release)(ITravelEntry *This);
      HRESULT (WINAPI *Invoke)(ITravelEntry *This,IUnknown *punk);
      HRESULT (WINAPI *Update)(ITravelEntry *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *GetPidl)(ITravelEntry *This,LPITEMIDLIST *ppidl);
    END_INTERFACE
  } ITravelEntryVtbl;
  struct ITravelEntry {
    CONST_VTBL struct ITravelEntryVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITravelEntry_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITravelEntry_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITravelEntry_Release(This) (This)->lpVtbl->Release(This)
#define ITravelEntry_Invoke(This,punk) (This)->lpVtbl->Invoke(This,punk)
#define ITravelEntry_Update(This,punk,fIsLocalAnchor) (This)->lpVtbl->Update(This,punk,fIsLocalAnchor)
#define ITravelEntry_GetPidl(This,ppidl) (This)->lpVtbl->GetPidl(This,ppidl)
#endif
#endif
  HRESULT WINAPI ITravelEntry_Invoke_Proxy(ITravelEntry *This,IUnknown *punk);
  void __RPC_STUB ITravelEntry_Invoke_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelEntry_Update_Proxy(ITravelEntry *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
  void __RPC_STUB ITravelEntry_Update_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelEntry_GetPidl_Proxy(ITravelEntry *This,LPITEMIDLIST *ppidl);
  void __RPC_STUB ITravelEntry_GetPidl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ITravelLog_INTERFACE_DEFINED__
#define __ITravelLog_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ITravelLog;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ITravelLog : public IUnknown {
  public:
    virtual HRESULT WINAPI AddEntry(IUnknown *punk,WINBOOL fIsLocalAnchor) = 0;
    virtual HRESULT WINAPI UpdateEntry(IUnknown *punk,WINBOOL fIsLocalAnchor) = 0;
    virtual HRESULT WINAPI UpdateExternal(IUnknown *punk,IUnknown *punkHLBrowseContext) = 0;
    virtual HRESULT WINAPI Travel(IUnknown *punk,int iOffset) = 0;
    virtual HRESULT WINAPI GetTravelEntry(IUnknown *punk,int iOffset,ITravelEntry **ppte) = 0;
    virtual HRESULT WINAPI FindTravelEntry(IUnknown *punk,LPCITEMIDLIST pidl,ITravelEntry **ppte) = 0;
    virtual HRESULT WINAPI GetToolTipText(IUnknown *punk,int iOffset,int idsTemplate,LPWSTR pwzText,DWORD cchText) = 0;
    virtual HRESULT WINAPI InsertMenuEntries(IUnknown *punk,HMENU hmenu,int nPos,int idFirst,int idLast,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI Clone(ITravelLog **pptl) = 0;
    virtual DWORD WINAPI CountEntries(IUnknown *punk) = 0;
    virtual HRESULT WINAPI Revert(void) = 0;
  };
#else
  typedef struct ITravelLogVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ITravelLog *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ITravelLog *This);
      ULONG (WINAPI *Release)(ITravelLog *This);
      HRESULT (WINAPI *AddEntry)(ITravelLog *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *UpdateEntry)(ITravelLog *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *UpdateExternal)(ITravelLog *This,IUnknown *punk,IUnknown *punkHLBrowseContext);
      HRESULT (WINAPI *Travel)(ITravelLog *This,IUnknown *punk,int iOffset);
      HRESULT (WINAPI *GetTravelEntry)(ITravelLog *This,IUnknown *punk,int iOffset,ITravelEntry **ppte);
      HRESULT (WINAPI *FindTravelEntry)(ITravelLog *This,IUnknown *punk,LPCITEMIDLIST pidl,ITravelEntry **ppte);
      HRESULT (WINAPI *GetToolTipText)(ITravelLog *This,IUnknown *punk,int iOffset,int idsTemplate,LPWSTR pwzText,DWORD cchText);
      HRESULT (WINAPI *InsertMenuEntries)(ITravelLog *This,IUnknown *punk,HMENU hmenu,int nPos,int idFirst,int idLast,DWORD dwFlags);
      HRESULT (WINAPI *Clone)(ITravelLog *This,ITravelLog **pptl);
      DWORD (WINAPI *CountEntries)(ITravelLog *This,IUnknown *punk);
      HRESULT (WINAPI *Revert)(ITravelLog *This);
    END_INTERFACE
  } ITravelLogVtbl;
  struct ITravelLog {
    CONST_VTBL struct ITravelLogVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ITravelLog_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ITravelLog_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ITravelLog_Release(This) (This)->lpVtbl->Release(This)
#define ITravelLog_AddEntry(This,punk,fIsLocalAnchor) (This)->lpVtbl->AddEntry(This,punk,fIsLocalAnchor)
#define ITravelLog_UpdateEntry(This,punk,fIsLocalAnchor) (This)->lpVtbl->UpdateEntry(This,punk,fIsLocalAnchor)
#define ITravelLog_UpdateExternal(This,punk,punkHLBrowseContext) (This)->lpVtbl->UpdateExternal(This,punk,punkHLBrowseContext)
#define ITravelLog_Travel(This,punk,iOffset) (This)->lpVtbl->Travel(This,punk,iOffset)
#define ITravelLog_GetTravelEntry(This,punk,iOffset,ppte) (This)->lpVtbl->GetTravelEntry(This,punk,iOffset,ppte)
#define ITravelLog_FindTravelEntry(This,punk,pidl,ppte) (This)->lpVtbl->FindTravelEntry(This,punk,pidl,ppte)
#define ITravelLog_GetToolTipText(This,punk,iOffset,idsTemplate,pwzText,cchText) (This)->lpVtbl->GetToolTipText(This,punk,iOffset,idsTemplate,pwzText,cchText)
#define ITravelLog_InsertMenuEntries(This,punk,hmenu,nPos,idFirst,idLast,dwFlags) (This)->lpVtbl->InsertMenuEntries(This,punk,hmenu,nPos,idFirst,idLast,dwFlags)
#define ITravelLog_Clone(This,pptl) (This)->lpVtbl->Clone(This,pptl)
#define ITravelLog_CountEntries(This,punk) (This)->lpVtbl->CountEntries(This,punk)
#define ITravelLog_Revert(This) (This)->lpVtbl->Revert(This)
#endif
#endif
  HRESULT WINAPI ITravelLog_AddEntry_Proxy(ITravelLog *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
  void __RPC_STUB ITravelLog_AddEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_UpdateEntry_Proxy(ITravelLog *This,IUnknown *punk,WINBOOL fIsLocalAnchor);
  void __RPC_STUB ITravelLog_UpdateEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_UpdateExternal_Proxy(ITravelLog *This,IUnknown *punk,IUnknown *punkHLBrowseContext);
  void __RPC_STUB ITravelLog_UpdateExternal_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_Travel_Proxy(ITravelLog *This,IUnknown *punk,int iOffset);
  void __RPC_STUB ITravelLog_Travel_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_GetTravelEntry_Proxy(ITravelLog *This,IUnknown *punk,int iOffset,ITravelEntry **ppte);
  void __RPC_STUB ITravelLog_GetTravelEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_FindTravelEntry_Proxy(ITravelLog *This,IUnknown *punk,LPCITEMIDLIST pidl,ITravelEntry **ppte);
  void __RPC_STUB ITravelLog_FindTravelEntry_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_GetToolTipText_Proxy(ITravelLog *This,IUnknown *punk,int iOffset,int idsTemplate,LPWSTR pwzText,DWORD cchText);
  void __RPC_STUB ITravelLog_GetToolTipText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_InsertMenuEntries_Proxy(ITravelLog *This,IUnknown *punk,HMENU hmenu,int nPos,int idFirst,int idLast,DWORD dwFlags);
  void __RPC_STUB ITravelLog_InsertMenuEntries_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_Clone_Proxy(ITravelLog *This,ITravelLog **pptl);
  void __RPC_STUB ITravelLog_Clone_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  DWORD WINAPI ITravelLog_CountEntries_Proxy(ITravelLog *This,IUnknown *punk);
  void __RPC_STUB ITravelLog_CountEntries_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ITravelLog_Revert_Proxy(ITravelLog *This);
  void __RPC_STUB ITravelLog_Revert_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
  class CIE4ConnectionPoint : public IConnectionPoint {
    virtual HRESULT DoInvokeIE4(WINBOOL *pf,void **ppv,DISPID dispid,DISPPARAMS *pdispparams) PURE;
    virtual HRESULT DoInvokePIDLIE4(DISPID dispid,LPCITEMIDLIST pidl,WINBOOL fCanCancel) PURE;
  };
#else
  typedef void *CIE4ConnectionPoint;
#endif

  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0404_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0404_v0_0_s_ifspec;
#ifndef __IExpDispSupport_INTERFACE_DEFINED__
#define __IExpDispSupport_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IExpDispSupport;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IExpDispSupport : public IUnknown {
  public:
    virtual HRESULT WINAPI FindCIE4ConnectionPoint(REFIID riid,CIE4ConnectionPoint **ppccp) = 0;
    virtual HRESULT WINAPI OnTranslateAccelerator(MSG *pMsg,DWORD grfModifiers) = 0;
    virtual HRESULT WINAPI OnInvoke(DISPID dispidMember,REFIID iid,LCID lcid,WORD wFlags,DISPPARAMS *pdispparams,VARIANT *pVarResult,EXCEPINFO *pexcepinfo,UINT *puArgErr) = 0;
  };
#else
  typedef struct IExpDispSupportVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IExpDispSupport *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IExpDispSupport *This);
      ULONG (WINAPI *Release)(IExpDispSupport *This);
      HRESULT (WINAPI *FindCIE4ConnectionPoint)(IExpDispSupport *This,REFIID riid,CIE4ConnectionPoint **ppccp);
      HRESULT (WINAPI *OnTranslateAccelerator)(IExpDispSupport *This,MSG *pMsg,DWORD grfModifiers);
      HRESULT (WINAPI *OnInvoke)(IExpDispSupport *This,DISPID dispidMember,REFIID iid,LCID lcid,WORD wFlags,DISPPARAMS *pdispparams,VARIANT *pVarResult,EXCEPINFO *pexcepinfo,UINT *puArgErr);
    END_INTERFACE
  } IExpDispSupportVtbl;
  struct IExpDispSupport {
    CONST_VTBL struct IExpDispSupportVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IExpDispSupport_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IExpDispSupport_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IExpDispSupport_Release(This) (This)->lpVtbl->Release(This)
#define IExpDispSupport_FindCIE4ConnectionPoint(This,riid,ppccp) (This)->lpVtbl->FindCIE4ConnectionPoint(This,riid,ppccp)
#define IExpDispSupport_OnTranslateAccelerator(This,pMsg,grfModifiers) (This)->lpVtbl->OnTranslateAccelerator(This,pMsg,grfModifiers)
#define IExpDispSupport_OnInvoke(This,dispidMember,iid,lcid,wFlags,pdispparams,pVarResult,pexcepinfo,puArgErr) (This)->lpVtbl->OnInvoke(This,dispidMember,iid,lcid,wFlags,pdispparams,pVarResult,pexcepinfo,puArgErr)
#endif
#endif
  HRESULT WINAPI IExpDispSupport_FindCIE4ConnectionPoint_Proxy(IExpDispSupport *This,REFIID riid,CIE4ConnectionPoint **ppccp);
  void __RPC_STUB IExpDispSupport_FindCIE4ConnectionPoint_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExpDispSupport_OnTranslateAccelerator_Proxy(IExpDispSupport *This,MSG *pMsg,DWORD grfModifiers);
  void __RPC_STUB IExpDispSupport_OnTranslateAccelerator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IExpDispSupport_OnInvoke_Proxy(IExpDispSupport *This,DISPID dispidMember,REFIID iid,LCID lcid,WORD wFlags,DISPPARAMS *pdispparams,VARIANT *pVarResult,EXCEPINFO *pexcepinfo,UINT *puArgErr);
  void __RPC_STUB IExpDispSupport_OnInvoke_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  typedef enum tagBNSTATE {
    BNS_NORMAL = 0,BNS_BEGIN_NAVIGATE = 1,BNS_NAVIGATE = 2
  } BNSTATE;

  enum __MIDL___MIDL_itf_shdeprecated_pub_0405_0001 {
    SBSC_HIDE = 0,SBSC_SHOW = 1,SBSC_TOGGLE = 2,SBSC_QUERY = 3
  };

#define BSF_REGISTERASDROPTARGET 0x00000001
#define BSF_THEATERMODE 0x00000002
#define BSF_NOLOCALFILEWARNING 0x00000010
#define BSF_UISETBYAUTOMATION 0x00000100
#define BSF_RESIZABLE 0x00000200
#define BSF_CANMAXIMIZE 0x00000400
#define BSF_TOPBROWSER 0x00000800
#define BSF_NAVNOHISTORY 0x00001000
#define BSF_HTMLNAVCANCELED 0x00002000
#define BSF_DONTSHOWNAVCANCELPAGE 0x00004000
#define BSF_SETNAVIGATABLECODEPAGE 0x00008000
#define BSF_DELEGATEDNAVIGATION 0x00010000
#define BSF_TRUSTEDFORACTIVEX 0x00020000
#define HLNF_CALLERUNTRUSTED 0x00200000
#define HLNF_TRUSTEDFORACTIVEX 0x00400000
#define HLNF_DISABLEWINDOWRESTRICTIONS 0x00800000
#define HLNF_TRUSTFIRSTDOWNLOAD 0x01000000
#define HLNF_UNTRUSTEDFORDOWNLOAD 0x02000000
#define SHHLNF_NOAUTOSELECT 0x04000000
#define SHHLNF_WRITENOHISTORY 0x08000000
#define HLNF_EXTERNALNAVIGATE 0x10000000
#define HLNF_ALLOW_AUTONAVIGATE 0x20000000
#define HLNF_NEWWINDOWSMANAGED 0x80000000

  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0405_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0405_v0_0_s_ifspec;
#ifndef __IBrowserService_INTERFACE_DEFINED__
#define __IBrowserService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBrowserService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBrowserService : public IUnknown {
  public:
    virtual HRESULT WINAPI GetParentSite(IOleInPlaceSite **ppipsite) = 0;
    virtual HRESULT WINAPI SetTitle(IShellView *psv,LPCWSTR pszName) = 0;
    virtual HRESULT WINAPI GetTitle(IShellView *psv,LPWSTR pszName,DWORD cchName) = 0;
    virtual HRESULT WINAPI GetOleObject(IOleObject **ppobjv) = 0;
    virtual HRESULT WINAPI GetTravelLog(ITravelLog **pptl) = 0;
    virtual HRESULT WINAPI ShowControlWindow(UINT id,WINBOOL fShow) = 0;
    virtual HRESULT WINAPI IsControlWindowShown(UINT id,WINBOOL *pfShown) = 0;
    virtual HRESULT WINAPI IEGetDisplayName(LPCITEMIDLIST pidl,LPWSTR pwszName,UINT uFlags) = 0;
    virtual HRESULT WINAPI IEParseDisplayName(UINT uiCP,LPCWSTR pwszPath,LPITEMIDLIST *ppidlOut) = 0;
    virtual HRESULT WINAPI DisplayParseError(HRESULT hres,LPCWSTR pwszPath) = 0;
    virtual HRESULT WINAPI NavigateToPidl(LPCITEMIDLIST pidl,DWORD grfHLNF) = 0;
    virtual HRESULT WINAPI SetNavigateState(BNSTATE bnstate) = 0;
    virtual HRESULT WINAPI GetNavigateState(BNSTATE *pbnstate) = 0;
    virtual HRESULT WINAPI NotifyRedirect(IShellView *psv,LPCITEMIDLIST pidl,WINBOOL *pfDidBrowse) = 0;
    virtual HRESULT WINAPI UpdateWindowList(void) = 0;
    virtual HRESULT WINAPI UpdateBackForwardState(void) = 0;
    virtual HRESULT WINAPI SetFlags(DWORD dwFlags,DWORD dwFlagMask) = 0;
    virtual HRESULT WINAPI GetFlags(DWORD *pdwFlags) = 0;
    virtual HRESULT WINAPI CanNavigateNow(void) = 0;
    virtual HRESULT WINAPI GetPidl(LPITEMIDLIST *ppidl) = 0;
    virtual HRESULT WINAPI SetReferrer(LPITEMIDLIST pidl) = 0;
    virtual DWORD WINAPI GetBrowserIndex(void) = 0;
    virtual HRESULT WINAPI GetBrowserByIndex(DWORD dwID,IUnknown **ppunk) = 0;
    virtual HRESULT WINAPI GetHistoryObject(IOleObject **ppole,IStream **pstm,IBindCtx **ppbc) = 0;
    virtual HRESULT WINAPI SetHistoryObject(IOleObject *pole,WINBOOL fIsLocalAnchor) = 0;
    virtual HRESULT WINAPI CacheOLEServer(IOleObject *pole) = 0;
    virtual HRESULT WINAPI GetSetCodePage(VARIANT *pvarIn,VARIANT *pvarOut) = 0;
    virtual HRESULT WINAPI OnHttpEquiv(IShellView *psv,WINBOOL fDone,VARIANT *pvarargIn,VARIANT *pvarargOut) = 0;
    virtual HRESULT WINAPI GetPalette(HPALETTE *hpal) = 0;
    virtual HRESULT WINAPI RegisterWindow(WINBOOL fForceRegister,int swc) = 0;
  };
#else
  typedef struct IBrowserServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBrowserService *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBrowserService *This);
      ULONG (WINAPI *Release)(IBrowserService *This);
      HRESULT (WINAPI *GetParentSite)(IBrowserService *This,IOleInPlaceSite **ppipsite);
      HRESULT (WINAPI *SetTitle)(IBrowserService *This,IShellView *psv,LPCWSTR pszName);
      HRESULT (WINAPI *GetTitle)(IBrowserService *This,IShellView *psv,LPWSTR pszName,DWORD cchName);
      HRESULT (WINAPI *GetOleObject)(IBrowserService *This,IOleObject **ppobjv);
      HRESULT (WINAPI *GetTravelLog)(IBrowserService *This,ITravelLog **pptl);
      HRESULT (WINAPI *ShowControlWindow)(IBrowserService *This,UINT id,WINBOOL fShow);
      HRESULT (WINAPI *IsControlWindowShown)(IBrowserService *This,UINT id,WINBOOL *pfShown);
      HRESULT (WINAPI *IEGetDisplayName)(IBrowserService *This,LPCITEMIDLIST pidl,LPWSTR pwszName,UINT uFlags);
      HRESULT (WINAPI *IEParseDisplayName)(IBrowserService *This,UINT uiCP,LPCWSTR pwszPath,LPITEMIDLIST *ppidlOut);
      HRESULT (WINAPI *DisplayParseError)(IBrowserService *This,HRESULT hres,LPCWSTR pwszPath);
      HRESULT (WINAPI *NavigateToPidl)(IBrowserService *This,LPCITEMIDLIST pidl,DWORD grfHLNF);
      HRESULT (WINAPI *SetNavigateState)(IBrowserService *This,BNSTATE bnstate);
      HRESULT (WINAPI *GetNavigateState)(IBrowserService *This,BNSTATE *pbnstate);
      HRESULT (WINAPI *NotifyRedirect)(IBrowserService *This,IShellView *psv,LPCITEMIDLIST pidl,WINBOOL *pfDidBrowse);
      HRESULT (WINAPI *UpdateWindowList)(IBrowserService *This);
      HRESULT (WINAPI *UpdateBackForwardState)(IBrowserService *This);
      HRESULT (WINAPI *SetFlags)(IBrowserService *This,DWORD dwFlags,DWORD dwFlagMask);
      HRESULT (WINAPI *GetFlags)(IBrowserService *This,DWORD *pdwFlags);
      HRESULT (WINAPI *CanNavigateNow)(IBrowserService *This);
      HRESULT (WINAPI *GetPidl)(IBrowserService *This,LPITEMIDLIST *ppidl);
      HRESULT (WINAPI *SetReferrer)(IBrowserService *This,LPITEMIDLIST pidl);
      DWORD (WINAPI *GetBrowserIndex)(IBrowserService *This);
      HRESULT (WINAPI *GetBrowserByIndex)(IBrowserService *This,DWORD dwID,IUnknown **ppunk);
      HRESULT (WINAPI *GetHistoryObject)(IBrowserService *This,IOleObject **ppole,IStream **pstm,IBindCtx **ppbc);
      HRESULT (WINAPI *SetHistoryObject)(IBrowserService *This,IOleObject *pole,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *CacheOLEServer)(IBrowserService *This,IOleObject *pole);
      HRESULT (WINAPI *GetSetCodePage)(IBrowserService *This,VARIANT *pvarIn,VARIANT *pvarOut);
      HRESULT (WINAPI *OnHttpEquiv)(IBrowserService *This,IShellView *psv,WINBOOL fDone,VARIANT *pvarargIn,VARIANT *pvarargOut);
      HRESULT (WINAPI *GetPalette)(IBrowserService *This,HPALETTE *hpal);
      HRESULT (WINAPI *RegisterWindow)(IBrowserService *This,WINBOOL fForceRegister,int swc);
    END_INTERFACE
  } IBrowserServiceVtbl;
  struct IBrowserService {
    CONST_VTBL struct IBrowserServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBrowserService_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBrowserService_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBrowserService_Release(This) (This)->lpVtbl->Release(This)
#define IBrowserService_GetParentSite(This,ppipsite) (This)->lpVtbl->GetParentSite(This,ppipsite)
#define IBrowserService_SetTitle(This,psv,pszName) (This)->lpVtbl->SetTitle(This,psv,pszName)
#define IBrowserService_GetTitle(This,psv,pszName,cchName) (This)->lpVtbl->GetTitle(This,psv,pszName,cchName)
#define IBrowserService_GetOleObject(This,ppobjv) (This)->lpVtbl->GetOleObject(This,ppobjv)
#define IBrowserService_GetTravelLog(This,pptl) (This)->lpVtbl->GetTravelLog(This,pptl)
#define IBrowserService_ShowControlWindow(This,id,fShow) (This)->lpVtbl->ShowControlWindow(This,id,fShow)
#define IBrowserService_IsControlWindowShown(This,id,pfShown) (This)->lpVtbl->IsControlWindowShown(This,id,pfShown)
#define IBrowserService_IEGetDisplayName(This,pidl,pwszName,uFlags) (This)->lpVtbl->IEGetDisplayName(This,pidl,pwszName,uFlags)
#define IBrowserService_IEParseDisplayName(This,uiCP,pwszPath,ppidlOut) (This)->lpVtbl->IEParseDisplayName(This,uiCP,pwszPath,ppidlOut)
#define IBrowserService_DisplayParseError(This,hres,pwszPath) (This)->lpVtbl->DisplayParseError(This,hres,pwszPath)
#define IBrowserService_NavigateToPidl(This,pidl,grfHLNF) (This)->lpVtbl->NavigateToPidl(This,pidl,grfHLNF)
#define IBrowserService_SetNavigateState(This,bnstate) (This)->lpVtbl->SetNavigateState(This,bnstate)
#define IBrowserService_GetNavigateState(This,pbnstate) (This)->lpVtbl->GetNavigateState(This,pbnstate)
#define IBrowserService_NotifyRedirect(This,psv,pidl,pfDidBrowse) (This)->lpVtbl->NotifyRedirect(This,psv,pidl,pfDidBrowse)
#define IBrowserService_UpdateWindowList(This) (This)->lpVtbl->UpdateWindowList(This)
#define IBrowserService_UpdateBackForwardState(This) (This)->lpVtbl->UpdateBackForwardState(This)
#define IBrowserService_SetFlags(This,dwFlags,dwFlagMask) (This)->lpVtbl->SetFlags(This,dwFlags,dwFlagMask)
#define IBrowserService_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define IBrowserService_CanNavigateNow(This) (This)->lpVtbl->CanNavigateNow(This)
#define IBrowserService_GetPidl(This,ppidl) (This)->lpVtbl->GetPidl(This,ppidl)
#define IBrowserService_SetReferrer(This,pidl) (This)->lpVtbl->SetReferrer(This,pidl)
#define IBrowserService_GetBrowserIndex(This) (This)->lpVtbl->GetBrowserIndex(This)
#define IBrowserService_GetBrowserByIndex(This,dwID,ppunk) (This)->lpVtbl->GetBrowserByIndex(This,dwID,ppunk)
#define IBrowserService_GetHistoryObject(This,ppole,pstm,ppbc) (This)->lpVtbl->GetHistoryObject(This,ppole,pstm,ppbc)
#define IBrowserService_SetHistoryObject(This,pole,fIsLocalAnchor) (This)->lpVtbl->SetHistoryObject(This,pole,fIsLocalAnchor)
#define IBrowserService_CacheOLEServer(This,pole) (This)->lpVtbl->CacheOLEServer(This,pole)
#define IBrowserService_GetSetCodePage(This,pvarIn,pvarOut) (This)->lpVtbl->GetSetCodePage(This,pvarIn,pvarOut)
#define IBrowserService_OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut) (This)->lpVtbl->OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut)
#define IBrowserService_GetPalette(This,hpal) (This)->lpVtbl->GetPalette(This,hpal)
#define IBrowserService_RegisterWindow(This,fForceRegister,swc) (This)->lpVtbl->RegisterWindow(This,fForceRegister,swc)
#endif
#endif
  HRESULT WINAPI IBrowserService_GetParentSite_Proxy(IBrowserService *This,IOleInPlaceSite **ppipsite);
  void __RPC_STUB IBrowserService_GetParentSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_SetTitle_Proxy(IBrowserService *This,IShellView *psv,LPCWSTR pszName);
  void __RPC_STUB IBrowserService_SetTitle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetTitle_Proxy(IBrowserService *This,IShellView *psv,LPWSTR pszName,DWORD cchName);
  void __RPC_STUB IBrowserService_GetTitle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetOleObject_Proxy(IBrowserService *This,IOleObject **ppobjv);
  void __RPC_STUB IBrowserService_GetOleObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetTravelLog_Proxy(IBrowserService *This,ITravelLog **pptl);
  void __RPC_STUB IBrowserService_GetTravelLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_ShowControlWindow_Proxy(IBrowserService *This,UINT id,WINBOOL fShow);
  void __RPC_STUB IBrowserService_ShowControlWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_IsControlWindowShown_Proxy(IBrowserService *This,UINT id,WINBOOL *pfShown);
  void __RPC_STUB IBrowserService_IsControlWindowShown_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_IEGetDisplayName_Proxy(IBrowserService *This,LPCITEMIDLIST pidl,LPWSTR pwszName,UINT uFlags);
  void __RPC_STUB IBrowserService_IEGetDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_IEParseDisplayName_Proxy(IBrowserService *This,UINT uiCP,LPCWSTR pwszPath,LPITEMIDLIST *ppidlOut);
  void __RPC_STUB IBrowserService_IEParseDisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_DisplayParseError_Proxy(IBrowserService *This,HRESULT hres,LPCWSTR pwszPath);
  void __RPC_STUB IBrowserService_DisplayParseError_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_NavigateToPidl_Proxy(IBrowserService *This,LPCITEMIDLIST pidl,DWORD grfHLNF);
  void __RPC_STUB IBrowserService_NavigateToPidl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_SetNavigateState_Proxy(IBrowserService *This,BNSTATE bnstate);
  void __RPC_STUB IBrowserService_SetNavigateState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetNavigateState_Proxy(IBrowserService *This,BNSTATE *pbnstate);
  void __RPC_STUB IBrowserService_GetNavigateState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_NotifyRedirect_Proxy(IBrowserService *This,IShellView *psv,LPCITEMIDLIST pidl,WINBOOL *pfDidBrowse);
  void __RPC_STUB IBrowserService_NotifyRedirect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_UpdateWindowList_Proxy(IBrowserService *This);
  void __RPC_STUB IBrowserService_UpdateWindowList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_UpdateBackForwardState_Proxy(IBrowserService *This);
  void __RPC_STUB IBrowserService_UpdateBackForwardState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_SetFlags_Proxy(IBrowserService *This,DWORD dwFlags,DWORD dwFlagMask);
  void __RPC_STUB IBrowserService_SetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetFlags_Proxy(IBrowserService *This,DWORD *pdwFlags);
  void __RPC_STUB IBrowserService_GetFlags_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_CanNavigateNow_Proxy(IBrowserService *This);
  void __RPC_STUB IBrowserService_CanNavigateNow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetPidl_Proxy(IBrowserService *This,LPITEMIDLIST *ppidl);
  void __RPC_STUB IBrowserService_GetPidl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_SetReferrer_Proxy(IBrowserService *This,LPITEMIDLIST pidl);
  void __RPC_STUB IBrowserService_SetReferrer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  DWORD WINAPI IBrowserService_GetBrowserIndex_Proxy(IBrowserService *This);
  void __RPC_STUB IBrowserService_GetBrowserIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetBrowserByIndex_Proxy(IBrowserService *This,DWORD dwID,IUnknown **ppunk);
  void __RPC_STUB IBrowserService_GetBrowserByIndex_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetHistoryObject_Proxy(IBrowserService *This,IOleObject **ppole,IStream **pstm,IBindCtx **ppbc);
  void __RPC_STUB IBrowserService_GetHistoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_SetHistoryObject_Proxy(IBrowserService *This,IOleObject *pole,WINBOOL fIsLocalAnchor);
  void __RPC_STUB IBrowserService_SetHistoryObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_CacheOLEServer_Proxy(IBrowserService *This,IOleObject *pole);
  void __RPC_STUB IBrowserService_CacheOLEServer_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetSetCodePage_Proxy(IBrowserService *This,VARIANT *pvarIn,VARIANT *pvarOut);
  void __RPC_STUB IBrowserService_GetSetCodePage_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_OnHttpEquiv_Proxy(IBrowserService *This,IShellView *psv,WINBOOL fDone,VARIANT *pvarargIn,VARIANT *pvarargOut);
  void __RPC_STUB IBrowserService_OnHttpEquiv_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_GetPalette_Proxy(IBrowserService *This,HPALETTE *hpal);
  void __RPC_STUB IBrowserService_GetPalette_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService_RegisterWindow_Proxy(IBrowserService *This,WINBOOL fForceRegister,int swc);
  void __RPC_STUB IBrowserService_RegisterWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IShellService_INTERFACE_DEFINED__
#define __IShellService_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IShellService;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IShellService : public IUnknown {
  public:
    virtual HRESULT WINAPI SetOwner(IUnknown *punkOwner) = 0;
  };
#else
  typedef struct IShellServiceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IShellService *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IShellService *This);
      ULONG (WINAPI *Release)(IShellService *This);
      HRESULT (WINAPI *SetOwner)(IShellService *This,IUnknown *punkOwner);
    END_INTERFACE
  } IShellServiceVtbl;
  struct IShellService {
    CONST_VTBL struct IShellServiceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IShellService_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IShellService_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IShellService_Release(This) (This)->lpVtbl->Release(This)
#define IShellService_SetOwner(This,punkOwner) (This)->lpVtbl->SetOwner(This,punkOwner)
#endif
#endif
  HRESULT WINAPI IShellService_SetOwner_Proxy(IShellService *This,IUnknown *punkOwner);
  void __RPC_STUB IShellService_SetOwner_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  enum __MIDL___MIDL_itf_shdeprecated_pub_0407_0001 {
    SECURELOCK_NOCHANGE = -1,SECURELOCK_SET_UNSECURE = 0,
    SECURELOCK_SET_MIXED,SECURELOCK_SET_SECUREUNKNOWNBIT,SECURELOCK_SET_SECURE40BIT,
    SECURELOCK_SET_SECURE56BIT,SECURELOCK_SET_FORTEZZA,SECURELOCK_SET_SECURE128BIT,
    SECURELOCK_FIRSTSUGGEST,SECURELOCK_SUGGEST_MIXED,SECURELOCK_SUGGEST_SECUREUNKNOWNBIT,
    SECURELOCK_SUGGEST_SECURE40BIT,SECURELOCK_SUGGEST_SECURE56BIT,SECURELOCK_SUGGEST_FORTEZZA,
    SECURELOCK_SUGGEST_SECURE128BIT,
    SECURELOCK_SUGGEST_UNSECURE = SECURELOCK_FIRSTSUGGEST
  };

#include <pshpack8.h>

  typedef struct __MIDL___MIDL_itf_shdeprecated_pub_0407_0002 {
    HWND _hwnd;
    ITravelLog *_ptl;
    IHlinkFrame *_phlf;
    IWebBrowser2 *_pautoWB2;
    IExpDispSupport *_pautoEDS;
    IShellService *_pautoSS;
    int _eSecureLockIcon;
    DWORD _fCreatingViewWindow : 1;
    UINT _uActivateState;
    LPCITEMIDLIST _pidlNewShellView;
    IOleCommandTarget *_pctView;
    LPITEMIDLIST _pidlCur;
    IShellView *_psv;
    IShellFolder *_psf;
    HWND _hwndView;
    LPWSTR _pszTitleCur;
    LPITEMIDLIST _pidlPending;
    IShellView *_psvPending;
    IShellFolder *_psfPending;
    HWND _hwndViewPending;
    LPWSTR _pszTitlePending;
    WINBOOL _fIsViewMSHTML;
    WINBOOL _fPrivacyImpacted;
  } BASEBROWSERDATA;

  typedef struct __MIDL___MIDL_itf_shdeprecated_pub_0407_0002 *LPBASEBROWSERDATA;
  typedef const BASEBROWSERDATA *LPCBASEBROWSERDATA;

#define VIEW_PRIORITY_RESTRICTED 0x00000070
#define VIEW_PRIORITY_CACHEHIT 0x00000050
#define VIEW_PRIORITY_STALECACHEHIT 0x00000045
#define VIEW_PRIORITY_USEASDEFAULT 0x00000043
#define VIEW_PRIORITY_SHELLEXT 0x00000040
#define VIEW_PRIORITY_CACHEMISS 0x00000030
#define VIEW_PRIORITY_INHERIT 0x00000020
#define VIEW_PRIORITY_SHELLEXT_ASBACKUP 0x0015
#define VIEW_PRIORITY_DESPERATE 0x00000010
#define VIEW_PRIORITY_NONE 0x00000000

  typedef struct tagFolderSetData {
    FOLDERSETTINGS _fs;
    SHELLVIEWID _vidRestore;
    DWORD _dwViewPriority;
  } FOLDERSETDATA;

  typedef struct tagFolderSetData *LPFOLDERSETDATA;

  typedef struct SToolbarItem {
    IDockingWindow *ptbar;
    BORDERWIDTHS rcBorderTool;
    LPWSTR pwszItem;
    WINBOOL fShow;
    HMONITOR hMon;
  } TOOLBARITEM;

  typedef struct SToolbarItem *LPTOOLBARITEM;

#define ITB_VIEW ((UINT)-1)

#include <poppack.h>

  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0407_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_shdeprecated_pub_0407_v0_0_s_ifspec;
#ifndef __IBrowserService2_INTERFACE_DEFINED__
#define __IBrowserService2_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IBrowserService2;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBrowserService2 : public IBrowserService {
  public:
    virtual LRESULT WINAPI WndProcBS(HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam) = 0;
    virtual HRESULT WINAPI SetAsDefFolderSettings(void) = 0;
    virtual HRESULT WINAPI GetViewRect(RECT *prc) = 0;
    virtual HRESULT WINAPI OnSize(WPARAM wParam) = 0;
    virtual HRESULT WINAPI OnCreate(struct tagCREATESTRUCTW *pcs) = 0;
    virtual LRESULT WINAPI OnCommand(WPARAM wParam,LPARAM lParam) = 0;
    virtual HRESULT WINAPI OnDestroy(void) = 0;
    virtual LRESULT WINAPI OnNotify(struct tagNMHDR *pnm) = 0;
    virtual HRESULT WINAPI OnSetFocus(void) = 0;
    virtual HRESULT WINAPI OnFrameWindowActivateBS(WINBOOL fActive) = 0;
    virtual HRESULT WINAPI ReleaseShellView(void) = 0;
    virtual HRESULT WINAPI ActivatePendingView(void) = 0;
    virtual HRESULT WINAPI CreateViewWindow(IShellView *psvNew,IShellView *psvOld,LPRECT prcView,HWND *phwnd) = 0;
    virtual HRESULT WINAPI CreateBrowserPropSheetExt(REFIID riid,void **ppv) = 0;
    virtual HRESULT WINAPI GetViewWindow(HWND *phwndView) = 0;
    virtual HRESULT WINAPI GetBaseBrowserData(LPCBASEBROWSERDATA *pbbd) = 0;
    virtual LPBASEBROWSERDATA WINAPI PutBaseBrowserData(void) = 0;
    virtual HRESULT WINAPI InitializeTravelLog(ITravelLog *ptl,DWORD dw) = 0;
    virtual HRESULT WINAPI SetTopBrowser(void) = 0;
    virtual HRESULT WINAPI Offline(int iCmd) = 0;
    virtual HRESULT WINAPI AllowViewResize(WINBOOL f) = 0;
    virtual HRESULT WINAPI SetActivateState(UINT u) = 0;
    virtual HRESULT WINAPI UpdateSecureLockIcon(int eSecureLock) = 0;
    virtual HRESULT WINAPI InitializeDownloadManager(void) = 0;
    virtual HRESULT WINAPI InitializeTransitionSite(void) = 0;
    virtual HRESULT WINAPI _Initialize(HWND hwnd,IUnknown *pauto) = 0;
    virtual HRESULT WINAPI _CancelPendingNavigationAsync(void) = 0;
    virtual HRESULT WINAPI _CancelPendingView(void) = 0;
    virtual HRESULT WINAPI _MaySaveChanges(void) = 0;
    virtual HRESULT WINAPI _PauseOrResumeView(WINBOOL fPaused) = 0;
    virtual HRESULT WINAPI _DisableModeless(void) = 0;
    virtual HRESULT WINAPI _NavigateToPidl(LPCITEMIDLIST pidl,DWORD grfHLNF,DWORD dwFlags) = 0;
    virtual HRESULT WINAPI _TryShell2Rename(IShellView *psv,LPCITEMIDLIST pidlNew) = 0;
    virtual HRESULT WINAPI _SwitchActivationNow(void) = 0;
    virtual HRESULT WINAPI _ExecChildren(IUnknown *punkBar,WINBOOL fBroadcast,const GUID *pguidCmdGroup,DWORD nCmdID,DWORD nCmdexecopt,VARIANTARG *pvarargIn,VARIANTARG *pvarargOut) = 0;
    virtual HRESULT WINAPI _SendChildren(HWND hwndBar,WINBOOL fBroadcast,UINT uMsg,WPARAM wParam,LPARAM lParam) = 0;
    virtual HRESULT WINAPI GetFolderSetData(struct tagFolderSetData *pfsd) = 0;
    virtual HRESULT WINAPI _OnFocusChange(UINT itb) = 0;
    virtual HRESULT WINAPI v_ShowHideChildWindows(WINBOOL fChildOnly) = 0;
    virtual UINT WINAPI _get_itbLastFocus(void) = 0;
    virtual HRESULT WINAPI _put_itbLastFocus(UINT itbLastFocus) = 0;
    virtual HRESULT WINAPI _UIActivateView(UINT uState) = 0;
    virtual HRESULT WINAPI _GetViewBorderRect(RECT *prc) = 0;
    virtual HRESULT WINAPI _UpdateViewRectSize(void) = 0;
    virtual HRESULT WINAPI _ResizeNextBorder(UINT itb) = 0;
    virtual HRESULT WINAPI _ResizeView(void) = 0;
    virtual HRESULT WINAPI _GetEffectiveClientArea(LPRECT lprectBorder,HMONITOR hmon) = 0;
    virtual IStream *WINAPI v_GetViewStream(LPCITEMIDLIST pidl,DWORD grfMode,LPCWSTR pwszName) = 0;
    virtual LRESULT WINAPI ForwardViewMsg(UINT uMsg,WPARAM wParam,LPARAM lParam) = 0;
    virtual HRESULT WINAPI SetAcceleratorMenu(HACCEL hacc) = 0;
    virtual int WINAPI _GetToolbarCount(void) = 0;
    virtual LPTOOLBARITEM WINAPI _GetToolbarItem(int itb) = 0;
    virtual HRESULT WINAPI _SaveToolbars(IStream *pstm) = 0;
    virtual HRESULT WINAPI _LoadToolbars(IStream *pstm) = 0;
    virtual HRESULT WINAPI _CloseAndReleaseToolbars(WINBOOL fClose) = 0;
    virtual HRESULT WINAPI v_MayGetNextToolbarFocus(LPMSG lpMsg,UINT itbNext,int citb,LPTOOLBARITEM *pptbi,HWND *phwnd) = 0;
    virtual HRESULT WINAPI _ResizeNextBorderHelper(UINT itb,WINBOOL bUseHmonitor) = 0;
    virtual UINT WINAPI _FindTBar(IUnknown *punkSrc) = 0;
    virtual HRESULT WINAPI _SetFocus(LPTOOLBARITEM ptbi,HWND hwnd,LPMSG lpMsg) = 0;
    virtual HRESULT WINAPI v_MayTranslateAccelerator(MSG *pmsg) = 0;
    virtual HRESULT WINAPI _GetBorderDWHelper(IUnknown *punkSrc,LPRECT lprectBorder,WINBOOL bUseHmonitor) = 0;
    virtual HRESULT WINAPI v_CheckZoneCrossing(LPCITEMIDLIST pidl) = 0;
  };
#else
  typedef struct IBrowserService2Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBrowserService2 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBrowserService2 *This);
      ULONG (WINAPI *Release)(IBrowserService2 *This);
      HRESULT (WINAPI *GetParentSite)(IBrowserService2 *This,IOleInPlaceSite **ppipsite);
      HRESULT (WINAPI *SetTitle)(IBrowserService2 *This,IShellView *psv,LPCWSTR pszName);
      HRESULT (WINAPI *GetTitle)(IBrowserService2 *This,IShellView *psv,LPWSTR pszName,DWORD cchName);
      HRESULT (WINAPI *GetOleObject)(IBrowserService2 *This,IOleObject **ppobjv);
      HRESULT (WINAPI *GetTravelLog)(IBrowserService2 *This,ITravelLog **pptl);
      HRESULT (WINAPI *ShowControlWindow)(IBrowserService2 *This,UINT id,WINBOOL fShow);
      HRESULT (WINAPI *IsControlWindowShown)(IBrowserService2 *This,UINT id,WINBOOL *pfShown);
      HRESULT (WINAPI *IEGetDisplayName)(IBrowserService2 *This,LPCITEMIDLIST pidl,LPWSTR pwszName,UINT uFlags);
      HRESULT (WINAPI *IEParseDisplayName)(IBrowserService2 *This,UINT uiCP,LPCWSTR pwszPath,LPITEMIDLIST *ppidlOut);
      HRESULT (WINAPI *DisplayParseError)(IBrowserService2 *This,HRESULT hres,LPCWSTR pwszPath);
      HRESULT (WINAPI *NavigateToPidl)(IBrowserService2 *This,LPCITEMIDLIST pidl,DWORD grfHLNF);
      HRESULT (WINAPI *SetNavigateState)(IBrowserService2 *This,BNSTATE bnstate);
      HRESULT (WINAPI *GetNavigateState)(IBrowserService2 *This,BNSTATE *pbnstate);
      HRESULT (WINAPI *NotifyRedirect)(IBrowserService2 *This,IShellView *psv,LPCITEMIDLIST pidl,WINBOOL *pfDidBrowse);
      HRESULT (WINAPI *UpdateWindowList)(IBrowserService2 *This);
      HRESULT (WINAPI *UpdateBackForwardState)(IBrowserService2 *This);
      HRESULT (WINAPI *SetFlags)(IBrowserService2 *This,DWORD dwFlags,DWORD dwFlagMask);
      HRESULT (WINAPI *GetFlags)(IBrowserService2 *This,DWORD *pdwFlags);
      HRESULT (WINAPI *CanNavigateNow)(IBrowserService2 *This);
      HRESULT (WINAPI *GetPidl)(IBrowserService2 *This,LPITEMIDLIST *ppidl);
      HRESULT (WINAPI *SetReferrer)(IBrowserService2 *This,LPITEMIDLIST pidl);
      DWORD (WINAPI *GetBrowserIndex)(IBrowserService2 *This);
      HRESULT (WINAPI *GetBrowserByIndex)(IBrowserService2 *This,DWORD dwID,IUnknown **ppunk);
      HRESULT (WINAPI *GetHistoryObject)(IBrowserService2 *This,IOleObject **ppole,IStream **pstm,IBindCtx **ppbc);
      HRESULT (WINAPI *SetHistoryObject)(IBrowserService2 *This,IOleObject *pole,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *CacheOLEServer)(IBrowserService2 *This,IOleObject *pole);
      HRESULT (WINAPI *GetSetCodePage)(IBrowserService2 *This,VARIANT *pvarIn,VARIANT *pvarOut);
      HRESULT (WINAPI *OnHttpEquiv)(IBrowserService2 *This,IShellView *psv,WINBOOL fDone,VARIANT *pvarargIn,VARIANT *pvarargOut);
      HRESULT (WINAPI *GetPalette)(IBrowserService2 *This,HPALETTE *hpal);
      HRESULT (WINAPI *RegisterWindow)(IBrowserService2 *This,WINBOOL fForceRegister,int swc);
      LRESULT (WINAPI *WndProcBS)(IBrowserService2 *This,HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *SetAsDefFolderSettings)(IBrowserService2 *This);
      HRESULT (WINAPI *GetViewRect)(IBrowserService2 *This,RECT *prc);
      HRESULT (WINAPI *OnSize)(IBrowserService2 *This,WPARAM wParam);
      HRESULT (WINAPI *OnCreate)(IBrowserService2 *This,struct tagCREATESTRUCTW *pcs);
      LRESULT (WINAPI *OnCommand)(IBrowserService2 *This,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *OnDestroy)(IBrowserService2 *This);
      LRESULT (WINAPI *OnNotify)(IBrowserService2 *This,struct tagNMHDR *pnm);
      HRESULT (WINAPI *OnSetFocus)(IBrowserService2 *This);
      HRESULT (WINAPI *OnFrameWindowActivateBS)(IBrowserService2 *This,WINBOOL fActive);
      HRESULT (WINAPI *ReleaseShellView)(IBrowserService2 *This);
      HRESULT (WINAPI *ActivatePendingView)(IBrowserService2 *This);
      HRESULT (WINAPI *CreateViewWindow)(IBrowserService2 *This,IShellView *psvNew,IShellView *psvOld,LPRECT prcView,HWND *phwnd);
      HRESULT (WINAPI *CreateBrowserPropSheetExt)(IBrowserService2 *This,REFIID riid,void **ppv);
      HRESULT (WINAPI *GetViewWindow)(IBrowserService2 *This,HWND *phwndView);
      HRESULT (WINAPI *GetBaseBrowserData)(IBrowserService2 *This,LPCBASEBROWSERDATA *pbbd);
      LPBASEBROWSERDATA (WINAPI *PutBaseBrowserData)(IBrowserService2 *This);
      HRESULT (WINAPI *InitializeTravelLog)(IBrowserService2 *This,ITravelLog *ptl,DWORD dw);
      HRESULT (WINAPI *SetTopBrowser)(IBrowserService2 *This);
      HRESULT (WINAPI *Offline)(IBrowserService2 *This,int iCmd);
      HRESULT (WINAPI *AllowViewResize)(IBrowserService2 *This,WINBOOL f);
      HRESULT (WINAPI *SetActivateState)(IBrowserService2 *This,UINT u);
      HRESULT (WINAPI *UpdateSecureLockIcon)(IBrowserService2 *This,int eSecureLock);
      HRESULT (WINAPI *InitializeDownloadManager)(IBrowserService2 *This);
      HRESULT (WINAPI *InitializeTransitionSite)(IBrowserService2 *This);
      HRESULT (WINAPI *_Initialize)(IBrowserService2 *This,HWND hwnd,IUnknown *pauto);
      HRESULT (WINAPI *_CancelPendingNavigationAsync)(IBrowserService2 *This);
      HRESULT (WINAPI *_CancelPendingView)(IBrowserService2 *This);
      HRESULT (WINAPI *_MaySaveChanges)(IBrowserService2 *This);
      HRESULT (WINAPI *_PauseOrResumeView)(IBrowserService2 *This,WINBOOL fPaused);
      HRESULT (WINAPI *_DisableModeless)(IBrowserService2 *This);
      HRESULT (WINAPI *_NavigateToPidl)(IBrowserService2 *This,LPCITEMIDLIST pidl,DWORD grfHLNF,DWORD dwFlags);
      HRESULT (WINAPI *_TryShell2Rename)(IBrowserService2 *This,IShellView *psv,LPCITEMIDLIST pidlNew);
      HRESULT (WINAPI *_SwitchActivationNow)(IBrowserService2 *This);
      HRESULT (WINAPI *_ExecChildren)(IBrowserService2 *This,IUnknown *punkBar,WINBOOL fBroadcast,const GUID *pguidCmdGroup,DWORD nCmdID,DWORD nCmdexecopt,VARIANTARG *pvarargIn,VARIANTARG *pvarargOut);
      HRESULT (WINAPI *_SendChildren)(IBrowserService2 *This,HWND hwndBar,WINBOOL fBroadcast,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *GetFolderSetData)(IBrowserService2 *This,struct tagFolderSetData *pfsd);
      HRESULT (WINAPI *_OnFocusChange)(IBrowserService2 *This,UINT itb);
      HRESULT (WINAPI *v_ShowHideChildWindows)(IBrowserService2 *This,WINBOOL fChildOnly);
      UINT (WINAPI *_get_itbLastFocus)(IBrowserService2 *This);
      HRESULT (WINAPI *_put_itbLastFocus)(IBrowserService2 *This,UINT itbLastFocus);
      HRESULT (WINAPI *_UIActivateView)(IBrowserService2 *This,UINT uState);
      HRESULT (WINAPI *_GetViewBorderRect)(IBrowserService2 *This,RECT *prc);
      HRESULT (WINAPI *_UpdateViewRectSize)(IBrowserService2 *This);
      HRESULT (WINAPI *_ResizeNextBorder)(IBrowserService2 *This,UINT itb);
      HRESULT (WINAPI *_ResizeView)(IBrowserService2 *This);
      HRESULT (WINAPI *_GetEffectiveClientArea)(IBrowserService2 *This,LPRECT lprectBorder,HMONITOR hmon);
      IStream *(WINAPI *v_GetViewStream)(IBrowserService2 *This,LPCITEMIDLIST pidl,DWORD grfMode,LPCWSTR pwszName);
      LRESULT (WINAPI *ForwardViewMsg)(IBrowserService2 *This,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *SetAcceleratorMenu)(IBrowserService2 *This,HACCEL hacc);
      int (WINAPI *_GetToolbarCount)(IBrowserService2 *This);
      LPTOOLBARITEM (WINAPI *_GetToolbarItem)(IBrowserService2 *This,int itb);
      HRESULT (WINAPI *_SaveToolbars)(IBrowserService2 *This,IStream *pstm);
      HRESULT (WINAPI *_LoadToolbars)(IBrowserService2 *This,IStream *pstm);
      HRESULT (WINAPI *_CloseAndReleaseToolbars)(IBrowserService2 *This,WINBOOL fClose);
      HRESULT (WINAPI *v_MayGetNextToolbarFocus)(IBrowserService2 *This,LPMSG lpMsg,UINT itbNext,int citb,LPTOOLBARITEM *pptbi,HWND *phwnd);
      HRESULT (WINAPI *_ResizeNextBorderHelper)(IBrowserService2 *This,UINT itb,WINBOOL bUseHmonitor);
      UINT (WINAPI *_FindTBar)(IBrowserService2 *This,IUnknown *punkSrc);
      HRESULT (WINAPI *_SetFocus)(IBrowserService2 *This,LPTOOLBARITEM ptbi,HWND hwnd,LPMSG lpMsg);
      HRESULT (WINAPI *v_MayTranslateAccelerator)(IBrowserService2 *This,MSG *pmsg);
      HRESULT (WINAPI *_GetBorderDWHelper)(IBrowserService2 *This,IUnknown *punkSrc,LPRECT lprectBorder,WINBOOL bUseHmonitor);
      HRESULT (WINAPI *v_CheckZoneCrossing)(IBrowserService2 *This,LPCITEMIDLIST pidl);
    END_INTERFACE
  } IBrowserService2Vtbl;
  struct IBrowserService2 {
    CONST_VTBL struct IBrowserService2Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBrowserService2_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBrowserService2_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBrowserService2_Release(This) (This)->lpVtbl->Release(This)
#define IBrowserService2_GetParentSite(This,ppipsite) (This)->lpVtbl->GetParentSite(This,ppipsite)
#define IBrowserService2_SetTitle(This,psv,pszName) (This)->lpVtbl->SetTitle(This,psv,pszName)
#define IBrowserService2_GetTitle(This,psv,pszName,cchName) (This)->lpVtbl->GetTitle(This,psv,pszName,cchName)
#define IBrowserService2_GetOleObject(This,ppobjv) (This)->lpVtbl->GetOleObject(This,ppobjv)
#define IBrowserService2_GetTravelLog(This,pptl) (This)->lpVtbl->GetTravelLog(This,pptl)
#define IBrowserService2_ShowControlWindow(This,id,fShow) (This)->lpVtbl->ShowControlWindow(This,id,fShow)
#define IBrowserService2_IsControlWindowShown(This,id,pfShown) (This)->lpVtbl->IsControlWindowShown(This,id,pfShown)
#define IBrowserService2_IEGetDisplayName(This,pidl,pwszName,uFlags) (This)->lpVtbl->IEGetDisplayName(This,pidl,pwszName,uFlags)
#define IBrowserService2_IEParseDisplayName(This,uiCP,pwszPath,ppidlOut) (This)->lpVtbl->IEParseDisplayName(This,uiCP,pwszPath,ppidlOut)
#define IBrowserService2_DisplayParseError(This,hres,pwszPath) (This)->lpVtbl->DisplayParseError(This,hres,pwszPath)
#define IBrowserService2_NavigateToPidl(This,pidl,grfHLNF) (This)->lpVtbl->NavigateToPidl(This,pidl,grfHLNF)
#define IBrowserService2_SetNavigateState(This,bnstate) (This)->lpVtbl->SetNavigateState(This,bnstate)
#define IBrowserService2_GetNavigateState(This,pbnstate) (This)->lpVtbl->GetNavigateState(This,pbnstate)
#define IBrowserService2_NotifyRedirect(This,psv,pidl,pfDidBrowse) (This)->lpVtbl->NotifyRedirect(This,psv,pidl,pfDidBrowse)
#define IBrowserService2_UpdateWindowList(This) (This)->lpVtbl->UpdateWindowList(This)
#define IBrowserService2_UpdateBackForwardState(This) (This)->lpVtbl->UpdateBackForwardState(This)
#define IBrowserService2_SetFlags(This,dwFlags,dwFlagMask) (This)->lpVtbl->SetFlags(This,dwFlags,dwFlagMask)
#define IBrowserService2_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define IBrowserService2_CanNavigateNow(This) (This)->lpVtbl->CanNavigateNow(This)
#define IBrowserService2_GetPidl(This,ppidl) (This)->lpVtbl->GetPidl(This,ppidl)
#define IBrowserService2_SetReferrer(This,pidl) (This)->lpVtbl->SetReferrer(This,pidl)
#define IBrowserService2_GetBrowserIndex(This) (This)->lpVtbl->GetBrowserIndex(This)
#define IBrowserService2_GetBrowserByIndex(This,dwID,ppunk) (This)->lpVtbl->GetBrowserByIndex(This,dwID,ppunk)
#define IBrowserService2_GetHistoryObject(This,ppole,pstm,ppbc) (This)->lpVtbl->GetHistoryObject(This,ppole,pstm,ppbc)
#define IBrowserService2_SetHistoryObject(This,pole,fIsLocalAnchor) (This)->lpVtbl->SetHistoryObject(This,pole,fIsLocalAnchor)
#define IBrowserService2_CacheOLEServer(This,pole) (This)->lpVtbl->CacheOLEServer(This,pole)
#define IBrowserService2_GetSetCodePage(This,pvarIn,pvarOut) (This)->lpVtbl->GetSetCodePage(This,pvarIn,pvarOut)
#define IBrowserService2_OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut) (This)->lpVtbl->OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut)
#define IBrowserService2_GetPalette(This,hpal) (This)->lpVtbl->GetPalette(This,hpal)
#define IBrowserService2_RegisterWindow(This,fForceRegister,swc) (This)->lpVtbl->RegisterWindow(This,fForceRegister,swc)
#define IBrowserService2_WndProcBS(This,hwnd,uMsg,wParam,lParam) (This)->lpVtbl->WndProcBS(This,hwnd,uMsg,wParam,lParam)
#define IBrowserService2_SetAsDefFolderSettings(This) (This)->lpVtbl->SetAsDefFolderSettings(This)
#define IBrowserService2_GetViewRect(This,prc) (This)->lpVtbl->GetViewRect(This,prc)
#define IBrowserService2_OnSize(This,wParam) (This)->lpVtbl->OnSize(This,wParam)
#define IBrowserService2_OnCreate(This,pcs) (This)->lpVtbl->OnCreate(This,pcs)
#define IBrowserService2_OnCommand(This,wParam,lParam) (This)->lpVtbl->OnCommand(This,wParam,lParam)
#define IBrowserService2_OnDestroy(This) (This)->lpVtbl->OnDestroy(This)
#define IBrowserService2_OnNotify(This,pnm) (This)->lpVtbl->OnNotify(This,pnm)
#define IBrowserService2_OnSetFocus(This) (This)->lpVtbl->OnSetFocus(This)
#define IBrowserService2_OnFrameWindowActivateBS(This,fActive) (This)->lpVtbl->OnFrameWindowActivateBS(This,fActive)
#define IBrowserService2_ReleaseShellView(This) (This)->lpVtbl->ReleaseShellView(This)
#define IBrowserService2_ActivatePendingView(This) (This)->lpVtbl->ActivatePendingView(This)
#define IBrowserService2_CreateViewWindow(This,psvNew,psvOld,prcView,phwnd) (This)->lpVtbl->CreateViewWindow(This,psvNew,psvOld,prcView,phwnd)
#define IBrowserService2_CreateBrowserPropSheetExt(This,riid,ppv) (This)->lpVtbl->CreateBrowserPropSheetExt(This,riid,ppv)
#define IBrowserService2_GetViewWindow(This,phwndView) (This)->lpVtbl->GetViewWindow(This,phwndView)
#define IBrowserService2_GetBaseBrowserData(This,pbbd) (This)->lpVtbl->GetBaseBrowserData(This,pbbd)
#define IBrowserService2_PutBaseBrowserData(This) (This)->lpVtbl->PutBaseBrowserData(This)
#define IBrowserService2_InitializeTravelLog(This,ptl,dw) (This)->lpVtbl->InitializeTravelLog(This,ptl,dw)
#define IBrowserService2_SetTopBrowser(This) (This)->lpVtbl->SetTopBrowser(This)
#define IBrowserService2_Offline(This,iCmd) (This)->lpVtbl->Offline(This,iCmd)
#define IBrowserService2_AllowViewResize(This,f) (This)->lpVtbl->AllowViewResize(This,f)
#define IBrowserService2_SetActivateState(This,u) (This)->lpVtbl->SetActivateState(This,u)
#define IBrowserService2_UpdateSecureLockIcon(This,eSecureLock) (This)->lpVtbl->UpdateSecureLockIcon(This,eSecureLock)
#define IBrowserService2_InitializeDownloadManager(This) (This)->lpVtbl->InitializeDownloadManager(This)
#define IBrowserService2_InitializeTransitionSite(This) (This)->lpVtbl->InitializeTransitionSite(This)
#define IBrowserService2__Initialize(This,hwnd,pauto) (This)->lpVtbl->_Initialize(This,hwnd,pauto)
#define IBrowserService2__CancelPendingNavigationAsync(This) (This)->lpVtbl->_CancelPendingNavigationAsync(This)
#define IBrowserService2__CancelPendingView(This) (This)->lpVtbl->_CancelPendingView(This)
#define IBrowserService2__MaySaveChanges(This) (This)->lpVtbl->_MaySaveChanges(This)
#define IBrowserService2__PauseOrResumeView(This,fPaused) (This)->lpVtbl->_PauseOrResumeView(This,fPaused)
#define IBrowserService2__DisableModeless(This) (This)->lpVtbl->_DisableModeless(This)
#define IBrowserService2__NavigateToPidl(This,pidl,grfHLNF,dwFlags) (This)->lpVtbl->_NavigateToPidl(This,pidl,grfHLNF,dwFlags)
#define IBrowserService2__TryShell2Rename(This,psv,pidlNew) (This)->lpVtbl->_TryShell2Rename(This,psv,pidlNew)
#define IBrowserService2__SwitchActivationNow(This) (This)->lpVtbl->_SwitchActivationNow(This)
#define IBrowserService2__ExecChildren(This,punkBar,fBroadcast,pguidCmdGroup,nCmdID,nCmdexecopt,pvarargIn,pvarargOut) (This)->lpVtbl->_ExecChildren(This,punkBar,fBroadcast,pguidCmdGroup,nCmdID,nCmdexecopt,pvarargIn,pvarargOut)
#define IBrowserService2__SendChildren(This,hwndBar,fBroadcast,uMsg,wParam,lParam) (This)->lpVtbl->_SendChildren(This,hwndBar,fBroadcast,uMsg,wParam,lParam)
#define IBrowserService2_GetFolderSetData(This,pfsd) (This)->lpVtbl->GetFolderSetData(This,pfsd)
#define IBrowserService2__OnFocusChange(This,itb) (This)->lpVtbl->_OnFocusChange(This,itb)
#define IBrowserService2_v_ShowHideChildWindows(This,fChildOnly) (This)->lpVtbl->v_ShowHideChildWindows(This,fChildOnly)
#define IBrowserService2__get_itbLastFocus(This) (This)->lpVtbl->_get_itbLastFocus(This)
#define IBrowserService2__put_itbLastFocus(This,itbLastFocus) (This)->lpVtbl->_put_itbLastFocus(This,itbLastFocus)
#define IBrowserService2__UIActivateView(This,uState) (This)->lpVtbl->_UIActivateView(This,uState)
#define IBrowserService2__GetViewBorderRect(This,prc) (This)->lpVtbl->_GetViewBorderRect(This,prc)
#define IBrowserService2__UpdateViewRectSize(This) (This)->lpVtbl->_UpdateViewRectSize(This)
#define IBrowserService2__ResizeNextBorder(This,itb) (This)->lpVtbl->_ResizeNextBorder(This,itb)
#define IBrowserService2__ResizeView(This) (This)->lpVtbl->_ResizeView(This)
#define IBrowserService2__GetEffectiveClientArea(This,lprectBorder,hmon) (This)->lpVtbl->_GetEffectiveClientArea(This,lprectBorder,hmon)
#define IBrowserService2_v_GetViewStream(This,pidl,grfMode,pwszName) (This)->lpVtbl->v_GetViewStream(This,pidl,grfMode,pwszName)
#define IBrowserService2_ForwardViewMsg(This,uMsg,wParam,lParam) (This)->lpVtbl->ForwardViewMsg(This,uMsg,wParam,lParam)
#define IBrowserService2_SetAcceleratorMenu(This,hacc) (This)->lpVtbl->SetAcceleratorMenu(This,hacc)
#define IBrowserService2__GetToolbarCount(This) (This)->lpVtbl->_GetToolbarCount(This)
#define IBrowserService2__GetToolbarItem(This,itb) (This)->lpVtbl->_GetToolbarItem(This,itb)
#define IBrowserService2__SaveToolbars(This,pstm) (This)->lpVtbl->_SaveToolbars(This,pstm)
#define IBrowserService2__LoadToolbars(This,pstm) (This)->lpVtbl->_LoadToolbars(This,pstm)
#define IBrowserService2__CloseAndReleaseToolbars(This,fClose) (This)->lpVtbl->_CloseAndReleaseToolbars(This,fClose)
#define IBrowserService2_v_MayGetNextToolbarFocus(This,lpMsg,itbNext,citb,pptbi,phwnd) (This)->lpVtbl->v_MayGetNextToolbarFocus(This,lpMsg,itbNext,citb,pptbi,phwnd)
#define IBrowserService2__ResizeNextBorderHelper(This,itb,bUseHmonitor) (This)->lpVtbl->_ResizeNextBorderHelper(This,itb,bUseHmonitor)
#define IBrowserService2__FindTBar(This,punkSrc) (This)->lpVtbl->_FindTBar(This,punkSrc)
#define IBrowserService2__SetFocus(This,ptbi,hwnd,lpMsg) (This)->lpVtbl->_SetFocus(This,ptbi,hwnd,lpMsg)
#define IBrowserService2_v_MayTranslateAccelerator(This,pmsg) (This)->lpVtbl->v_MayTranslateAccelerator(This,pmsg)
#define IBrowserService2__GetBorderDWHelper(This,punkSrc,lprectBorder,bUseHmonitor) (This)->lpVtbl->_GetBorderDWHelper(This,punkSrc,lprectBorder,bUseHmonitor)
#define IBrowserService2_v_CheckZoneCrossing(This,pidl) (This)->lpVtbl->v_CheckZoneCrossing(This,pidl)
#endif
#endif
  LRESULT WINAPI IBrowserService2_WndProcBS_Proxy(IBrowserService2 *This,HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam);
  void __RPC_STUB IBrowserService2_WndProcBS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_SetAsDefFolderSettings_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_SetAsDefFolderSettings_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_GetViewRect_Proxy(IBrowserService2 *This,RECT *prc);
  void __RPC_STUB IBrowserService2_GetViewRect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_OnSize_Proxy(IBrowserService2 *This,WPARAM wParam);
  void __RPC_STUB IBrowserService2_OnSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_OnCreate_Proxy(IBrowserService2 *This,struct tagCREATESTRUCTW *pcs);
  void __RPC_STUB IBrowserService2_OnCreate_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LRESULT WINAPI IBrowserService2_OnCommand_Proxy(IBrowserService2 *This,WPARAM wParam,LPARAM lParam);
  void __RPC_STUB IBrowserService2_OnCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_OnDestroy_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_OnDestroy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LRESULT WINAPI IBrowserService2_OnNotify_Proxy(IBrowserService2 *This,struct tagNMHDR *pnm);
  void __RPC_STUB IBrowserService2_OnNotify_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_OnSetFocus_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_OnSetFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_OnFrameWindowActivateBS_Proxy(IBrowserService2 *This,WINBOOL fActive);
  void __RPC_STUB IBrowserService2_OnFrameWindowActivateBS_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_ReleaseShellView_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_ReleaseShellView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_ActivatePendingView_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_ActivatePendingView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_CreateViewWindow_Proxy(IBrowserService2 *This,IShellView *psvNew,IShellView *psvOld,LPRECT prcView,HWND *phwnd);
  void __RPC_STUB IBrowserService2_CreateViewWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_CreateBrowserPropSheetExt_Proxy(IBrowserService2 *This,REFIID riid,void **ppv);
  void __RPC_STUB IBrowserService2_CreateBrowserPropSheetExt_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_GetViewWindow_Proxy(IBrowserService2 *This,HWND *phwndView);
  void __RPC_STUB IBrowserService2_GetViewWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_GetBaseBrowserData_Proxy(IBrowserService2 *This,LPCBASEBROWSERDATA *pbbd);
  void __RPC_STUB IBrowserService2_GetBaseBrowserData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LPBASEBROWSERDATA WINAPI IBrowserService2_PutBaseBrowserData_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_PutBaseBrowserData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_InitializeTravelLog_Proxy(IBrowserService2 *This,ITravelLog *ptl,DWORD dw);
  void __RPC_STUB IBrowserService2_InitializeTravelLog_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_SetTopBrowser_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_SetTopBrowser_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_Offline_Proxy(IBrowserService2 *This,int iCmd);
  void __RPC_STUB IBrowserService2_Offline_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_AllowViewResize_Proxy(IBrowserService2 *This,WINBOOL f);
  void __RPC_STUB IBrowserService2_AllowViewResize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_SetActivateState_Proxy(IBrowserService2 *This,UINT u);
  void __RPC_STUB IBrowserService2_SetActivateState_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_UpdateSecureLockIcon_Proxy(IBrowserService2 *This,int eSecureLock);
  void __RPC_STUB IBrowserService2_UpdateSecureLockIcon_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_InitializeDownloadManager_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_InitializeDownloadManager_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_InitializeTransitionSite_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2_InitializeTransitionSite_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__Initialize_Proxy(IBrowserService2 *This,HWND hwnd,IUnknown *pauto);
  void __RPC_STUB IBrowserService2__Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__CancelPendingNavigationAsync_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__CancelPendingNavigationAsync_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__CancelPendingView_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__CancelPendingView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__MaySaveChanges_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__MaySaveChanges_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__PauseOrResumeView_Proxy(IBrowserService2 *This,WINBOOL fPaused);
  void __RPC_STUB IBrowserService2__PauseOrResumeView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__DisableModeless_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__DisableModeless_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__NavigateToPidl_Proxy(IBrowserService2 *This,LPCITEMIDLIST pidl,DWORD grfHLNF,DWORD dwFlags);
  void __RPC_STUB IBrowserService2__NavigateToPidl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__TryShell2Rename_Proxy(IBrowserService2 *This,IShellView *psv,LPCITEMIDLIST pidlNew);
  void __RPC_STUB IBrowserService2__TryShell2Rename_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__SwitchActivationNow_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__SwitchActivationNow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__ExecChildren_Proxy(IBrowserService2 *This,IUnknown *punkBar,WINBOOL fBroadcast,const GUID *pguidCmdGroup,DWORD nCmdID,DWORD nCmdexecopt,VARIANTARG *pvarargIn,VARIANTARG *pvarargOut);
  void __RPC_STUB IBrowserService2__ExecChildren_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__SendChildren_Proxy(IBrowserService2 *This,HWND hwndBar,WINBOOL fBroadcast,UINT uMsg,WPARAM wParam,LPARAM lParam);
  void __RPC_STUB IBrowserService2__SendChildren_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_GetFolderSetData_Proxy(IBrowserService2 *This,struct tagFolderSetData *pfsd);
  void __RPC_STUB IBrowserService2_GetFolderSetData_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__OnFocusChange_Proxy(IBrowserService2 *This,UINT itb);
  void __RPC_STUB IBrowserService2__OnFocusChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_v_ShowHideChildWindows_Proxy(IBrowserService2 *This,WINBOOL fChildOnly);
  void __RPC_STUB IBrowserService2_v_ShowHideChildWindows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  UINT WINAPI IBrowserService2__get_itbLastFocus_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__get_itbLastFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__put_itbLastFocus_Proxy(IBrowserService2 *This,UINT itbLastFocus);
  void __RPC_STUB IBrowserService2__put_itbLastFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__UIActivateView_Proxy(IBrowserService2 *This,UINT uState);
  void __RPC_STUB IBrowserService2__UIActivateView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__GetViewBorderRect_Proxy(IBrowserService2 *This,RECT *prc);
  void __RPC_STUB IBrowserService2__GetViewBorderRect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__UpdateViewRectSize_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__UpdateViewRectSize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__ResizeNextBorder_Proxy(IBrowserService2 *This,UINT itb);
  void __RPC_STUB IBrowserService2__ResizeNextBorder_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__ResizeView_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__ResizeView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__GetEffectiveClientArea_Proxy(IBrowserService2 *This,LPRECT lprectBorder,HMONITOR hmon);
  void __RPC_STUB IBrowserService2__GetEffectiveClientArea_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  IStream *WINAPI IBrowserService2_v_GetViewStream_Proxy(IBrowserService2 *This,LPCITEMIDLIST pidl,DWORD grfMode,LPCWSTR pwszName);
  void __RPC_STUB IBrowserService2_v_GetViewStream_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LRESULT WINAPI IBrowserService2_ForwardViewMsg_Proxy(IBrowserService2 *This,UINT uMsg,WPARAM wParam,LPARAM lParam);
  void __RPC_STUB IBrowserService2_ForwardViewMsg_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_SetAcceleratorMenu_Proxy(IBrowserService2 *This,HACCEL hacc);
  void __RPC_STUB IBrowserService2_SetAcceleratorMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  int WINAPI IBrowserService2__GetToolbarCount_Proxy(IBrowserService2 *This);
  void __RPC_STUB IBrowserService2__GetToolbarCount_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  LPTOOLBARITEM WINAPI IBrowserService2__GetToolbarItem_Proxy(IBrowserService2 *This,int itb);
  void __RPC_STUB IBrowserService2__GetToolbarItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__SaveToolbars_Proxy(IBrowserService2 *This,IStream *pstm);
  void __RPC_STUB IBrowserService2__SaveToolbars_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__LoadToolbars_Proxy(IBrowserService2 *This,IStream *pstm);
  void __RPC_STUB IBrowserService2__LoadToolbars_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__CloseAndReleaseToolbars_Proxy(IBrowserService2 *This,WINBOOL fClose);
  void __RPC_STUB IBrowserService2__CloseAndReleaseToolbars_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_v_MayGetNextToolbarFocus_Proxy(IBrowserService2 *This,LPMSG lpMsg,UINT itbNext,int citb,LPTOOLBARITEM *pptbi,HWND *phwnd);
  void __RPC_STUB IBrowserService2_v_MayGetNextToolbarFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__ResizeNextBorderHelper_Proxy(IBrowserService2 *This,UINT itb,WINBOOL bUseHmonitor);
  void __RPC_STUB IBrowserService2__ResizeNextBorderHelper_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  UINT WINAPI IBrowserService2__FindTBar_Proxy(IBrowserService2 *This,IUnknown *punkSrc);
  void __RPC_STUB IBrowserService2__FindTBar_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__SetFocus_Proxy(IBrowserService2 *This,LPTOOLBARITEM ptbi,HWND hwnd,LPMSG lpMsg);
  void __RPC_STUB IBrowserService2__SetFocus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_v_MayTranslateAccelerator_Proxy(IBrowserService2 *This,MSG *pmsg);
  void __RPC_STUB IBrowserService2_v_MayTranslateAccelerator_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2__GetBorderDWHelper_Proxy(IBrowserService2 *This,IUnknown *punkSrc,LPRECT lprectBorder,WINBOOL bUseHmonitor);
  void __RPC_STUB IBrowserService2__GetBorderDWHelper_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService2_v_CheckZoneCrossing_Proxy(IBrowserService2 *This,LPCITEMIDLIST pidl);
  void __RPC_STUB IBrowserService2_v_CheckZoneCrossing_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IBrowserService3_INTERFACE_DEFINED__
#define __IBrowserService3_INTERFACE_DEFINED__
  typedef enum __MIDL_IBrowserService3_0001 {
    IEPDN_BINDINGUI = 0x1
  } IEPDNFLAGS;

  EXTERN_C const IID IID_IBrowserService3;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IBrowserService3 : public IBrowserService2 {
  public:
    virtual HRESULT WINAPI _PositionViewWindow(HWND hwnd,LPRECT prc) = 0;
    virtual HRESULT WINAPI IEParseDisplayNameEx(UINT uiCP,LPCWSTR pwszPath,DWORD dwFlags,LPITEMIDLIST *ppidlOut) = 0;
  };
#else
  typedef struct IBrowserService3Vtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IBrowserService3 *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IBrowserService3 *This);
      ULONG (WINAPI *Release)(IBrowserService3 *This);
      HRESULT (WINAPI *GetParentSite)(IBrowserService3 *This,IOleInPlaceSite **ppipsite);
      HRESULT (WINAPI *SetTitle)(IBrowserService3 *This,IShellView *psv,LPCWSTR pszName);
      HRESULT (WINAPI *GetTitle)(IBrowserService3 *This,IShellView *psv,LPWSTR pszName,DWORD cchName);
      HRESULT (WINAPI *GetOleObject)(IBrowserService3 *This,IOleObject **ppobjv);
      HRESULT (WINAPI *GetTravelLog)(IBrowserService3 *This,ITravelLog **pptl);
      HRESULT (WINAPI *ShowControlWindow)(IBrowserService3 *This,UINT id,WINBOOL fShow);
      HRESULT (WINAPI *IsControlWindowShown)(IBrowserService3 *This,UINT id,WINBOOL *pfShown);
      HRESULT (WINAPI *IEGetDisplayName)(IBrowserService3 *This,LPCITEMIDLIST pidl,LPWSTR pwszName,UINT uFlags);
      HRESULT (WINAPI *IEParseDisplayName)(IBrowserService3 *This,UINT uiCP,LPCWSTR pwszPath,LPITEMIDLIST *ppidlOut);
      HRESULT (WINAPI *DisplayParseError)(IBrowserService3 *This,HRESULT hres,LPCWSTR pwszPath);
      HRESULT (WINAPI *NavigateToPidl)(IBrowserService3 *This,LPCITEMIDLIST pidl,DWORD grfHLNF);
      HRESULT (WINAPI *SetNavigateState)(IBrowserService3 *This,BNSTATE bnstate);
      HRESULT (WINAPI *GetNavigateState)(IBrowserService3 *This,BNSTATE *pbnstate);
      HRESULT (WINAPI *NotifyRedirect)(IBrowserService3 *This,IShellView *psv,LPCITEMIDLIST pidl,WINBOOL *pfDidBrowse);
      HRESULT (WINAPI *UpdateWindowList)(IBrowserService3 *This);
      HRESULT (WINAPI *UpdateBackForwardState)(IBrowserService3 *This);
      HRESULT (WINAPI *SetFlags)(IBrowserService3 *This,DWORD dwFlags,DWORD dwFlagMask);
      HRESULT (WINAPI *GetFlags)(IBrowserService3 *This,DWORD *pdwFlags);
      HRESULT (WINAPI *CanNavigateNow)(IBrowserService3 *This);
      HRESULT (WINAPI *GetPidl)(IBrowserService3 *This,LPITEMIDLIST *ppidl);
      HRESULT (WINAPI *SetReferrer)(IBrowserService3 *This,LPITEMIDLIST pidl);
      DWORD (WINAPI *GetBrowserIndex)(IBrowserService3 *This);
      HRESULT (WINAPI *GetBrowserByIndex)(IBrowserService3 *This,DWORD dwID,IUnknown **ppunk);
      HRESULT (WINAPI *GetHistoryObject)(IBrowserService3 *This,IOleObject **ppole,IStream **pstm,IBindCtx **ppbc);
      HRESULT (WINAPI *SetHistoryObject)(IBrowserService3 *This,IOleObject *pole,WINBOOL fIsLocalAnchor);
      HRESULT (WINAPI *CacheOLEServer)(IBrowserService3 *This,IOleObject *pole);
      HRESULT (WINAPI *GetSetCodePage)(IBrowserService3 *This,VARIANT *pvarIn,VARIANT *pvarOut);
      HRESULT (WINAPI *OnHttpEquiv)(IBrowserService3 *This,IShellView *psv,WINBOOL fDone,VARIANT *pvarargIn,VARIANT *pvarargOut);
      HRESULT (WINAPI *GetPalette)(IBrowserService3 *This,HPALETTE *hpal);
      HRESULT (WINAPI *RegisterWindow)(IBrowserService3 *This,WINBOOL fForceRegister,int swc);
      LRESULT (WINAPI *WndProcBS)(IBrowserService3 *This,HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *SetAsDefFolderSettings)(IBrowserService3 *This);
      HRESULT (WINAPI *GetViewRect)(IBrowserService3 *This,RECT *prc);
      HRESULT (WINAPI *OnSize)(IBrowserService3 *This,WPARAM wParam);
      HRESULT (WINAPI *OnCreate)(IBrowserService3 *This,struct tagCREATESTRUCTW *pcs);
      LRESULT (WINAPI *OnCommand)(IBrowserService3 *This,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *OnDestroy)(IBrowserService3 *This);
      LRESULT (WINAPI *OnNotify)(IBrowserService3 *This,struct tagNMHDR *pnm);
      HRESULT (WINAPI *OnSetFocus)(IBrowserService3 *This);
      HRESULT (WINAPI *OnFrameWindowActivateBS)(IBrowserService3 *This,WINBOOL fActive);
      HRESULT (WINAPI *ReleaseShellView)(IBrowserService3 *This);
      HRESULT (WINAPI *ActivatePendingView)(IBrowserService3 *This);
      HRESULT (WINAPI *CreateViewWindow)(IBrowserService3 *This,IShellView *psvNew,IShellView *psvOld,LPRECT prcView,HWND *phwnd);
      HRESULT (WINAPI *CreateBrowserPropSheetExt)(IBrowserService3 *This,REFIID riid,void **ppv);
      HRESULT (WINAPI *GetViewWindow)(IBrowserService3 *This,HWND *phwndView);
      HRESULT (WINAPI *GetBaseBrowserData)(IBrowserService3 *This,LPCBASEBROWSERDATA *pbbd);
      LPBASEBROWSERDATA (WINAPI *PutBaseBrowserData)(IBrowserService3 *This);
      HRESULT (WINAPI *InitializeTravelLog)(IBrowserService3 *This,ITravelLog *ptl,DWORD dw);
      HRESULT (WINAPI *SetTopBrowser)(IBrowserService3 *This);
      HRESULT (WINAPI *Offline)(IBrowserService3 *This,int iCmd);
      HRESULT (WINAPI *AllowViewResize)(IBrowserService3 *This,WINBOOL f);
      HRESULT (WINAPI *SetActivateState)(IBrowserService3 *This,UINT u);
      HRESULT (WINAPI *UpdateSecureLockIcon)(IBrowserService3 *This,int eSecureLock);
      HRESULT (WINAPI *InitializeDownloadManager)(IBrowserService3 *This);
      HRESULT (WINAPI *InitializeTransitionSite)(IBrowserService3 *This);
      HRESULT (WINAPI *_Initialize)(IBrowserService3 *This,HWND hwnd,IUnknown *pauto);
      HRESULT (WINAPI *_CancelPendingNavigationAsync)(IBrowserService3 *This);
      HRESULT (WINAPI *_CancelPendingView)(IBrowserService3 *This);
      HRESULT (WINAPI *_MaySaveChanges)(IBrowserService3 *This);
      HRESULT (WINAPI *_PauseOrResumeView)(IBrowserService3 *This,WINBOOL fPaused);
      HRESULT (WINAPI *_DisableModeless)(IBrowserService3 *This);
      HRESULT (WINAPI *_NavigateToPidl)(IBrowserService3 *This,LPCITEMIDLIST pidl,DWORD grfHLNF,DWORD dwFlags);
      HRESULT (WINAPI *_TryShell2Rename)(IBrowserService3 *This,IShellView *psv,LPCITEMIDLIST pidlNew);
      HRESULT (WINAPI *_SwitchActivationNow)(IBrowserService3 *This);
      HRESULT (WINAPI *_ExecChildren)(IBrowserService3 *This,IUnknown *punkBar,WINBOOL fBroadcast,const GUID *pguidCmdGroup,DWORD nCmdID,DWORD nCmdexecopt,VARIANTARG *pvarargIn,VARIANTARG *pvarargOut);
      HRESULT (WINAPI *_SendChildren)(IBrowserService3 *This,HWND hwndBar,WINBOOL fBroadcast,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *GetFolderSetData)(IBrowserService3 *This,struct tagFolderSetData *pfsd);
      HRESULT (WINAPI *_OnFocusChange)(IBrowserService3 *This,UINT itb);
      HRESULT (WINAPI *v_ShowHideChildWindows)(IBrowserService3 *This,WINBOOL fChildOnly);
      UINT (WINAPI *_get_itbLastFocus)(IBrowserService3 *This);
      HRESULT (WINAPI *_put_itbLastFocus)(IBrowserService3 *This,UINT itbLastFocus);
      HRESULT (WINAPI *_UIActivateView)(IBrowserService3 *This,UINT uState);
      HRESULT (WINAPI *_GetViewBorderRect)(IBrowserService3 *This,RECT *prc);
      HRESULT (WINAPI *_UpdateViewRectSize)(IBrowserService3 *This);
      HRESULT (WINAPI *_ResizeNextBorder)(IBrowserService3 *This,UINT itb);
      HRESULT (WINAPI *_ResizeView)(IBrowserService3 *This);
      HRESULT (WINAPI *_GetEffectiveClientArea)(IBrowserService3 *This,LPRECT lprectBorder,HMONITOR hmon);
      IStream *(WINAPI *v_GetViewStream)(IBrowserService3 *This,LPCITEMIDLIST pidl,DWORD grfMode,LPCWSTR pwszName);
      LRESULT (WINAPI *ForwardViewMsg)(IBrowserService3 *This,UINT uMsg,WPARAM wParam,LPARAM lParam);
      HRESULT (WINAPI *SetAcceleratorMenu)(IBrowserService3 *This,HACCEL hacc);
      int (WINAPI *_GetToolbarCount)(IBrowserService3 *This);
      LPTOOLBARITEM (WINAPI *_GetToolbarItem)(IBrowserService3 *This,int itb);
      HRESULT (WINAPI *_SaveToolbars)(IBrowserService3 *This,IStream *pstm);
      HRESULT (WINAPI *_LoadToolbars)(IBrowserService3 *This,IStream *pstm);
      HRESULT (WINAPI *_CloseAndReleaseToolbars)(IBrowserService3 *This,WINBOOL fClose);
      HRESULT (WINAPI *v_MayGetNextToolbarFocus)(IBrowserService3 *This,LPMSG lpMsg,UINT itbNext,int citb,LPTOOLBARITEM *pptbi,HWND *phwnd);
      HRESULT (WINAPI *_ResizeNextBorderHelper)(IBrowserService3 *This,UINT itb,WINBOOL bUseHmonitor);
      UINT (WINAPI *_FindTBar)(IBrowserService3 *This,IUnknown *punkSrc);
      HRESULT (WINAPI *_SetFocus)(IBrowserService3 *This,LPTOOLBARITEM ptbi,HWND hwnd,LPMSG lpMsg);
      HRESULT (WINAPI *v_MayTranslateAccelerator)(IBrowserService3 *This,MSG *pmsg);
      HRESULT (WINAPI *_GetBorderDWHelper)(IBrowserService3 *This,IUnknown *punkSrc,LPRECT lprectBorder,WINBOOL bUseHmonitor);
      HRESULT (WINAPI *v_CheckZoneCrossing)(IBrowserService3 *This,LPCITEMIDLIST pidl);
      HRESULT (WINAPI *_PositionViewWindow)(IBrowserService3 *This,HWND hwnd,LPRECT prc);
      HRESULT (WINAPI *IEParseDisplayNameEx)(IBrowserService3 *This,UINT uiCP,LPCWSTR pwszPath,DWORD dwFlags,LPITEMIDLIST *ppidlOut);
    END_INTERFACE
  } IBrowserService3Vtbl;
  struct IBrowserService3 {
    CONST_VTBL struct IBrowserService3Vtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IBrowserService3_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IBrowserService3_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IBrowserService3_Release(This) (This)->lpVtbl->Release(This)
#define IBrowserService3_GetParentSite(This,ppipsite) (This)->lpVtbl->GetParentSite(This,ppipsite)
#define IBrowserService3_SetTitle(This,psv,pszName) (This)->lpVtbl->SetTitle(This,psv,pszName)
#define IBrowserService3_GetTitle(This,psv,pszName,cchName) (This)->lpVtbl->GetTitle(This,psv,pszName,cchName)
#define IBrowserService3_GetOleObject(This,ppobjv) (This)->lpVtbl->GetOleObject(This,ppobjv)
#define IBrowserService3_GetTravelLog(This,pptl) (This)->lpVtbl->GetTravelLog(This,pptl)
#define IBrowserService3_ShowControlWindow(This,id,fShow) (This)->lpVtbl->ShowControlWindow(This,id,fShow)
#define IBrowserService3_IsControlWindowShown(This,id,pfShown) (This)->lpVtbl->IsControlWindowShown(This,id,pfShown)
#define IBrowserService3_IEGetDisplayName(This,pidl,pwszName,uFlags) (This)->lpVtbl->IEGetDisplayName(This,pidl,pwszName,uFlags)
#define IBrowserService3_IEParseDisplayName(This,uiCP,pwszPath,ppidlOut) (This)->lpVtbl->IEParseDisplayName(This,uiCP,pwszPath,ppidlOut)
#define IBrowserService3_DisplayParseError(This,hres,pwszPath) (This)->lpVtbl->DisplayParseError(This,hres,pwszPath)
#define IBrowserService3_NavigateToPidl(This,pidl,grfHLNF) (This)->lpVtbl->NavigateToPidl(This,pidl,grfHLNF)
#define IBrowserService3_SetNavigateState(This,bnstate) (This)->lpVtbl->SetNavigateState(This,bnstate)
#define IBrowserService3_GetNavigateState(This,pbnstate) (This)->lpVtbl->GetNavigateState(This,pbnstate)
#define IBrowserService3_NotifyRedirect(This,psv,pidl,pfDidBrowse) (This)->lpVtbl->NotifyRedirect(This,psv,pidl,pfDidBrowse)
#define IBrowserService3_UpdateWindowList(This) (This)->lpVtbl->UpdateWindowList(This)
#define IBrowserService3_UpdateBackForwardState(This) (This)->lpVtbl->UpdateBackForwardState(This)
#define IBrowserService3_SetFlags(This,dwFlags,dwFlagMask) (This)->lpVtbl->SetFlags(This,dwFlags,dwFlagMask)
#define IBrowserService3_GetFlags(This,pdwFlags) (This)->lpVtbl->GetFlags(This,pdwFlags)
#define IBrowserService3_CanNavigateNow(This) (This)->lpVtbl->CanNavigateNow(This)
#define IBrowserService3_GetPidl(This,ppidl) (This)->lpVtbl->GetPidl(This,ppidl)
#define IBrowserService3_SetReferrer(This,pidl) (This)->lpVtbl->SetReferrer(This,pidl)
#define IBrowserService3_GetBrowserIndex(This) (This)->lpVtbl->GetBrowserIndex(This)
#define IBrowserService3_GetBrowserByIndex(This,dwID,ppunk) (This)->lpVtbl->GetBrowserByIndex(This,dwID,ppunk)
#define IBrowserService3_GetHistoryObject(This,ppole,pstm,ppbc) (This)->lpVtbl->GetHistoryObject(This,ppole,pstm,ppbc)
#define IBrowserService3_SetHistoryObject(This,pole,fIsLocalAnchor) (This)->lpVtbl->SetHistoryObject(This,pole,fIsLocalAnchor)
#define IBrowserService3_CacheOLEServer(This,pole) (This)->lpVtbl->CacheOLEServer(This,pole)
#define IBrowserService3_GetSetCodePage(This,pvarIn,pvarOut) (This)->lpVtbl->GetSetCodePage(This,pvarIn,pvarOut)
#define IBrowserService3_OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut) (This)->lpVtbl->OnHttpEquiv(This,psv,fDone,pvarargIn,pvarargOut)
#define IBrowserService3_GetPalette(This,hpal) (This)->lpVtbl->GetPalette(This,hpal)
#define IBrowserService3_RegisterWindow(This,fForceRegister,swc) (This)->lpVtbl->RegisterWindow(This,fForceRegister,swc)
#define IBrowserService3_WndProcBS(This,hwnd,uMsg,wParam,lParam) (This)->lpVtbl->WndProcBS(This,hwnd,uMsg,wParam,lParam)
#define IBrowserService3_SetAsDefFolderSettings(This) (This)->lpVtbl->SetAsDefFolderSettings(This)
#define IBrowserService3_GetViewRect(This,prc) (This)->lpVtbl->GetViewRect(This,prc)
#define IBrowserService3_OnSize(This,wParam) (This)->lpVtbl->OnSize(This,wParam)
#define IBrowserService3_OnCreate(This,pcs) (This)->lpVtbl->OnCreate(This,pcs)
#define IBrowserService3_OnCommand(This,wParam,lParam) (This)->lpVtbl->OnCommand(This,wParam,lParam)
#define IBrowserService3_OnDestroy(This) (This)->lpVtbl->OnDestroy(This)
#define IBrowserService3_OnNotify(This,pnm) (This)->lpVtbl->OnNotify(This,pnm)
#define IBrowserService3_OnSetFocus(This) (This)->lpVtbl->OnSetFocus(This)
#define IBrowserService3_OnFrameWindowActivateBS(This,fActive) (This)->lpVtbl->OnFrameWindowActivateBS(This,fActive)
#define IBrowserService3_ReleaseShellView(This) (This)->lpVtbl->ReleaseShellView(This)
#define IBrowserService3_ActivatePendingView(This) (This)->lpVtbl->ActivatePendingView(This)
#define IBrowserService3_CreateViewWindow(This,psvNew,psvOld,prcView,phwnd) (This)->lpVtbl->CreateViewWindow(This,psvNew,psvOld,prcView,phwnd)
#define IBrowserService3_CreateBrowserPropSheetExt(This,riid,ppv) (This)->lpVtbl->CreateBrowserPropSheetExt(This,riid,ppv)
#define IBrowserService3_GetViewWindow(This,phwndView) (This)->lpVtbl->GetViewWindow(This,phwndView)
#define IBrowserService3_GetBaseBrowserData(This,pbbd) (This)->lpVtbl->GetBaseBrowserData(This,pbbd)
#define IBrowserService3_PutBaseBrowserData(This) (This)->lpVtbl->PutBaseBrowserData(This)
#define IBrowserService3_InitializeTravelLog(This,ptl,dw) (This)->lpVtbl->InitializeTravelLog(This,ptl,dw)
#define IBrowserService3_SetTopBrowser(This) (This)->lpVtbl->SetTopBrowser(This)
#define IBrowserService3_Offline(This,iCmd) (This)->lpVtbl->Offline(This,iCmd)
#define IBrowserService3_AllowViewResize(This,f) (This)->lpVtbl->AllowViewResize(This,f)
#define IBrowserService3_SetActivateState(This,u) (This)->lpVtbl->SetActivateState(This,u)
#define IBrowserService3_UpdateSecureLockIcon(This,eSecureLock) (This)->lpVtbl->UpdateSecureLockIcon(This,eSecureLock)
#define IBrowserService3_InitializeDownloadManager(This) (This)->lpVtbl->InitializeDownloadManager(This)
#define IBrowserService3_InitializeTransitionSite(This) (This)->lpVtbl->InitializeTransitionSite(This)
#define IBrowserService3__Initialize(This,hwnd,pauto) (This)->lpVtbl->_Initialize(This,hwnd,pauto)
#define IBrowserService3__CancelPendingNavigationAsync(This) (This)->lpVtbl->_CancelPendingNavigationAsync(This)
#define IBrowserService3__CancelPendingView(This) (This)->lpVtbl->_CancelPendingView(This)
#define IBrowserService3__MaySaveChanges(This) (This)->lpVtbl->_MaySaveChanges(This)
#define IBrowserService3__PauseOrResumeView(This,fPaused) (This)->lpVtbl->_PauseOrResumeView(This,fPaused)
#define IBrowserService3__DisableModeless(This) (This)->lpVtbl->_DisableModeless(This)
#define IBrowserService3__NavigateToPidl(This,pidl,grfHLNF,dwFlags) (This)->lpVtbl->_NavigateToPidl(This,pidl,grfHLNF,dwFlags)
#define IBrowserService3__TryShell2Rename(This,psv,pidlNew) (This)->lpVtbl->_TryShell2Rename(This,psv,pidlNew)
#define IBrowserService3__SwitchActivationNow(This) (This)->lpVtbl->_SwitchActivationNow(This)
#define IBrowserService3__ExecChildren(This,punkBar,fBroadcast,pguidCmdGroup,nCmdID,nCmdexecopt,pvarargIn,pvarargOut) (This)->lpVtbl->_ExecChildren(This,punkBar,fBroadcast,pguidCmdGroup,nCmdID,nCmdexecopt,pvarargIn,pvarargOut)
#define IBrowserService3__SendChildren(This,hwndBar,fBroadcast,uMsg,wParam,lParam) (This)->lpVtbl->_SendChildren(This,hwndBar,fBroadcast,uMsg,wParam,lParam)
#define IBrowserService3_GetFolderSetData(This,pfsd) (This)->lpVtbl->GetFolderSetData(This,pfsd)
#define IBrowserService3__OnFocusChange(This,itb) (This)->lpVtbl->_OnFocusChange(This,itb)
#define IBrowserService3_v_ShowHideChildWindows(This,fChildOnly) (This)->lpVtbl->v_ShowHideChildWindows(This,fChildOnly)
#define IBrowserService3__get_itbLastFocus(This) (This)->lpVtbl->_get_itbLastFocus(This)
#define IBrowserService3__put_itbLastFocus(This,itbLastFocus) (This)->lpVtbl->_put_itbLastFocus(This,itbLastFocus)
#define IBrowserService3__UIActivateView(This,uState) (This)->lpVtbl->_UIActivateView(This,uState)
#define IBrowserService3__GetViewBorderRect(This,prc) (This)->lpVtbl->_GetViewBorderRect(This,prc)
#define IBrowserService3__UpdateViewRectSize(This) (This)->lpVtbl->_UpdateViewRectSize(This)
#define IBrowserService3__ResizeNextBorder(This,itb) (This)->lpVtbl->_ResizeNextBorder(This,itb)
#define IBrowserService3__ResizeView(This) (This)->lpVtbl->_ResizeView(This)
#define IBrowserService3__GetEffectiveClientArea(This,lprectBorder,hmon) (This)->lpVtbl->_GetEffectiveClientArea(This,lprectBorder,hmon)
#define IBrowserService3_v_GetViewStream(This,pidl,grfMode,pwszName) (This)->lpVtbl->v_GetViewStream(This,pidl,grfMode,pwszName)
#define IBrowserService3_ForwardViewMsg(This,uMsg,wParam,lParam) (This)->lpVtbl->ForwardViewMsg(This,uMsg,wParam,lParam)
#define IBrowserService3_SetAcceleratorMenu(This,hacc) (This)->lpVtbl->SetAcceleratorMenu(This,hacc)
#define IBrowserService3__GetToolbarCount(This) (This)->lpVtbl->_GetToolbarCount(This)
#define IBrowserService3__GetToolbarItem(This,itb) (This)->lpVtbl->_GetToolbarItem(This,itb)
#define IBrowserService3__SaveToolbars(This,pstm) (This)->lpVtbl->_SaveToolbars(This,pstm)
#define IBrowserService3__LoadToolbars(This,pstm) (This)->lpVtbl->_LoadToolbars(This,pstm)
#define IBrowserService3__CloseAndReleaseToolbars(This,fClose) (This)->lpVtbl->_CloseAndReleaseToolbars(This,fClose)
#define IBrowserService3_v_MayGetNextToolbarFocus(This,lpMsg,itbNext,citb,pptbi,phwnd) (This)->lpVtbl->v_MayGetNextToolbarFocus(This,lpMsg,itbNext,citb,pptbi,phwnd)
#define IBrowserService3__ResizeNextBorderHelper(This,itb,bUseHmonitor) (This)->lpVtbl->_ResizeNextBorderHelper(This,itb,bUseHmonitor)
#define IBrowserService3__FindTBar(This,punkSrc) (This)->lpVtbl->_FindTBar(This,punkSrc)
#define IBrowserService3__SetFocus(This,ptbi,hwnd,lpMsg) (This)->lpVtbl->_SetFocus(This,ptbi,hwnd,lpMsg)
#define IBrowserService3_v_MayTranslateAccelerator(This,pmsg) (This)->lpVtbl->v_MayTranslateAccelerator(This,pmsg)
#define IBrowserService3__GetBorderDWHelper(This,punkSrc,lprectBorder,bUseHmonitor) (This)->lpVtbl->_GetBorderDWHelper(This,punkSrc,lprectBorder,bUseHmonitor)
#define IBrowserService3_v_CheckZoneCrossing(This,pidl) (This)->lpVtbl->v_CheckZoneCrossing(This,pidl)
#define IBrowserService3__PositionViewWindow(This,hwnd,prc) (This)->lpVtbl->_PositionViewWindow(This,hwnd,prc)
#define IBrowserService3_IEParseDisplayNameEx(This,uiCP,pwszPath,dwFlags,ppidlOut) (This)->lpVtbl->IEParseDisplayNameEx(This,uiCP,pwszPath,dwFlags,ppidlOut)
#endif
#endif
  HRESULT WINAPI IBrowserService3__PositionViewWindow_Proxy(IBrowserService3 *This,HWND hwnd,LPRECT prc);
  void __RPC_STUB IBrowserService3__PositionViewWindow_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IBrowserService3_IEParseDisplayNameEx_Proxy(IBrowserService3 *This,UINT uiCP,LPCWSTR pwszPath,DWORD dwFlags,LPITEMIDLIST *ppidlOut);
  void __RPC_STUB IBrowserService3_IEParseDisplayNameEx_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifdef __cplusplus
}
#endif
#endif
