/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _RATINGS_H_
#define _RATINGS_H_

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#include <winerror.h>
#include <shlwapi.h>

STDAPI RatingEnable(HWND hwndParent,LPCSTR pszUsername,WINBOOL fEnable);
STDAPI RatingEnableW(HWND hwndParent, LPCWSTR pszUsername, WINBOOL fEnable);
STDAPI RatingCheckUserAccess(LPCSTR pszUsername,LPCSTR pszURL,LPCSTR pszRatingInfo,LPBYTE pData,DWORD cbData,void **ppRatingDetails);
STDAPI RatingCheckUserAccessW(LPCWSTR pszUsername, LPCWSTR pszURL, LPCWSTR pszRatingInfo, LPBYTE pData, DWORD cbData, void **ppRatingDetails);
STDAPI RatingAccessDeniedDialog(HWND hDlg,LPCSTR pszUsername,LPCSTR pszContentDescription,void *pRatingDetails);
STDAPI RatingAccessDeniedDialog2(HWND hDlg,LPCSTR pszUsername,void *pRatingDetails);
STDAPI RatingAccessDeniedDialogW(HWND hDlg, LPCWSTR pszUsername, LPCWSTR pszContentDescription, void *pRatingDetails);
STDAPI RatingFreeDetails(void *pRatingDetails);
STDAPI RatingObtainCancel(HANDLE hRatingObtainQuery);
STDAPI RatingObtainQuery(LPCSTR pszTargetUrl,DWORD dwUserData,void (*fCallback)(DWORD dwUserData,HRESULT hr,LPCSTR pszRating,void *lpvRatingDetails),HANDLE *phRatingObtainQuery);
STDAPI RatingObtainQueryW(LPCWSTR pszTargetUrl, DWORD dwUserData, void (*fCallback) (DWORD dwUserData, HRESULT hr, LPCWSTR pszRating, void *lpvRatingDetails),HANDLE *phRatingObtainQuery);
STDAPI RatingSetupUI(HWND hDlg,LPCSTR pszUsername);
STDAPI RatingSetupUIW (HWND hDlg, LPCWSTR pszUsername);
#ifdef _INC_COMMCTRL
STDAPI RatingAddPropertyPage(PROPSHEETHEADER *ppsh);
#endif

STDAPI RatingAddToApprovedSites (HWND hDlg, DWORD cbPasswordBlob, BYTE *pbPasswordBlob, LPCWSTR lpszUrl, WINBOOL fAlwaysNever, WINBOOL fSitePage, WINBOOL fApprovedSitesEnforced);
STDAPI RatingClickedOnPRFInternal (HWND hWndOwner, HINSTANCE, LPSTR lpszFileName, int nShow);
STDAPI RatingClickedOnRATInternal (HWND hWndOwner, HINSTANCE, LPSTR lpszFileName, int nShow);

STDAPI RatingEnabledQuery();
STDAPI RatingInit();
STDAPI_(void) RatingTerm();

static inline WINBOOL IS_RATINGS_ENABLED() {
  TCHAR sz[200];
  DWORD typ, sz = sizeof (sz);
  return (SHGetValue(HKEY_LOCAL_MACHINE,TEXT("Software\\Microsoft\\Windows\\CurrentVersion\\Policies\\Ratings"),TEXT("Key"), &typ,&sz, &sz) == ERROR_SUCCESS);
}

#define S_RATING_ALLOW S_OK
#define S_RATING_DENY S_FALSE
#define S_RATING_FOUND 0x00000002
#define E_RATING_NOT_FOUND 0x80000001

#undef INTERFACE
#define INTERFACE IObtainRating
DECLARE_INTERFACE_(IObtainRating,IUnknown) {
#ifndef __cplusplus
  STDMETHOD(QueryInterface) (THIS_ REFIID riid,void **ppvObj) PURE;
  STDMETHOD_(ULONG,AddRef) (THIS) PURE;
  STDMETHOD_(ULONG,Release) (THIS) PURE;
#endif
  STDMETHOD(ObtainRating) (THIS_ LPCSTR pszTargetUrl,HANDLE hAbortEvent,IMalloc *pAllocator,LPSTR *ppRatingOut) PURE;
  STDMETHOD_(ULONG,GetSortOrder) (THIS) PURE;
};
#undef INTERFACE

#define RATING_ORDER_REMOTESITE 0x80000000
#define RATING_ORDER_LOCALLIST 0xC0000000

#endif
#endif
