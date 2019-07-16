/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_SCRNSAVE
#define _INC_SCRNSAVE

#include <pshpack1.h>

#ifdef __cplusplus
extern "C" {
#endif

#define IDS_DESCRIPTION 1

#define ID_APP 100
#define DLG_SCRNSAVECONFIGURE 2003

#define idsIsPassword 1000
#define idsIniFile 1001
#define idsScreenSaver 1002
#define idsPassword 1003
#define idsDifferentPW 1004
#define idsChangePW 1005
#define idsBadOldPW 1006
#define idsAppName 1007
#define idsNoHelpMemory 1008
#define idsHelpFile 1009
#define idsDefKeyword 1010

#if defined(UNICODE)
  LRESULT WINAPI ScreenSaverProcW(HWND hWnd,UINT message,WPARAM wParam,LPARAM lParam);
#define ScreenSaverProc ScreenSaverProcW
#else
  LRESULT WINAPI ScreenSaverProc(HWND hWnd,UINT message,WPARAM wParam,LPARAM lParam);
#endif

  LRESULT WINAPI DefScreenSaverProc(HWND hWnd,UINT msg,WPARAM wParam,LPARAM lParam);
  WINBOOL WINAPI ScreenSaverConfigureDialog(HWND hDlg,UINT message,WPARAM wParam,LPARAM lParam);
  WINBOOL WINAPI RegisterDialogClasses(HANDLE hInst);

#define WS_GT (WS_GROUP | WS_TABSTOP)

#define MAXFILELEN 13
#define TITLEBARNAMELEN 40
#define APPNAMEBUFFERLEN 40
#define BUFFLEN 255

  extern HINSTANCE hMainInstance;
  extern HWND hMainWindow;
  extern WINBOOL fChildPreview;
  extern TCHAR szName[TITLEBARNAMELEN];
  extern TCHAR szAppName[APPNAMEBUFFERLEN];
  extern TCHAR szIniFile[MAXFILELEN];
  extern TCHAR szScreenSaver[22];
  extern TCHAR szHelpFile[MAXFILELEN];
  extern TCHAR szNoHelpMemory[BUFFLEN];
  extern UINT MyHelpMessage;

#define SCRM_VERIFYPW WM_APP

  void WINAPI ScreenSaverChangePassword(HWND hParent);

#ifdef __cplusplus
}
#endif

#include <poppack.h>
#endif
