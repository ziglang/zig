/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _WINCON_
#define _WINCON_

#include <_mingw_unicode.h>

#include <winapifamily.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef struct _COORD {
    SHORT X;
    SHORT Y;
  } COORD,*PCOORD;

  typedef struct _SMALL_RECT {
    SHORT Left;
    SHORT Top;
    SHORT Right;
    SHORT Bottom;
  } SMALL_RECT,*PSMALL_RECT;

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
  } KEY_EVENT_RECORD,*PKEY_EVENT_RECORD;

#define RIGHT_ALT_PRESSED 0x1
#define LEFT_ALT_PRESSED 0x2
#define RIGHT_CTRL_PRESSED 0x4
#define LEFT_CTRL_PRESSED 0x8
#define SHIFT_PRESSED 0x10
#define NUMLOCK_ON 0x20
#define SCROLLLOCK_ON 0x40
#define CAPSLOCK_ON 0x80
#define ENHANCED_KEY 0x100
#define NLS_DBCSCHAR 0x10000
#define NLS_ALPHANUMERIC 0x0
#define NLS_KATAKANA 0x20000
#define NLS_HIRAGANA 0x40000
#define NLS_ROMAN 0x400000
#define NLS_IME_CONVERSION 0x800000
#define NLS_IME_DISABLE 0x20000000

  typedef struct _MOUSE_EVENT_RECORD {
    COORD dwMousePosition;
    DWORD dwButtonState;
    DWORD dwControlKeyState;
    DWORD dwEventFlags;
  } MOUSE_EVENT_RECORD,*PMOUSE_EVENT_RECORD;

#define FROM_LEFT_1ST_BUTTON_PRESSED 0x1
#define RIGHTMOST_BUTTON_PRESSED 0x2
#define FROM_LEFT_2ND_BUTTON_PRESSED 0x4
#define FROM_LEFT_3RD_BUTTON_PRESSED 0x8
#define FROM_LEFT_4TH_BUTTON_PRESSED 0x10

#define MOUSE_MOVED 0x1
#define DOUBLE_CLICK 0x2
#define MOUSE_WHEELED 0x4
#if (_WIN32_WINNT >= 0x0600)
#define MOUSE_HWHEELED 0x8
#endif

  typedef struct _WINDOW_BUFFER_SIZE_RECORD {
    COORD dwSize;
  } WINDOW_BUFFER_SIZE_RECORD,*PWINDOW_BUFFER_SIZE_RECORD;

  typedef struct _MENU_EVENT_RECORD {
    UINT dwCommandId;
  } MENU_EVENT_RECORD,*PMENU_EVENT_RECORD;

  typedef struct _FOCUS_EVENT_RECORD {
    WINBOOL bSetFocus;
  } FOCUS_EVENT_RECORD,*PFOCUS_EVENT_RECORD;

  typedef struct _INPUT_RECORD {
    WORD EventType;
    union {
      KEY_EVENT_RECORD KeyEvent;
      MOUSE_EVENT_RECORD MouseEvent;
      WINDOW_BUFFER_SIZE_RECORD WindowBufferSizeEvent;
      MENU_EVENT_RECORD MenuEvent;
      FOCUS_EVENT_RECORD FocusEvent;
    } Event;
  } INPUT_RECORD,*PINPUT_RECORD;

#define KEY_EVENT 0x1
#define MOUSE_EVENT 0x2
#define WINDOW_BUFFER_SIZE_EVENT 0x4
#define MENU_EVENT 0x8
#define FOCUS_EVENT 0x10

  typedef struct _CHAR_INFO {
    union {
      WCHAR UnicodeChar;
      CHAR AsciiChar;
    } Char;
    WORD Attributes;
  } CHAR_INFO,*PCHAR_INFO;

#define FOREGROUND_BLUE 0x1
#define FOREGROUND_GREEN 0x2
#define FOREGROUND_RED 0x4
#define FOREGROUND_INTENSITY 0x8
#define BACKGROUND_BLUE 0x10
#define BACKGROUND_GREEN 0x20
#define BACKGROUND_RED 0x40
#define BACKGROUND_INTENSITY 0x80
#define COMMON_LVB_LEADING_BYTE 0x100
#define COMMON_LVB_TRAILING_BYTE 0x200
#define COMMON_LVB_GRID_HORIZONTAL 0x400
#define COMMON_LVB_GRID_LVERTICAL 0x800
#define COMMON_LVB_GRID_RVERTICAL 0x1000
#define COMMON_LVB_REVERSE_VIDEO 0x4000
#define COMMON_LVB_UNDERSCORE 0x8000

#define COMMON_LVB_SBCSDBCS 0x300

  typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
    COORD dwSize;
    COORD dwCursorPosition;
    WORD wAttributes;
    SMALL_RECT srWindow;
    COORD dwMaximumWindowSize;
  } CONSOLE_SCREEN_BUFFER_INFO,*PCONSOLE_SCREEN_BUFFER_INFO;

  typedef struct _CONSOLE_CURSOR_INFO {
    DWORD dwSize;
    WINBOOL bVisible;
  } CONSOLE_CURSOR_INFO,*PCONSOLE_CURSOR_INFO;

  typedef struct _CONSOLE_FONT_INFO {
    DWORD nFont;
    COORD dwFontSize;
  } CONSOLE_FONT_INFO,*PCONSOLE_FONT_INFO;

  typedef struct _CONSOLE_SELECTION_INFO {
    DWORD dwFlags;
    COORD dwSelectionAnchor;
    SMALL_RECT srSelection;
  } CONSOLE_SELECTION_INFO,*PCONSOLE_SELECTION_INFO;

#define CONSOLE_NO_SELECTION 0x0
#define CONSOLE_SELECTION_IN_PROGRESS 0x1
#define CONSOLE_SELECTION_NOT_EMPTY 0x2
#define CONSOLE_MOUSE_SELECTION 0x4
#define CONSOLE_MOUSE_DOWN 0x8

  typedef WINBOOL (WINAPI *PHANDLER_ROUTINE)(DWORD CtrlType);

#define CTRL_C_EVENT 0
#define CTRL_BREAK_EVENT 1
#define CTRL_CLOSE_EVENT 2

#define CTRL_LOGOFF_EVENT 5
#define CTRL_SHUTDOWN_EVENT 6

#define ENABLE_PROCESSED_INPUT 0x1
#define ENABLE_LINE_INPUT 0x2
#define ENABLE_ECHO_INPUT 0x4
#define ENABLE_WINDOW_INPUT 0x8
#define ENABLE_MOUSE_INPUT 0x10
#define ENABLE_INSERT_MODE 0x20
#define ENABLE_QUICK_EDIT_MODE 0x40
#define ENABLE_EXTENDED_FLAGS 0x80
#define ENABLE_AUTO_POSITION 0x100
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x200

#define ENABLE_PROCESSED_OUTPUT 0x1
#define ENABLE_WRAP_AT_EOL_OUTPUT 0x2
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x4
#define DISABLE_NEWLINE_AUTO_RETURN 0x8
#define ENABLE_LVB_GRID_WORLDWIDE 0x10

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#define PeekConsoleInput __MINGW_NAME_AW(PeekConsoleInput)
#define ReadConsoleInput __MINGW_NAME_AW(ReadConsoleInput)
#define WriteConsoleInput __MINGW_NAME_AW(WriteConsoleInput)
#define ReadConsoleOutput __MINGW_NAME_AW(ReadConsoleOutput)
#define WriteConsoleOutput __MINGW_NAME_AW(WriteConsoleOutput)
#define ReadConsoleOutputCharacter __MINGW_NAME_AW(ReadConsoleOutputCharacter)
#define WriteConsoleOutputCharacter __MINGW_NAME_AW(WriteConsoleOutputCharacter)
#define FillConsoleOutputCharacter __MINGW_NAME_AW(FillConsoleOutputCharacter)
#define ScrollConsoleScreenBuffer __MINGW_NAME_AW(ScrollConsoleScreenBuffer)
#define GetConsoleTitle __MINGW_NAME_AW(GetConsoleTitle)
#define SetConsoleTitle __MINGW_NAME_AW(SetConsoleTitle)
#define ReadConsole __MINGW_NAME_AW(ReadConsole)
#define WriteConsole __MINGW_NAME_AW(WriteConsole)
#define AddConsoleAlias __MINGW_NAME_AW(AddConsoleAlias)
#define GetConsoleAlias __MINGW_NAME_AW(GetConsoleAlias)
#define GetConsoleAliasesLength __MINGW_NAME_AW(GetConsoleAliasesLength)
#define GetConsoleAliasExesLength __MINGW_NAME_AW(GetConsoleAliasExesLength)
#define GetConsoleAliases __MINGW_NAME_AW(GetConsoleAliases)
#define GetConsoleAliasExes __MINGW_NAME_AW(GetConsoleAliasExes)

  WINBASEAPI WINBOOL WINAPI PeekConsoleInputA(HANDLE hConsoleInput,PINPUT_RECORD lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsRead);
  WINBASEAPI WINBOOL WINAPI PeekConsoleInputW(HANDLE hConsoleInput,PINPUT_RECORD lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsRead);
  WINBASEAPI WINBOOL WINAPI ReadConsoleInputA(HANDLE hConsoleInput,PINPUT_RECORD lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsRead);
  WINBASEAPI WINBOOL WINAPI ReadConsoleInputW(HANDLE hConsoleInput,PINPUT_RECORD lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsRead);
  WINBASEAPI WINBOOL WINAPI WriteConsoleInputA(HANDLE hConsoleInput,CONST INPUT_RECORD *lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsWritten);
  WINBASEAPI WINBOOL WINAPI WriteConsoleInputW(HANDLE hConsoleInput,CONST INPUT_RECORD *lpBuffer,DWORD nLength,LPDWORD lpNumberOfEventsWritten);
  WINBASEAPI WINBOOL WINAPI ReadConsoleOutputA(HANDLE hConsoleOutput,PCHAR_INFO lpBuffer,COORD dwBufferSize,COORD dwBufferCoord,PSMALL_RECT lpReadRegion);
  WINBASEAPI WINBOOL WINAPI ReadConsoleOutputW(HANDLE hConsoleOutput,PCHAR_INFO lpBuffer,COORD dwBufferSize,COORD dwBufferCoord,PSMALL_RECT lpReadRegion);
  WINBASEAPI WINBOOL WINAPI WriteConsoleOutputA(HANDLE hConsoleOutput,CONST CHAR_INFO *lpBuffer,COORD dwBufferSize,COORD dwBufferCoord,PSMALL_RECT lpWriteRegion);
  WINBASEAPI WINBOOL WINAPI WriteConsoleOutputW(HANDLE hConsoleOutput,CONST CHAR_INFO *lpBuffer,COORD dwBufferSize,COORD dwBufferCoord,PSMALL_RECT lpWriteRegion);
  WINBASEAPI WINBOOL WINAPI ReadConsoleOutputCharacterA(HANDLE hConsoleOutput,LPSTR lpCharacter,DWORD nLength,COORD dwReadCoord,LPDWORD lpNumberOfCharsRead);
  WINBASEAPI WINBOOL WINAPI ReadConsoleOutputCharacterW(HANDLE hConsoleOutput,LPWSTR lpCharacter,DWORD nLength,COORD dwReadCoord,LPDWORD lpNumberOfCharsRead);
  WINBASEAPI WINBOOL WINAPI ReadConsoleOutputAttribute(HANDLE hConsoleOutput,LPWORD lpAttribute,DWORD nLength,COORD dwReadCoord,LPDWORD lpNumberOfAttrsRead);
  WINBASEAPI WINBOOL WINAPI WriteConsoleOutputCharacterA(HANDLE hConsoleOutput,LPCSTR lpCharacter,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfCharsWritten);
  WINBASEAPI WINBOOL WINAPI WriteConsoleOutputCharacterW(HANDLE hConsoleOutput,LPCWSTR lpCharacter,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfCharsWritten);
  WINBASEAPI WINBOOL WINAPI WriteConsoleOutputAttribute(HANDLE hConsoleOutput,CONST WORD *lpAttribute,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfAttrsWritten);
  WINBASEAPI WINBOOL WINAPI FillConsoleOutputCharacterA(HANDLE hConsoleOutput,CHAR cCharacter,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfCharsWritten);
  WINBASEAPI WINBOOL WINAPI FillConsoleOutputCharacterW(HANDLE hConsoleOutput,WCHAR cCharacter,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfCharsWritten);
  WINBASEAPI WINBOOL WINAPI FillConsoleOutputAttribute(HANDLE hConsoleOutput,WORD wAttribute,DWORD nLength,COORD dwWriteCoord,LPDWORD lpNumberOfAttrsWritten);
  WINBASEAPI WINBOOL WINAPI GetConsoleMode(HANDLE hConsoleHandle,LPDWORD lpMode);
  WINBASEAPI WINBOOL WINAPI GetNumberOfConsoleInputEvents(HANDLE hConsoleInput,LPDWORD lpNumberOfEvents);
  WINBASEAPI WINBOOL WINAPI GetConsoleScreenBufferInfo(HANDLE hConsoleOutput,PCONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
  WINBASEAPI COORD WINAPI GetLargestConsoleWindowSize(HANDLE hConsoleOutput);
  WINBASEAPI WINBOOL WINAPI GetConsoleCursorInfo(HANDLE hConsoleOutput,PCONSOLE_CURSOR_INFO lpConsoleCursorInfo);
  WINBASEAPI WINBOOL WINAPI GetCurrentConsoleFont(HANDLE hConsoleOutput,WINBOOL bMaximumWindow,PCONSOLE_FONT_INFO lpConsoleCurrentFont);
  WINBASEAPI COORD WINAPI GetConsoleFontSize(HANDLE hConsoleOutput,DWORD nFont);
  WINBASEAPI WINBOOL WINAPI GetConsoleSelectionInfo(PCONSOLE_SELECTION_INFO lpConsoleSelectionInfo);
  WINBASEAPI WINBOOL WINAPI GetNumberOfConsoleMouseButtons(LPDWORD lpNumberOfMouseButtons);
  WINBASEAPI WINBOOL WINAPI SetConsoleMode(HANDLE hConsoleHandle,DWORD dwMode);
  WINBASEAPI WINBOOL WINAPI SetConsoleActiveScreenBuffer(HANDLE hConsoleOutput);
  WINBASEAPI WINBOOL WINAPI FlushConsoleInputBuffer(HANDLE hConsoleInput);
  WINBASEAPI WINBOOL WINAPI SetConsoleScreenBufferSize(HANDLE hConsoleOutput,COORD dwSize);
  WINBASEAPI WINBOOL WINAPI SetConsoleCursorPosition(HANDLE hConsoleOutput,COORD dwCursorPosition);
  WINBASEAPI WINBOOL WINAPI SetConsoleCursorInfo(HANDLE hConsoleOutput,CONST CONSOLE_CURSOR_INFO *lpConsoleCursorInfo);
  WINBASEAPI WINBOOL WINAPI ScrollConsoleScreenBufferA(HANDLE hConsoleOutput,CONST SMALL_RECT *lpScrollRectangle,CONST SMALL_RECT *lpClipRectangle,COORD dwDestinationOrigin,CONST CHAR_INFO *lpFill);
  WINBASEAPI WINBOOL WINAPI ScrollConsoleScreenBufferW(HANDLE hConsoleOutput,CONST SMALL_RECT *lpScrollRectangle,CONST SMALL_RECT *lpClipRectangle,COORD dwDestinationOrigin,CONST CHAR_INFO *lpFill);
  WINBASEAPI WINBOOL WINAPI SetConsoleWindowInfo(HANDLE hConsoleOutput,WINBOOL bAbsolute,CONST SMALL_RECT *lpConsoleWindow);
  WINBASEAPI WINBOOL WINAPI SetConsoleTextAttribute(HANDLE hConsoleOutput,WORD wAttributes);
  WINBASEAPI WINBOOL WINAPI SetConsoleCtrlHandler(PHANDLER_ROUTINE HandlerRoutine,WINBOOL Add);
  WINBASEAPI WINBOOL WINAPI GenerateConsoleCtrlEvent(DWORD dwCtrlEvent,DWORD dwProcessGroupId);
  WINBASEAPI WINBOOL WINAPI AllocConsole(VOID);
  WINBASEAPI WINBOOL WINAPI FreeConsole(VOID);
  WINBASEAPI WINBOOL WINAPI AttachConsole(DWORD dwProcessId);

#define ATTACH_PARENT_PROCESS ((DWORD)-1)

  WINBASEAPI DWORD WINAPI GetConsoleTitleA(LPSTR lpConsoleTitle,DWORD nSize);
  WINBASEAPI DWORD WINAPI GetConsoleTitleW(LPWSTR lpConsoleTitle,DWORD nSize);
  WINBASEAPI WINBOOL WINAPI SetConsoleTitleA(LPCSTR lpConsoleTitle);
  WINBASEAPI WINBOOL WINAPI SetConsoleTitleW(LPCWSTR lpConsoleTitle);
  WINBASEAPI WINBOOL WINAPI ReadConsoleA(HANDLE hConsoleInput,LPVOID lpBuffer,DWORD nNumberOfCharsToRead,LPDWORD lpNumberOfCharsRead,LPVOID lpReserved);
  WINBASEAPI WINBOOL WINAPI ReadConsoleW(HANDLE hConsoleInput,LPVOID lpBuffer,DWORD nNumberOfCharsToRead,LPDWORD lpNumberOfCharsRead,LPVOID lpReserved);
  WINBASEAPI WINBOOL WINAPI WriteConsoleA(HANDLE hConsoleOutput,CONST VOID *lpBuffer,DWORD nNumberOfCharsToWrite,LPDWORD lpNumberOfCharsWritten,LPVOID lpReserved);
  WINBASEAPI WINBOOL WINAPI WriteConsoleW(HANDLE hConsoleOutput,CONST VOID *lpBuffer,DWORD nNumberOfCharsToWrite,LPDWORD lpNumberOfCharsWritten,LPVOID lpReserved);

#define CONSOLE_TEXTMODE_BUFFER 1

  WINBASEAPI HANDLE WINAPI CreateConsoleScreenBuffer(DWORD dwDesiredAccess,DWORD dwShareMode,CONST SECURITY_ATTRIBUTES *lpSecurityAttributes,DWORD dwFlags,LPVOID lpScreenBufferData);
  WINBASEAPI UINT WINAPI GetConsoleCP(VOID);
  WINBASEAPI WINBOOL WINAPI SetConsoleCP(UINT wCodePageID);
  WINBASEAPI UINT WINAPI GetConsoleOutputCP(VOID);
  WINBASEAPI WINBOOL WINAPI SetConsoleOutputCP(UINT wCodePageID);

#define CONSOLE_FULLSCREEN 1
#define CONSOLE_FULLSCREEN_HARDWARE 2
  WINBASEAPI WINBOOL WINAPI GetConsoleDisplayMode(LPDWORD lpModeFlags);

#define CONSOLE_FULLSCREEN_MODE 1
#define CONSOLE_WINDOWED_MODE 2
  WINBASEAPI WINBOOL WINAPI SetConsoleDisplayMode(HANDLE hConsoleOutput, DWORD dwFlags, PCOORD lpNewScreenBufferDimensions);

  WINBASEAPI HWND WINAPI GetConsoleWindow(VOID);
  WINBASEAPI DWORD WINAPI GetConsoleProcessList(LPDWORD lpdwProcessList,DWORD dwProcessCount);
  WINBASEAPI WINBOOL WINAPI AddConsoleAliasA(LPSTR Source,LPSTR Target,LPSTR ExeName);
  WINBASEAPI WINBOOL WINAPI AddConsoleAliasW(LPWSTR Source,LPWSTR Target,LPWSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasA(LPSTR Source,LPSTR TargetBuffer,DWORD TargetBufferLength,LPSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasW(LPWSTR Source,LPWSTR TargetBuffer,DWORD TargetBufferLength,LPWSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasesLengthA(LPSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasesLengthW(LPWSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasExesLengthA(VOID);
  WINBASEAPI DWORD WINAPI GetConsoleAliasExesLengthW(VOID);
  WINBASEAPI DWORD WINAPI GetConsoleAliasesA(LPSTR AliasBuffer,DWORD AliasBufferLength,LPSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasesW(LPWSTR AliasBuffer,DWORD AliasBufferLength,LPWSTR ExeName);
  WINBASEAPI DWORD WINAPI GetConsoleAliasExesA(LPSTR ExeNameBuffer,DWORD ExeNameBufferLength);
  WINBASEAPI DWORD WINAPI GetConsoleAliasExesW(LPWSTR ExeNameBuffer,DWORD ExeNameBufferLength);

#ifndef LF_FACESIZE
#define LF_FACESIZE 32
#endif

typedef struct _CONSOLE_FONT_INFOEX {
  ULONG cbSize;
  DWORD nFont;
  COORD dwFontSize;
  UINT  FontFamily;
  UINT  FontWeight;
  WCHAR FaceName[LF_FACESIZE];
} CONSOLE_FONT_INFOEX, *PCONSOLE_FONT_INFOEX;

typedef struct _CONSOLE_HISTORY_INFO {
  UINT  cbSize;
  UINT  HistoryBufferSize;
  UINT  NumberOfHistoryBuffers;
  DWORD dwFlags;
} CONSOLE_HISTORY_INFO, *PCONSOLE_HISTORY_INFO;

typedef struct _CONSOLE_READCONSOLE_CONTROL {
  ULONG nLength;
  ULONG nInitialChars;
  ULONG dwCtrlWakeupMask;
  ULONG dwControlKeyState;
} CONSOLE_READCONSOLE_CONTROL, *PCONSOLE_READCONSOLE_CONTROL;

typedef struct _CONSOLE_SCREEN_BUFFER_INFOEX {
  ULONG      cbSize;
  COORD      dwSize;
  COORD      dwCursorPosition;
  WORD       wAttributes;
  SMALL_RECT srWindow;
  COORD      dwMaximumWindowSize;
  WORD       wPopupAttributes;
  WINBOOL    bFullscreenSupported;
  COLORREF   ColorTable[16];
} CONSOLE_SCREEN_BUFFER_INFOEX, *PCONSOLE_SCREEN_BUFFER_INFOEX;

WINBOOL WINAPI GetConsoleHistoryInfo(
  PCONSOLE_HISTORY_INFO lpConsoleHistoryInfo
);

#if (_WIN32_WINNT >= 0x0600)
#define GetConsoleOriginalTitle __MINGW_NAME_AW(GetConsoleOriginalTitle)

WINBASEAPI DWORD WINAPI GetConsoleOriginalTitleA(
  LPSTR lpConsoleTitle,
  DWORD nSize
);

WINBASEAPI DWORD WINAPI GetConsoleOriginalTitleW(
  LPWSTR lpConsoleTitle,
  DWORD nSize
);
#endif /* (_WIN32_WINNT >= 0x0600) */

WINBASEAPI WINBOOL WINAPI GetConsoleScreenBufferInfoEx(
  HANDLE hConsoleOutput,
  PCONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx
);

WINBASEAPI WINBOOL WINAPI GetCurrentConsoleFontEx(
  HANDLE hConsoleOutput,
  WINBOOL bMaximumWindow,
  PCONSOLE_FONT_INFOEX lpConsoleCurrentFontEx
);

WINBASEAPI WINBOOL WINAPI SetConsoleHistoryInfo(
  PCONSOLE_HISTORY_INFO lpConsoleHistoryInfo
);

WINBASEAPI WINBOOL WINAPI SetConsoleScreenBufferInfoEx(
  HANDLE hConsoleOutput,
  PCONSOLE_SCREEN_BUFFER_INFOEX lpConsoleScreenBufferInfoEx
);

WINBASEAPI WINBOOL WINAPI SetCurrentConsoleFontEx(
  HANDLE hConsoleOutput,
  WINBOOL bMaximumWindow,
  PCONSOLE_FONT_INFOEX lpConsoleCurrentFontEx
);

#if (NTDDI_VERSION >= 0x0A000006)

/* CreatePseudoConsole Flags */
#define PSEUDOCONSOLE_INHERIT_CURSOR 1

typedef VOID* HPCON;

WINBASEAPI HRESULT WINAPI CreatePseudoConsole(COORD size, HANDLE hInput, HANDLE hOutput, DWORD dwFlags, HPCON* phPC);
WINBASEAPI HRESULT WINAPI ResizePseudoConsole(HPCON hPC, COORD size);
WINBASEAPI VOID WINAPI ClosePseudoConsole(HPCON hPC);

#endif /* NTDDI_WIN10_RS5 */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) && defined(WINSTORECOMPAT)
WINBASEAPI UINT WINAPI GetConsoleOutputCP(VOID);
#endif

#ifdef __cplusplus
}
#endif
#endif
