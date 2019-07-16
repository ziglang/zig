/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
DEFINE_GUID(CLSID_DsAdminCreateObj,0xe301a009,0xf901,0x11d2,0x82,0xb9,0x0,0xc0,0x4f,0x68,0x92,0x8b);
DEFINE_GUID(IID_IDsAdminCreateObj,0x53554a38,0xf902,0x11d2,0x82,0xb9,0x0,0xc0,0x4f,0x68,0x92,0x8b);
DEFINE_GUID(IID_IDsAdminNewObj,0xf2573587,0xe6fc,0x11d2,0x82,0xaf,0x0,0xc0,0x4f,0x68,0x92,0x8b);
DEFINE_GUID(IID_IDsAdminNewObjPrimarySite,0xbe2b487e,0xf904,0x11d2,0x82,0xb9,0x0,0xc0,0x4f,0x68,0x92,0x8b);
DEFINE_GUID(IID_IDsAdminNewObjExt,0x6088eae2,0xe7bf,0x11d2,0x82,0xaf,0x0,0xc0,0x4f,0x68,0x92,0x8b);
DEFINE_GUID(IID_IDsAdminNotifyHandler,0xe4a2b8b3,0x5a18,0x11d2,0x97,0xc1,0x0,0xa0,0xc9,0xa0,0x6d,0x2d);

#ifndef _DSADMIN_H
#define _DSADMIN_H

#undef INTERFACE
#define INTERFACE IDsAdminCreateObj
DECLARE_INTERFACE_(IDsAdminCreateObj,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(Initialize)(THIS_ IADsContainer *pADsContainerObj,IADs *pADsCopySource,LPCWSTR lpszClassName) PURE;
  STDMETHOD(CreateModal)(THIS_ HWND hwndParent,IADs **ppADsObj) PURE;
};

#undef INTERFACE
#define INTERFACE IDsAdminNewObj
DECLARE_INTERFACE_(IDsAdminNewObj,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(SetButtons)(THIS_ ULONG nCurrIndex,WINBOOL bValid) PURE;
  STDMETHOD(GetPageCounts)(THIS_ LONG *pnTotal,LONG *pnStartIndex) PURE;
};

#undef INTERFACE
#define INTERFACE IDsAdminNewObjPrimarySite
DECLARE_INTERFACE_(IDsAdminNewObjPrimarySite,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(CreateNew)(THIS_ LPCWSTR pszName) PURE;
  STDMETHOD(Commit)(THIS_) PURE;
};

typedef struct {
  DWORD dwSize;
  HICON hObjClassIcon;
  LPWSTR lpszWizTitle;
  LPWSTR lpszContDisplayName;
} DSA_NEWOBJ_DISPINFO,*LPDSA_NEWOBJ_DISPINFO;

#define DSA_NEWOBJ_CTX_PRECOMMIT 0x00000001
#define DSA_NEWOBJ_CTX_COMMIT 0x00000002
#define DSA_NEWOBJ_CTX_POSTCOMMIT 0x00000003
#define DSA_NEWOBJ_CTX_CLEANUP 0x00000004

#undef INTERFACE
#define INTERFACE IDsAdminNewObjExt
DECLARE_INTERFACE_(IDsAdminNewObjExt,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(Initialize)(THIS_ IADsContainer *pADsContainerObj,IADs *pADsCopySource,LPCWSTR lpszClassName,IDsAdminNewObj *pDsAdminNewObj,LPDSA_NEWOBJ_DISPINFO pDispInfo) PURE;
  STDMETHOD(AddPages)(THIS_ LPFNADDPROPSHEETPAGE lpfnAddPage,LPARAM lParam) PURE;
  STDMETHOD(SetObject)(THIS_ IADs *pADsObj) PURE;
  STDMETHOD(WriteData)(THIS_ HWND hWnd,ULONG uContext) PURE;
  STDMETHOD(OnError)(THIS_ HWND hWnd,HRESULT hr,ULONG uContext) PURE;
  STDMETHOD(GetSummaryInfo)(THIS_ BSTR *pBstrText) PURE;
};

#define DSA_NOTIFY_DEL 0x00000001
#define DSA_NOTIFY_REN 0x00000002
#define DSA_NOTIFY_MOV 0x00000004
#define DSA_NOTIFY_PROP 0x00000008

#define DSA_NOTIFY_ALL (DSA_NOTIFY_DEL|DSA_NOTIFY_REN|DSA_NOTIFY_MOV|DSA_NOTIFY_PROP)

#define DSA_NOTIFY_FLAG_ADDITIONAL_DATA 0x00000002
#define DSA_NOTIFY_FLAG_FORCE_ADDITIONAL_DATA 0x00000001

#undef INTERFACE
#define INTERFACE IDsAdminNotifyHandler
DECLARE_INTERFACE_(IDsAdminNotifyHandler,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(Initialize)(THIS_ IDataObject *pExtraInfo,ULONG *puEventFlags) PURE;
  STDMETHOD(Begin)(THIS_ ULONG uEvent,IDataObject *pArg1,IDataObject *pArg2,ULONG *puFlags,BSTR *pBstr) PURE;
  STDMETHOD(Notify)(THIS_ ULONG nItem,ULONG uFlags) PURE;
  STDMETHOD(End)(THIS_) PURE;
};
#endif
