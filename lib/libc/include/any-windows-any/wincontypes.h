/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _WINCONTYPES_
#define _WINCONTYPES_

#include <minwindef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

typedef struct _COORD {
  SHORT X;
  SHORT Y;
} COORD, *PCOORD;

typedef struct _SMALL_RECT {
  SHORT Left;
  SHORT Top;
  SHORT Right;
  SHORT Bottom;
} SMALL_RECT, *PSMALL_RECT;

typedef struct _KEY_EVENT_RECORD {
  WINBOOL bKeyDown;
  WORD wRepeatCount;
  WORD wVirtualKeyCode;
  WORD wVirtualScanCode;
  union {
    WCHAR UnicodeChar;
    CHAR AsciiChar;
  } uChar;
  DWORD dwControlKeyState;
} KEY_EVENT_RECORD, *PKEY_EVENT_RECORD;

#define RIGHT_ALT_PRESSED 0x0001
#define LEFT_ALT_PRESSED 0x0002
#define RIGHT_CTRL_PRESSED 0x0004
#define LEFT_CTRL_PRESSED 0x0008
#define SHIFT_PRESSED 0x0010
#define NUMLOCK_ON 0x0020
#define SCROLLLOCK_ON 0x0040
#define CAPSLOCK_ON 0x0080
#define ENHANCED_KEY 0x0100
#define NLS_DBCSCHAR 0x00010000
#define NLS_ALPHANUMERIC 0x00000000
#define NLS_KATAKANA 0x00020000
#define NLS_HIRAGANA 0x00040000
#define NLS_ROMAN 0x00400000
#define NLS_IME_CONVERSION 0x00800000
#define ALTNUMPAD_BIT 0x04000000
#define NLS_IME_DISABLE 0x20000000

typedef struct _MOUSE_EVENT_RECORD {
  COORD dwMousePosition;
  DWORD dwButtonState;
  DWORD dwControlKeyState;
  DWORD dwEventFlags;
} MOUSE_EVENT_RECORD, *PMOUSE_EVENT_RECORD;

#define FROM_LEFT_1ST_BUTTON_PRESSED 0x0001
#define RIGHTMOST_BUTTON_PRESSED 0x0002
#define FROM_LEFT_2ND_BUTTON_PRESSED 0x0004
#define FROM_LEFT_3RD_BUTTON_PRESSED 0x0008
#define FROM_LEFT_4TH_BUTTON_PRESSED 0x0010

#define MOUSE_MOVED 0x0001
#define DOUBLE_CLICK 0x0002
#define MOUSE_WHEELED 0x0004
#if (_WIN32_WINNT >= 0x0600)
#define MOUSE_HWHEELED 0x0008
#endif /* _WIN32_WINNT >= 0x0600 */

typedef struct _WINDOW_BUFFER_SIZE_RECORD {
  COORD dwSize;
} WINDOW_BUFFER_SIZE_RECORD, *PWINDOW_BUFFER_SIZE_RECORD;

typedef struct _MENU_EVENT_RECORD {
  UINT dwCommandId;
} MENU_EVENT_RECORD, *PMENU_EVENT_RECORD;

typedef struct _FOCUS_EVENT_RECORD {
  WINBOOL bSetFocus;
} FOCUS_EVENT_RECORD, *PFOCUS_EVENT_RECORD;

typedef struct _INPUT_RECORD {
  WORD EventType;
  union {
    KEY_EVENT_RECORD KeyEvent;
    MOUSE_EVENT_RECORD MouseEvent;
    WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
    MENU_EVENT_RECORD MenuEvent;
    FOCUS_EVENT_RECORD FocusEvent;
  } Event;
} INPUT_RECORD, *PINPUT_RECORD;

#define KEY_EVENT 0x0001
#define MOUSE_EVENT 0x0002
#define WINDOW_BUFFER_SIZE_EVENT 0x0004
#define MENU_EVENT 0x0008
#define FOCUS_EVENT 0x0010

typedef struct _CHAR_INFO {
  union {
    WCHAR UnicodeChar;
    CHAR AsciiChar;
  } Char;
  WORD Attributes;
} CHAR_INFO, *PCHAR_INFO;

typedef struct _CONSOLE_FONT_INFO {
  DWORD nFont;
  COORD dwFontSize;
} CONSOLE_FONT_INFO, *PCONSOLE_FONT_INFO;

typedef VOID *HPCON;

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#ifdef __cplusplus
}
#endif

#endif /* _WINCONTYPES_ */
