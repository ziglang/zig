/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ADSPROP_H_
#define _ADSPROP_H_

#include <iads.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WM_ADSPROP_NOTIFY_PAGEINIT (WM_USER + 1101)
#define WM_ADSPROP_NOTIFY_PAGEHWND (WM_USER + 1102)
#define WM_ADSPROP_NOTIFY_CHANGE (WM_USER + 1103)
#define WM_ADSPROP_NOTIFY_APPLY (WM_USER + 1104)
#define WM_ADSPROP_NOTIFY_SETFOCUS (WM_USER + 1105)
#define WM_ADSPROP_NOTIFY_FOREGROUND (WM_USER + 1106)
#define WM_ADSPROP_NOTIFY_EXIT (WM_USER + 1107)
#define WM_ADSPROP_NOTIFY_ERROR (WM_USER + 1110)

  typedef struct _ADSPROPINITPARAMS {
    DWORD dwSize;
    DWORD dwFlags;
    HRESULT hr;
    IDirectoryObject *pDsObj;
    LPWSTR pwzCN;
    PADS_ATTR_INFO pWritableAttrs;
  } ADSPROPINITPARAMS,*PADSPROPINITPARAMS;

  typedef struct _ADSPROPERROR {
    HWND hwndPage;
    PWSTR pszPageTitle;
    PWSTR pszObjPath;
    PWSTR pszObjClass;
    HRESULT hr;
    PWSTR pszError;
  } ADSPROPERROR,*PADSPROPERROR;

  STDAPI ADsPropCreateNotifyObj(LPDATAOBJECT pAppThdDataObj,PWSTR pwzADsObjName,HWND *phNotifyObj);
  STDAPI_(WINBOOL) ADsPropGetInitInfo(HWND hNotifyObj,PADSPROPINITPARAMS pInitParams);
  STDAPI_(WINBOOL) ADsPropSetHwndWithTitle(HWND hNotifyObj,HWND hPage,PTSTR ptzTitle);
  STDAPI_(WINBOOL) ADsPropSetHwnd(HWND hNotifyObj,HWND hPage);
  STDAPI_(WINBOOL) ADsPropCheckIfWritable(const PWSTR pwzAttr,const PADS_ATTR_INFO pWritableAttrs);
  STDAPI_(WINBOOL) ADsPropSendErrorMessage(HWND hNotifyObj,PADSPROPERROR pError);
  STDAPI_(WINBOOL) ADsPropShowErrorDialog(HWND hNotifyObj,HWND hPage);

#ifdef __cplusplus
}
#endif
#endif
