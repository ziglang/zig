/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _APISETCONSOLEL2_
#define _APISETCONSOLEL2_

#include <_mingw_unicode.h>

#include <apiset.h>
#include <apisetcconv.h>
#include <minwinbase.h>
#include <minwindef.h>

#include <wincontypes.h>
#include <windef.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

#define FOREGROUND_BLUE 0x0001
#define FOREGROUND_GREEN 0x0002
#define FOREGROUND_RED 0x0004
#define FOREGROUND_INTENSITY 0x0008
#define BACKGROUND_BLUE 0x0010
#define BACKGROUND_GREEN 0x0020
#define BACKGROUND_RED 0x0040
#define BACKGROUND_INTENSITY 0x0080
#define COMMON_LVB_LEADING_BYTE 0x0100
#define COMMON_LVB_TRAILING_BYTE 0x0200
#define COMMON_LVB_GRID_HORIZONTAL 0x0400
#define COMMON_LVB_GRID_LVERTICAL 0x0800
#define COMMON_LVB_GRID_RVERTICAL 0x1000
#define COMMON_LVB_REVERSE_VIDEO 0x4000
#define COMMON_LVB_UNDERSCORE 0x8000

#define COMMON_LVB_SBCSDBCS 0x0300

WINBASEAPI WINBOOL WINAPI FillConsoleOutputCharacterA(HANDLE console_output, CHAR character, DWORD length, COORD write_coord, LPDWORD number_of_chars_written);
WINBASEAPI WINBOOL WINAPI FillConsoleOutputCharacterW(HANDLE console_output, WCHAR character, DWORD length, COORD write_coord, LPDWORD number_of_chars_written);
#define FillConsoleOutputCharacter __MINGW_NAME_AW(FillConsoleOutputCharacter)

WINBASEAPI WINBOOL WINAPI FillConsoleOutputAttribute(HANDLE console_output, WORD attribute, DWORD length, COORD write_coord, LPDWORD number_of_attrs_written);
WINBASEAPI WINBOOL WINAPI GenerateConsoleCtrlEvent(DWORD ctrl_event, DWORD process_group_id);
WINBASEAPI HANDLE WINAPI CreateConsoleScreenBuffer(DWORD desired_access, DWORD share_mode, const SECURITY_ATTRIBUTES *security_attributes, DWORD flags, LPVOID screen_buffer_data);
WINBASEAPI WINBOOL WINAPI SetConsoleActiveScreenBuffer(HANDLE console_output);
WINBASEAPI WINBOOL WINAPI FlushConsoleInputBuffer(HANDLE console_input);
WINBASEAPI WINBOOL WINAPI SetConsoleCP(UINT code_page_id);
WINBASEAPI WINBOOL WINAPI SetConsoleOutputCP(UINT code_page_id);

typedef struct _CONSOLE_CURSOR_INFO {
  DWORD dwSize;
  WINBOOL bVisible;
} CONSOLE_CURSOR_INFO, *PCONSOLE_CURSOR_INFO;

WINBASEAPI WINBOOL WINAPI GetConsoleCursorInfo(HANDLE console_output, PCONSOLE_CURSOR_INFO console_cursor_info);
WINBASEAPI WINBOOL WINAPI SetConsoleCursorInfo(HANDLE console_output, const CONSOLE_CURSOR_INFO *console_cursor_info);

typedef struct _CONSOLE_SCREEN_BUFFER_INFO {
  COORD dwSize;
  COORD dwCursorPosition;
  WORD wAttributes;
  SMALL_RECT srWindow;
  COORD dwMaximumWindowSize;
} CONSOLE_SCREEN_BUFFER_INFO, *PCONSOLE_SCREEN_BUFFER_INFO;

WINBASEAPI WINBOOL WINAPI GetConsoleScreenBufferInfo(HANDLE console_output, PCONSOLE_SCREEN_BUFFER_INFO console_screen_buffer_info);

typedef struct _CONSOLE_SCREEN_BUFFER_INFOEX {
  ULONG cbSize;
  COORD dwSize;
  COORD dwCursorPosition;
  WORD wAttributes;
  SMALL_RECT srWindow;
  COORD dwMaximumWindowSize;
  WORD wPopupAttributes;
  WINBOOL bFullscreenSupported;
  COLORREF ColorTable[16];
} CONSOLE_SCREEN_BUFFER_INFOEX, *PCONSOLE_SCREEN_BUFFER_INFOEX;

WINBASEAPI WINBOOL WINAPI GetConsoleScreenBufferInfoEx(HANDLE console_output, PCONSOLE_SCREEN_BUFFER_INFOEX console_screen_buffer_info_ex);
WINBASEAPI WINBOOL WINAPI SetConsoleScreenBufferInfoEx(HANDLE console_output, PCONSOLE_SCREEN_BUFFER_INFOEX console_screen_buffer_info_ex);
WINBASEAPI WINBOOL WINAPI SetConsoleScreenBufferSize(HANDLE console_output, COORD size);
WINBASEAPI WINBOOL WINAPI SetConsoleCursorPosition(HANDLE console_output, COORD cursor_position);
WINBASEAPI COORD WINAPI GetLargestConsoleWindowSize(HANDLE console_output);
WINBASEAPI WINBOOL WINAPI SetConsoleTextAttribute(HANDLE console_output, WORD attributes);
WINBASEAPI WINBOOL WINAPI SetConsoleWindowInfo(HANDLE console_output, WINBOOL absolute, const SMALL_RECT *console_window);

WINBASEAPI WINBOOL WINAPI WriteConsoleOutputCharacterA(HANDLE console_output, LPCSTR character, DWORD length, COORD write_coord, LPDWORD number_of_chars_written);
WINBASEAPI WINBOOL WINAPI WriteConsoleOutputCharacterW(HANDLE console_output, LPCWSTR character, DWORD length, COORD write_coord, LPDWORD number_of_chars_written);
#define WriteConsoleOutputCharacter __MINGW_NAME_AW(WriteConsoleOutputCharacter)

WINBASEAPI WINBOOL WINAPI WriteConsoleOutputAttribute(HANDLE console_output, const WORD *attribute, DWORD length, COORD write_coord, LPDWORD number_of_attrs_written);

WINBASEAPI WINBOOL WINAPI ReadConsoleOutputCharacterA(HANDLE console_output, LPSTR character, DWORD length, COORD read_coord, LPDWORD number_of_chars_read);
WINBASEAPI WINBOOL WINAPI ReadConsoleOutputCharacterW(HANDLE console_output, LPWSTR character, DWORD length, COORD read_coord, LPDWORD number_of_chars_read);
#define ReadConsoleOutputCharacter __MINGW_NAME_AW(ReadConsoleOutputCharacter)

WINBASEAPI WINBOOL WINAPI ReadConsoleOutputAttribute(HANDLE console_output, LPWORD attribute, DWORD length, COORD read_coord, LPDWORD number_of_attrs_read);

WINBASEAPI WINBOOL WINAPI WriteConsoleInputA(HANDLE console_input, const INPUT_RECORD *buffer, DWORD length, LPDWORD number_of_events_written);
WINBASEAPI WINBOOL WINAPI WriteConsoleInputW(HANDLE console_input, const INPUT_RECORD *buffer, DWORD length, LPDWORD number_of_events_written);
#define WriteConsoleInput __MINGW_NAME_AW(WriteConsoleInput)

WINBASEAPI WINBOOL WINAPI ScrollConsoleScreenBufferA(HANDLE console_output, const SMALL_RECT *scroll_rectangle, const SMALL_RECT *clip_rectangle, COORD destination_origin, const CHAR_INFO *fill);
WINBASEAPI WINBOOL WINAPI ScrollConsoleScreenBufferW(HANDLE console_output, const SMALL_RECT *scroll_rectangle, const SMALL_RECT *clip_rectangle, COORD destination_origin, const CHAR_INFO *fill);
#define ScrollConsoleScreenBuffer __MINGW_NAME_AW(ScrollConsoleScreenBuffer)

WINBASEAPI WINBOOL WINAPI WriteConsoleOutputA(HANDLE console_output, const CHAR_INFO *buffer, COORD buffer_size, COORD buffer_coord, PSMALL_RECT write_region);
WINBASEAPI WINBOOL WINAPI WriteConsoleOutputW(HANDLE console_output, const CHAR_INFO *buffer, COORD buffer_size, COORD buffer_coord, PSMALL_RECT write_region);
#define WriteConsoleOutput __MINGW_NAME_AW(WriteConsoleOutput)

WINBASEAPI WINBOOL WINAPI ReadConsoleOutputA(HANDLE console_output, PCHAR_INFO buffer, COORD buffer_size, COORD buffer_coord, PSMALL_RECT read_region);
WINBASEAPI WINBOOL WINAPI ReadConsoleOutputW(HANDLE console_output, PCHAR_INFO buffer, COORD buffer_size, COORD buffer_coord, PSMALL_RECT read_region);
#define ReadConsoleOutput __MINGW_NAME_AW(ReadConsoleOutput)

WINBASEAPI DWORD WINAPI GetConsoleTitleA(LPSTR console_title, DWORD size);
WINBASEAPI DWORD WINAPI GetConsoleTitleW(LPWSTR console_title, DWORD size);
#define GetConsoleTitle __MINGW_NAME_AW(GetConsoleTitle)

#if (_WIN32_WINNT >= 0x0600)

WINBASEAPI DWORD WINAPI GetConsoleOriginalTitleA(LPSTR console_title, DWORD size);
WINBASEAPI DWORD WINAPI GetConsoleOriginalTitleW(LPWSTR console_title, DWORD size);
#define GetConsoleOriginalTitle __MINGW_NAME_AW(GetConsoleOriginalTitle)

#endif /* _WIN32_WINNT >= 0x0600 */

WINBASEAPI WINBOOL WINAPI SetConsoleTitleA(LPCSTR console_title);
WINBASEAPI WINBOOL WINAPI SetConsoleTitleW(LPCWSTR console_title);
#define SetConsoleTitle __MINGW_NAME_AW(SetConsoleTitle)

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#ifdef __cplusplus
}
#endif

#endif /* _APISETCONSOLEL2_ */
