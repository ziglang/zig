/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */

#ifndef _APISETCONSOLEL3_
#define _APISETCONSOLEL3_

#include <_mingw_unicode.h>

#include <apiset.h>
#include <apisetcconv.h>
#include <minwinbase.h>
#include <minwindef.h>

#include <wincontypes.h>
#include <windef.h>

#ifndef NOGDI
#include <wingdi.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP)

WINBASEAPI WINBOOL WINAPI GetNumberOfConsoleMouseButtons(LPDWORD number_of_mouse_buttons);

#if (_WIN32_WINNT >= 0x0500)

WINBASEAPI COORD WINAPI GetConsoleFontSize(HANDLE console_output, DWORD font);
WINBASEAPI WINBOOL WINAPI GetCurrentConsoleFont(HANDLE console_output, WINBOOL maximum_window, PCONSOLE_FONT_INFO console_current_font);

#ifndef NOGDI

typedef struct _CONSOLE_FONT_INFOEX {
  ULONG cbSize;
  DWORD nFont;
  COORD dwFontSize;
  UINT FontFamily;
  UINT FontWeight;
  WCHAR FaceName[LF_FACESIZE];
} CONSOLE_FONT_INFOEX, *PCONSOLE_FONT_INFOEX;

WINBASEAPI WINBOOL WINAPI GetCurrentConsoleFontEx(HANDLE console_output, WINBOOL maximum_window, PCONSOLE_FONT_INFOEX console_current_font_ex);
WINBASEAPI WINBOOL WINAPI SetCurrentConsoleFontEx(HANDLE console_output, WINBOOL maximum_window, PCONSOLE_FONT_INFOEX console_current_font_ex);

#endif /* !NOGDI */

#define CONSOLE_NO_SELECTION 0x0000
#define CONSOLE_SELECTION_IN_PROGRESS 0x0001
#define CONSOLE_SELECTION_NOT_EMPTY 0x0002
#define CONSOLE_MOUSE_SELECTION 0x0004
#define CONSOLE_MOUSE_DOWN 0x0008

typedef struct _CONSOLE_SELECTION_INFO {
  DWORD dwFlags;
  COORD dwSelectionAnchor;
  SMALL_RECT srSelection;
} CONSOLE_SELECTION_INFO, *PCONSOLE_SELECTION_INFO;

WINBASEAPI WINBOOL WINAPI GetConsoleSelectionInfo(PCONSOLE_SELECTION_INFO console_selection_info);

#define HISTORY_NO_DUP_FLAG 0x1

typedef struct _CONSOLE_HISTORY_INFO {
  UINT cbSize;
  UINT HistoryBufferSize;
  UINT NumberOfHistoryBuffers;
  DWORD dwFlags;
} CONSOLE_HISTORY_INFO, *PCONSOLE_HISTORY_INFO;

WINBASEAPI WINBOOL WINAPI GetConsoleHistoryInfo(PCONSOLE_HISTORY_INFO console_history_info);
WINBASEAPI WINBOOL WINAPI SetConsoleHistoryInfo(PCONSOLE_HISTORY_INFO console_history_info);

#define CONSOLE_FULLSCREEN 1
#define CONSOLE_FULLSCREEN_HARDWARE 2

WINBASEAPI WINBOOL APIENTRY GetConsoleDisplayMode(LPDWORD mode_flags);

#define CONSOLE_FULLSCREEN_MODE 1
#define CONSOLE_WINDOWED_MODE 2

WINBASEAPI WINBOOL APIENTRY SetConsoleDisplayMode(HANDLE console_output, DWORD flags, PCOORD new_screen_buffer_dimensions);
WINBASEAPI HWND APIENTRY GetConsoleWindow(void);

#endif /* _WIN32_WINNT >= 0x0500 */

#if (_WIN32_WINNT >= 0x0501)

WINBASEAPI WINBOOL APIENTRY AddConsoleAliasA(LPSTR source, LPSTR target, LPSTR exe_name);
WINBASEAPI WINBOOL APIENTRY AddConsoleAliasW(LPWSTR source, LPWSTR target, LPWSTR exe_name);
#define AddConsoleAlias __MINGW_NAME_AW(AddConsoleAlias)

WINBASEAPI DWORD APIENTRY GetConsoleAliasA(LPSTR source, LPSTR target_buffer, DWORD target_buffer_length, LPSTR exe_name);
WINBASEAPI DWORD APIENTRY GetConsoleAliasW(LPWSTR source, LPWSTR target_buffer, DWORD target_buffer_length, LPWSTR exe_name);
#define GetConsoleAlias __MINGW_NAME_AW(GetConsoleAlias)

WINBASEAPI DWORD APIENTRY GetConsoleAliasesLengthA(LPSTR exe_name);
WINBASEAPI DWORD APIENTRY GetConsoleAliasesLengthW(LPWSTR exe_name);
#define GetConsoleAliasesLength __MINGW_NAME_AW(GetConsoleAliasesLength)

WINBASEAPI DWORD APIENTRY GetConsoleAliasExesLengthA(void);
WINBASEAPI DWORD APIENTRY GetConsoleAliasExesLengthW(void);
#define GetConsoleAliasExesLength __MINGW_NAME_AW(GetConsoleAliasExesLength)

WINBASEAPI DWORD APIENTRY GetConsoleAliasesA(LPSTR alias_buffer, DWORD alias_buffer_length, LPSTR exe_name);
WINBASEAPI DWORD APIENTRY GetConsoleAliasesW(LPWSTR alias_buffer, DWORD alias_buffer_length, LPWSTR exe_name);
#define GetConsoleAliases __MINGW_NAME_AW(GetConsoleAliases)

WINBASEAPI DWORD APIENTRY GetConsoleAliasExesA(LPSTR exe_name_buffer, DWORD exe_name_buffer_length);
WINBASEAPI DWORD APIENTRY GetConsoleAliasExesW(LPWSTR exe_name_buffer, DWORD exe_name_buffer_length);
#define GetConsoleAliasExes __MINGW_NAME_AW(GetConsoleAliasExes)

#endif /* _WIN32_WINNT >= 0x0501 */

WINBASEAPI void APIENTRY ExpungeConsoleCommandHistoryA(LPSTR exe_name);
WINBASEAPI void APIENTRY ExpungeConsoleCommandHistoryW(LPWSTR exe_name);
#define ExpungeConsoleCommandHistory __MINGW_NAME_AW(ExpungeConsoleCommandHistory)

WINBASEAPI WINBOOL APIENTRY SetConsoleNumberOfCommandsA(DWORD number, LPSTR exe_name);
WINBASEAPI WINBOOL APIENTRY SetConsoleNumberOfCommandsW(DWORD number, LPWSTR exe_name);
#define SetConsoleNumberOfCommands __MINGW_NAME_AW(SetConsoleNumberOfCommands)

WINBASEAPI DWORD APIENTRY GetConsoleCommandHistoryLengthA(LPSTR exe_name);
WINBASEAPI DWORD APIENTRY GetConsoleCommandHistoryLengthW(LPWSTR exe_name);
#define GetConsoleCommandHistoryLength __MINGW_NAME_AW(GetConsoleCommandHistoryLength)

WINBASEAPI DWORD APIENTRY GetConsoleCommandHistoryA(LPSTR commands, DWORD command_buffer_length, LPSTR exe_name);
WINBASEAPI DWORD APIENTRY GetConsoleCommandHistoryW(LPWSTR commands, DWORD command_buffer_length, LPWSTR exe_name);
#define GetConsoleCommandHistory __MINGW_NAME_AW(GetConsoleCommandHistory)

#if (_WIN32_WINNT >= 0x0501)
WINBASEAPI DWORD APIENTRY GetConsoleProcessList(LPDWORD process_list, DWORD process_count);
#endif /* _WIN32_WINNT >= 0x0501 */

#endif /* WINAPI_FAMILY_PARTITION(WINAPI_PARTITION_APP) */

#ifdef __cplusplus
}
#endif

#endif /* _APISETCONSOLEL3_ */
