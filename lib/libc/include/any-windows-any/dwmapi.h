/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#include <winapifamily.h>

#ifndef _DWMAPI_H_
#define _DWMAPI_H_

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#ifndef DWMAPI
#define DWMAPI EXTERN_C DECLSPEC_IMPORT HRESULT WINAPI
#define DWMAPI_(type) EXTERN_C DECLSPEC_IMPORT type WINAPI
#endif

#ifdef __cplusplus
extern "C" {
#endif

#include <wtypes.h>
#include <uxtheme.h>

#include <pshpack1.h>

  typedef ULONGLONG DWM_FRAME_COUNT;
  typedef ULONGLONG QPC_TIME;

  typedef HANDLE HTHUMBNAIL;
  typedef HTHUMBNAIL *PHTHUMBNAIL;

  enum DWMWINDOWATTRIBUTE {
    DWMWA_NCRENDERING_ENABLED = 1,
    DWMWA_NCRENDERING_POLICY,
    DWMWA_TRANSITIONS_FORCEDISABLED,
    DWMWA_ALLOW_NCPAINT,
    DWMWA_CAPTION_BUTTON_BOUNDS,
    DWMWA_NONCLIENT_RTL_LAYOUT,
    DWMWA_FORCE_ICONIC_REPRESENTATION,
    DWMWA_FLIP3D_POLICY,
    DWMWA_EXTENDED_FRAME_BOUNDS,
    DWMWA_HAS_ICONIC_BITMAP,
    DWMWA_DISALLOW_PEEK,
    DWMWA_EXCLUDED_FROM_PEEK,
    DWMWA_CLOAK,
    DWMWA_CLOAKED,
    DWMWA_FREEZE_REPRESENTATION,
    DWMWA_PASSIVE_UPDATE_MODE,
    DWMWA_USE_HOSTBACKDROPBRUSH,
    DWMWA_USE_IMMERSIVE_DARK_MODE = 20,
    DWMWA_WINDOW_CORNER_PREFERENCE = 33,
    DWMWA_BORDER_COLOR,
    DWMWA_CAPTION_COLOR,
    DWMWA_TEXT_COLOR,
    DWMWA_VISIBLE_FRAME_BORDER_THICKNESS,
    DWMWA_SYSTEMBACKDROP_TYPE,
    DWMWA_LAST
  };

  typedef enum {
    DWMWCP_DEFAULT = 0,
    DWMWCP_DONOTROUND = 1,
    DWMWCP_ROUND = 2,
    DWMWCP_ROUNDSMALL = 3
  } DWM_WINDOW_CORNER_PREFERENCE;

#define DWMWA_COLOR_DEFAULT 0xFFFFFFFF
#define DWMWA_COLOR_NONE 0xFFFFFFFE

  enum DWM_SYSTEMBACKDROP_TYPE {
    DWMSBT_AUTO,
    DWMSBT_NONE,
    DWMSBT_MAINWINDOW,
    DWMSBT_TRANSIENTWINDOW,
    DWMSBT_TABBEDWINDOW
  };

  enum DWMFLIP3DWINDOWPOLICY {
    DWMFLIP3D_DEFAULT,
    DWMFLIP3D_EXCLUDEBELOW,
    DWMFLIP3D_EXCLUDEABOVE,
    DWMFLIP3D_LAST
  };

  enum DWMNCRENDERINGPOLICY {
    DWMNCRP_USEWINDOWSTYLE,
    DWMNCRP_DISABLED,
    DWMNCRP_ENABLED,
    DWMNCRP_LAST
  };

#if NTDDI_VERSION >= NTDDI_WIN8
  enum GESTURE_TYPE {
    GT_PEN_TAP = 0,
    GT_PEN_DOUBLETAP = 1,
    GT_PEN_RIGHTTAP = 2,
    GT_PEN_PRESSANDHOLD = 3,
    GT_PEN_PRESSANDHOLDABORT = 4,
    GT_TOUCH_TAP = 5,
    GT_TOUCH_DOUBLETAP = 6,
    GT_TOUCH_RIGHTTAP = 7,
    GT_TOUCH_PRESSANDHOLD = 8,
    GT_TOUCH_PRESSANDHOLDABORT = 9,
    GT_TOUCH_PRESSANDTAP = 10
  };

  enum DWM_SHOWCONTACT {
    DWMSC_DOWN = 0x1,
    DWMSC_UP = 0x2,
    DWMSC_DRAG = 0x4,
    DWMSC_HOLD = 0x8,
    DWMSC_PENBARREL = 0x10,
    DWMSC_NONE = 0x0,
    DWMSC_ALL = 0xffffffff
  };

  DEFINE_ENUM_FLAG_OPERATORS (DWM_SHOWCONTACT);
#endif

#if NTDDI_VERSION >= NTDDI_WIN10_RS4
  enum DWM_TAB_WINDOW_REQUIREMENTS {
    DWMTWR_NONE = 0x0000,
    DWMTWR_IMPLEMENTED_BY_SYSTEM = 0x0001,
    DWMTWR_WINDOW_RELATIONSHIP = 0x0002,
    DWMTWR_WINDOW_STYLES = 0x0004,
    DWMTWR_WINDOW_REGION = 0x0008,
    DWMTWR_WINDOW_DWM_ATTRIBUTES = 0x0010,
    DWMTWR_WINDOW_MARGINS = 0x0020,
    DWMTWR_TABBING_ENABLED = 0x0040,
    DWMTWR_USER_POLICY = 0x0080,
    DWMTWR_GROUP_POLICY = 0x0100,
    DWMTWR_APP_COMPAT = 0x0200
  };

  DEFINE_ENUM_FLAG_OPERATORS(DWM_TAB_WINDOW_REQUIREMENTS);
#endif

  typedef enum {
    DWM_SOURCE_FRAME_SAMPLING_POINT,
    DWM_SOURCE_FRAME_SAMPLING_COVERAGE,
    DWM_SOURCE_FRAME_SAMPLING_LAST
  } DWM_SOURCE_FRAME_SAMPLING;

  enum DWMTRANSITION_OWNEDWINDOW_TARGET {
    DWMTRANSITION_OWNEDWINDOW_NULL = -1,
    DWMTRANSITION_OWNEDWINDOW_REPOSITION = 0
  };

  typedef struct _DWM_BLURBEHIND {
    DWORD dwFlags;
    WINBOOL fEnable;
    HRGN hRgnBlur;
    WINBOOL fTransitionOnMaximized;
  } DWM_BLURBEHIND, *PDWM_BLURBEHIND;

  typedef struct _DWM_THUMBNAIL_PROPERTIES {
    DWORD dwFlags;
    RECT rcDestination;
    RECT rcSource;
    BYTE opacity;
    WINBOOL fVisible;
    WINBOOL fSourceClientAreaOnly;
  } DWM_THUMBNAIL_PROPERTIES, *PDWM_THUMBNAIL_PROPERTIES;

  typedef struct _UNSIGNED_RATIO {
    UINT32 uiNumerator;
    UINT32 uiDenominator;
  } UNSIGNED_RATIO;

  typedef struct _DWM_TIMING_INFO {
    UINT32 cbSize;
    UNSIGNED_RATIO rateRefresh;
    QPC_TIME qpcRefreshPeriod;
    UNSIGNED_RATIO rateCompose;
    QPC_TIME qpcVBlank;
    DWM_FRAME_COUNT cRefresh;
    UINT cDXRefresh;
    QPC_TIME qpcCompose;
    DWM_FRAME_COUNT cFrame;
    UINT cDXPresent;
    DWM_FRAME_COUNT cRefreshFrame;
    DWM_FRAME_COUNT cFrameSubmitted;
    UINT cDXPresentSubmitted;
    DWM_FRAME_COUNT cFrameConfirmed;
    UINT cDXPresentConfirmed;
    DWM_FRAME_COUNT cRefreshConfirmed;
    UINT cDXRefreshConfirmed;
    DWM_FRAME_COUNT cFramesLate;
    UINT cFramesOutstanding;
    DWM_FRAME_COUNT cFrameDisplayed;
    QPC_TIME qpcFrameDisplayed;
    DWM_FRAME_COUNT cRefreshFrameDisplayed;
    DWM_FRAME_COUNT cFrameComplete;
    QPC_TIME qpcFrameComplete;
    DWM_FRAME_COUNT cFramePending;
    QPC_TIME qpcFramePending;
    DWM_FRAME_COUNT cFramesDisplayed;
    DWM_FRAME_COUNT cFramesComplete;
    DWM_FRAME_COUNT cFramesPending;
    DWM_FRAME_COUNT cFramesAvailable;
    DWM_FRAME_COUNT cFramesDropped;
    DWM_FRAME_COUNT cFramesMissed;
    DWM_FRAME_COUNT cRefreshNextDisplayed;
    DWM_FRAME_COUNT cRefreshNextPresented;
    DWM_FRAME_COUNT cRefreshesDisplayed;
    DWM_FRAME_COUNT cRefreshesPresented;
    DWM_FRAME_COUNT cRefreshStarted;
    ULONGLONG cPixelsReceived;
    ULONGLONG cPixelsDrawn;
    DWM_FRAME_COUNT cBuffersEmpty;
  } DWM_TIMING_INFO;

  typedef struct _DWM_PRESENT_PARAMETERS {
    UINT32 cbSize;
    WINBOOL fQueue;
    DWM_FRAME_COUNT cRefreshStart;
    UINT cBuffer;
    WINBOOL fUseSourceRate;
    UNSIGNED_RATIO rateSource;
    UINT cRefreshesPerFrame;
    DWM_SOURCE_FRAME_SAMPLING eSampling;
  } DWM_PRESENT_PARAMETERS;

#ifndef _MIL_MATRIX3X2D_DEFINED
#define _MIL_MATRIX3X2D_DEFINED

  typedef struct _MilMatrix3x2D {
    DOUBLE S_11;
    DOUBLE S_12;
    DOUBLE S_21;
    DOUBLE S_22;
    DOUBLE DX;
    DOUBLE DY;
  } MilMatrix3x2D;
#endif

#ifndef MILCORE_MIL_MATRIX3X2D_COMPAT_TYPEDEF
#define MILCORE_MIL_MATRIX3X2D_COMPAT_TYPEDEF
  typedef MilMatrix3x2D MIL_MATRIX3X2D;
#endif

#include <poppack.h>

#define DWM_BB_ENABLE 0x1
#define DWM_BB_BLURREGION 0x2
#define DWM_BB_TRANSITIONONMAXIMIZED 0x4

#define DWM_CLOAKED_APP 0x1
#define DWM_CLOAKED_SHELL 0x2
#define DWM_CLOAKED_INHERITED 0x4

#define DWM_TNP_RECTDESTINATION 0x1
#define DWM_TNP_RECTSOURCE 0x2
#define DWM_TNP_OPACITY 0x4
#define DWM_TNP_VISIBLE 0x8
#define DWM_TNP_SOURCECLIENTAREAONLY 0x10

#define DWM_FRAME_DURATION_DEFAULT -1

#define c_DwmMaxQueuedBuffers 8
#define c_DwmMaxMonitors 16
#define c_DwmMaxAdapters 16

#define DWM_EC_DISABLECOMPOSITION 0
#define DWM_EC_ENABLECOMPOSITION 1

#if _WIN32_WINNT >= 0x0601
#define DWM_SIT_DISPLAYFRAME 0x1
#endif

  DWMAPI_(WINBOOL) DwmDefWindowProc (HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam, LRESULT *plResult);
  DWMAPI DwmEnableBlurBehindWindow (HWND hWnd, const DWM_BLURBEHIND *pBlurBehind);
  DWMAPI DwmEnableComposition (UINT uCompositionAction);
  DWMAPI DwmEnableMMCSS (WINBOOL fEnableMMCSS);
  DWMAPI DwmExtendFrameIntoClientArea (HWND hWnd, const MARGINS *pMarInset);
  DWMAPI DwmGetColorizationColor (DWORD *pcrColorization, WINBOOL *pfOpaqueBlend);
  DWMAPI DwmGetCompositionTimingInfo (HWND hwnd, DWM_TIMING_INFO *pTimingInfo);
  DWMAPI DwmGetWindowAttribute (HWND hwnd, DWORD dwAttribute, PVOID pvAttribute, DWORD cbAttribute);
  DWMAPI DwmIsCompositionEnabled (WINBOOL *pfEnabled);
  DWMAPI DwmModifyPreviousDxFrameDuration (HWND hwnd, INT cRefreshes, WINBOOL fRelative);
  DWMAPI DwmQueryThumbnailSourceSize (HTHUMBNAIL hThumbnail, PSIZE pSize);
  DWMAPI DwmRegisterThumbnail (HWND hwndDestination, HWND hwndSource, PHTHUMBNAIL phThumbnailId);
  DWMAPI DwmSetDxFrameDuration (HWND hwnd, INT cRefreshes);
  DWMAPI DwmSetPresentParameters (HWND hwnd, DWM_PRESENT_PARAMETERS *pPresentParams);
  DWMAPI DwmSetWindowAttribute (HWND hwnd, DWORD dwAttribute, LPCVOID pvAttribute, DWORD cbAttribute);
  DWMAPI DwmUnregisterThumbnail (HTHUMBNAIL hThumbnailId);
  DWMAPI DwmUpdateThumbnailProperties (HTHUMBNAIL hThumbnailId, const DWM_THUMBNAIL_PROPERTIES *ptnProperties);
  DWMAPI DwmAttachMilContent (HWND hwnd);
  DWMAPI DwmDetachMilContent (HWND hwnd);
  DWMAPI DwmFlush (void);
  DWMAPI DwmGetGraphicsStreamTransformHint (UINT uIndex, MilMatrix3x2D *pTransform);
  DWMAPI DwmGetGraphicsStreamClient (UINT uIndex, UUID *pClientUuid);
  DWMAPI DwmGetTransportAttributes (WINBOOL *pfIsRemoting, WINBOOL *pfIsConnected, DWORD *pDwGeneration);
  DWMAPI DwmTransitionOwnedWindow (HWND hwnd, enum DWMTRANSITION_OWNEDWINDOW_TARGET target);
#if _WIN32_WINNT >= 0x0601
  DWMAPI DwmSetIconicThumbnail (HWND hwnd, HBITMAP hbmp, DWORD dwSITFlags);
  DWMAPI DwmSetIconicLivePreviewBitmap (HWND hwnd, HBITMAP hbmp, POINT *pptClient, DWORD dwSITFlags);
  DWMAPI DwmInvalidateIconicBitmaps (HWND hwnd);
#endif
#if NTDDI_VERSION >= NTDDI_WIN8
  DWMAPI DwmRenderGesture (enum GESTURE_TYPE gt, UINT cContacts, const DWORD *pdwPointerID, const POINT *pPoints);
  DWMAPI DwmTetherContact (DWORD dwPointerID, WINBOOL fEnable, POINT ptTether);
  DWMAPI DwmShowContact (DWORD dwPointerID, enum DWM_SHOWCONTACT eShowContact);
#endif
#if NTDDI_VERSION >= NTDDI_WIN10_RS4
  DWMAPI DwmGetUnmetTabRequirements (HWND appWindow, enum DWM_TAB_WINDOW_REQUIREMENTS *value);
#endif

#ifdef __cplusplus
}
#endif
#endif
#endif
