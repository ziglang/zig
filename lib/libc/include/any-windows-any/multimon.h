/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef SM_CMONITORS

#define SM_XVIRTUALSCREEN 76
#define SM_YVIRTUALSCREEN 77
#define SM_CXVIRTUALSCREEN 78
#define SM_CYVIRTUALSCREEN 79
#define SM_CMONITORS 80
#define SM_SAMEDISPLAYFORMAT 81

#define MONITOR_DEFAULTTONULL 0x00000000
#define MONITOR_DEFAULTTOPRIMARY 0x00000001
#define MONITOR_DEFAULTTONEAREST 0x00000002

#define MONITORINFOF_PRIMARY 0x00000001

  typedef struct tagMONITORINFO {
    DWORD cbSize;
    RECT rcMonitor;
    RECT rcWork;
    DWORD dwFlags;
  } MONITORINFO,*LPMONITORINFO;

#ifndef CCHDEVICENAME
#define CCHDEVICENAME 32
#endif

#ifdef __cplusplus
  typedef struct tagMONITORINFOEXA : public tagMONITORINFO {
    CHAR szDevice[CCHDEVICENAME];
  } MONITORINFOEXA,*LPMONITORINFOEXA;

  typedef struct tagMONITORINFOEXW : public tagMONITORINFO {
    WCHAR szDevice[CCHDEVICENAME];
  } MONITORINFOEXW,*LPMONITORINFOEXW;
#else
  typedef struct tagMONITORINFOEXA {
    __C89_NAMELESS struct {
      DWORD cbSize;
      RECT rcMonitor;
      RECT rcWork;
      DWORD dwFlags;
    }; /* MONITORINFO */;
    CHAR szDevice[CCHDEVICENAME];
  } MONITORINFOEXA,*LPMONITORINFOEXA;

  typedef struct tagMONITORINFOEXW {
    __C89_NAMELESS struct {
      DWORD cbSize;
      RECT rcMonitor;
      RECT rcWork;
      DWORD dwFlags;
    }; /* MONITORINFO */;
    WCHAR szDevice[CCHDEVICENAME];
  } MONITORINFOEXW,*LPMONITORINFOEXW;
#endif
  __MINGW_TYPEDEF_AW(MONITORINFOEX)
  __MINGW_TYPEDEF_AW(LPMONITORINFOEX)

  typedef WINBOOL (CALLBACK *MONITORENUMPROC)(HMONITOR, HDC, LPRECT, LPARAM);

#ifndef DISPLAY_DEVICE_ATTACHED_TO_DESKTOP
  typedef struct _DISPLAY_DEVICEA {
    DWORD cb;
    CHAR DeviceName[32];
    CHAR DeviceString[128];
    DWORD StateFlags;
    CHAR DeviceID[128];
    CHAR DeviceKey[128];
  } DISPLAY_DEVICEA,*PDISPLAY_DEVICEA,*LPDISPLAY_DEVICEA;

  typedef struct _DISPLAY_DEVICEW {
    DWORD cb;
    WCHAR DeviceName[32];
    WCHAR DeviceString[128];
    DWORD StateFlags;
    WCHAR DeviceID[128];
    WCHAR DeviceKey[128];
  } DISPLAY_DEVICEW,*PDISPLAY_DEVICEW,*LPDISPLAY_DEVICEW;

  __MINGW_TYPEDEF_AW(DISPLAY_DEVICE)
  __MINGW_TYPEDEF_AW(PDISPLAY_DEVICE)
  __MINGW_TYPEDEF_AW(LPDISPLAY_DEVICE)

#define DISPLAY_DEVICE_ATTACHED_TO_DESKTOP 0x00000001
#define DISPLAY_DEVICE_MULTI_DRIVER 0x00000002
#define DISPLAY_DEVICE_PRIMARY_DEVICE 0x00000004
#define DISPLAY_DEVICE_MIRRORING_DRIVER 0x00000008
#define DISPLAY_DEVICE_VGA_COMPATIBLE 0x00000010
#endif
#endif

#undef GetMonitorInfo
#undef GetSystemMetrics
#undef MonitorFromWindow
#undef MonitorFromRect
#undef MonitorFromPoint
#undef EnumDisplayMonitors
#undef EnumDisplayDevices

#ifdef COMPILE_MULTIMON_STUBS

#ifndef MULTIMON_FNS_DEFINED
  int (WINAPI *g_pfnGetSystemMetrics)(int) = NULL;
  HMONITOR (WINAPI *g_pfnMonitorFromWindow)(HWND, DWORD) = NULL;
  HMONITOR (WINAPI *g_pfnMonitorFromRect)(LPCRECT, DWORD) = NULL;
  HMONITOR (WINAPI *g_pfnMonitorFromPoint)(POINT, DWORD) = NULL;
  WINBOOL (WINAPI *g_pfnGetMonitorInfo)(HMONITOR, LPMONITORINFO) = NULL;
  WINBOOL (WINAPI *g_pfnEnumDisplayMonitors)(HDC, LPCRECT, MONITORENUMPROC, LPARAM) = NULL;
  WINBOOL (WINAPI *g_pfnEnumDisplayDevices)(PVOID, DWORD, PDISPLAY_DEVICE, DWORD) = NULL;
  WINBOOL g_fMultiMonInitDone = FALSE;
  WINBOOL g_fMultimonPlatformNT = FALSE;
#endif

  WINBOOL IsPlatformNT() {
    OSVERSIONINFOA oi = { 0 };

    oi.dwOSVersionInfoSize = sizeof (oi);
    GetVersionExA ((OSVERSIONINFOA *) &oi);
    return (oi.dwPlatformId == VER_PLATFORM_WIN32_NT);
  }

  WINBOOL InitMultipleMonitorStubs(void) {
    HMODULE h;

    if (g_fMultiMonInitDone)
      return g_pfnGetMonitorInfo != NULL;

    g_fMultimonPlatformNT = IsPlatformNT ();
    h = GetModuleHandle (TEXT ("USER32"));

    if (h
        && (*((FARPROC *) &g_pfnGetSystemMetrics) = GetProcAddress (h, "GetSystemMetrics")) != NULL
	&& (*((FARPROC *) &g_pfnMonitorFromWindow) = GetProcAddress (h, "MonitorFromWindow")) != NULL
	&& (*((FARPROC *) &g_pfnMonitorFromRect) = GetProcAddress (h, "MonitorFromRect")) != NULL
	&& (*((FARPROC *) &g_pfnMonitorFromPoint) = GetProcAddress (h, "MonitorFromPoint")) != NULL
	&& (*((FARPROC *) &g_pfnEnumDisplayMonitors) = GetProcAddress (h, "EnumDisplayMonitors")) != NULL
#ifdef UNICODE
        && (*((FARPROC *) &g_pfnEnumDisplayDevices) = GetProcAddress (h, "EnumDisplayDevicesW")) != NULL
	&& (*((FARPROC *) &g_pfnGetMonitorInfo) = (g_fMultimonPlatformNT ? GetProcAddress (h, "GetMonitorInfoW") : GetProcAddress (h, "GetMonitorInfoA"))) != NULL
#else
        && (*((FARPROC *) &g_pfnGetMonitorInfo) = GetProcAddress (h, "GetMonitorInfoA")) != NULL
	&& (*((FARPROC *) &g_pfnEnumDisplayDevices) = GetProcAddress (h, "EnumDisplayDevicesA")) != NULL
#endif
    ) {
      g_fMultiMonInitDone = TRUE;
      return TRUE;
    }

    g_pfnGetSystemMetrics = NULL;
    g_pfnMonitorFromWindow = NULL;
    g_pfnMonitorFromRect = NULL;
    g_pfnMonitorFromPoint = NULL;
    g_pfnGetMonitorInfo = NULL;
    g_pfnEnumDisplayMonitors = NULL;
    g_pfnEnumDisplayDevices = NULL;
    g_fMultiMonInitDone = TRUE;
    return FALSE;
  }

  int WINAPI xGetSystemMetrics(int n) {
    if (InitMultipleMonitorStubs ())
      return g_pfnGetSystemMetrics (n);

    switch (n) {
    case SM_CMONITORS:
    case SM_SAMEDISPLAYFORMAT:
      return 1;
    case SM_XVIRTUALSCREEN:
    case SM_YVIRTUALSCREEN:
      return 0;
    case SM_CXVIRTUALSCREEN:
      return GetSystemMetrics (SM_CXSCREEN);
    case SM_CYVIRTUALSCREEN:
      return GetSystemMetrics (SM_CYSCREEN);
    default:
      break;
    }

    return GetSystemMetrics (n);
  }

#define xPRIMARY_MONITOR ((HMONITOR)0x12340042)

  HMONITOR WINAPI xMonitorFromPoint (POINT pt, DWORD flags) {
    if (InitMultipleMonitorStubs ())
      return g_pfnMonitorFromPoint (pt, flags);

    if ((flags & (MONITOR_DEFAULTTOPRIMARY | MONITOR_DEFAULTTONEAREST)) != 0
        || (pt.x >= 0 && pt.y >= 0 && pt.x < GetSystemMetrics (SM_CXSCREEN) && pt.y < GetSystemMetrics (SM_CYSCREEN)))
      return xPRIMARY_MONITOR;

    return NULL;
  }

  HMONITOR WINAPI xMonitorFromRect (LPCRECT pr, DWORD flags) {
    if (InitMultipleMonitorStubs ())
      return g_pfnMonitorFromRect (pr, flags);

    if ((flags & (MONITOR_DEFAULTTOPRIMARY | MONITOR_DEFAULTTONEAREST)) != 0
        || (pr->right > 0 && pr->bottom > 0 && pr->left < GetSystemMetrics (SM_CXSCREEN) && pr->top < GetSystemMetrics (SM_CYSCREEN)))
      return xPRIMARY_MONITOR;

    return NULL;
  }

  HMONITOR WINAPI xMonitorFromWindow (HWND hw, DWORD flags) {
    WINDOWPLACEMENT wp;

    if (InitMultipleMonitorStubs ())
      return g_pfnMonitorFromWindow (hw, flags);

    if ((flags & (MONITOR_DEFAULTTOPRIMARY | MONITOR_DEFAULTTONEAREST)) != 0)
      return xPRIMARY_MONITOR;

    if ((IsIconic (hw) ? GetWindowPlacement (hw, &wp) : GetWindowRect (hw, &wp.rcNormalPosition)) != 0)
      return xMonitorFromRect (&wp.rcNormalPosition, flags);

    return NULL;
  }

  WINBOOL WINAPI xGetMonitorInfo (HMONITOR hmon, LPMONITORINFO pmi) {
    RECT r;
    WINBOOL f;
    union { LPMONITORINFO mi; LPMONITORINFOEX ex; } c;

    c.mi = pmi;
    if (InitMultipleMonitorStubs ()) {
      f = g_pfnGetMonitorInfo (hmon, pmi);
#ifdef UNICODE
      if (f && !g_fMultimonPlatformNT && pmi->cbSize >= sizeof (MONITORINFOEX))
	MultiByteToWideChar (CP_ACP, 0, (LPSTR) c.ex->szDevice, -1, c.ex->szDevice, (sizeof (c.ex->szDevice) / 2));
#endif
      return f;
    }

    if ((hmon == xPRIMARY_MONITOR) && pmi &&(pmi->cbSize >= sizeof (MONITORINFO)) && SystemParametersInfoA (SPI_GETWORKAREA, 0,&r, 0)) {
      pmi->rcMonitor.left = 0;
      pmi->rcMonitor.top = 0;
      pmi->rcMonitor.right = GetSystemMetrics (SM_CXSCREEN);
      pmi->rcMonitor.bottom = GetSystemMetrics (SM_CYSCREEN);
      pmi->rcWork = r;
      pmi->dwFlags = MONITORINFOF_PRIMARY;
      if (pmi->cbSize >= sizeof (MONITORINFOEX)) {
#ifdef UNICODE
	MultiByteToWideChar (CP_ACP, 0, "DISPLAY", -1, c.ex->szDevice, (sizeof (c.ex->szDevice) / 2));
#else
	lstrcpyn (c.ex->szDevice, "DISPLAY", sizeof (c.ex->szDevice));
#endif
      }

      return TRUE;
    }

    return FALSE;
  }

  WINBOOL WINAPI xEnumDisplayMonitors (HDC hdcOptionalForPainting, LPCRECT lprcEnumMonitorsThatIntersect, MONITORENUMPROC lpfnEnumProc, LPARAM dwData) {
    RECT rcLimit, rcClip;
    POINT ptOrg;

    if (InitMultipleMonitorStubs ())
      return g_pfnEnumDisplayMonitors (hdcOptionalForPainting, lprcEnumMonitorsThatIntersect, lpfnEnumProc, dwData);

    if (!lpfnEnumProc)
      return FALSE;

    rcLimit.left = rcLimit.top = 0;
    rcLimit.right = GetSystemMetrics (SM_CXSCREEN);
    rcLimit.bottom = GetSystemMetrics (SM_CYSCREEN);

    if (hdcOptionalForPainting) {
      switch (GetClipBox (hdcOptionalForPainting,&rcClip)) {
      default:
	if (!GetDCOrgEx (hdcOptionalForPainting,&ptOrg))
	  return FALSE;

	OffsetRect (&rcLimit, -ptOrg.x, -ptOrg.y);

	if (IntersectRect (&rcLimit, &rcLimit, &rcClip)
	    && (!lprcEnumMonitorsThatIntersect || IntersectRect (&rcLimit, &rcLimit, lprcEnumMonitorsThatIntersect)))
	  break;

      case NULLREGION:
	return TRUE;
      case ERROR:
	return FALSE;
      }
    } else if (lprcEnumMonitorsThatIntersect && !IntersectRect (&rcLimit, &rcLimit, lprcEnumMonitorsThatIntersect))
      return TRUE;

    return lpfnEnumProc (xPRIMARY_MONITOR, hdcOptionalForPainting, &rcLimit, dwData);
  }

  WINBOOL WINAPI xEnumDisplayDevices (PVOID Unused, DWORD iDevNum, PDISPLAY_DEVICE lpDisplayDevice, DWORD flags) {
    if (InitMultipleMonitorStubs ())
      return g_pfnEnumDisplayDevices (Unused, iDevNum, lpDisplayDevice, flags);
    if (Unused || iDevNum || lpDisplayDevice == NULL || lpDisplayDevice->cb < sizeof (DISPLAY_DEVICE))
      return FALSE;
#ifdef UNICODE
    MultiByteToWideChar (CP_ACP, 0, "DISPLAY", -1, lpDisplayDevice->DeviceName, (sizeof (lpDisplayDevice->DeviceName) / 2));
    MultiByteToWideChar (CP_ACP, 0, "DISPLAY", -1, lpDisplayDevice->DeviceString, (sizeof (lpDisplayDevice->DeviceString) / 2));
#else
    lstrcpyn ((LPTSTR)lpDisplayDevice->DeviceName, "DISPLAY", sizeof (lpDisplayDevice->DeviceName));
    lstrcpyn ((LPTSTR)lpDisplayDevice->DeviceString, "DISPLAY", sizeof (lpDisplayDevice->DeviceString));
#endif
    lpDisplayDevice->StateFlags = DISPLAY_DEVICE_ATTACHED_TO_DESKTOP | DISPLAY_DEVICE_PRIMARY_DEVICE;

    return TRUE;
  }

#undef xPRIMARY_MONITOR
#undef COMPILE_MULTIMON_STUBS
#else
  extern int WINAPI xGetSystemMetrics (int);
  extern HMONITOR WINAPI xMonitorFromWindow (HWND, DWORD);
  extern HMONITOR WINAPI xMonitorFromRect (LPCRECT, DWORD);
  extern HMONITOR WINAPI xMonitorFromPoint (POINT, DWORD);
  extern WINBOOL WINAPI xGetMonitorInfo (HMONITOR, LPMONITORINFO);
  extern WINBOOL WINAPI xEnumDisplayMonitors (HDC, LPCRECT, MONITORENUMPROC, LPARAM);
  extern WINBOOL WINAPI xEnumDisplayDevices (PVOID, DWORD, PDISPLAY_DEVICE, DWORD);
#endif

#define GetSystemMetrics xGetSystemMetrics
#define MonitorFromWindow xMonitorFromWindow
#define MonitorFromRect xMonitorFromRect
#define MonitorFromPoint xMonitorFromPoint
#define GetMonitorInfo xGetMonitorInfo
#define EnumDisplayMonitors xEnumDisplayMonitors
#define EnumDisplayDevices xEnumDisplayDevices

#ifdef __cplusplus
}
#endif

#endif
