/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MSOAV_H
#define _MSOAV_H

typedef struct _msoavinfo {
  int cbsize;
  struct {
    ULONG fPath:1;
    ULONG fReadOnlyRequest:1;
    ULONG fInstalled:1;
    ULONG fHttpDownload:1;
  };
  HWND hwnd;
  union {
    WCHAR *pwzFullPath;
    LPSTORAGE lpstg;
  } u;
  WCHAR *pwzHostName;
  WCHAR *pwzOrigURL;
} MSOAVINFO;

DEFINE_GUID(IID_IOfficeAntiVirus,0x56ffcc30,0xd398,0x11d0,0xb2,0xae,0x0,0xa0,0xc9,0x8,0xfa,0x49);
DEFINE_GUID(CATID_MSOfficeAntiVirus,0x56ffcc30,0xd398,0x11d0,0xb2,0xae,0x0,0xa0,0xc9,0x8,0xfa,0x49);

#undef INTERFACE
#define INTERFACE IOfficeAntiVirus
DECLARE_INTERFACE_(IOfficeAntiVirus,IUnknown) {
  BEGIN_INTERFACE
    STDMETHOD(QueryInterface)(THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef)(THIS) PURE;
    STDMETHOD_(ULONG,Release)(THIS) PURE;
    STDMETHOD_(HRESULT,Scan)(THIS_ MSOAVINFO *pmsoavinfo) PURE;
};

#ifndef AVVENDOR
MSOAPI_(WINBOOL) MsoFAnyAntiVirus(HMSOINST hmsoinst);
MSOAPI_(WINBOOL) MsoFDoAntiVirusScan(HMSOINST hmsoinst,MSOAVINFO *msoavinfo);
MSOAPI_(void) MsoFreeMsoavStuff(HMSOINST hmsoinst);
MSOAPI_(WINBOOL) MsoFDoSecurityLevelDlg(HMSOINST hmsoinst,DWORD msorid,int *pSecurityLevel,WINBOOL *pfTrustInstalled,HWND hwndParent,WINBOOL fShowVirusCheckers,WCHAR *wzHelpFile,DWORD dwHelpId);

#define msoedmEnable 1
#define msoedmDisable 2
#define msoedmDontOpen 3

MSOAPI_(int) MsoMsoedmDialog(HMSOINST hmsoinst,WINBOOL fAppIsActive,WINBOOL fHasVBMacros,WINBOOL fHasXLMMacros,void *pvDigSigStore,void *pvMacro,int nAppID,HWND hwnd,const WCHAR *pwtzPath,int iClient,int iSecurityLevel,int *pmsodsv,WCHAR *wzHelpFile,DWORD dwHelpId,HANDLE hFileDLL,WINBOOL fUserControl);

#define msoslUndefined 0
#define msoslNone 1
#define msoslMedium 2
#define msoslHigh 3

MSOAPI_(int) MsoMsoslGetSL(HMSOINST hmsoinst);
MSOAPI_(int) MsoMsoslSetSL(DWORD msorid,HMSOINST hmsoinst);

#define msodsvNoMacros 0
#define msodsvUnsigned 1

#define msodsvPassedTrusted 2
#define msodsvFailed 3
#define msodsvLowSecurityLevel 4
#define msodsvPassedTrustedCert 5
#endif

#endif
