/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _MAPIWZ_H
#define _MAPIWZ_H

#include <mapidefs.h>

#define WIZ_QUERYNUMPAGES (WM_USER +10)
#define WIZ_NEXT (WM_USER +11)
#define WIZ_PREV (WM_USER +12)

#define MAPI_PW_FIRST_PROFILE 0x00000001
#define MAPI_PW_LAUNCHED_BY_CONFIG 0x00000002
#define MAPI_PW_ADD_SERVICE_ONLY 0x00000004
#define MAPI_PW_PROVIDER_UI_ONLY 0x00000008
#define MAPI_PW_HIDE_SERVICES_LIST 0x00000010

#define PR_WIZARD_NO_PST_PAGE PROP_TAG(PT_BOOLEAN,0x6700)
#define PR_WIZARD_NO_PAB_PAGE PROP_TAG(PT_BOOLEAN,0x6701)

typedef HRESULT (WINAPI LAUNCHWIZARDENTRY)(HWND hParentWnd,ULONG ulFlags,LPCTSTR *lppszServiceNameToAdd,ULONG cbBufferMax,LPTSTR lpszNewProfileName);
typedef LAUNCHWIZARDENTRY *LPLAUNCHWIZARDENTRY;
typedef WINBOOL (WINAPI SERVICEWIZARDDLGPROC)(HWND hDlg,UINT wMsgID,WPARAM wParam,LPARAM lParam);
typedef SERVICEWIZARDDLGPROC *LPSERVICEWIZARDDLGPROC;
typedef ULONG (WINAPI WIZARDENTRY)(HINSTANCE hProviderDLLInstance,LPTSTR *lppcsResourceName,DLGPROC *lppDlgProc,LPMAPIPROP lpMapiProp,LPVOID lpMapiSupportObject);
typedef WIZARDENTRY *LPWIZARDENTRY;

#define LAUNCHWIZARDENTRYNAME "LAUNCHWIZARD"
#endif
