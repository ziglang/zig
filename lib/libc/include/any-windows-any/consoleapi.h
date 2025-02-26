/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _APISETCONSOLE_
#define _APISETCONSOLE_

#include <_mingw_unicode.h>

#include <apiset.h>
#include <apisetcconv.h>
#include <minwinbase.h>
#include <minwindef.h>

#include <wincontypes.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

WINBASEAPI WINBOOL WINAPI AllocConsole(void);

#if (NTDDI_VERSION >= NTDDI_WIN11_GE)

typedef enum ALLOC_CONSOLE_MODE {
  ALLOC_CONSOLE_MODE_DEFAULT = 0,
  ALLOC_CONSOLE_MODE_NEW_WINDOW = 1,
  ALLOC_CONSOLE_MODE_NO_WINDOW = 2
} ALLOC_CONSOLE_MODE;

typedef struct ALLOC_CONSOLE_OPTIONS {
  ALLOC_CONSOLE_MODE mode;
  WINBOOL useShowWindow;
  WORD showWindow;
} ALLOC_CONSOLE_OPTIONS, *PALLOC_CONSOLE_OPTIONS;

typedef enum ALLOC_CONSOLE_RESULT {
  ALLOC_CONSOLE_RESULT_NO_CONSOLE = 0,
  ALLOC_CONSOLE_RESULT_NEW_CONSOLE = 1,
  ALLOC_CONSOLE_RESULT_EXISTING_CONSOLE = 2
} ALLOC_CONSOLE_RESULT, *PALLOC_CONSOLE_RESULT;

WINBASEAPI HRESULT WINAPI AllocConsoleWithOptions(PALLOC_CONSOLE_OPTIONS options, PALLOC_CONSOLE_RESULT result);

#endif /* NTDDI_VERSION >= NTDDI_WIN11_GE */

WINBASEAPI WINBOOL WINAPI FreeConsole(void);

#if (_WIN32_WINNT >= 0x0500)

WINBASEAPI WINBOOL WINAPI AttachConsole(DWORD process_id);

#define ATTACH_PARENT_PROCESS ((DWORD)-1)

#endif /* _WIN32_WINNT >= 0x0500 */

WINBASEAPI UINT WINAPI GetConsoleCP(void);
WINBASEAPI UINT WINAPI GetConsoleOutputCP(void);

#define ENABLE_PROCESSED_INPUT 0x0001
#define ENABLE_LINE_INPUT 0x0002
#define ENABLE_ECHO_INPUT 0x0004
#define ENABLE_WINDOW_INPUT 0x0008
#define ENABLE_MOUSE_INPUT 0x0010
#define ENABLE_INSERT_MODE 0x0020
#define ENABLE_QUICK_EDIT_MODE 0x0040
#define ENABLE_EXTENDED_FLAGS 0x0080
#define ENABLE_AUTO_POSITION 0x0100
#define ENABLE_VIRTUAL_TERMINAL_INPUT 0x0200

#define ENABLE_PROCESSED_OUTPUT 0x0001
#define ENABLE_WRAP_AT_EOL_OUTPUT 0x0002
#define ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
#define DISABLE_NEWLINE_AUTO_RETURN 0x0008
#define ENABLE_LVB_GRID_WORLDWIDE 0x0010

WINBASEAPI WINBOOL WINAPI GetConsoleMode(HANDLE console_handle, LPDWORD mode);
WINBASEAPI WINBOOL WINAPI SetConsoleMode(HANDLE console_handle, DWORD mode);
WINBASEAPI WINBOOL WINAPI GetNumberOfConsoleInputEvents(HANDLE console_input, LPDWORD number_of_events);

WINBASEAPI WINBOOL WINAPI ReadConsoleInputA(HANDLE console_input, PINPUT_RECORD buffer, DWORD length, LPDWORD number_of_events_read);
WINBASEAPI WINBOOL WINAPI ReadConsoleInputW(HANDLE console_input, PINPUT_RECORD buffer, DWORD length, LPDWORD number_of_events_read);
#define ReadConsoleInput __MINGW_NAME_AW(ReadConsoleInput)

WINBASEAPI WINBOOL WINAPI PeekConsoleInputA(HANDLE console_input, PINPUT_RECORD buffer, DWORD length, LPDWORD number_of_events_read);
WINBASEAPI WINBOOL WINAPI PeekConsoleInputW(HANDLE console_input, PINPUT_RECORD buffer, DWORD length, LPDWORD number_of_events_read);
#define PeekConsoleInput __MINGW_NAME_AW(PeekConsoleInput)

typedef struct _CONSOLE_READCONSOLE_CONTROL {
  ULONG nLength;
  ULONG nInitialChars;
  ULONG dwCtrlWakeupMask;
  ULONG dwControlKeyState;
} CONSOLE_READCONSOLE_CONTROL, *PCONSOLE_READCONSOLE_CONTROL;

WINBASEAPI WINBOOL WINAPI ReadConsoleA(HANDLE console_input, LPVOID buffer, DWORD number_of_chars_to_read, LPDWORD number_of_chars_read, PCONSOLE_READCONSOLE_CONTROL input_control);
WINBASEAPI WINBOOL WINAPI ReadConsoleW(HANDLE console_input, LPVOID buffer, DWORD number_of_chars_to_read, LPDWORD number_of_chars_read, PCONSOLE_READCONSOLE_CONTROL input_control);
#define ReadConsole __MINGW_NAME_AW(ReadConsole)

WINBASEAPI WINBOOL WINAPI WriteConsoleA(HANDLE console_output, const void *buffer, DWORD number_of_chars_to_write, LPDWORD number_of_chars_written, LPVOID reserved);
WINBASEAPI WINBOOL WINAPI WriteConsoleW(HANDLE console_output, const void *buffer, DWORD number_of_chars_to_write, LPDWORD number_of_chars_written, LPVOID reserved);
#define WriteConsole __MINGW_NAME_AW(WriteConsole)

#define CTRL_C_EVENT 0
#define CTRL_BREAK_EVENT 1
#define CTRL_CLOSE_EVENT 2
#define CTRL_LOGOFF_EVENT 5
#define CTRL_SHUTDOWN_EVENT 6

typedef WINBOOL (WINAPI *PHANDLER_ROUTINE)(DWORD ctrl_type);
WINBASEAPI WINBOOL WINAPI SetConsoleCtrlHandler(PHANDLER_ROUTINE handler_routine, WINBOOL add);

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP)

#if (NTDDI_VERSION >= NTDDI_WIN10_RS5)
#define PSEUDOCONSOLE_INHERIT_CURSOR (0x1)

WINBASEAPI HRESULT WINAPI CreatePseudoConsole(COORD size, HANDLE input, HANDLE output, DWORD flags, HPCON *pc);
WINBASEAPI HRESULT WINAPI ResizePseudoConsole(HPCON pc, COORD size);
WINBASEAPI void WINAPI ClosePseudoConsole(HPCON pc);
#endif

#if (NTDDI_VERSION >= NTDDI_WIN11_GE)
WINBASEAPI HRESULT WINAPI ReleasePseudoConsole(HPCON pc);
#endif

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_DESKTOP) */

#ifdef __cplusplus
}
#endif

#endif /* _APISETCONSOLE_ */
