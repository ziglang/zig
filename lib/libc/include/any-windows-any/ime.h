/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _IME_
#define _IME_

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#ifndef _WINDEF_
  typedef unsigned int UINT;
#endif

#define IME_MAXPROCESS 32

#define SendIMEMessageEx __MINGW_NAME_AW(SendIMEMessageEx)

  LRESULT WINAPI SendIMEMessageExA(HWND,LPARAM);
  LRESULT WINAPI SendIMEMessageExW(HWND,LPARAM);

  typedef struct tagIMESTRUCT {
    UINT fnc;
    WPARAM wParam;
    UINT wCount;
    UINT dchSource;
    UINT dchDest;
    LPARAM lParam1;
    LPARAM lParam2;
    LPARAM lParam3;
  } IMESTRUCT,*PIMESTRUCT,*NPIMESTRUCT,*LPIMESTRUCT;

#define CP_HWND 0
#define CP_OPEN 1
#define CP_DIRECT 2
#define CP_LEVEL 3

#if !defined(VK_DBE_ALPHANUMERIC)
#define VK_DBE_ALPHANUMERIC 0x0f0
#define VK_DBE_KATAKANA 0x0f1
#define VK_DBE_HIRAGANA 0x0f2
#define VK_DBE_SBCSCHAR 0x0f3
#define VK_DBE_DBCSCHAR 0x0f4
#define VK_DBE_ROMAN 0x0f5
#define VK_DBE_NOROMAN 0x0f6
#define VK_DBE_ENTERWORDREGISTERMODE 0x0f7
#define VK_DBE_ENTERIMECONFIGMODE 0x0f8
#define VK_DBE_FLUSHSTRING 0x0f9
#define VK_DBE_CODEINPUT 0x0fa
#define VK_DBE_NOCODEINPUT 0x0fb
#define VK_DBE_DETERMINESTRING 0x0fc
#define VK_DBE_ENTERDLGCONVERSIONMODE 0x0fd
#endif

#define MCW_DEFAULT 0x00
#define MCW_RECT 0x01
#define MCW_WINDOW 0x02
#define MCW_SCREEN 0x04
#define MCW_VERTICAL 0x08
#define MCW_HIDDEN 0x10

#define IME_MODE_ALPHANUMERIC 0x0001

#ifdef KOREA
#define IME_MODE_SBCSCHAR 0x0002
#else
#define IME_MODE_SBCSCHAR 0x0008
#endif

#define IME_MODE_KATAKANA 0x0002
#define IME_MODE_HIRAGANA 0x0004
#define IME_MODE_HANJACONVERT 0x0004
#define IME_MODE_DBCSCHAR 0x0010
#define IME_MODE_ROMAN 0x0020
#define IME_MODE_NOROMAN 0x0040
#define IME_MODE_CODEINPUT 0x0080
#define IME_MODE_NOCODEINPUT 0x0100

#define IME_GETIMECAPS 0x03
#define IME_SETOPEN 0x04
#define IME_GETOPEN 0x05
#define IME_GETVERSION 0x07
#define IME_SETCONVERSIONWINDOW 0x08
#define IME_MOVEIMEWINDOW IME_SETCONVERSIONWINDOW
#define IME_SETCONVERSIONMODE 0x10

#define IME_GETCONVERSIONMODE 0x11
#define IME_SET_MODE 0x12
#define IME_SENDVKEY 0x13
#define IME_ENTERWORDREGISTERMODE 0x18
#define IME_SETCONVERSIONFONTEX 0x19

#define IME_BANJAtoJUNJA 0x13
#define IME_JUNJAtoBANJA 0x14
#define IME_JOHABtoKS 0x15
#define IME_KStoJOHAB 0x16

#define IMEA_INIT 0x01
#define IMEA_NEXT 0x02
#define IMEA_PREV 0x03

#define IME_REQUEST_CONVERT 0x01
#define IME_ENABLE_CONVERT 0x02

#define INTERIM_WINDOW 0x00
#define MODE_WINDOW 0x01
#define HANJA_WINDOW 0x02

#define IME_RS_ERROR 0x01
#define IME_RS_NOIME 0x02
#define IME_RS_TOOLONG 0x05
#define IME_RS_ILLEGAL 0x06
#define IME_RS_NOTFOUND 0x07
#define IME_RS_NOROOM 0x0a
#define IME_RS_DISKERROR 0x0e
#define IME_RS_INVALID 0x11
#define IME_RS_NEST 0x12
#define IME_RS_SYSTEMMODAL 0x13

#define WM_IME_REPORT 0x0280

#define IR_STRINGSTART 0x100
#define IR_STRINGEND 0x101
#define IR_OPENCONVERT 0x120
#define IR_CHANGECONVERT 0x121
#define IR_CLOSECONVERT 0x122
#define IR_FULLCONVERT 0x123
#define IR_IMESELECT 0x130
#define IR_STRING 0x140
#define IR_DBCSCHAR 0x160
#define IR_UNDETERMINE 0x170
#define IR_STRINGEX 0x180
#define IR_MODEINFO 0x190

#define WM_WNT_CONVERTREQUESTEX 0x0109
#define WM_CONVERTREQUEST 0x010A
#define WM_CONVERTRESULT 0x010B
#define WM_INTERIM 0x010C

#define WM_IMEKEYDOWN 0x290
#define WM_IMEKEYUP 0x291

  typedef struct tagUNDETERMINESTRUCT {
    DWORD dwSize;
    UINT uDefIMESize;
    UINT uDefIMEPos;
    UINT uUndetTextLen;
    UINT uUndetTextPos;
    UINT uUndetAttrPos;
    UINT uCursorPos;
    UINT uDeltaStart;
    UINT uDetermineTextLen;
    UINT uDetermineTextPos;
    UINT uDetermineDelimPos;
    UINT uYomiTextLen;
    UINT uYomiTextPos;
    UINT uYomiDelimPos;
  } UNDETERMINESTRUCT,*PUNDETERMINESTRUCT,*NPUNDETERMINESTRUCT,*LPUNDETERMINESTRUCT;

  typedef struct tagSTRINGEXSTRUCT {
    DWORD dwSize;
    UINT uDeterminePos;
    UINT uDetermineDelimPos;
    UINT uYomiPos;
    UINT uYomiDelimPos;
  } STRINGEXSTRUCT,*NPSTRINGEXSTRUCT,*LPSTRINGEXSTRUCT;

#ifdef __cplusplus
}
#endif
#endif
