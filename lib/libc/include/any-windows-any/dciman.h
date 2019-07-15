/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_DCIMAN
#define _INC_DCIMAN

#ifdef __cplusplus
#define __inline inline
extern "C" {
#endif

#include "dciddi.h"

  DECLARE_HANDLE(HWINWATCH);

  extern HDC WINAPI DCIOpenProvider(void);
  extern void WINAPI DCICloseProvider(HDC hdc);

  extern int WINAPI DCICreatePrimary(HDC hdc,LPDCISURFACEINFO *lplpSurface);
  extern int WINAPI DCICreateOffscreen(HDC hdc,DWORD dwCompression,DWORD dwRedMask,DWORD dwGreenMask,DWORD dwBlueMask,DWORD dwWidth,DWORD dwHeight,DWORD dwDCICaps,DWORD dwBitCount,LPDCIOFFSCREEN *lplpSurface);
  extern int WINAPI DCICreateOverlay(HDC hdc,LPVOID lpOffscreenSurf,LPDCIOVERLAY *lplpSurface);
  extern int WINAPI DCIEnum(HDC hdc,LPRECT lprDst,LPRECT lprSrc,LPVOID lpFnCallback,LPVOID lpContext);
  extern DCIRVAL WINAPI DCISetSrcDestClip(LPDCIOFFSCREEN pdci,LPRECT srcrc,LPRECT destrc,LPRGNDATA prd);

  extern HWINWATCH WINAPI WinWatchOpen(HWND hwnd);
  extern void WINAPI WinWatchClose(HWINWATCH hWW);
  extern UINT WINAPI WinWatchGetClipList(HWINWATCH hWW,LPRECT prc,UINT size,LPRGNDATA prd);
  extern WINBOOL WINAPI WinWatchDidStatusChange(HWINWATCH hWW);
  extern DWORD WINAPI GetWindowRegionData(HWND hwnd,DWORD size,LPRGNDATA prd);
  extern DWORD WINAPI GetDCRegionData(HDC hdc,DWORD size,LPRGNDATA prd);

#define WINWATCHNOTIFY_START 0
#define WINWATCHNOTIFY_STOP 1
#define WINWATCHNOTIFY_DESTROY 2
#define WINWATCHNOTIFY_CHANGING 3
#define WINWATCHNOTIFY_CHANGED 4
  typedef void (CALLBACK *WINWATCHNOTIFYPROC)(HWINWATCH hww,HWND hwnd,DWORD code,LPARAM lParam);

  extern WINBOOL WINAPI WinWatchNotify(HWINWATCH hWW,WINWATCHNOTIFYPROC NotifyCallback,LPARAM NotifyParam);

  extern void WINAPI DCIEndAccess(LPDCISURFACEINFO pdci);
  extern DCIRVAL WINAPI DCIBeginAccess(LPDCISURFACEINFO pdci,int x,int y,int dx,int dy);
  extern void WINAPI DCIDestroy(LPDCISURFACEINFO pdci);
  extern DCIRVAL WINAPI DCIDraw(LPDCIOFFSCREEN pdci);
  extern DCIRVAL WINAPI DCISetClipList(LPDCIOFFSCREEN pdci,LPRGNDATA prd);
  extern DCIRVAL WINAPI DCISetDestination(LPDCIOFFSCREEN pdci,LPRECT dst,LPRECT src);

#ifdef __cplusplus
}
#endif
#endif
