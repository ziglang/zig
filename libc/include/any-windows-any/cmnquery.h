/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __cmnquery_h
#define __cmnquery_h

DEFINE_GUID(IID_IQueryForm,0x8cfcee30,0x39bd,0x11d0,0xb8,0xd1,0x0,0xa0,0x24,0xab,0x2d,0xbb);
DEFINE_GUID(IID_IPersistQuery,0x1a3114b8,0xa62e,0x11d0,0xa6,0xc5,0x0,0xa0,0xc9,0x06,0xaf,0x45);
DEFINE_GUID(CLSID_CommonQuery,0x83bc5ec0,0x6f2a,0x11d0,0xa1,0xc4,0x0,0xaa,0x00,0xc1,0x6e,0x65);
DEFINE_GUID(IID_ICommonQuery,0xab50dec0,0x6f1d,0x11d0,0xa1,0xc4,0x0,0xaa,0x00,0xc1,0x6e,0x65);

#ifndef GUID_DEFS_ONLY
#define QUERYFORM_CHANGESFORMLIST 0x000000001
#define QUERYFORM_CHANGESOPTFORMLIST 0x000000002

#define CQFF_NOGLOBALPAGES 0x0000001
#define CQFF_ISOPTIONAL 0x0000002

typedef struct {
  DWORD cbStruct;
  DWORD dwFlags;
  CLSID clsid;
  HICON hIcon;
  LPCWSTR pszTitle;
} CQFORM,*LPCQFORM;

typedef HRESULT (CALLBACK *LPCQADDFORMSPROC)(LPARAM lParam,LPCQFORM pForm);

struct _cqpage;
typedef struct _cqpage CQPAGE,*LPCQPAGE;
typedef HRESULT (CALLBACK *LPCQADDPAGESPROC)(LPARAM lParam,REFCLSID clsidForm,LPCQPAGE pPage);
typedef HRESULT (CALLBACK *LPCQPAGEPROC)(LPCQPAGE pPage,HWND hwnd,UINT uMsg,WPARAM wParam,LPARAM lParam);

struct _cqpage {
  DWORD cbStruct;
  DWORD dwFlags;
  LPCQPAGEPROC pPageProc;
  HINSTANCE hInstance;
  INT idPageName;
  INT idPageTemplate;
  DLGPROC pDlgProc;
  LPARAM lParam;
};

#undef INTERFACE
#define INTERFACE IQueryForm
DECLARE_INTERFACE_(IQueryForm,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(Initialize)(THIS_ HKEY hkForm) PURE;
  STDMETHOD(AddForms)(THIS_ LPCQADDFORMSPROC pAddFormsProc,LPARAM lParam) PURE;
  STDMETHOD(AddPages)(THIS_ LPCQADDPAGESPROC pAddPagesProc,LPARAM lParam) PURE;
};

#define CQPM_INITIALIZE 0x00000001
#define CQPM_RELEASE 0x00000002
#define CQPM_ENABLE 0x00000003
#define CQPM_GETPARAMETERS 0x00000005
#define CQPM_CLEARFORM 0x00000006
#define CQPM_PERSIST 0x00000007
#define CQPM_HELP 0x00000008
#define CQPM_SETDEFAULTPARAMETERS 0x00000009

#define CQPM_HANDLERSPECIFIC 0x10000000

#undef INTERFACE
#define INTERFACE IPersistQuery
DECLARE_INTERFACE_(IPersistQuery,IPersist) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(GetClassID)(THIS_ CLSID *pClassID) PURE;
  STDMETHOD(WriteString)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,LPCWSTR pValue) PURE;
  STDMETHOD(ReadString)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,LPWSTR pBuffer,INT cchBuffer) PURE;
  STDMETHOD(WriteInt)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,INT value) PURE;
  STDMETHOD(ReadInt)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,LPINT pValue) PURE;
  STDMETHOD(WriteStruct)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,LPVOID pStruct,DWORD cbStruct) PURE;
  STDMETHOD(ReadStruct)(THIS_ LPCWSTR pSection,LPCWSTR pValueName,LPVOID pStruct,DWORD cbStruct) PURE;
  STDMETHOD(Clear)(THIS) PURE;
};

#define OQWF_OKCANCEL 0x00000001
#define OQWF_DEFAULTFORM 0x00000002
#define OQWF_SINGLESELECT 0x00000004
#define OQWF_LOADQUERY 0x00000008
#define OQWF_REMOVESCOPES 0x00000010
#define OQWF_REMOVEFORMS 0x00000020
#define OQWF_ISSUEONOPEN 0x00000040
#define OQWF_SHOWOPTIONAL 0x00000080
#define OQWF_SAVEQUERYONOK 0x00000200
#define OQWF_HIDEMENUS 0x00000400
#define OQWF_HIDESEARCHUI 0x00000800

#define OQWF_PARAMISPROPERTYBAG 0x80000000

typedef struct {
  DWORD cbStruct;
  DWORD dwFlags;
  CLSID clsidHandler;
  LPVOID pHandlerParameters;
  CLSID clsidDefaultForm;
  IPersistQuery *pPersistQuery;
  __C89_NAMELESS union {
    void *pFormParameters;
    IPropertyBag *ppbFormParameters;
  };
} OPENQUERYWINDOW,*LPOPENQUERYWINDOW;

#undef INTERFACE
#define INTERFACE ICommonQuery
DECLARE_INTERFACE_(ICommonQuery,IUnknown) {
  STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef)(THIS) PURE;
  STDMETHOD_(ULONG,Release)(THIS) PURE;
  STDMETHOD(OpenQueryWindow)(THIS_ HWND hwndParent,LPOPENQUERYWINDOW pQueryWnd,IDataObject **ppDataObject) PURE;
};
#endif
#endif
