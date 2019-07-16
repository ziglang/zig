/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __HTMLHELP_H__
#define __HTMLHELP_H__

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define HH_DISPLAY_TOPIC 0x0000
#define HH_HELP_FINDER 0x0000
#define HH_DISPLAY_TOC 0x0001
#define HH_DISPLAY_INDEX 0x0002
#define HH_DISPLAY_SEARCH 0x0003
#define HH_SET_WIN_TYPE 0x0004
#define HH_GET_WIN_TYPE 0x0005
#define HH_GET_WIN_HANDLE 0x0006
#define HH_ENUM_INFO_TYPE 0x0007
#define HH_SET_INFO_TYPE 0x0008
#define HH_SYNC 0x0009
#define HH_RESERVED1 0x000A
#define HH_RESERVED2 0x000B
#define HH_RESERVED3 0x000C
#define HH_KEYWORD_LOOKUP 0x000D
#define HH_DISPLAY_TEXT_POPUP 0x000E
#define HH_HELP_CONTEXT 0x000F
#define HH_TP_HELP_CONTEXTMENU 0x0010
#define HH_TP_HELP_WM_HELP 0x0011
#define HH_CLOSE_ALL 0x0012
#define HH_ALINK_LOOKUP 0x0013
#define HH_GET_LAST_ERROR 0x0014
#define HH_ENUM_CATEGORY 0x0015
#define HH_ENUM_CATEGORY_IT 0x0016
#define HH_RESET_IT_FILTER 0x0017
#define HH_SET_INCLUSIVE_FILTER 0x0018
#define HH_SET_EXCLUSIVE_FILTER 0x0019
#define HH_INITIALIZE 0x001C
#define HH_UNINITIALIZE 0x001D
#define HH_SET_QUERYSERVICE 0x001E
#define HH_PRETRANSLATEMESSAGE 0x00fd
#define HH_SET_GLOBAL_PROPERTY 0x00fc
#define HH_SAFE_DISPLAY_TOPIC 0x0020

#define HHWIN_PROP_TAB_AUTOHIDESHOW (1 << 0)
#define HHWIN_PROP_ONTOP (1 << 1)
#define HHWIN_PROP_NOTITLEBAR (1 << 2)
#define HHWIN_PROP_NODEF_STYLES (1 << 3)
#define HHWIN_PROP_NODEF_EXSTYLES (1 << 4)
#define HHWIN_PROP_TRI_PANE (1 << 5)
#define HHWIN_PROP_NOTB_TEXT (1 << 6)
#define HHWIN_PROP_POST_QUIT (1 << 7)
#define HHWIN_PROP_AUTO_SYNC (1 << 8)
#define HHWIN_PROP_TRACKING (1 << 9)
#define HHWIN_PROP_TAB_SEARCH (1 << 10)
#define HHWIN_PROP_TAB_HISTORY (1 << 11)
#define HHWIN_PROP_TAB_FAVORITES (1 << 12)
#define HHWIN_PROP_CHANGE_TITLE (1 << 13)
#define HHWIN_PROP_NAV_ONLY_WIN (1 << 14)
#define HHWIN_PROP_NO_TOOLBAR (1 << 15)
#define HHWIN_PROP_MENU (1 << 16)
#define HHWIN_PROP_TAB_ADVSEARCH (1 << 17)
#define HHWIN_PROP_USER_POS (1 << 18)
#define HHWIN_PROP_TAB_CUSTOM1 (1 << 19)
#define HHWIN_PROP_TAB_CUSTOM2 (1 << 20)
#define HHWIN_PROP_TAB_CUSTOM3 (1 << 21)
#define HHWIN_PROP_TAB_CUSTOM4 (1 << 22)
#define HHWIN_PROP_TAB_CUSTOM5 (1 << 23)
#define HHWIN_PROP_TAB_CUSTOM6 (1 << 24)
#define HHWIN_PROP_TAB_CUSTOM7 (1 << 25)
#define HHWIN_PROP_TAB_CUSTOM8 (1 << 26)
#define HHWIN_PROP_TAB_CUSTOM9 (1 << 27)
#define HHWIN_TB_MARGIN (1 << 28)

#define HHWIN_PARAM_PROPERTIES (1 << 1)
#define HHWIN_PARAM_STYLES (1 << 2)
#define HHWIN_PARAM_EXSTYLES (1 << 3)
#define HHWIN_PARAM_RECT (1 << 4)
#define HHWIN_PARAM_NAV_WIDTH (1 << 5)
#define HHWIN_PARAM_SHOWSTATE (1 << 6)
#define HHWIN_PARAM_INFOTYPES (1 << 7)
#define HHWIN_PARAM_TB_FLAGS (1 << 8)
#define HHWIN_PARAM_EXPANSION (1 << 9)
#define HHWIN_PARAM_TABPOS (1 << 10)
#define HHWIN_PARAM_TABORDER (1 << 11)
#define HHWIN_PARAM_HISTORY_COUNT (1 << 12)
#define HHWIN_PARAM_CUR_TAB (1 << 13)

#define HHWIN_BUTTON_EXPAND (1 << 1)
#define HHWIN_BUTTON_BACK (1 << 2)
#define HHWIN_BUTTON_FORWARD (1 << 3)
#define HHWIN_BUTTON_STOP (1 << 4)
#define HHWIN_BUTTON_REFRESH (1 << 5)
#define HHWIN_BUTTON_HOME (1 << 6)
#define HHWIN_BUTTON_BROWSE_FWD (1 << 7)
#define HHWIN_BUTTON_BROWSE_BCK (1 << 8)
#define HHWIN_BUTTON_NOTES (1 << 9)
#define HHWIN_BUTTON_CONTENTS (1 << 10)
#define HHWIN_BUTTON_SYNC (1 << 11)
#define HHWIN_BUTTON_OPTIONS (1 << 12)
#define HHWIN_BUTTON_PRINT (1 << 13)
#define HHWIN_BUTTON_INDEX (1 << 14)
#define HHWIN_BUTTON_SEARCH (1 << 15)
#define HHWIN_BUTTON_HISTORY (1 << 16)
#define HHWIN_BUTTON_FAVORITES (1 << 17)
#define HHWIN_BUTTON_JUMP1 (1 << 18)
#define HHWIN_BUTTON_JUMP2 (1 << 19)
#define HHWIN_BUTTON_ZOOM (1 << 20)
#define HHWIN_BUTTON_TOC_NEXT (1 << 21)
#define HHWIN_BUTTON_TOC_PREV (1 << 22)

#define HHWIN_DEF_BUTTONS (HHWIN_BUTTON_EXPAND | HHWIN_BUTTON_BACK | HHWIN_BUTTON_OPTIONS | HHWIN_BUTTON_PRINT)

#define IDTB_EXPAND 200
#define IDTB_CONTRACT 201
#define IDTB_STOP 202
#define IDTB_REFRESH 203
#define IDTB_BACK 204
#define IDTB_HOME 205
#define IDTB_SYNC 206
#define IDTB_PRINT 207
#define IDTB_OPTIONS 208
#define IDTB_FORWARD 209
#define IDTB_NOTES 210
#define IDTB_BROWSE_FWD 211
#define IDTB_BROWSE_BACK 212
#define IDTB_CONTENTS 213
#define IDTB_INDEX 214
#define IDTB_SEARCH 215
#define IDTB_HISTORY 216
#define IDTB_FAVORITES 217
#define IDTB_JUMP1 218
#define IDTB_JUMP2 219
#define IDTB_CUSTOMIZE 221
#define IDTB_ZOOM 222
#define IDTB_TOC_NEXT 223
#define IDTB_TOC_PREV 224

#define HHN_FIRST (0U-860U)
#define HHN_LAST (0U-879U)

#define HHN_NAVCOMPLETE (HHN_FIRST-0)
#define HHN_TRACK (HHN_FIRST-1)
#define HHN_WINDOW_CREATE (HHN_FIRST-2)

  typedef struct tagHHN_NOTIFY {
    NMHDR hdr;
    PCSTR pszUrl;
  } HHN_NOTIFY;

  typedef struct tagHH_POPUP {
    int cbStruct;
    HINSTANCE hinst;
    UINT idString;
    LPCTSTR pszText;
    POINT pt;
    COLORREF clrForeground;
    COLORREF clrBackground;
    RECT rcMargins;
    LPCTSTR pszFont;
  } HH_POPUP;

  typedef struct tagHH_AKLINK {
    int cbStruct;
    WINBOOL fReserved;
    LPCTSTR pszKeywords;
    LPCTSTR pszUrl;
    LPCTSTR pszMsgText;
    LPCTSTR pszMsgTitle;
    LPCTSTR pszWindow;
    WINBOOL fIndexOnFail;
  } HH_AKLINK;

  enum {
    HHWIN_NAVTYPE_TOC,HHWIN_NAVTYPE_INDEX,HHWIN_NAVTYPE_SEARCH,HHWIN_NAVTYPE_FAVORITES,HHWIN_NAVTYPE_HISTORY,HHWIN_NAVTYPE_AUTHOR,
    HHWIN_NAVTYPE_CUSTOM_FIRST = 11
  };

  enum {
    IT_INCLUSIVE,IT_EXCLUSIVE,IT_HIDDEN
  };

  typedef struct tagHH_ENUM_IT {
    int cbStruct;
    int iType;
    LPCSTR pszCatName;
    LPCSTR pszITName;
    LPCSTR pszITDescription;
  } HH_ENUM_IT,*PHH_ENUM_IT;

  typedef struct tagHH_ENUM_CAT {
    int cbStruct;
    LPCSTR pszCatName;
    LPCSTR pszCatDescription;
  } HH_ENUM_CAT,*PHH_ENUM_CAT;

  typedef struct tagHH_SET_INFOTYPE {
    int cbStruct;
    LPCSTR pszCatName;
    LPCSTR pszInfoTypeName;
  } HH_SET_INFOTYPE,*PHH_SET_INFOTYPE;

  typedef DWORD HH_INFOTYPE;
  typedef HH_INFOTYPE *PHH_INFOTYPE;

  enum {
    HHWIN_NAVTAB_TOP,HHWIN_NAVTAB_LEFT,HHWIN_NAVTAB_BOTTOM
  };

#define HH_MAX_TABS 19

  enum {
    HH_TAB_CONTENTS,HH_TAB_INDEX,HH_TAB_SEARCH,HH_TAB_FAVORITES,HH_TAB_HISTORY,HH_TAB_AUTHOR,HH_TAB_CUSTOM_FIRST = 11,
    HH_TAB_CUSTOM_LAST = HH_MAX_TABS
  };

#define HH_MAX_TABS_CUSTOM (HH_TAB_CUSTOM_LAST - HH_TAB_CUSTOM_FIRST + 1)

#define HH_FTS_DEFAULT_PROXIMITY (-1)

  typedef struct tagHH_FTS_QUERY {
    int cbStruct;
    WINBOOL fUniCodeStrings;
    LPCTSTR pszSearchQuery;
    LONG iProximity;
    WINBOOL fStemmedSearch;
    WINBOOL fTitleOnly;
    WINBOOL fExecute;
    LPCTSTR pszWindow;
  } HH_FTS_QUERY;

  typedef struct tagHH_WINTYPE {
    int cbStruct;
    WINBOOL fUniCodeStrings;
    LPCTSTR pszType;
    DWORD fsValidMembers;
    DWORD fsWinProperties;
    LPCTSTR pszCaption;
    DWORD dwStyles;
    DWORD dwExStyles;
    RECT rcWindowPos;
    int nShowState;
    HWND hwndHelp;
    HWND hwndCaller;
    HH_INFOTYPE *paInfoTypes;
    HWND hwndToolBar;
    HWND hwndNavigation;
    HWND hwndHTML;
    int iNavWidth;
    RECT rcHTML;
    LPCTSTR pszToc;
    LPCTSTR pszIndex;
    LPCTSTR pszFile;
    LPCTSTR pszHome;
    DWORD fsToolBarFlags;
    WINBOOL fNotExpanded;
    int curNavType;
    int tabpos;
    int idNotify;
    BYTE tabOrder[HH_MAX_TABS + 1];
    int cHistory;
    LPCTSTR pszJump1;
    LPCTSTR pszJump2;
    LPCTSTR pszUrlJump1;
    LPCTSTR pszUrlJump2;
    RECT rcMinSize;
    int cbInfoTypes;
    LPCTSTR pszCustomTabs;
  } HH_WINTYPE,*PHH_WINTYPE;

  enum {
    HHACT_TAB_CONTENTS,HHACT_TAB_INDEX,HHACT_TAB_SEARCH,HHACT_TAB_HISTORY,HHACT_TAB_FAVORITES,HHACT_EXPAND,HHACT_CONTRACT,
    HHACT_BACK,HHACT_FORWARD,HHACT_STOP,HHACT_REFRESH,HHACT_HOME,HHACT_SYNC,HHACT_OPTIONS,HHACT_PRINT,HHACT_HIGHLIGHT,HHACT_CUSTOMIZE,
    HHACT_JUMP1,HHACT_JUMP2,HHACT_ZOOM,HHACT_TOC_NEXT,HHACT_TOC_PREV,HHACT_NOTES,HHACT_LAST_ENUM
  };

  typedef struct tagHHNTRACK {
    NMHDR hdr;
    PCSTR pszCurUrl;
    int idAction;
    HH_WINTYPE *phhWinType;
  } HHNTRACK;

#define HtmlHelp __MINGW_NAME_AW(HtmlHelp)

  HWND WINAPI HtmlHelpA(HWND hwndCaller,LPCSTR pszFile,UINT uCommand,DWORD_PTR dwData);
  HWND WINAPI HtmlHelpW(HWND hwndCaller,LPCWSTR pszFile,UINT uCommand,DWORD_PTR dwData);

#define ATOM_HTMLHELP_API_ANSI (LPTSTR)((DWORD)((WORD)(14)))
#define ATOM_HTMLHELP_API_UNICODE (LPTSTR)((DWORD)((WORD)(15)))

  typedef enum tagHH_GPROPID {
    HH_GPROPID_SINGLETHREAD=1,HH_GPROPID_TOOLBAR_MARGIN=2,HH_GPROPID_UI_LANGUAGE=3,HH_GPROPID_CURRENT_SUBSET=4,HH_GPROPID_CONTENT_LANGUAGE=5
  } HH_GPROPID;

#ifdef __oaidl_h__
#pragma pack(push,8)

  typedef struct tagHH_GLOBAL_PROPERTY {
    HH_GPROPID id;
    VARIANT var;
  } HH_GLOBAL_PROPERTY;

#pragma pack(pop)
#endif

#ifdef __cplusplus
}
#endif
#endif
