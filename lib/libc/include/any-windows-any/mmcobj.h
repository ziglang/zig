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

#ifndef __mmcobj_h__
#define __mmcobj_h__

#ifndef __ISnapinProperties_FWD_DEFINED__
#define __ISnapinProperties_FWD_DEFINED__
typedef struct ISnapinProperties ISnapinProperties;
#endif

#ifndef __ISnapinPropertiesCallback_FWD_DEFINED__
#define __ISnapinPropertiesCallback_FWD_DEFINED__
typedef struct ISnapinPropertiesCallback ISnapinPropertiesCallback;
#endif

#ifndef ___Application_FWD_DEFINED__
#define ___Application_FWD_DEFINED__
typedef struct _Application _Application;
#endif

#ifndef ___AppEvents_FWD_DEFINED__
#define ___AppEvents_FWD_DEFINED__
typedef struct _AppEvents _AppEvents;
#endif

#ifndef __AppEvents_FWD_DEFINED__
#define __AppEvents_FWD_DEFINED__
typedef struct AppEvents AppEvents;
#endif

#ifndef __Application_FWD_DEFINED__
#define __Application_FWD_DEFINED__
#ifdef __cplusplus
typedef class Application Application;
#else
typedef struct Application Application;
#endif
#endif

#ifndef ___EventConnector_FWD_DEFINED__
#define ___EventConnector_FWD_DEFINED__
typedef struct _EventConnector _EventConnector;
#endif

#ifndef __AppEventsDHTMLConnector_FWD_DEFINED__
#define __AppEventsDHTMLConnector_FWD_DEFINED__
#ifdef __cplusplus
typedef class AppEventsDHTMLConnector AppEventsDHTMLConnector;
#else
typedef struct AppEventsDHTMLConnector AppEventsDHTMLConnector;
#endif
#endif

#ifndef __Frame_FWD_DEFINED__
#define __Frame_FWD_DEFINED__
typedef struct Frame Frame;
#endif

#ifndef __Node_FWD_DEFINED__
#define __Node_FWD_DEFINED__
typedef struct Node Node;
#endif

#ifndef __ScopeNamespace_FWD_DEFINED__
#define __ScopeNamespace_FWD_DEFINED__
typedef struct ScopeNamespace ScopeNamespace;
#endif

#ifndef __Document_FWD_DEFINED__
#define __Document_FWD_DEFINED__
typedef struct Document Document;
#endif

#ifndef __SnapIn_FWD_DEFINED__
#define __SnapIn_FWD_DEFINED__
typedef struct SnapIn SnapIn;
#endif

#ifndef __SnapIns_FWD_DEFINED__
#define __SnapIns_FWD_DEFINED__
typedef struct SnapIns SnapIns;
#endif

#ifndef __Extension_FWD_DEFINED__
#define __Extension_FWD_DEFINED__
typedef struct Extension Extension;
#endif

#ifndef __Extensions_FWD_DEFINED__
#define __Extensions_FWD_DEFINED__
typedef struct Extensions Extensions;
#endif

#ifndef __Columns_FWD_DEFINED__
#define __Columns_FWD_DEFINED__
typedef struct Columns Columns;
#endif

#ifndef __Column_FWD_DEFINED__
#define __Column_FWD_DEFINED__
typedef struct Column Column;
#endif

#ifndef __Views_FWD_DEFINED__
#define __Views_FWD_DEFINED__
typedef struct Views Views;
#endif

#ifndef __View_FWD_DEFINED__
#define __View_FWD_DEFINED__
typedef struct View View;
#endif

#ifndef __Nodes_FWD_DEFINED__
#define __Nodes_FWD_DEFINED__
typedef struct Nodes Nodes;
#endif

#ifndef __ContextMenu_FWD_DEFINED__
#define __ContextMenu_FWD_DEFINED__
typedef struct ContextMenu ContextMenu;
#endif

#ifndef __MenuItem_FWD_DEFINED__
#define __MenuItem_FWD_DEFINED__
typedef struct MenuItem MenuItem;
#endif

#ifndef __Properties_FWD_DEFINED__
#define __Properties_FWD_DEFINED__
typedef struct Properties Properties;
#endif

#ifndef __Property_FWD_DEFINED__
#define __Property_FWD_DEFINED__
typedef struct Property Property;
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

#ifndef MMC_VER
#define MMC_VER 0x0200
#endif

#if (MMC_VER >= 0x0200)
  typedef _Application *PAPPLICATION;
  typedef _Application **PPAPPLICATION;
  typedef Column *PCOLUMN;
  typedef Column **PPCOLUMN;
  typedef Columns *PCOLUMNS;
  typedef Columns **PPCOLUMNS;
  typedef ContextMenu *PCONTEXTMENU;
  typedef ContextMenu **PPCONTEXTMENU;
  typedef Document *PDOCUMENT;
  typedef Document **PPDOCUMENT;
  typedef Frame *PFRAME;
  typedef Frame **PPFRAME;
  typedef MenuItem *PMENUITEM;
  typedef MenuItem **PPMENUITEM;
  typedef Node *PNODE;
  typedef Node **PPNODE;
  typedef Nodes *PNODES;
  typedef Nodes **PPNODES;
  typedef Properties *PPROPERTIES;
  typedef Properties **PPPROPERTIES;
  typedef Property *PPROPERTY;
  typedef Property **PPPROPERTY;
  typedef ScopeNamespace *PSCOPENAMESPACE;
  typedef ScopeNamespace **PPSCOPENAMESPACE;
  typedef SnapIn *PSNAPIN;
  typedef SnapIn **PPSNAPIN;
  typedef SnapIns *PSNAPINS;
  typedef SnapIns **PPSNAPINS;
  typedef Extension *PEXTENSION;
  typedef Extension **PPEXTENSION;
  typedef Extensions *PEXTENSIONS;
  typedef Extensions **PPEXTENSIONS;
  typedef View *PVIEW;
  typedef View **PPVIEW;
  typedef Views *PVIEWS;
  typedef Views **PPVIEWS;
  typedef ISnapinProperties *LPSNAPINPROPERTIES;
  typedef ISnapinPropertiesCallback *LPSNAPINPROPERTIESCALLBACK;
  typedef WINBOOL *PBOOL;
  typedef int *PINT;
  typedef BSTR *PBSTR;
  typedef VARIANT *PVARIANT;
  typedef __LONG32 *PLONG;
  typedef IDispatch *PDISPATCH;
  typedef IDispatch **PPDISPATCH;

  extern RPC_IF_HANDLE __MIDL_itf_mmcobj_0000_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mmcobj_0000_v0_0_s_ifspec;

#ifndef __ISnapinProperties_INTERFACE_DEFINED__
#define __ISnapinProperties_INTERFACE_DEFINED__
  typedef enum _MMC_PROPERTY_ACTION {
    MMC_PROPACT_DELETING = 1,MMC_PROPACT_CHANGING,MMC_PROPACT_INITIALIZED
  } MMC_PROPERTY_ACTION;

  typedef struct _MMC_SNAPIN_PROPERTY {
    LPCOLESTR pszPropName;
    VARIANT varValue;
    MMC_PROPERTY_ACTION eAction;
  } MMC_SNAPIN_PROPERTY;

  EXTERN_C const IID IID_ISnapinProperties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISnapinProperties : public IUnknown {
  public:
    virtual HRESULT WINAPI Initialize(Properties *pProperties) = 0;
    virtual HRESULT WINAPI QueryPropertyNames(ISnapinPropertiesCallback *pCallback) = 0;
    virtual HRESULT WINAPI PropertiesChanged(__LONG32 cProperties,MMC_SNAPIN_PROPERTY *pProperties) = 0;
  };
#else
  typedef struct ISnapinPropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISnapinProperties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISnapinProperties *This);
      ULONG (WINAPI *Release)(ISnapinProperties *This);
      HRESULT (WINAPI *Initialize)(ISnapinProperties *This,Properties *pProperties);
      HRESULT (WINAPI *QueryPropertyNames)(ISnapinProperties *This,ISnapinPropertiesCallback *pCallback);
      HRESULT (WINAPI *PropertiesChanged)(ISnapinProperties *This,__LONG32 cProperties,MMC_SNAPIN_PROPERTY *pProperties);
    END_INTERFACE
  } ISnapinPropertiesVtbl;
  struct ISnapinProperties {
    CONST_VTBL struct ISnapinPropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISnapinProperties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISnapinProperties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISnapinProperties_Release(This) (This)->lpVtbl->Release(This)
#define ISnapinProperties_Initialize(This,pProperties) (This)->lpVtbl->Initialize(This,pProperties)
#define ISnapinProperties_QueryPropertyNames(This,pCallback) (This)->lpVtbl->QueryPropertyNames(This,pCallback)
#define ISnapinProperties_PropertiesChanged(This,cProperties,pProperties) (This)->lpVtbl->PropertiesChanged(This,cProperties,pProperties)
#endif
#endif
  HRESULT WINAPI ISnapinProperties_Initialize_Proxy(ISnapinProperties *This,Properties *pProperties);
  void __RPC_STUB ISnapinProperties_Initialize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISnapinProperties_QueryPropertyNames_Proxy(ISnapinProperties *This,ISnapinPropertiesCallback *pCallback);
  void __RPC_STUB ISnapinProperties_QueryPropertyNames_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ISnapinProperties_PropertiesChanged_Proxy(ISnapinProperties *This,__LONG32 cProperties,MMC_SNAPIN_PROPERTY *pProperties);
  void __RPC_STUB ISnapinProperties_PropertiesChanged_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ISnapinPropertiesCallback_INTERFACE_DEFINED__
#define __ISnapinPropertiesCallback_INTERFACE_DEFINED__

#define MMC_PROP_CHANGEAFFECTSUI (0x1)
#define MMC_PROP_MODIFIABLE (0x2)
#define MMC_PROP_REMOVABLE (0x4)
#define MMC_PROP_PERSIST (0x8)

  EXTERN_C const IID IID_ISnapinPropertiesCallback;

#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ISnapinPropertiesCallback : public IUnknown {
  public:
    virtual HRESULT WINAPI AddPropertyName(LPCOLESTR pszPropName,DWORD dwFlags) = 0;
  };
#else
  typedef struct ISnapinPropertiesCallbackVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ISnapinPropertiesCallback *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ISnapinPropertiesCallback *This);
      ULONG (WINAPI *Release)(ISnapinPropertiesCallback *This);
      HRESULT (WINAPI *AddPropertyName)(ISnapinPropertiesCallback *This,LPCOLESTR pszPropName,DWORD dwFlags);
    END_INTERFACE
  } ISnapinPropertiesCallbackVtbl;
  struct ISnapinPropertiesCallback {
    CONST_VTBL struct ISnapinPropertiesCallbackVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ISnapinPropertiesCallback_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ISnapinPropertiesCallback_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ISnapinPropertiesCallback_Release(This) (This)->lpVtbl->Release(This)
#define ISnapinPropertiesCallback_AddPropertyName(This,pszPropName,dwFlags) (This)->lpVtbl->AddPropertyName(This,pszPropName,dwFlags)
#endif
#endif
  HRESULT WINAPI ISnapinPropertiesCallback_AddPropertyName_Proxy(ISnapinPropertiesCallback *This,LPCOLESTR pszPropName,DWORD dwFlags);
  void __RPC_STUB ISnapinPropertiesCallback_AddPropertyName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __MMC20_LIBRARY_DEFINED__
#define __MMC20_LIBRARY_DEFINED__
  typedef enum DocumentMode {
    DocumentMode_Author = 0,DocumentMode_User,DocumentMode_User_MDI,DocumentMode_User_SDI
  } _DocumentMode;

  typedef enum DocumentMode DOCUMENTMODE;
  typedef enum DocumentMode *PDOCUMENTMODE;
  typedef enum DocumentMode **PPDOCUMENTMODE;

  typedef enum ListViewMode {
    ListMode_Small_Icons = 0,ListMode_Large_Icons,ListMode_List,ListMode_Detail,
    ListMode_Filtered
  } _ListViewMode;

  typedef enum ListViewMode LISTVIEWMODE;
  typedef enum ListViewMode *PLISTVIEWMODE;
  typedef enum ListViewMode **PPLISTVIEWMODE;

  typedef enum ViewOptions {
    ViewOption_Default = 0,ViewOption_ScopeTreeHidden = 0x1,ViewOption_NoToolBars = 0x2,ViewOption_NotPersistable = 0x4
  } _ViewOptions;

  typedef enum ViewOptions VIEWOPTIONS;
  typedef enum ViewOptions *PVIEWOPTIONS;
  typedef enum ViewOptions **PPVIEWOPTIONS;

  typedef enum ExportListOptions {
    ExportListOptions_Default = 0,ExportListOptions_Unicode = 0x1,ExportListOptions_TabDelimited = 0x2,ExportListOptions_SelectedItemsOnly = 0x4
  } _ExportListOptions;

  typedef enum ExportListOptions EXPORTLISTOPTIONS;

  EXTERN_C const IID LIBID_MMC20;
#ifndef ___Application_INTERFACE_DEFINED__
#define ___Application_INTERFACE_DEFINED__
  EXTERN_C const IID IID__Application;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _Application : public IDispatch {
  public:
    virtual void WINAPI Help(void) = 0;
    virtual void WINAPI Quit(void) = 0;
    virtual HRESULT WINAPI get_Document(PPDOCUMENT Document) = 0;
    virtual HRESULT WINAPI Load(BSTR Filename) = 0;
    virtual HRESULT WINAPI get_Frame(PPFRAME Frame) = 0;
    virtual HRESULT WINAPI get_Visible(PBOOL Visible) = 0;
    virtual HRESULT WINAPI Show(void) = 0;
    virtual HRESULT WINAPI Hide(void) = 0;
    virtual HRESULT WINAPI get_UserControl(PBOOL UserControl) = 0;
    virtual HRESULT WINAPI put_UserControl(WINBOOL UserControl) = 0;
    virtual HRESULT WINAPI get_VersionMajor(PLONG VersionMajor) = 0;
    virtual HRESULT WINAPI get_VersionMinor(PLONG VersionMinor) = 0;
  };
#else
  typedef struct _ApplicationVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_Application *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_Application *This);
      ULONG (WINAPI *Release)(_Application *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_Application *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_Application *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_Application *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_Application *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      void (WINAPI *Help)(_Application *This);
      void (WINAPI *Quit)(_Application *This);
      HRESULT (WINAPI *get_Document)(_Application *This,PPDOCUMENT Document);
      HRESULT (WINAPI *Load)(_Application *This,BSTR Filename);
      HRESULT (WINAPI *get_Frame)(_Application *This,PPFRAME Frame);
      HRESULT (WINAPI *get_Visible)(_Application *This,PBOOL Visible);
      HRESULT (WINAPI *Show)(_Application *This);
      HRESULT (WINAPI *Hide)(_Application *This);
      HRESULT (WINAPI *get_UserControl)(_Application *This,PBOOL UserControl);
      HRESULT (WINAPI *put_UserControl)(_Application *This,WINBOOL UserControl);
      HRESULT (WINAPI *get_VersionMajor)(_Application *This,PLONG VersionMajor);
      HRESULT (WINAPI *get_VersionMinor)(_Application *This,PLONG VersionMinor);
    END_INTERFACE
  } _ApplicationVtbl;
  struct _Application {
    CONST_VTBL struct _ApplicationVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _Application_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _Application_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _Application_Release(This) (This)->lpVtbl->Release(This)
#define _Application_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _Application_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _Application_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _Application_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define _Application_Help(This) (This)->lpVtbl->Help(This)
#define _Application_Quit(This) (This)->lpVtbl->Quit(This)
#define _Application_get_Document(This,Document) (This)->lpVtbl->get_Document(This,Document)
#define _Application_Load(This,Filename) (This)->lpVtbl->Load(This,Filename)
#define _Application_get_Frame(This,Frame) (This)->lpVtbl->get_Frame(This,Frame)
#define _Application_get_Visible(This,Visible) (This)->lpVtbl->get_Visible(This,Visible)
#define _Application_Show(This) (This)->lpVtbl->Show(This)
#define _Application_Hide(This) (This)->lpVtbl->Hide(This)
#define _Application_get_UserControl(This,UserControl) (This)->lpVtbl->get_UserControl(This,UserControl)
#define _Application_put_UserControl(This,UserControl) (This)->lpVtbl->put_UserControl(This,UserControl)
#define _Application_get_VersionMajor(This,VersionMajor) (This)->lpVtbl->get_VersionMajor(This,VersionMajor)
#define _Application_get_VersionMinor(This,VersionMinor) (This)->lpVtbl->get_VersionMinor(This,VersionMinor)
#endif
#endif
  void WINAPI _Application_Help_Proxy(_Application *This);
  void __RPC_STUB _Application_Help_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  void WINAPI _Application_Quit_Proxy(_Application *This);
  void __RPC_STUB _Application_Quit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_Document_Proxy(_Application *This,PPDOCUMENT Document);
  void __RPC_STUB _Application_get_Document_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_Load_Proxy(_Application *This,BSTR Filename);
  void __RPC_STUB _Application_Load_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_Frame_Proxy(_Application *This,PPFRAME Frame);
  void __RPC_STUB _Application_get_Frame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_Visible_Proxy(_Application *This,PBOOL Visible);
  void __RPC_STUB _Application_get_Visible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_Show_Proxy(_Application *This);
  void __RPC_STUB _Application_Show_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_Hide_Proxy(_Application *This);
  void __RPC_STUB _Application_Hide_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_UserControl_Proxy(_Application *This,PBOOL UserControl);
  void __RPC_STUB _Application_get_UserControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_put_UserControl_Proxy(_Application *This,WINBOOL UserControl);
  void __RPC_STUB _Application_put_UserControl_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_VersionMajor_Proxy(_Application *This,PLONG VersionMajor);
  void __RPC_STUB _Application_get_VersionMajor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _Application_get_VersionMinor_Proxy(_Application *This,PLONG VersionMinor);
  void __RPC_STUB _Application_get_VersionMinor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef ___AppEvents_INTERFACE_DEFINED__
#define ___AppEvents_INTERFACE_DEFINED__
  EXTERN_C const IID IID__AppEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _AppEvents : public IDispatch {
  public:
    virtual HRESULT WINAPI OnQuit(PAPPLICATION Application) = 0;
    virtual HRESULT WINAPI OnDocumentOpen(PDOCUMENT Document,WINBOOL New) = 0;
    virtual HRESULT WINAPI OnDocumentClose(PDOCUMENT Document) = 0;
    virtual HRESULT WINAPI OnSnapInAdded(PDOCUMENT Document,PSNAPIN SnapIn) = 0;
    virtual HRESULT WINAPI OnSnapInRemoved(PDOCUMENT Document,PSNAPIN SnapIn) = 0;
    virtual HRESULT WINAPI OnNewView(PVIEW View) = 0;
    virtual HRESULT WINAPI OnViewClose(PVIEW View) = 0;
    virtual HRESULT WINAPI OnViewChange(PVIEW View,PNODE NewOwnerNode) = 0;
    virtual HRESULT WINAPI OnSelectionChange(PVIEW View,PNODES NewNodes) = 0;
    virtual HRESULT WINAPI OnContextMenuExecuted(PMENUITEM MenuItem) = 0;
    virtual HRESULT WINAPI OnToolbarButtonClicked(void) = 0;
    virtual HRESULT WINAPI OnListUpdated(PVIEW View) = 0;
  };
#else
  typedef struct _AppEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_AppEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_AppEvents *This);
      ULONG (WINAPI *Release)(_AppEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_AppEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_AppEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_AppEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_AppEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *OnQuit)(_AppEvents *This,PAPPLICATION Application);
      HRESULT (WINAPI *OnDocumentOpen)(_AppEvents *This,PDOCUMENT Document,WINBOOL New);
      HRESULT (WINAPI *OnDocumentClose)(_AppEvents *This,PDOCUMENT Document);
      HRESULT (WINAPI *OnSnapInAdded)(_AppEvents *This,PDOCUMENT Document,PSNAPIN SnapIn);
      HRESULT (WINAPI *OnSnapInRemoved)(_AppEvents *This,PDOCUMENT Document,PSNAPIN SnapIn);
      HRESULT (WINAPI *OnNewView)(_AppEvents *This,PVIEW View);
      HRESULT (WINAPI *OnViewClose)(_AppEvents *This,PVIEW View);
      HRESULT (WINAPI *OnViewChange)(_AppEvents *This,PVIEW View,PNODE NewOwnerNode);
      HRESULT (WINAPI *OnSelectionChange)(_AppEvents *This,PVIEW View,PNODES NewNodes);
      HRESULT (WINAPI *OnContextMenuExecuted)(_AppEvents *This,PMENUITEM MenuItem);
      HRESULT (WINAPI *OnToolbarButtonClicked)(_AppEvents *This);
      HRESULT (WINAPI *OnListUpdated)(_AppEvents *This,PVIEW View);
    END_INTERFACE
  } _AppEventsVtbl;
  struct _AppEvents {
    CONST_VTBL struct _AppEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _AppEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _AppEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _AppEvents_Release(This) (This)->lpVtbl->Release(This)
#define _AppEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _AppEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _AppEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _AppEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define _AppEvents_OnQuit(This,Application) (This)->lpVtbl->OnQuit(This,Application)
#define _AppEvents_OnDocumentOpen(This,Document,New) (This)->lpVtbl->OnDocumentOpen(This,Document,New)
#define _AppEvents_OnDocumentClose(This,Document) (This)->lpVtbl->OnDocumentClose(This,Document)
#define _AppEvents_OnSnapInAdded(This,Document,SnapIn) (This)->lpVtbl->OnSnapInAdded(This,Document,SnapIn)
#define _AppEvents_OnSnapInRemoved(This,Document,SnapIn) (This)->lpVtbl->OnSnapInRemoved(This,Document,SnapIn)
#define _AppEvents_OnNewView(This,View) (This)->lpVtbl->OnNewView(This,View)
#define _AppEvents_OnViewClose(This,View) (This)->lpVtbl->OnViewClose(This,View)
#define _AppEvents_OnViewChange(This,View,NewOwnerNode) (This)->lpVtbl->OnViewChange(This,View,NewOwnerNode)
#define _AppEvents_OnSelectionChange(This,View,NewNodes) (This)->lpVtbl->OnSelectionChange(This,View,NewNodes)
#define _AppEvents_OnContextMenuExecuted(This,MenuItem) (This)->lpVtbl->OnContextMenuExecuted(This,MenuItem)
#define _AppEvents_OnToolbarButtonClicked(This) (This)->lpVtbl->OnToolbarButtonClicked(This)
#define _AppEvents_OnListUpdated(This,View) (This)->lpVtbl->OnListUpdated(This,View)
#endif
#endif
  HRESULT WINAPI _AppEvents_OnQuit_Proxy(_AppEvents *This,PAPPLICATION Application);
  void __RPC_STUB _AppEvents_OnQuit_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnDocumentOpen_Proxy(_AppEvents *This,PDOCUMENT Document,WINBOOL New);
  void __RPC_STUB _AppEvents_OnDocumentOpen_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnDocumentClose_Proxy(_AppEvents *This,PDOCUMENT Document);
  void __RPC_STUB _AppEvents_OnDocumentClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnSnapInAdded_Proxy(_AppEvents *This,PDOCUMENT Document,PSNAPIN SnapIn);
  void __RPC_STUB _AppEvents_OnSnapInAdded_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnSnapInRemoved_Proxy(_AppEvents *This,PDOCUMENT Document,PSNAPIN SnapIn);
  void __RPC_STUB _AppEvents_OnSnapInRemoved_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnNewView_Proxy(_AppEvents *This,PVIEW View);
  void __RPC_STUB _AppEvents_OnNewView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnViewClose_Proxy(_AppEvents *This,PVIEW View);
  void __RPC_STUB _AppEvents_OnViewClose_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnViewChange_Proxy(_AppEvents *This,PVIEW View,PNODE NewOwnerNode);
  void __RPC_STUB _AppEvents_OnViewChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnSelectionChange_Proxy(_AppEvents *This,PVIEW View,PNODES NewNodes);
  void __RPC_STUB _AppEvents_OnSelectionChange_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnContextMenuExecuted_Proxy(_AppEvents *This,PMENUITEM MenuItem);
  void __RPC_STUB _AppEvents_OnContextMenuExecuted_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnToolbarButtonClicked_Proxy(_AppEvents *This);
  void __RPC_STUB _AppEvents_OnToolbarButtonClicked_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _AppEvents_OnListUpdated_Proxy(_AppEvents *This,PVIEW View);
  void __RPC_STUB _AppEvents_OnListUpdated_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __AppEvents_DISPINTERFACE_DEFINED__
#define __AppEvents_DISPINTERFACE_DEFINED__
  EXTERN_C const IID DIID_AppEvents;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct AppEvents : public IDispatch {
  };
#else
  typedef struct AppEventsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(AppEvents *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(AppEvents *This);
      ULONG (WINAPI *Release)(AppEvents *This);
      HRESULT (WINAPI *GetTypeInfoCount)(AppEvents *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(AppEvents *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(AppEvents *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(AppEvents *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
    END_INTERFACE
  } AppEventsVtbl;
  struct AppEvents {
    CONST_VTBL struct AppEventsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define AppEvents_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define AppEvents_AddRef(This) (This)->lpVtbl->AddRef(This)
#define AppEvents_Release(This) (This)->lpVtbl->Release(This)
#define AppEvents_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define AppEvents_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define AppEvents_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define AppEvents_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#endif
#endif
#endif
  EXTERN_C const CLSID CLSID_Application;
#ifdef __cplusplus
  class Application;
#endif

#ifndef ___EventConnector_INTERFACE_DEFINED__
#define ___EventConnector_INTERFACE_DEFINED__
  EXTERN_C const IID IID__EventConnector;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct _EventConnector : public IDispatch {
  public:
    virtual HRESULT WINAPI ConnectTo(PAPPLICATION Application) = 0;
    virtual HRESULT WINAPI Disconnect(void) = 0;
  };
#else
  typedef struct _EventConnectorVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(_EventConnector *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(_EventConnector *This);
      ULONG (WINAPI *Release)(_EventConnector *This);
      HRESULT (WINAPI *GetTypeInfoCount)(_EventConnector *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(_EventConnector *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(_EventConnector *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(_EventConnector *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *ConnectTo)(_EventConnector *This,PAPPLICATION Application);
      HRESULT (WINAPI *Disconnect)(_EventConnector *This);
    END_INTERFACE
  } _EventConnectorVtbl;
  struct _EventConnector {
    CONST_VTBL struct _EventConnectorVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define _EventConnector_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define _EventConnector_AddRef(This) (This)->lpVtbl->AddRef(This)
#define _EventConnector_Release(This) (This)->lpVtbl->Release(This)
#define _EventConnector_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define _EventConnector_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define _EventConnector_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define _EventConnector_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define _EventConnector_ConnectTo(This,Application) (This)->lpVtbl->ConnectTo(This,Application)
#define _EventConnector_Disconnect(This) (This)->lpVtbl->Disconnect(This)
#endif
#endif
  HRESULT WINAPI _EventConnector_ConnectTo_Proxy(_EventConnector *This,PAPPLICATION Application);
  void __RPC_STUB _EventConnector_ConnectTo_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI _EventConnector_Disconnect_Proxy(_EventConnector *This);
  void __RPC_STUB _EventConnector_Disconnect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

  EXTERN_C const CLSID CLSID_AppEventsDHTMLConnector;
#ifdef __cplusplus
  class AppEventsDHTMLConnector;
#endif

#ifndef __Frame_INTERFACE_DEFINED__
#define __Frame_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Frame;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Frame : public IDispatch {
  public:
    virtual HRESULT WINAPI Maximize(void) = 0;
    virtual HRESULT WINAPI Minimize(void) = 0;
    virtual HRESULT WINAPI Restore(void) = 0;
    virtual HRESULT WINAPI get_Top(PINT Top) = 0;
    virtual HRESULT WINAPI put_Top(int top) = 0;
    virtual HRESULT WINAPI get_Bottom(PINT Bottom) = 0;
    virtual HRESULT WINAPI put_Bottom(int bottom) = 0;
    virtual HRESULT WINAPI get_Left(PINT Left) = 0;
    virtual HRESULT WINAPI put_Left(int left) = 0;
    virtual HRESULT WINAPI get_Right(PINT Right) = 0;
    virtual HRESULT WINAPI put_Right(int right) = 0;
  };
#else
  typedef struct FrameVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Frame *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Frame *This);
      ULONG (WINAPI *Release)(Frame *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Frame *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Frame *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Frame *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Frame *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Maximize)(Frame *This);
      HRESULT (WINAPI *Minimize)(Frame *This);
      HRESULT (WINAPI *Restore)(Frame *This);
      HRESULT (WINAPI *get_Top)(Frame *This,PINT Top);
      HRESULT (WINAPI *put_Top)(Frame *This,int top);
      HRESULT (WINAPI *get_Bottom)(Frame *This,PINT Bottom);
      HRESULT (WINAPI *put_Bottom)(Frame *This,int bottom);
      HRESULT (WINAPI *get_Left)(Frame *This,PINT Left);
      HRESULT (WINAPI *put_Left)(Frame *This,int left);
      HRESULT (WINAPI *get_Right)(Frame *This,PINT Right);
      HRESULT (WINAPI *put_Right)(Frame *This,int right);
    END_INTERFACE
  } FrameVtbl;
  struct Frame {
    CONST_VTBL struct FrameVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Frame_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Frame_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Frame_Release(This) (This)->lpVtbl->Release(This)
#define Frame_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Frame_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Frame_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Frame_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Frame_Maximize(This) (This)->lpVtbl->Maximize(This)
#define Frame_Minimize(This) (This)->lpVtbl->Minimize(This)
#define Frame_Restore(This) (This)->lpVtbl->Restore(This)
#define Frame_get_Top(This,Top) (This)->lpVtbl->get_Top(This,Top)
#define Frame_put_Top(This,top) (This)->lpVtbl->put_Top(This,top)
#define Frame_get_Bottom(This,Bottom) (This)->lpVtbl->get_Bottom(This,Bottom)
#define Frame_put_Bottom(This,bottom) (This)->lpVtbl->put_Bottom(This,bottom)
#define Frame_get_Left(This,Left) (This)->lpVtbl->get_Left(This,Left)
#define Frame_put_Left(This,left) (This)->lpVtbl->put_Left(This,left)
#define Frame_get_Right(This,Right) (This)->lpVtbl->get_Right(This,Right)
#define Frame_put_Right(This,right) (This)->lpVtbl->put_Right(This,right)
#endif
#endif
  HRESULT WINAPI Frame_Maximize_Proxy(Frame *This);
  void __RPC_STUB Frame_Maximize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_Minimize_Proxy(Frame *This);
  void __RPC_STUB Frame_Minimize_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_Restore_Proxy(Frame *This);
  void __RPC_STUB Frame_Restore_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_get_Top_Proxy(Frame *This,PINT Top);
  void __RPC_STUB Frame_get_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_put_Top_Proxy(Frame *This,int top);
  void __RPC_STUB Frame_put_Top_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_get_Bottom_Proxy(Frame *This,PINT Bottom);
  void __RPC_STUB Frame_get_Bottom_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_put_Bottom_Proxy(Frame *This,int bottom);
  void __RPC_STUB Frame_put_Bottom_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_get_Left_Proxy(Frame *This,PINT Left);
  void __RPC_STUB Frame_get_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_put_Left_Proxy(Frame *This,int left);
  void __RPC_STUB Frame_put_Left_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_get_Right_Proxy(Frame *This,PINT Right);
  void __RPC_STUB Frame_get_Right_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Frame_put_Right_Proxy(Frame *This,int right);
  void __RPC_STUB Frame_put_Right_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Node_INTERFACE_DEFINED__
#define __Node_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Node;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Node : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(PBSTR Name) = 0;
    virtual HRESULT WINAPI get_Property(BSTR PropertyName,PBSTR PropertyValue) = 0;
    virtual HRESULT WINAPI get_Bookmark(PBSTR Bookmark) = 0;
    virtual HRESULT WINAPI IsScopeNode(PBOOL IsScopeNode) = 0;
    virtual HRESULT WINAPI get_Nodetype(PBSTR Nodetype) = 0;
  };
#else
  typedef struct NodeVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Node *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Node *This);
      ULONG (WINAPI *Release)(Node *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Node *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Node *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Node *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Node *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(Node *This,PBSTR Name);
      HRESULT (WINAPI *get_Property)(Node *This,BSTR PropertyName,PBSTR PropertyValue);
      HRESULT (WINAPI *get_Bookmark)(Node *This,PBSTR Bookmark);
      HRESULT (WINAPI *IsScopeNode)(Node *This,PBOOL IsScopeNode);
      HRESULT (WINAPI *get_Nodetype)(Node *This,PBSTR Nodetype);
    END_INTERFACE
  } NodeVtbl;
  struct Node {
    CONST_VTBL struct NodeVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Node_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Node_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Node_Release(This) (This)->lpVtbl->Release(This)
#define Node_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Node_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Node_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Node_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Node_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define Node_get_Property(This,PropertyName,PropertyValue) (This)->lpVtbl->get_Property(This,PropertyName,PropertyValue)
#define Node_get_Bookmark(This,Bookmark) (This)->lpVtbl->get_Bookmark(This,Bookmark)
#define Node_IsScopeNode(This,IsScopeNode) (This)->lpVtbl->IsScopeNode(This,IsScopeNode)
#define Node_get_Nodetype(This,Nodetype) (This)->lpVtbl->get_Nodetype(This,Nodetype)
#endif
#endif
  HRESULT WINAPI Node_get_Name_Proxy(Node *This,PBSTR Name);
  void __RPC_STUB Node_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Node_get_Property_Proxy(Node *This,BSTR PropertyName,PBSTR PropertyValue);
  void __RPC_STUB Node_get_Property_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Node_get_Bookmark_Proxy(Node *This,PBSTR Bookmark);
  void __RPC_STUB Node_get_Bookmark_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Node_IsScopeNode_Proxy(Node *This,PBOOL IsScopeNode);
  void __RPC_STUB Node_IsScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Node_get_Nodetype_Proxy(Node *This,PBSTR Nodetype);
  void __RPC_STUB Node_get_Nodetype_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ScopeNamespace_INTERFACE_DEFINED__
#define __ScopeNamespace_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ScopeNamespace;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ScopeNamespace : public IDispatch {
  public:
    virtual HRESULT WINAPI GetParent(PNODE Node,PPNODE Parent) = 0;
    virtual HRESULT WINAPI GetChild(PNODE Node,PPNODE Child) = 0;
    virtual HRESULT WINAPI GetNext(PNODE Node,PPNODE Next) = 0;
    virtual HRESULT WINAPI GetRoot(PPNODE Root) = 0;
    virtual HRESULT WINAPI Expand(PNODE Node) = 0;
  };
#else
  typedef struct ScopeNamespaceVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ScopeNamespace *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ScopeNamespace *This);
      ULONG (WINAPI *Release)(ScopeNamespace *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ScopeNamespace *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ScopeNamespace *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ScopeNamespace *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ScopeNamespace *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *GetParent)(ScopeNamespace *This,PNODE Node,PPNODE Parent);
      HRESULT (WINAPI *GetChild)(ScopeNamespace *This,PNODE Node,PPNODE Child);
      HRESULT (WINAPI *GetNext)(ScopeNamespace *This,PNODE Node,PPNODE Next);
      HRESULT (WINAPI *GetRoot)(ScopeNamespace *This,PPNODE Root);
      HRESULT (WINAPI *Expand)(ScopeNamespace *This,PNODE Node);
    END_INTERFACE
  } ScopeNamespaceVtbl;
  struct ScopeNamespace {
    CONST_VTBL struct ScopeNamespaceVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ScopeNamespace_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ScopeNamespace_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ScopeNamespace_Release(This) (This)->lpVtbl->Release(This)
#define ScopeNamespace_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ScopeNamespace_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ScopeNamespace_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ScopeNamespace_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ScopeNamespace_GetParent(This,Node,Parent) (This)->lpVtbl->GetParent(This,Node,Parent)
#define ScopeNamespace_GetChild(This,Node,Child) (This)->lpVtbl->GetChild(This,Node,Child)
#define ScopeNamespace_GetNext(This,Node,Next) (This)->lpVtbl->GetNext(This,Node,Next)
#define ScopeNamespace_GetRoot(This,Root) (This)->lpVtbl->GetRoot(This,Root)
#define ScopeNamespace_Expand(This,Node) (This)->lpVtbl->Expand(This,Node)
#endif
#endif
  HRESULT WINAPI ScopeNamespace_GetParent_Proxy(ScopeNamespace *This,PNODE Node,PPNODE Parent);
  void __RPC_STUB ScopeNamespace_GetParent_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ScopeNamespace_GetChild_Proxy(ScopeNamespace *This,PNODE Node,PPNODE Child);
  void __RPC_STUB ScopeNamespace_GetChild_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ScopeNamespace_GetNext_Proxy(ScopeNamespace *This,PNODE Node,PPNODE Next);
  void __RPC_STUB ScopeNamespace_GetNext_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ScopeNamespace_GetRoot_Proxy(ScopeNamespace *This,PPNODE Root);
  void __RPC_STUB ScopeNamespace_GetRoot_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ScopeNamespace_Expand_Proxy(ScopeNamespace *This,PNODE Node);
  void __RPC_STUB ScopeNamespace_Expand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Document_INTERFACE_DEFINED__
#define __Document_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Document;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Document : public IDispatch {
  public:
    virtual HRESULT WINAPI Save(void) = 0;
    virtual HRESULT WINAPI SaveAs(BSTR Filename) = 0;
    virtual HRESULT WINAPI Close(WINBOOL SaveChanges) = 0;
    virtual HRESULT WINAPI get_Views(PPVIEWS Views) = 0;
    virtual HRESULT WINAPI get_SnapIns(PPSNAPINS SnapIns) = 0;
    virtual HRESULT WINAPI get_ActiveView(PPVIEW View) = 0;
    virtual HRESULT WINAPI get_Name(PBSTR Name) = 0;
    virtual HRESULT WINAPI put_Name(BSTR Name) = 0;
    virtual HRESULT WINAPI get_Location(PBSTR Location) = 0;
    virtual HRESULT WINAPI get_IsSaved(PBOOL IsSaved) = 0;
    virtual HRESULT WINAPI get_Mode(PDOCUMENTMODE Mode) = 0;
    virtual HRESULT WINAPI put_Mode(DOCUMENTMODE Mode) = 0;
    virtual HRESULT WINAPI get_RootNode(PPNODE Node) = 0;
    virtual HRESULT WINAPI get_ScopeNamespace(PPSCOPENAMESPACE ScopeNamespace) = 0;
    virtual HRESULT WINAPI CreateProperties(PPPROPERTIES Properties) = 0;
    virtual HRESULT WINAPI get_Application(PPAPPLICATION Application) = 0;
  };
#else
  typedef struct DocumentVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Document *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Document *This);
      ULONG (WINAPI *Release)(Document *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Document *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Document *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Document *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Document *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Save)(Document *This);
      HRESULT (WINAPI *SaveAs)(Document *This,BSTR Filename);
      HRESULT (WINAPI *Close)(Document *This,WINBOOL SaveChanges);
      HRESULT (WINAPI *get_Views)(Document *This,PPVIEWS Views);
      HRESULT (WINAPI *get_SnapIns)(Document *This,PPSNAPINS SnapIns);
      HRESULT (WINAPI *get_ActiveView)(Document *This,PPVIEW View);
      HRESULT (WINAPI *get_Name)(Document *This,PBSTR Name);
      HRESULT (WINAPI *put_Name)(Document *This,BSTR Name);
      HRESULT (WINAPI *get_Location)(Document *This,PBSTR Location);
      HRESULT (WINAPI *get_IsSaved)(Document *This,PBOOL IsSaved);
      HRESULT (WINAPI *get_Mode)(Document *This,PDOCUMENTMODE Mode);
      HRESULT (WINAPI *put_Mode)(Document *This,DOCUMENTMODE Mode);
      HRESULT (WINAPI *get_RootNode)(Document *This,PPNODE Node);
      HRESULT (WINAPI *get_ScopeNamespace)(Document *This,PPSCOPENAMESPACE ScopeNamespace);
      HRESULT (WINAPI *CreateProperties)(Document *This,PPPROPERTIES Properties);
      HRESULT (WINAPI *get_Application)(Document *This,PPAPPLICATION Application);
    END_INTERFACE
  } DocumentVtbl;
  struct Document {
    CONST_VTBL struct DocumentVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Document_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Document_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Document_Release(This) (This)->lpVtbl->Release(This)
#define Document_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Document_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Document_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Document_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Document_Save(This) (This)->lpVtbl->Save(This)
#define Document_SaveAs(This,Filename) (This)->lpVtbl->SaveAs(This,Filename)
#define Document_Close(This,SaveChanges) (This)->lpVtbl->Close(This,SaveChanges)
#define Document_get_Views(This,Views) (This)->lpVtbl->get_Views(This,Views)
#define Document_get_SnapIns(This,SnapIns) (This)->lpVtbl->get_SnapIns(This,SnapIns)
#define Document_get_ActiveView(This,View) (This)->lpVtbl->get_ActiveView(This,View)
#define Document_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define Document_put_Name(This,Name) (This)->lpVtbl->put_Name(This,Name)
#define Document_get_Location(This,Location) (This)->lpVtbl->get_Location(This,Location)
#define Document_get_IsSaved(This,IsSaved) (This)->lpVtbl->get_IsSaved(This,IsSaved)
#define Document_get_Mode(This,Mode) (This)->lpVtbl->get_Mode(This,Mode)
#define Document_put_Mode(This,Mode) (This)->lpVtbl->put_Mode(This,Mode)
#define Document_get_RootNode(This,Node) (This)->lpVtbl->get_RootNode(This,Node)
#define Document_get_ScopeNamespace(This,ScopeNamespace) (This)->lpVtbl->get_ScopeNamespace(This,ScopeNamespace)
#define Document_CreateProperties(This,Properties) (This)->lpVtbl->CreateProperties(This,Properties)
#define Document_get_Application(This,Application) (This)->lpVtbl->get_Application(This,Application)
#endif
#endif
  HRESULT WINAPI Document_Save_Proxy(Document *This);
  void __RPC_STUB Document_Save_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_SaveAs_Proxy(Document *This,BSTR Filename);
  void __RPC_STUB Document_SaveAs_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_Close_Proxy(Document *This,WINBOOL SaveChanges);
  void __RPC_STUB Document_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_Views_Proxy(Document *This,PPVIEWS Views);
  void __RPC_STUB Document_get_Views_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_SnapIns_Proxy(Document *This,PPSNAPINS SnapIns);
  void __RPC_STUB Document_get_SnapIns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_ActiveView_Proxy(Document *This,PPVIEW View);
  void __RPC_STUB Document_get_ActiveView_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_Name_Proxy(Document *This,PBSTR Name);
  void __RPC_STUB Document_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_put_Name_Proxy(Document *This,BSTR Name);
  void __RPC_STUB Document_put_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_Location_Proxy(Document *This,PBSTR Location);
  void __RPC_STUB Document_get_Location_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_IsSaved_Proxy(Document *This,PBOOL IsSaved);
  void __RPC_STUB Document_get_IsSaved_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_Mode_Proxy(Document *This,PDOCUMENTMODE Mode);
  void __RPC_STUB Document_get_Mode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_put_Mode_Proxy(Document *This,DOCUMENTMODE Mode);
  void __RPC_STUB Document_put_Mode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_RootNode_Proxy(Document *This,PPNODE Node);
  void __RPC_STUB Document_get_RootNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_ScopeNamespace_Proxy(Document *This,PPSCOPENAMESPACE ScopeNamespace);
  void __RPC_STUB Document_get_ScopeNamespace_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_CreateProperties_Proxy(Document *This,PPPROPERTIES Properties);
  void __RPC_STUB Document_CreateProperties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Document_get_Application_Proxy(Document *This,PPAPPLICATION Application);
  void __RPC_STUB Document_get_Application_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __SnapIn_INTERFACE_DEFINED__
#define __SnapIn_INTERFACE_DEFINED__
  EXTERN_C const IID IID_SnapIn;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct SnapIn : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(PBSTR Name) = 0;
    virtual HRESULT WINAPI get_Vendor(PBSTR Vendor) = 0;
    virtual HRESULT WINAPI get_Version(PBSTR Version) = 0;
    virtual HRESULT WINAPI get_Extensions(PPEXTENSIONS Extensions) = 0;
    virtual HRESULT WINAPI get_SnapinCLSID(PBSTR SnapinCLSID) = 0;
    virtual HRESULT WINAPI get_Properties(PPPROPERTIES Properties) = 0;
    virtual HRESULT WINAPI EnableAllExtensions(WINBOOL Enable) = 0;
  };
#else
  typedef struct SnapInVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(SnapIn *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(SnapIn *This);
      ULONG (WINAPI *Release)(SnapIn *This);
      HRESULT (WINAPI *GetTypeInfoCount)(SnapIn *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(SnapIn *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(SnapIn *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(SnapIn *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(SnapIn *This,PBSTR Name);
      HRESULT (WINAPI *get_Vendor)(SnapIn *This,PBSTR Vendor);
      HRESULT (WINAPI *get_Version)(SnapIn *This,PBSTR Version);
      HRESULT (WINAPI *get_Extensions)(SnapIn *This,PPEXTENSIONS Extensions);
      HRESULT (WINAPI *get_SnapinCLSID)(SnapIn *This,PBSTR SnapinCLSID);
      HRESULT (WINAPI *get_Properties)(SnapIn *This,PPPROPERTIES Properties);
      HRESULT (WINAPI *EnableAllExtensions)(SnapIn *This,WINBOOL Enable);
    END_INTERFACE
  } SnapInVtbl;
  struct SnapIn {
    CONST_VTBL struct SnapInVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define SnapIn_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define SnapIn_AddRef(This) (This)->lpVtbl->AddRef(This)
#define SnapIn_Release(This) (This)->lpVtbl->Release(This)
#define SnapIn_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define SnapIn_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define SnapIn_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define SnapIn_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define SnapIn_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define SnapIn_get_Vendor(This,Vendor) (This)->lpVtbl->get_Vendor(This,Vendor)
#define SnapIn_get_Version(This,Version) (This)->lpVtbl->get_Version(This,Version)
#define SnapIn_get_Extensions(This,Extensions) (This)->lpVtbl->get_Extensions(This,Extensions)
#define SnapIn_get_SnapinCLSID(This,SnapinCLSID) (This)->lpVtbl->get_SnapinCLSID(This,SnapinCLSID)
#define SnapIn_get_Properties(This,Properties) (This)->lpVtbl->get_Properties(This,Properties)
#define SnapIn_EnableAllExtensions(This,Enable) (This)->lpVtbl->EnableAllExtensions(This,Enable)
#endif
#endif
  HRESULT WINAPI SnapIn_get_Name_Proxy(SnapIn *This,PBSTR Name);
  void __RPC_STUB SnapIn_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_get_Vendor_Proxy(SnapIn *This,PBSTR Vendor);
  void __RPC_STUB SnapIn_get_Vendor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_get_Version_Proxy(SnapIn *This,PBSTR Version);
  void __RPC_STUB SnapIn_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_get_Extensions_Proxy(SnapIn *This,PPEXTENSIONS Extensions);
  void __RPC_STUB SnapIn_get_Extensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_get_SnapinCLSID_Proxy(SnapIn *This,PBSTR SnapinCLSID);
  void __RPC_STUB SnapIn_get_SnapinCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_get_Properties_Proxy(SnapIn *This,PPPROPERTIES Properties);
  void __RPC_STUB SnapIn_get_Properties_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIn_EnableAllExtensions_Proxy(SnapIn *This,WINBOOL Enable);
  void __RPC_STUB SnapIn_EnableAllExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __SnapIns_INTERFACE_DEFINED__
#define __SnapIns_INTERFACE_DEFINED__
  EXTERN_C const IID IID_SnapIns;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct SnapIns : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Item(__LONG32 Index,PPSNAPIN SnapIn) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
    virtual HRESULT WINAPI Add(BSTR SnapinNameOrCLSID,VARIANT ParentSnapin,VARIANT Properties,PPSNAPIN SnapIn) = 0;
    virtual HRESULT WINAPI Remove(PSNAPIN SnapIn) = 0;
  };
#else
  typedef struct SnapInsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(SnapIns *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(SnapIns *This);
      ULONG (WINAPI *Release)(SnapIns *This);
      HRESULT (WINAPI *GetTypeInfoCount)(SnapIns *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(SnapIns *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(SnapIns *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(SnapIns *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(SnapIns *This,IUnknown **retval);
      HRESULT (WINAPI *Item)(SnapIns *This,__LONG32 Index,PPSNAPIN SnapIn);
      HRESULT (WINAPI *get_Count)(SnapIns *This,PLONG Count);
      HRESULT (WINAPI *Add)(SnapIns *This,BSTR SnapinNameOrCLSID,VARIANT ParentSnapin,VARIANT Properties,PPSNAPIN SnapIn);
      HRESULT (WINAPI *Remove)(SnapIns *This,PSNAPIN SnapIn);
    END_INTERFACE
  } SnapInsVtbl;
  struct SnapIns {
    CONST_VTBL struct SnapInsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define SnapIns_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define SnapIns_AddRef(This) (This)->lpVtbl->AddRef(This)
#define SnapIns_Release(This) (This)->lpVtbl->Release(This)
#define SnapIns_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define SnapIns_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define SnapIns_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define SnapIns_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define SnapIns_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define SnapIns_Item(This,Index,SnapIn) (This)->lpVtbl->Item(This,Index,SnapIn)
#define SnapIns_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define SnapIns_Add(This,SnapinNameOrCLSID,ParentSnapin,Properties,SnapIn) (This)->lpVtbl->Add(This,SnapinNameOrCLSID,ParentSnapin,Properties,SnapIn)
#define SnapIns_Remove(This,SnapIn) (This)->lpVtbl->Remove(This,SnapIn)
#endif
#endif
  HRESULT WINAPI SnapIns_get__NewEnum_Proxy(SnapIns *This,IUnknown **retval);
  void __RPC_STUB SnapIns_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIns_Item_Proxy(SnapIns *This,__LONG32 Index,PPSNAPIN SnapIn);
  void __RPC_STUB SnapIns_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIns_get_Count_Proxy(SnapIns *This,PLONG Count);
  void __RPC_STUB SnapIns_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIns_Add_Proxy(SnapIns *This,BSTR SnapinNameOrCLSID,VARIANT ParentSnapin,VARIANT Properties,PPSNAPIN SnapIn);
  void __RPC_STUB SnapIns_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI SnapIns_Remove_Proxy(SnapIns *This,PSNAPIN SnapIn);
  void __RPC_STUB SnapIns_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Extension_INTERFACE_DEFINED__
#define __Extension_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Extension;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Extension : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Name(PBSTR Name) = 0;
    virtual HRESULT WINAPI get_Vendor(PBSTR Vendor) = 0;
    virtual HRESULT WINAPI get_Version(PBSTR Version) = 0;
    virtual HRESULT WINAPI get_Extensions(PPEXTENSIONS Extensions) = 0;
    virtual HRESULT WINAPI get_SnapinCLSID(PBSTR SnapinCLSID) = 0;
    virtual HRESULT WINAPI EnableAllExtensions(WINBOOL Enable) = 0;
    virtual HRESULT WINAPI Enable(WINBOOL Enable) = 0;
  };
#else
  typedef struct ExtensionVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Extension *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Extension *This);
      ULONG (WINAPI *Release)(Extension *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Extension *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Extension *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Extension *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Extension *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Name)(Extension *This,PBSTR Name);
      HRESULT (WINAPI *get_Vendor)(Extension *This,PBSTR Vendor);
      HRESULT (WINAPI *get_Version)(Extension *This,PBSTR Version);
      HRESULT (WINAPI *get_Extensions)(Extension *This,PPEXTENSIONS Extensions);
      HRESULT (WINAPI *get_SnapinCLSID)(Extension *This,PBSTR SnapinCLSID);
      HRESULT (WINAPI *EnableAllExtensions)(Extension *This,WINBOOL Enable);
      HRESULT (WINAPI *Enable)(Extension *This,WINBOOL Enable);
    END_INTERFACE
  } ExtensionVtbl;
  struct Extension {
    CONST_VTBL struct ExtensionVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Extension_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Extension_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Extension_Release(This) (This)->lpVtbl->Release(This)
#define Extension_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Extension_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Extension_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Extension_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Extension_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#define Extension_get_Vendor(This,Vendor) (This)->lpVtbl->get_Vendor(This,Vendor)
#define Extension_get_Version(This,Version) (This)->lpVtbl->get_Version(This,Version)
#define Extension_get_Extensions(This,Extensions) (This)->lpVtbl->get_Extensions(This,Extensions)
#define Extension_get_SnapinCLSID(This,SnapinCLSID) (This)->lpVtbl->get_SnapinCLSID(This,SnapinCLSID)
#define Extension_EnableAllExtensions(This,Enable) (This)->lpVtbl->EnableAllExtensions(This,Enable)
#define Extension_Enable(This,Enable) (This)->lpVtbl->Enable(This,Enable)
#endif
#endif
  HRESULT WINAPI Extension_get_Name_Proxy(Extension *This,PBSTR Name);
  void __RPC_STUB Extension_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_get_Vendor_Proxy(Extension *This,PBSTR Vendor);
  void __RPC_STUB Extension_get_Vendor_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_get_Version_Proxy(Extension *This,PBSTR Version);
  void __RPC_STUB Extension_get_Version_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_get_Extensions_Proxy(Extension *This,PPEXTENSIONS Extensions);
  void __RPC_STUB Extension_get_Extensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_get_SnapinCLSID_Proxy(Extension *This,PBSTR SnapinCLSID);
  void __RPC_STUB Extension_get_SnapinCLSID_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_EnableAllExtensions_Proxy(Extension *This,WINBOOL Enable);
  void __RPC_STUB Extension_EnableAllExtensions_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extension_Enable_Proxy(Extension *This,WINBOOL Enable);
  void __RPC_STUB Extension_Enable_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Extensions_INTERFACE_DEFINED__
#define __Extensions_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Extensions;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Extensions : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Item(__LONG32 Index,PPEXTENSION Extension) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
  };
#else
  typedef struct ExtensionsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Extensions *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Extensions *This);
      ULONG (WINAPI *Release)(Extensions *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Extensions *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Extensions *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Extensions *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Extensions *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(Extensions *This,IUnknown **retval);
      HRESULT (WINAPI *Item)(Extensions *This,__LONG32 Index,PPEXTENSION Extension);
      HRESULT (WINAPI *get_Count)(Extensions *This,PLONG Count);
    END_INTERFACE
  } ExtensionsVtbl;
  struct Extensions {
    CONST_VTBL struct ExtensionsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Extensions_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Extensions_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Extensions_Release(This) (This)->lpVtbl->Release(This)
#define Extensions_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Extensions_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Extensions_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Extensions_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Extensions_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define Extensions_Item(This,Index,Extension) (This)->lpVtbl->Item(This,Index,Extension)
#define Extensions_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#endif
#endif
  HRESULT WINAPI Extensions_get__NewEnum_Proxy(Extensions *This,IUnknown **retval);
  void __RPC_STUB Extensions_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extensions_Item_Proxy(Extensions *This,__LONG32 Index,PPEXTENSION Extension);
  void __RPC_STUB Extensions_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Extensions_get_Count_Proxy(Extensions *This,PLONG Count);
  void __RPC_STUB Extensions_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Columns_INTERFACE_DEFINED__
#define __Columns_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Columns;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Columns : public IDispatch {
  public:
    virtual HRESULT WINAPI Item(__LONG32 Index,PPCOLUMN Column) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
  };
#else
  typedef struct ColumnsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Columns *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Columns *This);
      ULONG (WINAPI *Release)(Columns *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Columns *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Columns *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Columns *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Columns *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Item)(Columns *This,__LONG32 Index,PPCOLUMN Column);
      HRESULT (WINAPI *get_Count)(Columns *This,PLONG Count);
      HRESULT (WINAPI *get__NewEnum)(Columns *This,IUnknown **retval);
    END_INTERFACE
  } ColumnsVtbl;
  struct Columns {
    CONST_VTBL struct ColumnsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Columns_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Columns_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Columns_Release(This) (This)->lpVtbl->Release(This)
#define Columns_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Columns_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Columns_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Columns_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Columns_Item(This,Index,Column) (This)->lpVtbl->Item(This,Index,Column)
#define Columns_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define Columns_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#endif
#endif
  HRESULT WINAPI Columns_Item_Proxy(Columns *This,__LONG32 Index,PPCOLUMN Column);
  void __RPC_STUB Columns_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Columns_get_Count_Proxy(Columns *This,PLONG Count);
  void __RPC_STUB Columns_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Columns_get__NewEnum_Proxy(Columns *This,IUnknown **retval);
  void __RPC_STUB Columns_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Column_INTERFACE_DEFINED__
#define __Column_INTERFACE_DEFINED__
  typedef enum ColumnSortOrder {
    SortOrder_Ascending = 0,SortOrder_Descending = SortOrder_Ascending + 1
  } _ColumnSortOrder;

  typedef enum ColumnSortOrder COLUMNSORTORDER;

  EXTERN_C const IID IID_Column;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Column : public IDispatch {
  public:
    virtual HRESULT WINAPI Name(BSTR *Name) = 0;
    virtual HRESULT WINAPI get_Width(PLONG Width) = 0;
    virtual HRESULT WINAPI put_Width(__LONG32 Width) = 0;
    virtual HRESULT WINAPI get_DisplayPosition(PLONG DisplayPosition) = 0;
    virtual HRESULT WINAPI put_DisplayPosition(__LONG32 Index) = 0;
    virtual HRESULT WINAPI get_Hidden(PBOOL Hidden) = 0;
    virtual HRESULT WINAPI put_Hidden(WINBOOL Hidden) = 0;
    virtual HRESULT WINAPI SetAsSortColumn(COLUMNSORTORDER SortOrder) = 0;
    virtual HRESULT WINAPI IsSortColumn(PBOOL IsSortColumn) = 0;
  };
#else
  typedef struct ColumnVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Column *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Column *This);
      ULONG (WINAPI *Release)(Column *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Column *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Column *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Column *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Column *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Name)(Column *This,BSTR *Name);
      HRESULT (WINAPI *get_Width)(Column *This,PLONG Width);
      HRESULT (WINAPI *put_Width)(Column *This,__LONG32 Width);
      HRESULT (WINAPI *get_DisplayPosition)(Column *This,PLONG DisplayPosition);
      HRESULT (WINAPI *put_DisplayPosition)(Column *This,__LONG32 Index);
      HRESULT (WINAPI *get_Hidden)(Column *This,PBOOL Hidden);
      HRESULT (WINAPI *put_Hidden)(Column *This,WINBOOL Hidden);
      HRESULT (WINAPI *SetAsSortColumn)(Column *This,COLUMNSORTORDER SortOrder);
      HRESULT (WINAPI *IsSortColumn)(Column *This,PBOOL IsSortColumn);
    END_INTERFACE
  } ColumnVtbl;
  struct Column {
    CONST_VTBL struct ColumnVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Column_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Column_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Column_Release(This) (This)->lpVtbl->Release(This)
#define Column_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Column_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Column_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Column_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Column_Name(This,Name) (This)->lpVtbl->Name(This,Name)
#define Column_get_Width(This,Width) (This)->lpVtbl->get_Width(This,Width)
#define Column_put_Width(This,Width) (This)->lpVtbl->put_Width(This,Width)
#define Column_get_DisplayPosition(This,DisplayPosition) (This)->lpVtbl->get_DisplayPosition(This,DisplayPosition)
#define Column_put_DisplayPosition(This,Index) (This)->lpVtbl->put_DisplayPosition(This,Index)
#define Column_get_Hidden(This,Hidden) (This)->lpVtbl->get_Hidden(This,Hidden)
#define Column_put_Hidden(This,Hidden) (This)->lpVtbl->put_Hidden(This,Hidden)
#define Column_SetAsSortColumn(This,SortOrder) (This)->lpVtbl->SetAsSortColumn(This,SortOrder)
#define Column_IsSortColumn(This,IsSortColumn) (This)->lpVtbl->IsSortColumn(This,IsSortColumn)
#endif
#endif
  HRESULT WINAPI Column_Name_Proxy(Column *This,BSTR *Name);
  void __RPC_STUB Column_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_get_Width_Proxy(Column *This,PLONG Width);
  void __RPC_STUB Column_get_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_put_Width_Proxy(Column *This,__LONG32 Width);
  void __RPC_STUB Column_put_Width_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_get_DisplayPosition_Proxy(Column *This,PLONG DisplayPosition);
  void __RPC_STUB Column_get_DisplayPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_put_DisplayPosition_Proxy(Column *This,__LONG32 Index);
  void __RPC_STUB Column_put_DisplayPosition_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_get_Hidden_Proxy(Column *This,PBOOL Hidden);
  void __RPC_STUB Column_get_Hidden_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_put_Hidden_Proxy(Column *This,WINBOOL Hidden);
  void __RPC_STUB Column_put_Hidden_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_SetAsSortColumn_Proxy(Column *This,COLUMNSORTORDER SortOrder);
  void __RPC_STUB Column_SetAsSortColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Column_IsSortColumn_Proxy(Column *This,PBOOL IsSortColumn);
  void __RPC_STUB Column_IsSortColumn_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Views_INTERFACE_DEFINED__
#define __Views_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Views;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Views : public IDispatch {
  public:
    virtual HRESULT WINAPI Item(__LONG32 Index,PPVIEW View) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
    virtual HRESULT WINAPI Add(PNODE Node,VIEWOPTIONS viewOptions = ViewOption_Default) = 0;
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
  };
#else
  typedef struct ViewsVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Views *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Views *This);
      ULONG (WINAPI *Release)(Views *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Views *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Views *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Views *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Views *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *Item)(Views *This,__LONG32 Index,PPVIEW View);
      HRESULT (WINAPI *get_Count)(Views *This,PLONG Count);
      HRESULT (WINAPI *Add)(Views *This,PNODE Node,VIEWOPTIONS viewOptions);
      HRESULT (WINAPI *get__NewEnum)(Views *This,IUnknown **retval);
    END_INTERFACE
  } ViewsVtbl;
  struct Views {
    CONST_VTBL struct ViewsVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Views_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Views_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Views_Release(This) (This)->lpVtbl->Release(This)
#define Views_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Views_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Views_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Views_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Views_Item(This,Index,View) (This)->lpVtbl->Item(This,Index,View)
#define Views_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define Views_Add(This,Node,viewOptions) (This)->lpVtbl->Add(This,Node,viewOptions)
#define Views_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#endif
#endif
  HRESULT WINAPI Views_Item_Proxy(Views *This,__LONG32 Index,PPVIEW View);
  void __RPC_STUB Views_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Views_get_Count_Proxy(Views *This,PLONG Count);
  void __RPC_STUB Views_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Views_Add_Proxy(Views *This,PNODE Node,VIEWOPTIONS viewOptions);
  void __RPC_STUB Views_Add_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Views_get__NewEnum_Proxy(Views *This,IUnknown **retval);
  void __RPC_STUB Views_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __View_INTERFACE_DEFINED__
#define __View_INTERFACE_DEFINED__
  EXTERN_C const IID IID_View;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct View : public IDispatch {
  public:
    virtual HRESULT WINAPI get_ActiveScopeNode(PPNODE Node) = 0;
    virtual HRESULT WINAPI put_ActiveScopeNode(PNODE Node) = 0;
    virtual HRESULT WINAPI get_Selection(PPNODES Nodes) = 0;
    virtual HRESULT WINAPI get_ListItems(PPNODES Nodes) = 0;
    virtual HRESULT WINAPI SnapinScopeObject(VARIANT ScopeNode,PPDISPATCH ScopeNodeObject) = 0;
    virtual HRESULT WINAPI SnapinSelectionObject(PPDISPATCH SelectionObject) = 0;
    virtual HRESULT WINAPI Is(PVIEW View,VARIANT_BOOL *TheSame) = 0;
    virtual HRESULT WINAPI get_Document(PPDOCUMENT Document) = 0;
    virtual HRESULT WINAPI SelectAll(void) = 0;
    virtual HRESULT WINAPI Select(PNODE Node) = 0;
    virtual HRESULT WINAPI Deselect(PNODE Node) = 0;
    virtual HRESULT WINAPI IsSelected(PNODE Node,PBOOL IsSelected) = 0;
    virtual HRESULT WINAPI DisplayScopeNodePropertySheet(VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI DisplaySelectionPropertySheet(void) = 0;
    virtual HRESULT WINAPI CopyScopeNode(VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI CopySelection(void) = 0;
    virtual HRESULT WINAPI DeleteScopeNode(VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI DeleteSelection(void) = 0;
    virtual HRESULT WINAPI RenameScopeNode(BSTR NewName,VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI RenameSelectedItem(BSTR NewName) = 0;
    virtual HRESULT WINAPI get_ScopeNodeContextMenu(VARIANT ScopeNode,PPCONTEXTMENU ContextMenu) = 0;
    virtual HRESULT WINAPI get_SelectionContextMenu(PPCONTEXTMENU ContextMenu) = 0;
    virtual HRESULT WINAPI RefreshScopeNode(VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI RefreshSelection(void) = 0;
    virtual HRESULT WINAPI ExecuteSelectionMenuItem(BSTR MenuItemPath) = 0;
    virtual HRESULT WINAPI ExecuteScopeNodeMenuItem(BSTR MenuItemPath,VARIANT ScopeNode) = 0;
    virtual HRESULT WINAPI ExecuteShellCommand(BSTR Command,BSTR Directory,BSTR Parameters,BSTR WindowState) = 0;
    virtual HRESULT WINAPI get_Frame(PPFRAME Frame) = 0;
    virtual HRESULT WINAPI Close(void) = 0;
    virtual HRESULT WINAPI get_ScopeTreeVisible(PBOOL Visible) = 0;
    virtual HRESULT WINAPI put_ScopeTreeVisible(WINBOOL Visible) = 0;
    virtual HRESULT WINAPI Back(void) = 0;
    virtual HRESULT WINAPI Forward(void) = 0;
    virtual HRESULT WINAPI put_StatusBarText(BSTR StatusBarText) = 0;
    virtual HRESULT WINAPI get_Memento(PBSTR Memento) = 0;
    virtual HRESULT WINAPI ViewMemento(BSTR Memento) = 0;
    virtual HRESULT WINAPI get_Columns(PPCOLUMNS Columns) = 0;
    virtual HRESULT WINAPI get_CellContents(PNODE Node,__LONG32 Column,PBSTR CellContents) = 0;
    virtual HRESULT WINAPI ExportList(BSTR File,EXPORTLISTOPTIONS exportoptions = ExportListOptions_Default) = 0;
    virtual HRESULT WINAPI get_ListViewMode(PLISTVIEWMODE Mode) = 0;
    virtual HRESULT WINAPI put_ListViewMode(LISTVIEWMODE mode) = 0;
    virtual HRESULT WINAPI get_ControlObject(PPDISPATCH Control) = 0;
  };
#else
  typedef struct ViewVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(View *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(View *This);
      ULONG (WINAPI *Release)(View *This);
      HRESULT (WINAPI *GetTypeInfoCount)(View *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(View *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(View *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(View *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_ActiveScopeNode)(View *This,PPNODE Node);
      HRESULT (WINAPI *put_ActiveScopeNode)(View *This,PNODE Node);
      HRESULT (WINAPI *get_Selection)(View *This,PPNODES Nodes);
      HRESULT (WINAPI *get_ListItems)(View *This,PPNODES Nodes);
      HRESULT (WINAPI *SnapinScopeObject)(View *This,VARIANT ScopeNode,PPDISPATCH ScopeNodeObject);
      HRESULT (WINAPI *SnapinSelectionObject)(View *This,PPDISPATCH SelectionObject);
      HRESULT (WINAPI *Is)(View *This,PVIEW View,VARIANT_BOOL *TheSame);
      HRESULT (WINAPI *get_Document)(View *This,PPDOCUMENT Document);
      HRESULT (WINAPI *SelectAll)(View *This);
      HRESULT (WINAPI *Select)(View *This,PNODE Node);
      HRESULT (WINAPI *Deselect)(View *This,PNODE Node);
      HRESULT (WINAPI *IsSelected)(View *This,PNODE Node,PBOOL IsSelected);
      HRESULT (WINAPI *DisplayScopeNodePropertySheet)(View *This,VARIANT ScopeNode);
      HRESULT (WINAPI *DisplaySelectionPropertySheet)(View *This);
      HRESULT (WINAPI *CopyScopeNode)(View *This,VARIANT ScopeNode);
      HRESULT (WINAPI *CopySelection)(View *This);
      HRESULT (WINAPI *DeleteScopeNode)(View *This,VARIANT ScopeNode);
      HRESULT (WINAPI *DeleteSelection)(View *This);
      HRESULT (WINAPI *RenameScopeNode)(View *This,BSTR NewName,VARIANT ScopeNode);
      HRESULT (WINAPI *RenameSelectedItem)(View *This,BSTR NewName);
      HRESULT (WINAPI *get_ScopeNodeContextMenu)(View *This,VARIANT ScopeNode,PPCONTEXTMENU ContextMenu);
      HRESULT (WINAPI *get_SelectionContextMenu)(View *This,PPCONTEXTMENU ContextMenu);
      HRESULT (WINAPI *RefreshScopeNode)(View *This,VARIANT ScopeNode);
      HRESULT (WINAPI *RefreshSelection)(View *This);
      HRESULT (WINAPI *ExecuteSelectionMenuItem)(View *This,BSTR MenuItemPath);
      HRESULT (WINAPI *ExecuteScopeNodeMenuItem)(View *This,BSTR MenuItemPath,VARIANT ScopeNode);
      HRESULT (WINAPI *ExecuteShellCommand)(View *This,BSTR Command,BSTR Directory,BSTR Parameters,BSTR WindowState);
      HRESULT (WINAPI *get_Frame)(View *This,PPFRAME Frame);
      HRESULT (WINAPI *Close)(View *This);
      HRESULT (WINAPI *get_ScopeTreeVisible)(View *This,PBOOL Visible);
      HRESULT (WINAPI *put_ScopeTreeVisible)(View *This,WINBOOL Visible);
      HRESULT (WINAPI *Back)(View *This);
      HRESULT (WINAPI *Forward)(View *This);
      HRESULT (WINAPI *put_StatusBarText)(View *This,BSTR StatusBarText);
      HRESULT (WINAPI *get_Memento)(View *This,PBSTR Memento);
      HRESULT (WINAPI *ViewMemento)(View *This,BSTR Memento);
      HRESULT (WINAPI *get_Columns)(View *This,PPCOLUMNS Columns);
      HRESULT (WINAPI *get_CellContents)(View *This,PNODE Node,__LONG32 Column,PBSTR CellContents);
      HRESULT (WINAPI *ExportList)(View *This,BSTR File,EXPORTLISTOPTIONS exportoptions);
      HRESULT (WINAPI *get_ListViewMode)(View *This,PLISTVIEWMODE Mode);
      HRESULT (WINAPI *put_ListViewMode)(View *This,LISTVIEWMODE mode);
      HRESULT (WINAPI *get_ControlObject)(View *This,PPDISPATCH Control);
    END_INTERFACE
  } ViewVtbl;
  struct View {
    CONST_VTBL struct ViewVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define View_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define View_AddRef(This) (This)->lpVtbl->AddRef(This)
#define View_Release(This) (This)->lpVtbl->Release(This)
#define View_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define View_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define View_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define View_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define View_get_ActiveScopeNode(This,Node) (This)->lpVtbl->get_ActiveScopeNode(This,Node)
#define View_put_ActiveScopeNode(This,Node) (This)->lpVtbl->put_ActiveScopeNode(This,Node)
#define View_get_Selection(This,Nodes) (This)->lpVtbl->get_Selection(This,Nodes)
#define View_get_ListItems(This,Nodes) (This)->lpVtbl->get_ListItems(This,Nodes)
#define View_SnapinScopeObject(This,ScopeNode,ScopeNodeObject) (This)->lpVtbl->SnapinScopeObject(This,ScopeNode,ScopeNodeObject)
#define View_SnapinSelectionObject(This,SelectionObject) (This)->lpVtbl->SnapinSelectionObject(This,SelectionObject)
#define View_Is(This,View,TheSame) (This)->lpVtbl->Is(This,View,TheSame)
#define View_get_Document(This,Document) (This)->lpVtbl->get_Document(This,Document)
#define View_SelectAll(This) (This)->lpVtbl->SelectAll(This)
#define View_Select(This,Node) (This)->lpVtbl->Select(This,Node)
#define View_Deselect(This,Node) (This)->lpVtbl->Deselect(This,Node)
#define View_IsSelected(This,Node,IsSelected) (This)->lpVtbl->IsSelected(This,Node,IsSelected)
#define View_DisplayScopeNodePropertySheet(This,ScopeNode) (This)->lpVtbl->DisplayScopeNodePropertySheet(This,ScopeNode)
#define View_DisplaySelectionPropertySheet(This) (This)->lpVtbl->DisplaySelectionPropertySheet(This)
#define View_CopyScopeNode(This,ScopeNode) (This)->lpVtbl->CopyScopeNode(This,ScopeNode)
#define View_CopySelection(This) (This)->lpVtbl->CopySelection(This)
#define View_DeleteScopeNode(This,ScopeNode) (This)->lpVtbl->DeleteScopeNode(This,ScopeNode)
#define View_DeleteSelection(This) (This)->lpVtbl->DeleteSelection(This)
#define View_RenameScopeNode(This,NewName,ScopeNode) (This)->lpVtbl->RenameScopeNode(This,NewName,ScopeNode)
#define View_RenameSelectedItem(This,NewName) (This)->lpVtbl->RenameSelectedItem(This,NewName)
#define View_get_ScopeNodeContextMenu(This,ScopeNode,ContextMenu) (This)->lpVtbl->get_ScopeNodeContextMenu(This,ScopeNode,ContextMenu)
#define View_get_SelectionContextMenu(This,ContextMenu) (This)->lpVtbl->get_SelectionContextMenu(This,ContextMenu)
#define View_RefreshScopeNode(This,ScopeNode) (This)->lpVtbl->RefreshScopeNode(This,ScopeNode)
#define View_RefreshSelection(This) (This)->lpVtbl->RefreshSelection(This)
#define View_ExecuteSelectionMenuItem(This,MenuItemPath) (This)->lpVtbl->ExecuteSelectionMenuItem(This,MenuItemPath)
#define View_ExecuteScopeNodeMenuItem(This,MenuItemPath,ScopeNode) (This)->lpVtbl->ExecuteScopeNodeMenuItem(This,MenuItemPath,ScopeNode)
#define View_ExecuteShellCommand(This,Command,Directory,Parameters,WindowState) (This)->lpVtbl->ExecuteShellCommand(This,Command,Directory,Parameters,WindowState)
#define View_get_Frame(This,Frame) (This)->lpVtbl->get_Frame(This,Frame)
#define View_Close(This) (This)->lpVtbl->Close(This)
#define View_get_ScopeTreeVisible(This,Visible) (This)->lpVtbl->get_ScopeTreeVisible(This,Visible)
#define View_put_ScopeTreeVisible(This,Visible) (This)->lpVtbl->put_ScopeTreeVisible(This,Visible)
#define View_Back(This) (This)->lpVtbl->Back(This)
#define View_Forward(This) (This)->lpVtbl->Forward(This)
#define View_put_StatusBarText(This,StatusBarText) (This)->lpVtbl->put_StatusBarText(This,StatusBarText)
#define View_get_Memento(This,Memento) (This)->lpVtbl->get_Memento(This,Memento)
#define View_ViewMemento(This,Memento) (This)->lpVtbl->ViewMemento(This,Memento)
#define View_get_Columns(This,Columns) (This)->lpVtbl->get_Columns(This,Columns)
#define View_get_CellContents(This,Node,Column,CellContents) (This)->lpVtbl->get_CellContents(This,Node,Column,CellContents)
#define View_ExportList(This,File,exportoptions) (This)->lpVtbl->ExportList(This,File,exportoptions)
#define View_get_ListViewMode(This,Mode) (This)->lpVtbl->get_ListViewMode(This,Mode)
#define View_put_ListViewMode(This,mode) (This)->lpVtbl->put_ListViewMode(This,mode)
#define View_get_ControlObject(This,Control) (This)->lpVtbl->get_ControlObject(This,Control)
#endif
#endif
  HRESULT WINAPI View_get_ActiveScopeNode_Proxy(View *This,PPNODE Node);
  void __RPC_STUB View_get_ActiveScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_put_ActiveScopeNode_Proxy(View *This,PNODE Node);
  void __RPC_STUB View_put_ActiveScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_Selection_Proxy(View *This,PPNODES Nodes);
  void __RPC_STUB View_get_Selection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_ListItems_Proxy(View *This,PPNODES Nodes);
  void __RPC_STUB View_get_ListItems_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_SnapinScopeObject_Proxy(View *This,VARIANT ScopeNode,PPDISPATCH ScopeNodeObject);
  void __RPC_STUB View_SnapinScopeObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_SnapinSelectionObject_Proxy(View *This,PPDISPATCH SelectionObject);
  void __RPC_STUB View_SnapinSelectionObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Is_Proxy(View *This,PVIEW View,VARIANT_BOOL *TheSame);
  void __RPC_STUB View_Is_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_Document_Proxy(View *This,PPDOCUMENT Document);
  void __RPC_STUB View_get_Document_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_SelectAll_Proxy(View *This);
  void __RPC_STUB View_SelectAll_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Select_Proxy(View *This,PNODE Node);
  void __RPC_STUB View_Select_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Deselect_Proxy(View *This,PNODE Node);
  void __RPC_STUB View_Deselect_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_IsSelected_Proxy(View *This,PNODE Node,PBOOL IsSelected);
  void __RPC_STUB View_IsSelected_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_DisplayScopeNodePropertySheet_Proxy(View *This,VARIANT ScopeNode);
  void __RPC_STUB View_DisplayScopeNodePropertySheet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_DisplaySelectionPropertySheet_Proxy(View *This);
  void __RPC_STUB View_DisplaySelectionPropertySheet_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_CopyScopeNode_Proxy(View *This,VARIANT ScopeNode);
  void __RPC_STUB View_CopyScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_CopySelection_Proxy(View *This);
  void __RPC_STUB View_CopySelection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_DeleteScopeNode_Proxy(View *This,VARIANT ScopeNode);
  void __RPC_STUB View_DeleteScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_DeleteSelection_Proxy(View *This);
  void __RPC_STUB View_DeleteSelection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_RenameScopeNode_Proxy(View *This,BSTR NewName,VARIANT ScopeNode);
  void __RPC_STUB View_RenameScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_RenameSelectedItem_Proxy(View *This,BSTR NewName);
  void __RPC_STUB View_RenameSelectedItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_ScopeNodeContextMenu_Proxy(View *This,VARIANT ScopeNode,PPCONTEXTMENU ContextMenu);
  void __RPC_STUB View_get_ScopeNodeContextMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_SelectionContextMenu_Proxy(View *This,PPCONTEXTMENU ContextMenu);
  void __RPC_STUB View_get_SelectionContextMenu_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_RefreshScopeNode_Proxy(View *This,VARIANT ScopeNode);
  void __RPC_STUB View_RefreshScopeNode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_RefreshSelection_Proxy(View *This);
  void __RPC_STUB View_RefreshSelection_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_ExecuteSelectionMenuItem_Proxy(View *This,BSTR MenuItemPath);
  void __RPC_STUB View_ExecuteSelectionMenuItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_ExecuteScopeNodeMenuItem_Proxy(View *This,BSTR MenuItemPath,VARIANT ScopeNode);
  void __RPC_STUB View_ExecuteScopeNodeMenuItem_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_ExecuteShellCommand_Proxy(View *This,BSTR Command,BSTR Directory,BSTR Parameters,BSTR WindowState);
  void __RPC_STUB View_ExecuteShellCommand_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_Frame_Proxy(View *This,PPFRAME Frame);
  void __RPC_STUB View_get_Frame_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Close_Proxy(View *This);
  void __RPC_STUB View_Close_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_ScopeTreeVisible_Proxy(View *This,PBOOL Visible);
  void __RPC_STUB View_get_ScopeTreeVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_put_ScopeTreeVisible_Proxy(View *This,WINBOOL Visible);
  void __RPC_STUB View_put_ScopeTreeVisible_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Back_Proxy(View *This);
  void __RPC_STUB View_Back_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_Forward_Proxy(View *This);
  void __RPC_STUB View_Forward_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_put_StatusBarText_Proxy(View *This,BSTR StatusBarText);
  void __RPC_STUB View_put_StatusBarText_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_Memento_Proxy(View *This,PBSTR Memento);
  void __RPC_STUB View_get_Memento_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_ViewMemento_Proxy(View *This,BSTR Memento);
  void __RPC_STUB View_ViewMemento_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_Columns_Proxy(View *This,PPCOLUMNS Columns);
  void __RPC_STUB View_get_Columns_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_CellContents_Proxy(View *This,PNODE Node,__LONG32 Column,PBSTR CellContents);
  void __RPC_STUB View_get_CellContents_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_ExportList_Proxy(View *This,BSTR File,EXPORTLISTOPTIONS exportoptions);
  void __RPC_STUB View_ExportList_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_ListViewMode_Proxy(View *This,PLISTVIEWMODE Mode);
  void __RPC_STUB View_get_ListViewMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_put_ListViewMode_Proxy(View *This,LISTVIEWMODE mode);
  void __RPC_STUB View_put_ListViewMode_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI View_get_ControlObject_Proxy(View *This,PPDISPATCH Control);
  void __RPC_STUB View_get_ControlObject_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Nodes_INTERFACE_DEFINED__
#define __Nodes_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Nodes;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Nodes : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Item(__LONG32 Index,PPNODE Node) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
  };
#else
  typedef struct NodesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Nodes *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Nodes *This);
      ULONG (WINAPI *Release)(Nodes *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Nodes *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Nodes *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Nodes *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Nodes *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(Nodes *This,IUnknown **retval);
      HRESULT (WINAPI *Item)(Nodes *This,__LONG32 Index,PPNODE Node);
      HRESULT (WINAPI *get_Count)(Nodes *This,PLONG Count);
    END_INTERFACE
  } NodesVtbl;
  struct Nodes {
    CONST_VTBL struct NodesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Nodes_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Nodes_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Nodes_Release(This) (This)->lpVtbl->Release(This)
#define Nodes_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Nodes_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Nodes_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Nodes_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Nodes_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define Nodes_Item(This,Index,Node) (This)->lpVtbl->Item(This,Index,Node)
#define Nodes_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#endif
#endif
  HRESULT WINAPI Nodes_get__NewEnum_Proxy(Nodes *This,IUnknown **retval);
  void __RPC_STUB Nodes_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Nodes_Item_Proxy(Nodes *This,__LONG32 Index,PPNODE Node);
  void __RPC_STUB Nodes_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Nodes_get_Count_Proxy(Nodes *This,PLONG Count);
  void __RPC_STUB Nodes_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __ContextMenu_INTERFACE_DEFINED__
#define __ContextMenu_INTERFACE_DEFINED__
  EXTERN_C const IID IID_ContextMenu;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct ContextMenu : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI get_Item(VARIANT IndexOrPath,PPMENUITEM MenuItem) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
  };
#else
  typedef struct ContextMenuVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(ContextMenu *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(ContextMenu *This);
      ULONG (WINAPI *Release)(ContextMenu *This);
      HRESULT (WINAPI *GetTypeInfoCount)(ContextMenu *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(ContextMenu *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(ContextMenu *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(ContextMenu *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(ContextMenu *This,IUnknown **retval);
      HRESULT (WINAPI *get_Item)(ContextMenu *This,VARIANT IndexOrPath,PPMENUITEM MenuItem);
      HRESULT (WINAPI *get_Count)(ContextMenu *This,PLONG Count);
    END_INTERFACE
  } ContextMenuVtbl;
  struct ContextMenu {
    CONST_VTBL struct ContextMenuVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define ContextMenu_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define ContextMenu_AddRef(This) (This)->lpVtbl->AddRef(This)
#define ContextMenu_Release(This) (This)->lpVtbl->Release(This)
#define ContextMenu_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define ContextMenu_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define ContextMenu_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define ContextMenu_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define ContextMenu_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define ContextMenu_get_Item(This,IndexOrPath,MenuItem) (This)->lpVtbl->get_Item(This,IndexOrPath,MenuItem)
#define ContextMenu_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#endif
#endif
  HRESULT WINAPI ContextMenu_get__NewEnum_Proxy(ContextMenu *This,IUnknown **retval);
  void __RPC_STUB ContextMenu_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextMenu_get_Item_Proxy(ContextMenu *This,VARIANT IndexOrPath,PPMENUITEM MenuItem);
  void __RPC_STUB ContextMenu_get_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI ContextMenu_get_Count_Proxy(ContextMenu *This,PLONG Count);
  void __RPC_STUB ContextMenu_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __MenuItem_INTERFACE_DEFINED__
#define __MenuItem_INTERFACE_DEFINED__
  EXTERN_C const IID IID_MenuItem;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct MenuItem : public IDispatch {
  public:
    virtual HRESULT WINAPI get_DisplayName(PBSTR DisplayName) = 0;
    virtual HRESULT WINAPI get_LanguageIndependentName(PBSTR LanguageIndependentName) = 0;
    virtual HRESULT WINAPI get_Path(PBSTR Path) = 0;
    virtual HRESULT WINAPI get_LanguageIndependentPath(PBSTR LanguageIndependentPath) = 0;
    virtual HRESULT WINAPI Execute(void) = 0;
    virtual HRESULT WINAPI get_Enabled(PBOOL Enabled) = 0;
  };
#else
  typedef struct MenuItemVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(MenuItem *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(MenuItem *This);
      ULONG (WINAPI *Release)(MenuItem *This);
      HRESULT (WINAPI *GetTypeInfoCount)(MenuItem *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(MenuItem *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(MenuItem *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(MenuItem *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_DisplayName)(MenuItem *This,PBSTR DisplayName);
      HRESULT (WINAPI *get_LanguageIndependentName)(MenuItem *This,PBSTR LanguageIndependentName);
      HRESULT (WINAPI *get_Path)(MenuItem *This,PBSTR Path);
      HRESULT (WINAPI *get_LanguageIndependentPath)(MenuItem *This,PBSTR LanguageIndependentPath);
      HRESULT (WINAPI *Execute)(MenuItem *This);
      HRESULT (WINAPI *get_Enabled)(MenuItem *This,PBOOL Enabled);
    END_INTERFACE
  } MenuItemVtbl;
  struct MenuItem {
    CONST_VTBL struct MenuItemVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define MenuItem_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define MenuItem_AddRef(This) (This)->lpVtbl->AddRef(This)
#define MenuItem_Release(This) (This)->lpVtbl->Release(This)
#define MenuItem_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define MenuItem_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define MenuItem_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define MenuItem_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define MenuItem_get_DisplayName(This,DisplayName) (This)->lpVtbl->get_DisplayName(This,DisplayName)
#define MenuItem_get_LanguageIndependentName(This,LanguageIndependentName) (This)->lpVtbl->get_LanguageIndependentName(This,LanguageIndependentName)
#define MenuItem_get_Path(This,Path) (This)->lpVtbl->get_Path(This,Path)
#define MenuItem_get_LanguageIndependentPath(This,LanguageIndependentPath) (This)->lpVtbl->get_LanguageIndependentPath(This,LanguageIndependentPath)
#define MenuItem_Execute(This) (This)->lpVtbl->Execute(This)
#define MenuItem_get_Enabled(This,Enabled) (This)->lpVtbl->get_Enabled(This,Enabled)
#endif
#endif
  HRESULT WINAPI MenuItem_get_DisplayName_Proxy(MenuItem *This,PBSTR DisplayName);
  void __RPC_STUB MenuItem_get_DisplayName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI MenuItem_get_LanguageIndependentName_Proxy(MenuItem *This,PBSTR LanguageIndependentName);
  void __RPC_STUB MenuItem_get_LanguageIndependentName_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI MenuItem_get_Path_Proxy(MenuItem *This,PBSTR Path);
  void __RPC_STUB MenuItem_get_Path_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI MenuItem_get_LanguageIndependentPath_Proxy(MenuItem *This,PBSTR LanguageIndependentPath);
  void __RPC_STUB MenuItem_get_LanguageIndependentPath_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI MenuItem_Execute_Proxy(MenuItem *This);
  void __RPC_STUB MenuItem_Execute_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI MenuItem_get_Enabled_Proxy(MenuItem *This,PBOOL Enabled);
  void __RPC_STUB MenuItem_get_Enabled_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Properties_INTERFACE_DEFINED__
#define __Properties_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Properties;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Properties : public IDispatch {
  public:
    virtual HRESULT WINAPI get__NewEnum(IUnknown **retval) = 0;
    virtual HRESULT WINAPI Item(BSTR Name,PPPROPERTY Property) = 0;
    virtual HRESULT WINAPI get_Count(PLONG Count) = 0;
    virtual HRESULT WINAPI Remove(BSTR Name) = 0;
  };
#else
  typedef struct PropertiesVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Properties *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Properties *This);
      ULONG (WINAPI *Release)(Properties *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Properties *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Properties *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Properties *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Properties *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get__NewEnum)(Properties *This,IUnknown **retval);
      HRESULT (WINAPI *Item)(Properties *This,BSTR Name,PPPROPERTY Property);
      HRESULT (WINAPI *get_Count)(Properties *This,PLONG Count);
      HRESULT (WINAPI *Remove)(Properties *This,BSTR Name);
    END_INTERFACE
  } PropertiesVtbl;
  struct Properties {
    CONST_VTBL struct PropertiesVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Properties_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Properties_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Properties_Release(This) (This)->lpVtbl->Release(This)
#define Properties_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Properties_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Properties_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Properties_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Properties_get__NewEnum(This,retval) (This)->lpVtbl->get__NewEnum(This,retval)
#define Properties_Item(This,Name,Property) (This)->lpVtbl->Item(This,Name,Property)
#define Properties_get_Count(This,Count) (This)->lpVtbl->get_Count(This,Count)
#define Properties_Remove(This,Name) (This)->lpVtbl->Remove(This,Name)
#endif
#endif
  HRESULT WINAPI Properties_get__NewEnum_Proxy(Properties *This,IUnknown **retval);
  void __RPC_STUB Properties_get__NewEnum_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Properties_Item_Proxy(Properties *This,BSTR Name,PPPROPERTY Property);
  void __RPC_STUB Properties_Item_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Properties_get_Count_Proxy(Properties *This,PLONG Count);
  void __RPC_STUB Properties_get_Count_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Properties_Remove_Proxy(Properties *This,BSTR Name);
  void __RPC_STUB Properties_Remove_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif

#ifndef __Property_INTERFACE_DEFINED__
#define __Property_INTERFACE_DEFINED__
  EXTERN_C const IID IID_Property;
#if defined(__cplusplus) && !defined(CINTERFACE)
  struct Property : public IDispatch {
  public:
    virtual HRESULT WINAPI get_Value(PVARIANT Value) = 0;
    virtual HRESULT WINAPI put_Value(VARIANT Value) = 0;
    virtual HRESULT WINAPI get_Name(PBSTR Name) = 0;
  };
#else
  typedef struct PropertyVtbl {
    BEGIN_INTERFACE
      HRESULT (WINAPI *QueryInterface)(Property *This,REFIID riid,void **ppvObject);
      ULONG (WINAPI *AddRef)(Property *This);
      ULONG (WINAPI *Release)(Property *This);
      HRESULT (WINAPI *GetTypeInfoCount)(Property *This,UINT *pctinfo);
      HRESULT (WINAPI *GetTypeInfo)(Property *This,UINT iTInfo,LCID lcid,ITypeInfo **ppTInfo);
      HRESULT (WINAPI *GetIDsOfNames)(Property *This,REFIID riid,LPOLESTR *rgszNames,UINT cNames,LCID lcid,DISPID *rgDispId);
      HRESULT (WINAPI *Invoke)(Property *This,DISPID dispIdMember,REFIID riid,LCID lcid,WORD wFlags,DISPPARAMS *pDispParams,VARIANT *pVarResult,EXCEPINFO *pExcepInfo,UINT *puArgErr);
      HRESULT (WINAPI *get_Value)(Property *This,PVARIANT Value);
      HRESULT (WINAPI *put_Value)(Property *This,VARIANT Value);
      HRESULT (WINAPI *get_Name)(Property *This,PBSTR Name);
    END_INTERFACE
  } PropertyVtbl;
  struct Property {
    CONST_VTBL struct PropertyVtbl *lpVtbl;
  };
#ifdef COBJMACROS
#define Property_QueryInterface(This,riid,ppvObject) (This)->lpVtbl->QueryInterface(This,riid,ppvObject)
#define Property_AddRef(This) (This)->lpVtbl->AddRef(This)
#define Property_Release(This) (This)->lpVtbl->Release(This)
#define Property_GetTypeInfoCount(This,pctinfo) (This)->lpVtbl->GetTypeInfoCount(This,pctinfo)
#define Property_GetTypeInfo(This,iTInfo,lcid,ppTInfo) (This)->lpVtbl->GetTypeInfo(This,iTInfo,lcid,ppTInfo)
#define Property_GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId) (This)->lpVtbl->GetIDsOfNames(This,riid,rgszNames,cNames,lcid,rgDispId)
#define Property_Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr) (This)->lpVtbl->Invoke(This,dispIdMember,riid,lcid,wFlags,pDispParams,pVarResult,pExcepInfo,puArgErr)
#define Property_get_Value(This,Value) (This)->lpVtbl->get_Value(This,Value)
#define Property_put_Value(This,Value) (This)->lpVtbl->put_Value(This,Value)
#define Property_get_Name(This,Name) (This)->lpVtbl->get_Name(This,Name)
#endif
#endif
  HRESULT WINAPI Property_get_Value_Proxy(Property *This,PVARIANT Value);
  void __RPC_STUB Property_get_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Property_put_Value_Proxy(Property *This,VARIANT Value);
  void __RPC_STUB Property_put_Value_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
  HRESULT WINAPI Property_get_Name_Proxy(Property *This,PBSTR Name);
  void __RPC_STUB Property_get_Name_Stub(IRpcStubBuffer *This,IRpcChannelBuffer *_pRpcChannelBuffer,PRPC_MESSAGE _pRpcMessage,DWORD *_pdwStubPhase);
#endif
#endif
#endif

  extern RPC_IF_HANDLE __MIDL_itf_mmcobj_0138_v0_0_c_ifspec;
  extern RPC_IF_HANDLE __MIDL_itf_mmcobj_0138_v0_0_s_ifspec;

  ULONG __RPC_API VARIANT_UserSize(ULONG *,ULONG,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserMarshal(ULONG *,unsigned char *,VARIANT *);
  unsigned char *__RPC_API VARIANT_UserUnmarshal(ULONG *,unsigned char *,VARIANT *);
  void __RPC_API VARIANT_UserFree(ULONG *,VARIANT *);

#ifdef __cplusplus
}
#endif
#endif
