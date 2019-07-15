/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_CPL
#define _INC_CPL

#include <_mingw_unicode.h>
#include <pshpack1.h>

#ifdef __cplusplus
extern "C" {
#endif

#define WM_CPL_LAUNCH (WM_USER+1000)
#define WM_CPL_LAUNCHED (WM_USER+1001)

#define CPL_DYNAMIC_RES 0
#define CPL_INIT 1
#define CPL_GETCOUNT 2
#define CPL_INQUIRE 3
#define CPL_SELECT 4
#define CPL_DBLCLK 5
#define CPL_STOP 6
#define CPL_EXIT 7
#define CPL_NEWINQUIRE 8
#define CPL_STARTWPARMSA 9
#define CPL_STARTWPARMSW 10

  typedef LONG (WINAPI *APPLET_PROC)(HWND hwndCpl,UINT msg,LPARAM lParam1,LPARAM lParam2);

  typedef struct tagCPLINFO {
    int idIcon;
    int idName;
    int idInfo;
    LONG_PTR lData;
  } CPLINFO,*LPCPLINFO;

  typedef struct tagNEWCPLINFOA {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwHelpContext;
    LONG_PTR lData;
    HICON hIcon;
    CHAR szName[32];
    CHAR szInfo[64];
    CHAR szHelpFile[128];
  } NEWCPLINFOA,*LPNEWCPLINFOA;

  typedef struct tagNEWCPLINFOW {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwHelpContext;
    LONG_PTR lData;
    HICON hIcon;
    WCHAR szName[32];
    WCHAR szInfo[64];
    WCHAR szHelpFile[128];
  } NEWCPLINFOW,*LPNEWCPLINFOW;

  __MINGW_TYPEDEF_AW(NEWCPLINFO)
  __MINGW_TYPEDEF_AW(LPNEWCPLINFO)

#define CPL_STARTWPARMS __MINGW_NAME_AW(CPL_STARTWPARMS)

#define CPL_SETUP 200

#ifdef __cplusplus
}
#endif

#include <poppack.h>
#endif
