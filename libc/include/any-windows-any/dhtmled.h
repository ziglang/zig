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

#ifndef __dhtmled_h__
#define __dhtmled_h__

#ifdef __cplusplus
extern "C"{
#endif

#ifndef __IDEGetBlockFmtNamesParam_FWD_DEFINED__
#define __IDEGetBlockFmtNamesParam_FWD_DEFINED__
  typedef struct IDEGetBlockFmtNamesParam IDEGetBlockFmtNamesParam;
#endif

#ifndef __IDHTMLSafe_FWD_DEFINED__
#define __IDHTMLSafe_FWD_DEFINED__
  typedef struct IDHTMLSafe IDHTMLSafe;
#endif

#ifndef __IDHTMLEdit_FWD_DEFINED__
#define __IDHTMLEdit_FWD_DEFINED__
  typedef struct IDHTMLEdit IDHTMLEdit;
#endif

#ifndef __IDEInsertTableParam_FWD_DEFINED__
#define __IDEInsertTableParam_FWD_DEFINED__
  typedef struct IDEInsertTableParam IDEInsertTableParam;
#endif

#ifndef ___DHTMLSafeEvents_FWD_DEFINED__
#define ___DHTMLSafeEvents_FWD_DEFINED__
  typedef struct _DHTMLSafeEvents _DHTMLSafeEvents;
#endif

#ifndef ___DHTMLEditEvents_FWD_DEFINED__
#define ___DHTMLEditEvents_FWD_DEFINED__
  typedef struct _DHTMLEditEvents _DHTMLEditEvents;
#endif

#ifndef __DHTMLEdit_FWD_DEFINED__
#define __DHTMLEdit_FWD_DEFINED__
#ifdef __cplusplus
  typedef class DHTMLEdit DHTMLEdit;
#else
  typedef struct DHTMLEdit DHTMLEdit;
#endif
#endif

#ifndef __DHTMLSafe_FWD_DEFINED__
#define __DHTMLSafe_FWD_DEFINED__
#ifdef __cplusplus
  typedef class DHTMLSafe DHTMLSafe;
#else
  typedef struct DHTMLSafe DHTMLSafe;
#endif
#endif

#ifndef __DEInsertTableParam_FWD_DEFINED__
#define __DEInsertTableParam_FWD_DEFINED__
#ifdef __cplusplus
  typedef class DEInsertTableParam DEInsertTableParam;
#else
  typedef struct DEInsertTableParam DEInsertTableParam;
#endif
#endif

#ifndef __DEGetBlockFmtNamesParam_FWD_DEFINED__
#define __DEGetBlockFmtNamesParam_FWD_DEFINED__
#ifdef __cplusplus
  typedef class DEGetBlockFmtNamesParam DEGetBlockFmtNamesParam;
#else
  typedef struct DEGetBlockFmtNamesParam DEGetBlockFmtNamesParam;
#endif
#endif

#include "oaidl.h"
#include "ocidl.h"
#include "docobj.h"

#ifndef __MIDL_user_allocate_free_DEFINED__
#define __MIDL_user_allocate_free_DEFINED__
  void *__RPC_API MIDL_user_allocate(size_t);
  void __RPC_API MIDL_user_free(void *);
#endif

#define DE_E_INVALIDARG E_INVALIDARG
#define DE_E_PATH_NOT_FOUND HRESULT_FROM_WIN32(ERROR_PATH_NOT_FOUND)
#define DE_E_FILE_NOT_FOUND HRESULT_FROM_WIN32(ERROR_FILE_NOT_FOUND)
#define DE_E_UNEXPECTED E_UNEXPECTED
#define DE_E_DISK_FULL HRESULT_FROM_WIN32(ERROR_HANDLE_DISK_FULL)
#define DE_E_NOTSUPPORTED OLECMDERR_E_NOTSUPPORTED
#define DE_E_ACCESS_DENIED HRESULT_FROM_WIN32(ERROR_ACCESS_DENIED)

#define DE_E_URL_SYNTAX MK_E_SYNTAX
#define DE_E_INVALID_URL 0x800C0002
#define DE_E_NO_SESSION 0x800C0003
#define DE_E_CANNOT_CONNECT 0x800C0004
#define DE_E_RESOURCE_NOT_FOUND 0x800C0005
#define DE_E_OBJECT_NOT_FOUND 0x800C0006
#define DE_E_DATA_NOT_AVAILABLE 0x800C0007
#define DE_E_DOWNLOAD_FAILURE 0x800C0008
#define DE_E_AUTHENTICATION_REQUIRED 0x800C0009
#define DE_E_NO_VALID_MEDIA 0x800C000A
#define DE_E_CONNECTION_TIMEOUT 0x800C000B
#define DE_E_INVALID_REQUEST 0x800C000C
#define DE_E_UNKNOWN_PROTOCOL 0x800C000D
#define DE_E_SECURITY_PROBLEM 0x800C000E
#define DE_E_CANNOT_LOAD_DATA 0x800C000F
#define DE_E_CANNOT_INSTANTIATE_OBJECT 0x800C0010
#define DE_E_REDIRECT_FAILED 0x800C0014
#define DE_E_REDIRECT_TO_DIR 0x800C0015
#define DE_E_CANNOT_LOCK_REQUEST 0x800C0016

#define DE_E_FILTER_FRAMESET 0x80100001
#define DE_E_FILTER_SERVERSCRIPT 0x80100002
#define DE_E_FILTER_MULTIPLETAGS 0x80100004
#define DE_E_FILTER_SCRIPTLISTING 0x80100008
#define DE_E_FILTER_SCRIPTLABEL 0x80100010
#define DE_E_FILTER_SCRIPTTEXTAREA 0x80100020
#define DE_E_FILTER_SCRIPTSELECT 0x80100040

  extern RPC_IF_HANDLE __MIDL_itf_dhtmled_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_dhtmled_0000_v0_0_s_ifspec;

#ifndef __DHTMLEDLib_LIBRARY_DEFINED__
#define __DHTMLEDLib_LIBRARY_DEFINED__
  typedef enum DHTMLEDITCMDID {
    DECMD_BOLD = 5000,DECMD_COPY = 5002,DECMD_CUT,DECMD_DELETE,DECMD_DELETECELLS,
    DECMD_DELETECOLS,DECMD_DELETEROWS,DECMD_FINDTEXT,DECMD_FONT,DECMD_GETBACKCOLOR,
    DECMD_GETBLOCKFMT,DECMD_GETBLOCKFMTNAMES,DECMD_GETFONTNAME,DECMD_GETFONTSIZE,
    DECMD_GETFORECOLOR,DECMD_HYPERLINK,DECMD_IMAGE,DECMD_INDENT,DECMD_INSERTCELL,
    DECMD_INSERTCOL,DECMD_INSERTROW,DECMD_INSERTTABLE,DECMD_ITALIC,DECMD_JUSTIFYCENTER,
    DECMD_JUSTIFYLEFT,DECMD_JUSTIFYRIGHT,DECMD_LOCK_ELEMENT,DECMD_MAKE_ABSOLUTE,
    DECMD_MERGECELLS,DECMD_ORDERLIST,DECMD_OUTDENT,DECMD_PASTE,
    DECMD_REDO,DECMD_REMOVEFORMAT,DECMD_SELECTALL,DECMD_SEND_BACKWARD,
    DECMD_BRING_FORWARD,DECMD_SEND_BELOW_TEXT,DECMD_BRING_ABOVE_TEXT,
    DECMD_SEND_TO_BACK,DECMD_BRING_TO_FRONT,DECMD_SETBACKCOLOR,DECMD_SETBLOCKFMT,
    DECMD_SETFONTNAME,DECMD_SETFONTSIZE,DECMD_SETFORECOLOR,DECMD_SPLITCELL,
    DECMD_UNDERLINE,DECMD_UNDO,DECMD_UNLINK,DECMD_UNORDERLIST,DECMD_PROPERTIES
  } DHTMLEDITCMDID;

  typedef enum DHTMLEDITCMDF {
    DECMDF_NOTSUPPORTED = 0,DECMDF_DISABLED = 0x1,DECMDF_ENABLED = 0x3,DECMDF_LATCHED = 0x7,DECMDF_NINCHED = 0xb
  } DHTMLEDITCMDF;

  typedef enum DHTMLEDITAPPEARANCE {
    DEAPPEARANCE_FLAT = 0,DEAPPEARANCE_3D = 0x1
  } DHTMLEDITAPPEARANCE;

  EXTERN_C const IID LIBID_DHTMLEDLib;
#ifndef __IDEGetBlockFmtNamesParam_INTERFACE_DEFINED__
#define __IDEGetBlockFmtNamesParam_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDEGetBlockFmtNamesParam;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDEGetBlockFmtNamesParam : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Names(VARIANT *pVal) = 0;
    virtual HRESULT WINAPI put_Names(VARIANT *newVal) = 0;
  };
#else
  typedef struct IDEGetBlockFmtNamesParamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDEGetBlockFmtNamesParam *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDEGetBlockFmtNamesParam *This);
      ULONG (WINAPI *Release)(IDEGetBlockFmtNamesParam *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDEGetBlockFmtNamesParam *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDEGetBlockFmtNamesParam *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDEGetBlockFmtNamesParam *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDEGetBlockFmtNamesParam *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Names)(IDEGetBlockFmtNamesParam *This,VARIANT *pVal);
      HRESULT (WINAPI *put_Names)(IDEGetBlockFmtNamesParam *This,VARIANT *newVal);
    END_INTERFACE
  } IDEGetBlockFmtNamesParamVtbl;
  struct IDEGetBlockFmtNamesParam {
    CONST_VTBL struct IDEGetBlockFmtNamesParamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDEGetBlockFmtNamesParam_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDEGetBlockFmtNamesParam_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDEGetBlockFmtNamesParam_Release(This) (This)->lpVtbl->Release(This)
#define IDEGetBlockFmtNamesParam_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDEGetBlockFmtNamesParam_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDEGetBlockFmtNamesParam_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDEGetBlockFmtNamesParam_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDEGetBlockFmtNamesParam_get_Names(This,pVal) (This)->lpVtbl->get_Names(This,pVal)
#define IDEGetBlockFmtNamesParam_put_Names(This,newVal) (This)->lpVtbl->put_Names(This,newVal)
#endif
#endif
  HRESULT WINAPI IDEGetBlockFmtNamesParam_get_Names_Proxy(IDEGetBlockFmtNamesParam *This,VARIANT *pVal);
  void __RPC_STUB IDEGetBlockFmtNamesParam_get_Names_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEGetBlockFmtNamesParam_put_Names_Proxy(IDEGetBlockFmtNamesParam *This,VARIANT *newVal);
  void __RPC_STUB IDEGetBlockFmtNamesParam_put_Names_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDHTMLSafe_INTERFACE_DEFINED__
#define __IDHTMLSafe_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDHTMLSafe;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDHTMLSafe : public IDispatch {
  public:
    virtual HRESULT WINAPI ExecCommand(DHTMLEDITCMDID cmdID,OLECMDEXECOPT cmdexecopt,VARIANT *pInVar,VARIANT *pOutVar) = 0;
    virtual HRESULT WINAPI QueryStatus(DHTMLEDITCMDID cmdID,DHTMLEDITCMDF *retval) = 0;
    virtual HRESULT WINAPI SetContextMenu(VARIANT *menuStrings,VARIANT *menuStates) = 0;
    virtual HRESULT WINAPI NewDocument(void) = 0;
    virtual HRESULT WINAPI LoadURL(BSTR url) = 0;
    virtual HRESULT WINAPI FilterSourceCode(BSTR sourceCodeIn,BSTR *sourceCodeOut) = 0;
    virtual HRESULT WINAPI Refresh(void) = 0;
    virtual HRESULT WINAPI get_DOM(IHTMLDocument2 **pVal) = 0;
    virtual HRESULT WINAPI get_DocumentHTML(BSTR *docHTML) = 0;
    virtual HRESULT WINAPI put_DocumentHTML(BSTR docHTML) = 0;
    virtual HRESULT WINAPI get_ActivateApplets(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ActivateApplets(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ActivateActiveXControls(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ActivateActiveXControls(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ActivateDTCs(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ActivateDTCs(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowDetails(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowDetails(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ShowBorders(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_ShowBorders(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_Appearance(DHTMLEDITAPPEARANCE *pVal) = 0;
    virtual HRESULT WINAPI put_Appearance(DHTMLEDITAPPEARANCE newVal) = 0;
    virtual HRESULT WINAPI get_Scrollbars(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_Scrollbars(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_ScrollbarAppearance(DHTMLEDITAPPEARANCE *pVal) = 0;
    virtual HRESULT WINAPI put_ScrollbarAppearance(DHTMLEDITAPPEARANCE newVal) = 0;
    virtual HRESULT WINAPI get_SourceCodePreservation(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_SourceCodePreservation(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_AbsoluteDropMode(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_AbsoluteDropMode(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_SnapToGridX(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_SnapToGridX(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI get_SnapToGridY(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_SnapToGridY(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI get_SnapToGrid(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_SnapToGrid(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_IsDirty(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI get_CurrentDocumentPath(BSTR *docPath) = 0;
    virtual HRESULT WINAPI get_BaseURL(BSTR *baseURL) = 0;
    virtual HRESULT WINAPI put_BaseURL(BSTR baseURL) = 0;
    virtual HRESULT WINAPI get_DocumentTitle(BSTR *docTitle) = 0;
    virtual HRESULT WINAPI get_UseDivOnCarriageReturn(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_UseDivOnCarriageReturn(VARIANT_BOOL newVal) = 0;
    virtual HRESULT WINAPI get_Busy(VARIANT_BOOL *pVal) = 0;
  };
#else
  typedef struct IDHTMLSafeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDHTMLSafe *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDHTMLSafe *This);
      ULONG (WINAPI *Release)(IDHTMLSafe *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDHTMLSafe *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDHTMLSafe *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDHTMLSafe *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDHTMLSafe *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ExecCommand)(IDHTMLSafe *This,DHTMLEDITCMDID cmdID,OLECMDEXECOPT cmdexecopt,VARIANT *pInVar,VARIANT *pOutVar);
      HRESULT (WINAPI *QueryStatus)(IDHTMLSafe *This,DHTMLEDITCMDID cmdID,DHTMLEDITCMDF *retval);
      HRESULT (WINAPI *SetContextMenu)(IDHTMLSafe *This,VARIANT *menuStrings,VARIANT *menuStates);
      HRESULT (WINAPI *NewDocument)(IDHTMLSafe *This);
      HRESULT (WINAPI *LoadURL)(IDHTMLSafe *This,BSTR url);
      HRESULT (WINAPI *FilterSourceCode)(IDHTMLSafe *This,BSTR sourceCodeIn,BSTR *sourceCodeOut);
      HRESULT (WINAPI *Refresh)(IDHTMLSafe *This);
      HRESULT (WINAPI *get_DOM)(IDHTMLSafe *This,IHTMLDocument2 **pVal);
      HRESULT (WINAPI *get_DocumentHTML)(IDHTMLSafe *This,BSTR *docHTML);
      HRESULT (WINAPI *put_DocumentHTML)(IDHTMLSafe *This,BSTR docHTML);
      HRESULT (WINAPI *get_ActivateApplets)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateApplets)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ActivateActiveXControls)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateActiveXControls)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ActivateDTCs)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateDTCs)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowDetails)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowDetails)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowBorders)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowBorders)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Appearance)(IDHTMLSafe *This,DHTMLEDITAPPEARANCE *pVal);
      HRESULT (WINAPI *put_Appearance)(IDHTMLSafe *This,DHTMLEDITAPPEARANCE newVal);
      HRESULT (WINAPI *get_Scrollbars)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_Scrollbars)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ScrollbarAppearance)(IDHTMLSafe *This,DHTMLEDITAPPEARANCE *pVal);
      HRESULT (WINAPI *put_ScrollbarAppearance)(IDHTMLSafe *This,DHTMLEDITAPPEARANCE newVal);
      HRESULT (WINAPI *get_SourceCodePreservation)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_SourceCodePreservation)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_AbsoluteDropMode)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AbsoluteDropMode)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_SnapToGridX)(IDHTMLSafe *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_SnapToGridX)(IDHTMLSafe *This,__LONG32 newVal);
      HRESULT (WINAPI *get_SnapToGridY)(IDHTMLSafe *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_SnapToGridY)(IDHTMLSafe *This,__LONG32 newVal);
      HRESULT (WINAPI *get_SnapToGrid)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_SnapToGrid)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_IsDirty)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_CurrentDocumentPath)(IDHTMLSafe *This,BSTR *docPath);
      HRESULT (WINAPI *get_BaseURL)(IDHTMLSafe *This,BSTR *baseURL);
      HRESULT (WINAPI *put_BaseURL)(IDHTMLSafe *This,BSTR baseURL);
      HRESULT (WINAPI *get_DocumentTitle)(IDHTMLSafe *This,BSTR *docTitle);
      HRESULT (WINAPI *get_UseDivOnCarriageReturn)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_UseDivOnCarriageReturn)(IDHTMLSafe *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Busy)(IDHTMLSafe *This,VARIANT_BOOL *pVal);
    END_INTERFACE
  } IDHTMLSafeVtbl;
  struct IDHTMLSafe {
    CONST_VTBL struct IDHTMLSafeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDHTMLSafe_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDHTMLSafe_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDHTMLSafe_Release(This) (This)->lpVtbl->Release(This)
#define IDHTMLSafe_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDHTMLSafe_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDHTMLSafe_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDHTMLSafe_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDHTMLSafe_ExecCommand(This,cmdID,cmdexecopt,pInVar,pOutVar) (This)->lpVtbl->ExecCommand(This,cmdID,cmdexecopt,pInVar,pOutVar)
#define IDHTMLSafe_QueryStatus(This,cmdID,retval) (This)->lpVtbl->QueryStatus(This,cmdID,retval)
#define IDHTMLSafe_SetContextMenu(This,menuStrings,menuStates) (This)->lpVtbl->SetContextMenu(This,menuStrings,menuStates)
#define IDHTMLSafe_NewDocument(This) (This)->lpVtbl->NewDocument(This)
#define IDHTMLSafe_LoadURL(This,url) (This)->lpVtbl->LoadURL(This,url)
#define IDHTMLSafe_FilterSourceCode(This,sourceCodeIn,sourceCodeOut) (This)->lpVtbl->FilterSourceCode(This,sourceCodeIn,sourceCodeOut)
#define IDHTMLSafe_Refresh(This) (This)->lpVtbl->Refresh(This)
#define IDHTMLSafe_get_DOM(This,pVal) (This)->lpVtbl->get_DOM(This,pVal)
#define IDHTMLSafe_get_DocumentHTML(This,docHTML) (This)->lpVtbl->get_DocumentHTML(This,docHTML)
#define IDHTMLSafe_put_DocumentHTML(This,docHTML) (This)->lpVtbl->put_DocumentHTML(This,docHTML)
#define IDHTMLSafe_get_ActivateApplets(This,pVal) (This)->lpVtbl->get_ActivateApplets(This,pVal)
#define IDHTMLSafe_put_ActivateApplets(This,newVal) (This)->lpVtbl->put_ActivateApplets(This,newVal)
#define IDHTMLSafe_get_ActivateActiveXControls(This,pVal) (This)->lpVtbl->get_ActivateActiveXControls(This,pVal)
#define IDHTMLSafe_put_ActivateActiveXControls(This,newVal) (This)->lpVtbl->put_ActivateActiveXControls(This,newVal)
#define IDHTMLSafe_get_ActivateDTCs(This,pVal) (This)->lpVtbl->get_ActivateDTCs(This,pVal)
#define IDHTMLSafe_put_ActivateDTCs(This,newVal) (This)->lpVtbl->put_ActivateDTCs(This,newVal)
#define IDHTMLSafe_get_ShowDetails(This,pVal) (This)->lpVtbl->get_ShowDetails(This,pVal)
#define IDHTMLSafe_put_ShowDetails(This,newVal) (This)->lpVtbl->put_ShowDetails(This,newVal)
#define IDHTMLSafe_get_ShowBorders(This,pVal) (This)->lpVtbl->get_ShowBorders(This,pVal)
#define IDHTMLSafe_put_ShowBorders(This,newVal) (This)->lpVtbl->put_ShowBorders(This,newVal)
#define IDHTMLSafe_get_Appearance(This,pVal) (This)->lpVtbl->get_Appearance(This,pVal)
#define IDHTMLSafe_put_Appearance(This,newVal) (This)->lpVtbl->put_Appearance(This,newVal)
#define IDHTMLSafe_get_Scrollbars(This,pVal) (This)->lpVtbl->get_Scrollbars(This,pVal)
#define IDHTMLSafe_put_Scrollbars(This,newVal) (This)->lpVtbl->put_Scrollbars(This,newVal)
#define IDHTMLSafe_get_ScrollbarAppearance(This,pVal) (This)->lpVtbl->get_ScrollbarAppearance(This,pVal)
#define IDHTMLSafe_put_ScrollbarAppearance(This,newVal) (This)->lpVtbl->put_ScrollbarAppearance(This,newVal)
#define IDHTMLSafe_get_SourceCodePreservation(This,pVal) (This)->lpVtbl->get_SourceCodePreservation(This,pVal)
#define IDHTMLSafe_put_SourceCodePreservation(This,newVal) (This)->lpVtbl->put_SourceCodePreservation(This,newVal)
#define IDHTMLSafe_get_AbsoluteDropMode(This,pVal) (This)->lpVtbl->get_AbsoluteDropMode(This,pVal)
#define IDHTMLSafe_put_AbsoluteDropMode(This,newVal) (This)->lpVtbl->put_AbsoluteDropMode(This,newVal)
#define IDHTMLSafe_get_SnapToGridX(This,pVal) (This)->lpVtbl->get_SnapToGridX(This,pVal)
#define IDHTMLSafe_put_SnapToGridX(This,newVal) (This)->lpVtbl->put_SnapToGridX(This,newVal)
#define IDHTMLSafe_get_SnapToGridY(This,pVal) (This)->lpVtbl->get_SnapToGridY(This,pVal)
#define IDHTMLSafe_put_SnapToGridY(This,newVal) (This)->lpVtbl->put_SnapToGridY(This,newVal)
#define IDHTMLSafe_get_SnapToGrid(This,pVal) (This)->lpVtbl->get_SnapToGrid(This,pVal)
#define IDHTMLSafe_put_SnapToGrid(This,newVal) (This)->lpVtbl->put_SnapToGrid(This,newVal)
#define IDHTMLSafe_get_IsDirty(This,pVal) (This)->lpVtbl->get_IsDirty(This,pVal)
#define IDHTMLSafe_get_CurrentDocumentPath(This,docPath) (This)->lpVtbl->get_CurrentDocumentPath(This,docPath)
#define IDHTMLSafe_get_BaseURL(This,baseURL) (This)->lpVtbl->get_BaseURL(This,baseURL)
#define IDHTMLSafe_put_BaseURL(This,baseURL) (This)->lpVtbl->put_BaseURL(This,baseURL)
#define IDHTMLSafe_get_DocumentTitle(This,docTitle) (This)->lpVtbl->get_DocumentTitle(This,docTitle)
#define IDHTMLSafe_get_UseDivOnCarriageReturn(This,pVal) (This)->lpVtbl->get_UseDivOnCarriageReturn(This,pVal)
#define IDHTMLSafe_put_UseDivOnCarriageReturn(This,newVal) (This)->lpVtbl->put_UseDivOnCarriageReturn(This,newVal)
#define IDHTMLSafe_get_Busy(This,pVal) (This)->lpVtbl->get_Busy(This,pVal)
#endif
#endif
  HRESULT WINAPI IDHTMLSafe_ExecCommand_Proxy(IDHTMLSafe *This,DHTMLEDITCMDID cmdID,OLECMDEXECOPT cmdexecopt,VARIANT *pInVar,VARIANT *pOutVar);
  void __RPC_STUB IDHTMLSafe_ExecCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_QueryStatus_Proxy(IDHTMLSafe *This,DHTMLEDITCMDID cmdID,DHTMLEDITCMDF *retval);
  void __RPC_STUB IDHTMLSafe_QueryStatus_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_SetContextMenu_Proxy(IDHTMLSafe *This,VARIANT *menuStrings,VARIANT *menuStates);
  void __RPC_STUB IDHTMLSafe_SetContextMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_NewDocument_Proxy(IDHTMLSafe *This);
  void __RPC_STUB IDHTMLSafe_NewDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_LoadURL_Proxy(IDHTMLSafe *This,BSTR url);
  void __RPC_STUB IDHTMLSafe_LoadURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_FilterSourceCode_Proxy(IDHTMLSafe *This,BSTR sourceCodeIn,BSTR *sourceCodeOut);
  void __RPC_STUB IDHTMLSafe_FilterSourceCode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_Refresh_Proxy(IDHTMLSafe *This);
  void __RPC_STUB IDHTMLSafe_Refresh_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_DOM_Proxy(IDHTMLSafe *This,IHTMLDocument2 **pVal);
  void __RPC_STUB IDHTMLSafe_get_DOM_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_DocumentHTML_Proxy(IDHTMLSafe *This,BSTR *docHTML);
  void __RPC_STUB IDHTMLSafe_get_DocumentHTML_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_DocumentHTML_Proxy(IDHTMLSafe *This,BSTR docHTML);
  void __RPC_STUB IDHTMLSafe_put_DocumentHTML_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ActivateApplets_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_ActivateApplets_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ActivateApplets_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_ActivateApplets_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ActivateActiveXControls_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_ActivateActiveXControls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ActivateActiveXControls_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_ActivateActiveXControls_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ActivateDTCs_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_ActivateDTCs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ActivateDTCs_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_ActivateDTCs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ShowDetails_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_ShowDetails_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ShowDetails_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_ShowDetails_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ShowBorders_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_ShowBorders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ShowBorders_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_ShowBorders_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_Appearance_Proxy(IDHTMLSafe *This,DHTMLEDITAPPEARANCE *pVal);
  void __RPC_STUB IDHTMLSafe_get_Appearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_Appearance_Proxy(IDHTMLSafe *This,DHTMLEDITAPPEARANCE newVal);
  void __RPC_STUB IDHTMLSafe_put_Appearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_Scrollbars_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_Scrollbars_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_Scrollbars_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_Scrollbars_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_ScrollbarAppearance_Proxy(IDHTMLSafe *This,DHTMLEDITAPPEARANCE *pVal);
  void __RPC_STUB IDHTMLSafe_get_ScrollbarAppearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_ScrollbarAppearance_Proxy(IDHTMLSafe *This,DHTMLEDITAPPEARANCE newVal);
  void __RPC_STUB IDHTMLSafe_put_ScrollbarAppearance_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_SourceCodePreservation_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_SourceCodePreservation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_SourceCodePreservation_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_SourceCodePreservation_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_AbsoluteDropMode_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_AbsoluteDropMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_AbsoluteDropMode_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_AbsoluteDropMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_SnapToGridX_Proxy(IDHTMLSafe *This,__LONG32 *pVal);
  void __RPC_STUB IDHTMLSafe_get_SnapToGridX_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_SnapToGridX_Proxy(IDHTMLSafe *This,__LONG32 newVal);
  void __RPC_STUB IDHTMLSafe_put_SnapToGridX_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_SnapToGridY_Proxy(IDHTMLSafe *This,__LONG32 *pVal);
  void __RPC_STUB IDHTMLSafe_get_SnapToGridY_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_SnapToGridY_Proxy(IDHTMLSafe *This,__LONG32 newVal);
  void __RPC_STUB IDHTMLSafe_put_SnapToGridY_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_SnapToGrid_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_SnapToGrid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_SnapToGrid_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_SnapToGrid_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_IsDirty_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_IsDirty_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_CurrentDocumentPath_Proxy(IDHTMLSafe *This,BSTR *docPath);
  void __RPC_STUB IDHTMLSafe_get_CurrentDocumentPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_BaseURL_Proxy(IDHTMLSafe *This,BSTR *baseURL);
  void __RPC_STUB IDHTMLSafe_get_BaseURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_BaseURL_Proxy(IDHTMLSafe *This,BSTR baseURL);
  void __RPC_STUB IDHTMLSafe_put_BaseURL_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_DocumentTitle_Proxy(IDHTMLSafe *This,BSTR *docTitle);
  void __RPC_STUB IDHTMLSafe_get_DocumentTitle_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_UseDivOnCarriageReturn_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_UseDivOnCarriageReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_put_UseDivOnCarriageReturn_Proxy(IDHTMLSafe *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLSafe_put_UseDivOnCarriageReturn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLSafe_get_Busy_Proxy(IDHTMLSafe *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLSafe_get_Busy_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDHTMLEdit_INTERFACE_DEFINED__
#define __IDHTMLEdit_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDHTMLEdit;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDHTMLEdit : public IDHTMLSafe {
  public:
    virtual HRESULT WINAPI LoadDocument(VARIANT *pathIn,VARIANT *promptUser) = 0;
    virtual HRESULT WINAPI SaveDocument(VARIANT *pathIn,VARIANT *promptUser) = 0;
    virtual HRESULT WINAPI PrintDocument(VARIANT *withUI) = 0;
    virtual HRESULT WINAPI get_BrowseMode(VARIANT_BOOL *pVal) = 0;
    virtual HRESULT WINAPI put_BrowseMode(VARIANT_BOOL newVal) = 0;
  };
#else
  typedef struct IDHTMLEditVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDHTMLEdit *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDHTMLEdit *This);
      ULONG (WINAPI *Release)(IDHTMLEdit *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDHTMLEdit *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDHTMLEdit *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDHTMLEdit *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDHTMLEdit *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ExecCommand)(IDHTMLEdit *This,DHTMLEDITCMDID cmdID,OLECMDEXECOPT cmdexecopt,VARIANT *pInVar,VARIANT *pOutVar);
      HRESULT (WINAPI *QueryStatus)(IDHTMLEdit *This,DHTMLEDITCMDID cmdID,DHTMLEDITCMDF *retval);
      HRESULT (WINAPI *SetContextMenu)(IDHTMLEdit *This,VARIANT *menuStrings,VARIANT *menuStates);
      HRESULT (WINAPI *NewDocument)(IDHTMLEdit *This);
      HRESULT (WINAPI *LoadURL)(IDHTMLEdit *This,BSTR url);
      HRESULT (WINAPI *FilterSourceCode)(IDHTMLEdit *This,BSTR sourceCodeIn,BSTR *sourceCodeOut);
      HRESULT (WINAPI *Refresh)(IDHTMLEdit *This);
      HRESULT (WINAPI *get_DOM)(IDHTMLEdit *This,IHTMLDocument2 **pVal);
      HRESULT (WINAPI *get_DocumentHTML)(IDHTMLEdit *This,BSTR *docHTML);
      HRESULT (WINAPI *put_DocumentHTML)(IDHTMLEdit *This,BSTR docHTML);
      HRESULT (WINAPI *get_ActivateApplets)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateApplets)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ActivateActiveXControls)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateActiveXControls)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ActivateDTCs)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ActivateDTCs)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowDetails)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowDetails)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ShowBorders)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_ShowBorders)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Appearance)(IDHTMLEdit *This,DHTMLEDITAPPEARANCE *pVal);
      HRESULT (WINAPI *put_Appearance)(IDHTMLEdit *This,DHTMLEDITAPPEARANCE newVal);
      HRESULT (WINAPI *get_Scrollbars)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_Scrollbars)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_ScrollbarAppearance)(IDHTMLEdit *This,DHTMLEDITAPPEARANCE *pVal);
      HRESULT (WINAPI *put_ScrollbarAppearance)(IDHTMLEdit *This,DHTMLEDITAPPEARANCE newVal);
      HRESULT (WINAPI *get_SourceCodePreservation)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_SourceCodePreservation)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_AbsoluteDropMode)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_AbsoluteDropMode)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_SnapToGridX)(IDHTMLEdit *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_SnapToGridX)(IDHTMLEdit *This,__LONG32 newVal);
      HRESULT (WINAPI *get_SnapToGridY)(IDHTMLEdit *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_SnapToGridY)(IDHTMLEdit *This,__LONG32 newVal);
      HRESULT (WINAPI *get_SnapToGrid)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_SnapToGrid)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_IsDirty)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *get_CurrentDocumentPath)(IDHTMLEdit *This,BSTR *docPath);
      HRESULT (WINAPI *get_BaseURL)(IDHTMLEdit *This,BSTR *baseURL);
      HRESULT (WINAPI *put_BaseURL)(IDHTMLEdit *This,BSTR baseURL);
      HRESULT (WINAPI *get_DocumentTitle)(IDHTMLEdit *This,BSTR *docTitle);
      HRESULT (WINAPI *get_UseDivOnCarriageReturn)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_UseDivOnCarriageReturn)(IDHTMLEdit *This,VARIANT_BOOL newVal);
      HRESULT (WINAPI *get_Busy)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *LoadDocument)(IDHTMLEdit *This,VARIANT *pathIn,VARIANT *promptUser);
      HRESULT (WINAPI *SaveDocument)(IDHTMLEdit *This,VARIANT *pathIn,VARIANT *promptUser);
      HRESULT (WINAPI *PrintDocument)(IDHTMLEdit *This,VARIANT *withUI);
      HRESULT (WINAPI *get_BrowseMode)(IDHTMLEdit *This,VARIANT_BOOL *pVal);
      HRESULT (WINAPI *put_BrowseMode)(IDHTMLEdit *This,VARIANT_BOOL newVal);
    END_INTERFACE
  } IDHTMLEditVtbl;
  struct IDHTMLEdit {
    CONST_VTBL struct IDHTMLEditVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDHTMLEdit_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDHTMLEdit_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDHTMLEdit_Release(This) (This)->lpVtbl->Release(This)
#define IDHTMLEdit_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDHTMLEdit_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDHTMLEdit_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDHTMLEdit_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDHTMLEdit_ExecCommand(This,cmdID,cmdexecopt,pInVar,pOutVar) (This)->lpVtbl->ExecCommand(This,cmdID,cmdexecopt,pInVar,pOutVar)
#define IDHTMLEdit_QueryStatus(This,cmdID,retval) (This)->lpVtbl->QueryStatus(This,cmdID,retval)
#define IDHTMLEdit_SetContextMenu(This,menuStrings,menuStates) (This)->lpVtbl->SetContextMenu(This,menuStrings,menuStates)
#define IDHTMLEdit_NewDocument(This) (This)->lpVtbl->NewDocument(This)
#define IDHTMLEdit_LoadURL(This,url) (This)->lpVtbl->LoadURL(This,url)
#define IDHTMLEdit_FilterSourceCode(This,sourceCodeIn,sourceCodeOut) (This)->lpVtbl->FilterSourceCode(This,sourceCodeIn,sourceCodeOut)
#define IDHTMLEdit_Refresh(This) (This)->lpVtbl->Refresh(This)
#define IDHTMLEdit_get_DOM(This,pVal) (This)->lpVtbl->get_DOM(This,pVal)
#define IDHTMLEdit_get_DocumentHTML(This,docHTML) (This)->lpVtbl->get_DocumentHTML(This,docHTML)
#define IDHTMLEdit_put_DocumentHTML(This,docHTML) (This)->lpVtbl->put_DocumentHTML(This,docHTML)
#define IDHTMLEdit_get_ActivateApplets(This,pVal) (This)->lpVtbl->get_ActivateApplets(This,pVal)
#define IDHTMLEdit_put_ActivateApplets(This,newVal) (This)->lpVtbl->put_ActivateApplets(This,newVal)
#define IDHTMLEdit_get_ActivateActiveXControls(This,pVal) (This)->lpVtbl->get_ActivateActiveXControls(This,pVal)
#define IDHTMLEdit_put_ActivateActiveXControls(This,newVal) (This)->lpVtbl->put_ActivateActiveXControls(This,newVal)
#define IDHTMLEdit_get_ActivateDTCs(This,pVal) (This)->lpVtbl->get_ActivateDTCs(This,pVal)
#define IDHTMLEdit_put_ActivateDTCs(This,newVal) (This)->lpVtbl->put_ActivateDTCs(This,newVal)
#define IDHTMLEdit_get_ShowDetails(This,pVal) (This)->lpVtbl->get_ShowDetails(This,pVal)
#define IDHTMLEdit_put_ShowDetails(This,newVal) (This)->lpVtbl->put_ShowDetails(This,newVal)
#define IDHTMLEdit_get_ShowBorders(This,pVal) (This)->lpVtbl->get_ShowBorders(This,pVal)
#define IDHTMLEdit_put_ShowBorders(This,newVal) (This)->lpVtbl->put_ShowBorders(This,newVal)
#define IDHTMLEdit_get_Appearance(This,pVal) (This)->lpVtbl->get_Appearance(This,pVal)
#define IDHTMLEdit_put_Appearance(This,newVal) (This)->lpVtbl->put_Appearance(This,newVal)
#define IDHTMLEdit_get_Scrollbars(This,pVal) (This)->lpVtbl->get_Scrollbars(This,pVal)
#define IDHTMLEdit_put_Scrollbars(This,newVal) (This)->lpVtbl->put_Scrollbars(This,newVal)
#define IDHTMLEdit_get_ScrollbarAppearance(This,pVal) (This)->lpVtbl->get_ScrollbarAppearance(This,pVal)
#define IDHTMLEdit_put_ScrollbarAppearance(This,newVal) (This)->lpVtbl->put_ScrollbarAppearance(This,newVal)
#define IDHTMLEdit_get_SourceCodePreservation(This,pVal) (This)->lpVtbl->get_SourceCodePreservation(This,pVal)
#define IDHTMLEdit_put_SourceCodePreservation(This,newVal) (This)->lpVtbl->put_SourceCodePreservation(This,newVal)
#define IDHTMLEdit_get_AbsoluteDropMode(This,pVal) (This)->lpVtbl->get_AbsoluteDropMode(This,pVal)
#define IDHTMLEdit_put_AbsoluteDropMode(This,newVal) (This)->lpVtbl->put_AbsoluteDropMode(This,newVal)
#define IDHTMLEdit_get_SnapToGridX(This,pVal) (This)->lpVtbl->get_SnapToGridX(This,pVal)
#define IDHTMLEdit_put_SnapToGridX(This,newVal) (This)->lpVtbl->put_SnapToGridX(This,newVal)
#define IDHTMLEdit_get_SnapToGridY(This,pVal) (This)->lpVtbl->get_SnapToGridY(This,pVal)
#define IDHTMLEdit_put_SnapToGridY(This,newVal) (This)->lpVtbl->put_SnapToGridY(This,newVal)
#define IDHTMLEdit_get_SnapToGrid(This,pVal) (This)->lpVtbl->get_SnapToGrid(This,pVal)
#define IDHTMLEdit_put_SnapToGrid(This,newVal) (This)->lpVtbl->put_SnapToGrid(This,newVal)
#define IDHTMLEdit_get_IsDirty(This,pVal) (This)->lpVtbl->get_IsDirty(This,pVal)
#define IDHTMLEdit_get_CurrentDocumentPath(This,docPath) (This)->lpVtbl->get_CurrentDocumentPath(This,docPath)
#define IDHTMLEdit_get_BaseURL(This,baseURL) (This)->lpVtbl->get_BaseURL(This,baseURL)
#define IDHTMLEdit_put_BaseURL(This,baseURL) (This)->lpVtbl->put_BaseURL(This,baseURL)
#define IDHTMLEdit_get_DocumentTitle(This,docTitle) (This)->lpVtbl->get_DocumentTitle(This,docTitle)
#define IDHTMLEdit_get_UseDivOnCarriageReturn(This,pVal) (This)->lpVtbl->get_UseDivOnCarriageReturn(This,pVal)
#define IDHTMLEdit_put_UseDivOnCarriageReturn(This,newVal) (This)->lpVtbl->put_UseDivOnCarriageReturn(This,newVal)
#define IDHTMLEdit_get_Busy(This,pVal) (This)->lpVtbl->get_Busy(This,pVal)
#define IDHTMLEdit_LoadDocument(This,pathIn,promptUser) (This)->lpVtbl->LoadDocument(This,pathIn,promptUser)
#define IDHTMLEdit_SaveDocument(This,pathIn,promptUser) (This)->lpVtbl->SaveDocument(This,pathIn,promptUser)
#define IDHTMLEdit_PrintDocument(This,withUI) (This)->lpVtbl->PrintDocument(This,withUI)
#define IDHTMLEdit_get_BrowseMode(This,pVal) (This)->lpVtbl->get_BrowseMode(This,pVal)
#define IDHTMLEdit_put_BrowseMode(This,newVal) (This)->lpVtbl->put_BrowseMode(This,newVal)
#endif
#endif
  HRESULT WINAPI IDHTMLEdit_LoadDocument_Proxy(IDHTMLEdit *This,VARIANT *pathIn,VARIANT *promptUser);
  void __RPC_STUB IDHTMLEdit_LoadDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLEdit_SaveDocument_Proxy(IDHTMLEdit *This,VARIANT *pathIn,VARIANT *promptUser);
  void __RPC_STUB IDHTMLEdit_SaveDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLEdit_PrintDocument_Proxy(IDHTMLEdit *This,VARIANT *withUI);
  void __RPC_STUB IDHTMLEdit_PrintDocument_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLEdit_get_BrowseMode_Proxy(IDHTMLEdit *This,VARIANT_BOOL *pVal);
  void __RPC_STUB IDHTMLEdit_get_BrowseMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDHTMLEdit_put_BrowseMode_Proxy(IDHTMLEdit *This,VARIANT_BOOL newVal);
  void __RPC_STUB IDHTMLEdit_put_BrowseMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __IDEInsertTableParam_INTERFACE_DEFINED__
#define __IDEInsertTableParam_INTERFACE_DEFINED__
  EXTERN_C const IID IID_IDEInsertTableParam;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct IDEInsertTableParam : public IDispatch {
  public:
    virtual HRESULT WINAPI get_NumRows(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_NumRows(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI get_NumCols(__LONG32 *pVal) = 0;
    virtual HRESULT WINAPI put_NumCols(__LONG32 newVal) = 0;
    virtual HRESULT WINAPI get_TableAttrs(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_TableAttrs(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_CellAttrs(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_CellAttrs(BSTR newVal) = 0;
    virtual HRESULT WINAPI get_Caption(BSTR *pVal) = 0;
    virtual HRESULT WINAPI put_Caption(BSTR newVal) = 0;
  };
#else
  typedef struct IDEInsertTableParamVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(IDEInsertTableParam *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(IDEInsertTableParam *This);
      ULONG (WINAPI *Release)(IDEInsertTableParam *This);
      HRESULT (WINAPI *GetTypeInfoCount)(IDEInsertTableParam *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(IDEInsertTableParam *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(IDEInsertTableParam *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(IDEInsertTableParam *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_NumRows)(IDEInsertTableParam *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_NumRows)(IDEInsertTableParam *This,__LONG32 newVal);
      HRESULT (WINAPI *get_NumCols)(IDEInsertTableParam *This,__LONG32 *pVal);
      HRESULT (WINAPI *put_NumCols)(IDEInsertTableParam *This,__LONG32 newVal);
      HRESULT (WINAPI *get_TableAttrs)(IDEInsertTableParam *This,BSTR *pVal);
      HRESULT (WINAPI *put_TableAttrs)(IDEInsertTableParam *This,BSTR newVal);
      HRESULT (WINAPI *get_CellAttrs)(IDEInsertTableParam *This,BSTR *pVal);
      HRESULT (WINAPI *put_CellAttrs)(IDEInsertTableParam *This,BSTR newVal);
      HRESULT (WINAPI *get_Caption)(IDEInsertTableParam *This,BSTR *pVal);
      HRESULT (WINAPI *put_Caption)(IDEInsertTableParam *This,BSTR newVal);
    END_INTERFACE
  } IDEInsertTableParamVtbl;
  struct IDEInsertTableParam {
    CONST_VTBL struct IDEInsertTableParamVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define IDEInsertTableParam_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define IDEInsertTableParam_AddRef(This) (This)->lpVtbl->AddRef(This)
#define IDEInsertTableParam_Release(This) (This)->lpVtbl->Release(This)
#define IDEInsertTableParam_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define IDEInsertTableParam_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define IDEInsertTableParam_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define IDEInsertTableParam_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define IDEInsertTableParam_get_NumRows(This,pVal) (This)->lpVtbl->get_NumRows(This,pVal)
#define IDEInsertTableParam_put_NumRows(This,newVal) (This)->lpVtbl->put_NumRows(This,newVal)
#define IDEInsertTableParam_get_NumCols(This,pVal) (This)->lpVtbl->get_NumCols(This,pVal)
#define IDEInsertTableParam_put_NumCols(This,newVal) (This)->lpVtbl->put_NumCols(This,newVal)
#define IDEInsertTableParam_get_TableAttrs(This,pVal) (This)->lpVtbl->get_TableAttrs(This,pVal)
#define IDEInsertTableParam_put_TableAttrs(This,newVal) (This)->lpVtbl->put_TableAttrs(This,newVal)
#define IDEInsertTableParam_get_CellAttrs(This,pVal) (This)->lpVtbl->get_CellAttrs(This,pVal)
#define IDEInsertTableParam_put_CellAttrs(This,newVal) (This)->lpVtbl->put_CellAttrs(This,newVal)
#define IDEInsertTableParam_get_Caption(This,pVal) (This)->lpVtbl->get_Caption(This,pVal)
#define IDEInsertTableParam_put_Caption(This,newVal) (This)->lpVtbl->put_Caption(This,newVal)
#endif
#endif
  HRESULT WINAPI IDEInsertTableParam_get_NumRows_Proxy(IDEInsertTableParam *This,__LONG32 *pVal);
  void __RPC_STUB IDEInsertTableParam_get_NumRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_put_NumRows_Proxy(IDEInsertTableParam *This,__LONG32 newVal);
  void __RPC_STUB IDEInsertTableParam_put_NumRows_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_get_NumCols_Proxy(IDEInsertTableParam *This,__LONG32 *pVal);
  void __RPC_STUB IDEInsertTableParam_get_NumCols_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_put_NumCols_Proxy(IDEInsertTableParam *This,__LONG32 newVal);
  void __RPC_STUB IDEInsertTableParam_put_NumCols_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_get_TableAttrs_Proxy(IDEInsertTableParam *This,BSTR *pVal);
  void __RPC_STUB IDEInsertTableParam_get_TableAttrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_put_TableAttrs_Proxy(IDEInsertTableParam *This,BSTR newVal);
  void __RPC_STUB IDEInsertTableParam_put_TableAttrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_get_CellAttrs_Proxy(IDEInsertTableParam *This,BSTR *pVal);
  void __RPC_STUB IDEInsertTableParam_get_CellAttrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_put_CellAttrs_Proxy(IDEInsertTableParam *This,BSTR newVal);
  void __RPC_STUB IDEInsertTableParam_put_CellAttrs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_get_Caption_Proxy(IDEInsertTableParam *This,BSTR *pVal);
  void __RPC_STUB IDEInsertTableParam_get_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI IDEInsertTableParam_put_Caption_Proxy(IDEInsertTableParam *This,BSTR newVal);
  void __RPC_STUB IDEInsertTableParam_put_Caption_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef ___DHTMLSafeEvents_DISPINTERFACE_DEFINED__
#define ___DHTMLSafeEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID__DHTMLSafeEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _DHTMLSafeEvents : public IDispatch {
  };
#else
  typedef struct _DHTMLSafeEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_DHTMLSafeEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_DHTMLSafeEvents *This);
      ULONG (WINAPI *Release)(_DHTMLSafeEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_DHTMLSafeEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_DHTMLSafeEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_DHTMLSafeEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_DHTMLSafeEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } _DHTMLSafeEventsVtbl;
  struct _DHTMLSafeEvents {
    CONST_VTBL struct _DHTMLSafeEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _DHTMLSafeEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _DHTMLSafeEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _DHTMLSafeEvents_Release(This) (This)->lpVtbl->Release(This)
#define _DHTMLSafeEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _DHTMLSafeEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _DHTMLSafeEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _DHTMLSafeEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

#ifndef ___DHTMLEditEvents_DISPINTERFACE_DEFINED__
#define ___DHTMLEditEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID__DHTMLEditEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _DHTMLEditEvents : public IDispatch {
  };
#else
  typedef struct _DHTMLEditEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_DHTMLEditEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_DHTMLEditEvents *This);
      ULONG (WINAPI *Release)(_DHTMLEditEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_DHTMLEditEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_DHTMLEditEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_DHTMLEditEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_DHTMLEditEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } _DHTMLEditEventsVtbl;
  struct _DHTMLEditEvents {
    CONST_VTBL struct _DHTMLEditEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _DHTMLEditEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _DHTMLEditEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _DHTMLEditEvents_Release(This) (This)->lpVtbl->Release(This)
#define _DHTMLEditEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _DHTMLEditEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _DHTMLEditEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _DHTMLEditEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif

  EXTERN_C const CLSID CLSID_DHTMLEdit;
#ifdef __cplusplus
  class DHTMLEdit;
#endif
  EXTERN_C const CLSID CLSID_DHTMLSafe;
#ifdef __cplusplus
  class DHTMLSafe;
#endif
  EXTERN_C const CLSID CLSID_DEInsertTableParam;
#ifdef __cplusplus
  class DEInsertTableParam;
#endif
  EXTERN_C const CLSID CLSID_DEGetBlockFmtNamesParam;
#ifdef __cplusplus
  class DEGetBlockFmtNamesParam;
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
