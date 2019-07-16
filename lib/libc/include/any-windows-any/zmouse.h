/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <_mingw_unicode.h>
#include <psdk_inc/_push_BOOL.h>

#define MSH_MOUSEWHEEL __MINGW_STRING_AW("MSWHEEL_ROLLMSG")

#define WHEEL_DELTA 120

#ifndef WM_MOUSEWHEEL
#define WM_MOUSEWHEEL (WM_MOUSELAST+1)
#endif

#define MOUSEZ_CLASSNAME __MINGW_STRING_AW("MouseZ")
#define MOUSEZ_TITLE __MINGW_STRING_AW("Magellan MSWHEEL")

#define MSH_WHEELMODULE_CLASS (MOUSEZ_CLASSNAME)
#define MSH_WHEELMODULE_TITLE (MOUSEZ_TITLE)

#define MSH_WHEELSUPPORT __MINGW_STRING_AW("MSH_WHEELSUPPORT_MSG")
#define MSH_SCROLL_LINES __MINGW_STRING_AW("MSH_SCROLL_LINES_MSG")

#ifndef WHEEL_PAGESCROLL
#define WHEEL_PAGESCROLL (UINT_MAX)
#endif

#ifndef SPI_SETWHEELSCROLLLINES
#define SPI_SETWHEELSCROLLLINES 105
#endif

#ifndef __CRT__NO_INLINE
__CRT_INLINE HWND HwndMSWheel (PUINT puiMsh_MsgMouseWheel, PUINT puiMsh_Msg3DSupport, PUINT puiMsh_MsgScrollLines, PBOOL pf3DSupport, PINT piScrollLines) {
  HWND hw = FindWindow (MSH_WHEELMODULE_CLASS, MSH_WHEELMODULE_TITLE);

  *puiMsh_MsgMouseWheel = RegisterWindowMessage (MSH_MOUSEWHEEL);
  *puiMsh_Msg3DSupport = RegisterWindowMessage (MSH_WHEELSUPPORT);
  *puiMsh_MsgScrollLines = RegisterWindowMessage (MSH_SCROLL_LINES);
  *pf3DSupport = (*puiMsh_Msg3DSupport ? (WINBOOL) SendMessage (hw, *puiMsh_Msg3DSupport, 0, 0) : FALSE);
  *piScrollLines = (*puiMsh_MsgScrollLines ? (int)SendMessage (hw, *puiMsh_MsgScrollLines, 0, 0) : 3);
  return hw;
}
#endif

#include <psdk_inc/_pop_BOOL.h>
