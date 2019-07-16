/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#include <winapifamily.h>

#include <rpc.h>
#include <rpcndr.h>

#ifndef _OBJBASE_H_
#define _OBJBASE_H_

#include <pshpack8.h>
#include <combaseapi.h>

typedef enum tagCOINIT {
  COINIT_APARTMENTTHREADED = 0x2,
  COINIT_MULTITHREADED = COINITBASE_MULTITHREADED,
  COINIT_DISABLE_OLE1DDE = 0x4,
  COINIT_SPEED_OVER_MEMORY = 0x8
} COINIT;

#define MARSHALINTERFACE_MIN 500
#define CWCSTORAGENAME 32

#define STGM_DIRECT __MSABI_LONG(0x00000000)
#define STGM_TRANSACTED __MSABI_LONG(0x00010000)
#define STGM_SIMPLE __MSABI_LONG(0x08000000)

#define STGM_READ __MSABI_LONG(0x00000000)
#define STGM_WRITE __MSABI_LONG(0x00000001)
#define STGM_READWRITE __MSABI_LONG(0x00000002)

#define STGM_SHARE_DENY_NONE __MSABI_LONG(0x00000040)
#define STGM_SHARE_DENY_READ __MSABI_LONG(0x00000030)
#define STGM_SHARE_DENY_WRITE __MSABI_LONG(0x00000020)
#define STGM_SHARE_EXCLUSIVE __MSABI_LONG(0x00000010)

#define STGM_PRIORITY __MSABI_LONG(0x00040000)
#define STGM_DELETEONRELEASE __MSABI_LONG(0x04000000)
#define STGM_NOSCRATCH __MSABI_LONG(0x00100000)
#define STGM_CREATE __MSABI_LONG(0x00001000)
#define STGM_CONVERT __MSABI_LONG(0x00020000)
#define STGM_FAILIFTHERE __MSABI_LONG(0x00000000)
#define STGM_NOSNAPSHOT __MSABI_LONG(0x00200000)
#define STGM_DIRECT_SWMR __MSABI_LONG(0x00400000)

#define ASYNC_MODE_COMPATIBILITY __MSABI_LONG(0x00000001)
#define ASYNC_MODE_DEFAULT __MSABI_LONG(0x00000000)

#define STGTY_REPEAT __MSABI_LONG(0x00000100)
#define STG_TOEND __MSABI_LONG(0xffffffff)

#define STG_LAYOUT_SEQUENTIAL __MSABI_LONG(0x00000000)
#define STG_LAYOUT_INTERLEAVED __MSABI_LONG(0x00000001)

typedef DWORD STGFMT;

#define STGFMT_STORAGE 0
#define STGFMT_NATIVE 1
#define STGFMT_FILE 3
#define STGFMT_ANY 4
#define STGFMT_DOCFILE 5
#define STGFMT_DOCUMENT 0

#include <objidl.h>

#ifdef _OLE32_
#ifdef _OLE32PRIV_
WINBOOL _fastcall wIsEqualGUID (REFGUID rguid1, REFGUID rguid2);

#define IsEqualGUID(rguid1, rguid2) wIsEqualGUID (rguid1, rguid2)
#else
#define __INLINE_ISEQUAL_GUID
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
WINOLEAPI_(DWORD) CoBuildVersion (VOID);
WINOLEAPI CoInitialize (LPVOID pvReserved);
WINOLEAPI CoRegisterMallocSpy (LPMALLOCSPY pMallocSpy);
WINOLEAPI CoRevokeMallocSpy (void);
WINOLEAPI CoCreateStandardMalloc (DWORD memctx, IMalloc **ppMalloc);
WINOLEAPI CoRegisterInitializeSpy (LPINITIALIZESPY pSpy, ULARGE_INTEGER *puliCookie);
WINOLEAPI CoRevokeInitializeSpy (ULARGE_INTEGER uliCookie);

typedef enum tagCOMSD {
  SD_LAUNCHPERMISSIONS = 0,
  SD_ACCESSPERMISSIONS = 1,
  SD_LAUNCHRESTRICTIONS = 2,
  SD_ACCESSRESTRICTIONS = 3
} COMSD;

WINOLEAPI CoGetSystemSecurityPermissions (COMSD comSDType, PSECURITY_DESCRIPTOR *ppSD);
WINOLEAPI_(HINSTANCE) CoLoadLibrary (LPOLESTR lpszLibName, WINBOOL bAutoFree);
WINOLEAPI_(void) CoFreeLibrary (HINSTANCE hInst);
WINOLEAPI_(void) CoFreeAllLibraries (void);
WINOLEAPI CoGetInstanceFromFile (COSERVERINFO *pServerInfo, CLSID *pClsid, IUnknown *punkOuter, DWORD dwClsCtx, DWORD grfMode, OLECHAR *pwszName, DWORD dwCount, MULTI_QI *pResults);
WINOLEAPI CoGetInstanceFromIStorage (COSERVERINFO *pServerInfo, CLSID *pClsid, IUnknown *punkOuter, DWORD dwClsCtx, struct IStorage *pstg, DWORD dwCount, MULTI_QI *pResults);
WINOLEAPI CoAllowSetForegroundWindow (IUnknown *pUnk, LPVOID lpvReserved);
WINOLEAPI DcomChannelSetHResult (LPVOID pvReserved, ULONG *pulReserved, HRESULT appsHR);
WINOLEAPI_(WINBOOL) CoIsOle1Class (REFCLSID rclsid);
WINOLEAPI CLSIDFromProgIDEx (LPCOLESTR lpszProgID, LPCLSID lpclsid);
WINOLEAPI_(WINBOOL) CoFileTimeToDosDateTime (FILETIME *lpFileTime, LPWORD lpDosDate, LPWORD lpDosTime);
WINOLEAPI_(WINBOOL) CoDosDateTimeToFileTime (WORD nDosDate, WORD nDosTime, FILETIME *lpFileTime);
WINOLEAPI CoFileTimeNow (FILETIME *lpFileTime);
WINOLEAPI CoRegisterMessageFilter (LPMESSAGEFILTER lpMessageFilter, LPMESSAGEFILTER *lplpMessageFilter);
WINOLEAPI CoRegisterChannelHook (REFGUID ExtensionUuid, IChannelHook *pChannelHook);
WINOLEAPI CoTreatAsClass (REFCLSID clsidOld, REFCLSID clsidNew);
WINOLEAPI CreateDataAdviseHolder (LPDATAADVISEHOLDER *ppDAHolder);
WINOLEAPI CreateDataCache (LPUNKNOWN pUnkOuter, REFCLSID rclsid, REFIID iid, LPVOID *ppv);
WINOLEAPI StgOpenLayoutDocfile (OLECHAR const *pwcsDfName, DWORD grfMode, DWORD reserved, IStorage **ppstgOpen);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
WINOLEAPI StgCreateDocfile (const WCHAR *pwcsName, DWORD grfMode, DWORD reserved, IStorage **ppstgOpen);
WINOLEAPI StgCreateDocfileOnILockBytes (ILockBytes *plkbyt, DWORD grfMode, DWORD reserved, IStorage **ppstgOpen);
WINOLEAPI StgOpenStorage (const WCHAR *pwcsName, IStorage *pstgPriority, DWORD grfMode, SNB snbExclude, DWORD reserved, IStorage **ppstgOpen);
WINOLEAPI StgOpenStorageOnILockBytes (ILockBytes *plkbyt, IStorage *pstgPriority, DWORD grfMode, SNB snbExclude, DWORD reserved, IStorage **ppstgOpen);
WINOLEAPI StgIsStorageFile (const WCHAR *pwcsName);
WINOLEAPI StgIsStorageILockBytes (ILockBytes *plkbyt);
WINOLEAPI StgSetTimes (const WCHAR *lpszName, const FILETIME *pctime, const FILETIME *patime, const FILETIME *pmtime);
WINOLEAPI StgOpenAsyncDocfileOnIFillLockBytes (IFillLockBytes *pflb, DWORD grfMode, DWORD asyncFlags, IStorage **ppstgOpen);
WINOLEAPI StgGetIFillLockBytesOnILockBytes (ILockBytes *pilb, IFillLockBytes **ppflb);
WINOLEAPI StgGetIFillLockBytesOnFile (OLECHAR const *pwcsName, IFillLockBytes **ppflb);
#endif

#define STGOPTIONS_VERSION 2

typedef struct tagSTGOPTIONS {
  USHORT usVersion;
  USHORT reserved;
  ULONG ulSectorSize;
#if STGOPTIONS_VERSION >= 2
  const WCHAR *pwcsTemplateFile;
#endif
} STGOPTIONS;

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
WINOLEAPI StgCreateStorageEx (const WCHAR *pwcsName, DWORD grfMode, DWORD stgfmt, DWORD grfAttrs, STGOPTIONS *pStgOptions, PSECURITY_DESCRIPTOR pSecurityDescriptor, REFIID riid, void **ppObjectOpen);
WINOLEAPI StgOpenStorageEx (const WCHAR *pwcsName, DWORD grfMode, DWORD stgfmt, DWORD grfAttrs, STGOPTIONS *pStgOptions, PSECURITY_DESCRIPTOR pSecurityDescriptor, REFIID riid, void **ppObjectOpen);
WINOLEAPI BindMoniker (LPMONIKER pmk, DWORD grfOpt, REFIID iidResult, LPVOID *ppvResult);
WINOLEAPI CoGetObject (LPCWSTR pszName, BIND_OPTS *pBindOptions, REFIID riid, void **ppv);
WINOLEAPI MkParseDisplayName (LPBC pbc, LPCOLESTR szUserName, ULONG *pchEaten, LPMONIKER *ppmk);
WINOLEAPI MonikerRelativePathTo (LPMONIKER pmkSrc, LPMONIKER pmkDest, LPMONIKER *ppmkRelPath, WINBOOL dwReserved);
WINOLEAPI MonikerCommonPrefixWith (LPMONIKER pmkThis, LPMONIKER pmkOther, LPMONIKER *ppmkCommon);
WINOLEAPI CreateBindCtx (DWORD reserved, LPBC *ppbc);
WINOLEAPI CreateGenericComposite (LPMONIKER pmkFirst, LPMONIKER pmkRest, LPMONIKER *ppmkComposite);
WINOLEAPI GetClassFile (LPCOLESTR szFilename, CLSID *pclsid);
WINOLEAPI CreateClassMoniker (REFCLSID rclsid, LPMONIKER *ppmk);
WINOLEAPI CreateFileMoniker (LPCOLESTR lpszPathName, LPMONIKER *ppmk);
WINOLEAPI CreateItemMoniker (LPCOLESTR lpszDelim, LPCOLESTR lpszItem, LPMONIKER *ppmk);
WINOLEAPI CreateAntiMoniker (LPMONIKER *ppmk);
WINOLEAPI CreatePointerMoniker (LPUNKNOWN punk, LPMONIKER *ppmk);
WINOLEAPI CreateObjrefMoniker (LPUNKNOWN punk, LPMONIKER *ppmk);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
WINOLEAPI CoInstall (IBindCtx *pbc, DWORD dwFlags, uCLSSPEC *pClassSpec, QUERYCONTEXT *pQuery, LPWSTR pszCodeBase);
WINOLEAPI GetRunningObjectTable (DWORD reserved, LPRUNNINGOBJECTTABLE *pprot);
#endif

#include <urlmon.h>
#include <propidl.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
WINOLEAPI CreateStdProgressIndicator (HWND hwndParent, LPCOLESTR pszTitle, IBindStatusCallback *pIbscCaller, IBindStatusCallback **ppIbsc);
#endif

#ifndef RC_INVOKED
#include <poppack.h>
#endif
#endif
