/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */

#include <winapifamily.h>

#ifndef _INC_COMMDLG
#define _INC_COMMDLG

#include <_mingw_unicode.h>

#ifdef DEFINE_GUID
DEFINE_GUID(IID_IPrintDialogCallback,0x5852a2c3,0x6530,0x11d1,0xb6,0xa3,0x0,0x0,0xf8,0x75,0x7b,0xf9);
DEFINE_GUID(IID_IPrintDialogServices,0x509aaeda,0x5639,0x11d1,0xb6,0xa1,0x0,0x0,0xf8,0x75,0x7b,0xf9);
#endif

#ifndef GUID_DEFS_ONLY
#include <prsht.h>
#if !defined(_WIN64)
#include <pshpack1.h>
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#ifdef __cplusplus
extern "C" {
#endif

#ifndef WINCOMMDLGAPI
#ifndef _COMDLG32_
#define WINCOMMDLGAPI DECLSPEC_IMPORT
#else
#define WINCOMMDLGAPI
#endif
#endif

#ifndef SNDMSG
#ifdef __cplusplus
#define SNDMSG ::SendMessage
#else
#define SNDMSG SendMessage
#endif
#endif

  typedef UINT_PTR (CALLBACK *LPOFNHOOKPROC) (HWND,UINT,WPARAM,LPARAM);

#ifndef CDSIZEOF_STRUCT
#define CDSIZEOF_STRUCT(structname,member) (((int)((LPBYTE)(&((structname*)0)->member) - ((LPBYTE)((structname*)0)))) + sizeof(((structname*)0)->member))
#endif

  typedef struct tagOFN_NT4A {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    LPCSTR lpstrFilter;
    LPSTR lpstrCustomFilter;
    DWORD nMaxCustFilter;
    DWORD nFilterIndex;
    LPSTR lpstrFile;
    DWORD nMaxFile;
    LPSTR lpstrFileTitle;
    DWORD nMaxFileTitle;
    LPCSTR lpstrInitialDir;
    LPCSTR lpstrTitle;
    DWORD Flags;
    WORD nFileOffset;
    WORD nFileExtension;
    LPCSTR lpstrDefExt;
    LPARAM lCustData;
    LPOFNHOOKPROC lpfnHook;
    LPCSTR lpTemplateName;
  } OPENFILENAME_NT4A,*LPOPENFILENAME_NT4A;
  typedef struct tagOFN_NT4W {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    LPCWSTR lpstrFilter;
    LPWSTR lpstrCustomFilter;
    DWORD nMaxCustFilter;
    DWORD nFilterIndex;
    LPWSTR lpstrFile;
    DWORD nMaxFile;
    LPWSTR lpstrFileTitle;
    DWORD nMaxFileTitle;
    LPCWSTR lpstrInitialDir;
    LPCWSTR lpstrTitle;
    DWORD Flags;
    WORD nFileOffset;
    WORD nFileExtension;
    LPCWSTR lpstrDefExt;
    LPARAM lCustData;
    LPOFNHOOKPROC lpfnHook;
    LPCWSTR lpTemplateName;
  } OPENFILENAME_NT4W,*LPOPENFILENAME_NT4W;

  __MINGW_TYPEDEF_AW(OPENFILENAME_NT4)
  __MINGW_TYPEDEF_AW(LPOPENFILENAME_NT4)

  typedef struct tagOFNA {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    LPCSTR lpstrFilter;
    LPSTR lpstrCustomFilter;
    DWORD nMaxCustFilter;
    DWORD nFilterIndex;
    LPSTR lpstrFile;
    DWORD nMaxFile;
    LPSTR lpstrFileTitle;
    DWORD nMaxFileTitle;
    LPCSTR lpstrInitialDir;
    LPCSTR lpstrTitle;
    DWORD Flags;
    WORD nFileOffset;
    WORD nFileExtension;
    LPCSTR lpstrDefExt;
    LPARAM lCustData;
    LPOFNHOOKPROC lpfnHook;
    LPCSTR lpTemplateName;
    void *pvReserved;
    DWORD dwReserved;
    DWORD FlagsEx;
  } OPENFILENAMEA,*LPOPENFILENAMEA;
  typedef struct tagOFNW {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    LPCWSTR lpstrFilter;
    LPWSTR lpstrCustomFilter;
    DWORD nMaxCustFilter;
    DWORD nFilterIndex;
    LPWSTR lpstrFile;
    DWORD nMaxFile;
    LPWSTR lpstrFileTitle;
    DWORD nMaxFileTitle;
    LPCWSTR lpstrInitialDir;
    LPCWSTR lpstrTitle;
    DWORD Flags;
    WORD nFileOffset;
    WORD nFileExtension;
    LPCWSTR lpstrDefExt;
    LPARAM lCustData;
    LPOFNHOOKPROC lpfnHook;
    LPCWSTR lpTemplateName;
    void *pvReserved;
    DWORD dwReserved;
    DWORD FlagsEx;
  } OPENFILENAMEW,*LPOPENFILENAMEW;

  __MINGW_TYPEDEF_AW(OPENFILENAME)
  __MINGW_TYPEDEF_AW(LPOPENFILENAME)

#define OPENFILENAME_SIZE_VERSION_400A CDSIZEOF_STRUCT(OPENFILENAMEA,lpTemplateName)
#define OPENFILENAME_SIZE_VERSION_400W CDSIZEOF_STRUCT(OPENFILENAMEW,lpTemplateName)

#define OPENFILENAME_SIZE_VERSION_400 __MINGW_NAME_AW(OPENFILENAME_SIZE_VERSION_400)

  WINCOMMDLGAPI WINBOOL WINAPI GetOpenFileNameA(LPOPENFILENAMEA);
  WINCOMMDLGAPI WINBOOL WINAPI GetOpenFileNameW(LPOPENFILENAMEW);

#define GetOpenFileName __MINGW_NAME_AW(GetOpenFileName)

  WINCOMMDLGAPI WINBOOL WINAPI GetSaveFileNameA(LPOPENFILENAMEA);
  WINCOMMDLGAPI WINBOOL WINAPI GetSaveFileNameW(LPOPENFILENAMEW);

#define GetSaveFileName __MINGW_NAME_AW(GetSaveFileName)

  WINCOMMDLGAPI short WINAPI GetFileTitleA(LPCSTR,LPSTR,WORD);
  WINCOMMDLGAPI short WINAPI GetFileTitleW(LPCWSTR,LPWSTR,WORD);

#define GetFileTitle __MINGW_NAME_AW(GetFileTitle)

#define OFN_READONLY 0x1
#define OFN_OVERWRITEPROMPT 0x2
#define OFN_HIDEREADONLY 0x4
#define OFN_NOCHANGEDIR 0x8
#define OFN_SHOWHELP 0x10
#define OFN_ENABLEHOOK 0x20
#define OFN_ENABLETEMPLATE 0x40
#define OFN_ENABLETEMPLATEHANDLE 0x80
#define OFN_NOVALIDATE 0x100
#define OFN_ALLOWMULTISELECT 0x200
#define OFN_EXTENSIONDIFFERENT 0x400
#define OFN_PATHMUSTEXIST 0x800
#define OFN_FILEMUSTEXIST 0x1000
#define OFN_CREATEPROMPT 0x2000
#define OFN_SHAREAWARE 0x4000
#define OFN_NOREADONLYRETURN 0x8000
#define OFN_NOTESTFILECREATE 0x10000
#define OFN_NONETWORKBUTTON 0x20000
#define OFN_NOLONGNAMES 0x40000
#define OFN_EXPLORER 0x80000
#define OFN_NODEREFERENCELINKS 0x100000
#define OFN_LONGNAMES 0x200000
#define OFN_ENABLEINCLUDENOTIFY 0x400000
#define OFN_ENABLESIZING 0x800000
#define OFN_DONTADDTORECENT 0x2000000
#define OFN_FORCESHOWHIDDEN 0x10000000
#define OFN_EX_NOPLACESBAR 0x1
#define OFN_SHAREFALLTHROUGH 2
#define OFN_SHARENOWARN 1
#define OFN_SHAREWARN 0

  typedef UINT_PTR (CALLBACK *LPCCHOOKPROC) (HWND,UINT,WPARAM,LPARAM);

  typedef struct _OFNOTIFYA {
    NMHDR hdr;
    LPOPENFILENAMEA lpOFN;
    LPSTR pszFile;
  } OFNOTIFYA,*LPOFNOTIFYA;

  typedef struct _OFNOTIFYW {
    NMHDR hdr;
    LPOPENFILENAMEW lpOFN;
    LPWSTR pszFile;
  } OFNOTIFYW,*LPOFNOTIFYW;

  __MINGW_TYPEDEF_AW(OFNOTIFY)
  __MINGW_TYPEDEF_AW(LPOFNOTIFY)

  typedef struct _OFNOTIFYEXA {
    NMHDR hdr;
    LPOPENFILENAMEA lpOFN;
    LPVOID psf;
    LPVOID pidl;
  } OFNOTIFYEXA,*LPOFNOTIFYEXA;

  typedef struct _OFNOTIFYEXW {
    NMHDR hdr;
    LPOPENFILENAMEW lpOFN;
    LPVOID psf;
    LPVOID pidl;
  } OFNOTIFYEXW,*LPOFNOTIFYEXW;

  __MINGW_TYPEDEF_AW(OFNOTIFYEX)
  __MINGW_TYPEDEF_AW(LPOFNOTIFYEX)

#define CDN_FIRST (0U-601U)
#define CDN_LAST (0U-699U)

#define CDN_INITDONE (CDN_FIRST)
#define CDN_SELCHANGE (CDN_FIRST - 1)
#define CDN_FOLDERCHANGE (CDN_FIRST - 2)
#define CDN_SHAREVIOLATION (CDN_FIRST - 3)
#define CDN_HELP (CDN_FIRST - 4)
#define CDN_FILEOK (CDN_FIRST - 5)
#define CDN_TYPECHANGE (CDN_FIRST - 6)
#define CDN_INCLUDEITEM (CDN_FIRST - 7)

#define CDM_FIRST (WM_USER + 100)
#define CDM_LAST (WM_USER + 200)

#define CDM_GETSPEC (CDM_FIRST)
#define CommDlg_OpenSave_GetSpecA(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETSPEC,(WPARAM)_cbmax,(LPARAM)(LPSTR)_psz)
#define CommDlg_OpenSave_GetSpecW(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETSPEC,(WPARAM)_cbmax,(LPARAM)(LPWSTR)_psz)

#define CommDlg_OpenSave_GetSpec __MINGW_NAME_AW(CommDlg_OpenSave_GetSpec)

#define CDM_GETFILEPATH (CDM_FIRST + 1)
#define CommDlg_OpenSave_GetFilePathA(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETFILEPATH,(WPARAM)_cbmax,(LPARAM)(LPSTR)_psz)
#define CommDlg_OpenSave_GetFilePathW(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETFILEPATH,(WPARAM)_cbmax,(LPARAM)(LPWSTR)_psz)

#define CommDlg_OpenSave_GetFilePath __MINGW_NAME_AW(CommDlg_OpenSave_GetFilePath)

#define CDM_GETFOLDERPATH (CDM_FIRST + 2)
#define CommDlg_OpenSave_GetFolderPathA(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETFOLDERPATH,(WPARAM)_cbmax,(LPARAM)(LPSTR)_psz)
#define CommDlg_OpenSave_GetFolderPathW(_hdlg,_psz,_cbmax) (int)SNDMSG(_hdlg,CDM_GETFOLDERPATH,(WPARAM)_cbmax,(LPARAM)(LPWSTR)_psz)

#define CommDlg_OpenSave_GetFolderPath __MINGW_NAME_AW(CommDlg_OpenSave_GetFolderPath)

#define CDM_GETFOLDERIDLIST (CDM_FIRST + 3)
#define CommDlg_OpenSave_GetFolderIDList(_hdlg,_pidl,_cbmax) (int)SNDMSG(_hdlg,CDM_GETFOLDERIDLIST,(WPARAM)_cbmax,(LPARAM)(LPVOID)_pidl)
#define CDM_SETCONTROLTEXT (CDM_FIRST + 4)
#define CommDlg_OpenSave_SetControlText(_hdlg,_id,_text) (void)SNDMSG(_hdlg,CDM_SETCONTROLTEXT,(WPARAM)_id,(LPARAM)(LPSTR)_text)
#define CDM_HIDECONTROL (CDM_FIRST + 5)
#define CommDlg_OpenSave_HideControl(_hdlg,_id) (void)SNDMSG(_hdlg,CDM_HIDECONTROL,(WPARAM)_id,0)
#define CDM_SETDEFEXT (CDM_FIRST + 6)
#define CommDlg_OpenSave_SetDefExt(_hdlg,_pszext) (void)SNDMSG(_hdlg,CDM_SETDEFEXT,0,(LPARAM)(LPSTR)_pszext)

  typedef struct tagCHOOSECOLORA {
    DWORD lStructSize;
    HWND hwndOwner;
    HWND hInstance;
    COLORREF rgbResult;
    COLORREF *lpCustColors;
    DWORD Flags;
    LPARAM lCustData;
    LPCCHOOKPROC lpfnHook;
    LPCSTR lpTemplateName;
  } CHOOSECOLORA,*LPCHOOSECOLORA;
  typedef struct tagCHOOSECOLORW {
    DWORD lStructSize;
    HWND hwndOwner;
    HWND hInstance;
    COLORREF rgbResult;
    COLORREF *lpCustColors;
    DWORD Flags;
    LPARAM lCustData;
    LPCCHOOKPROC lpfnHook;
    LPCWSTR lpTemplateName;
  } CHOOSECOLORW,*LPCHOOSECOLORW;

  __MINGW_TYPEDEF_AW(CHOOSECOLOR)
  __MINGW_TYPEDEF_AW(LPCHOOSECOLOR)

  WINCOMMDLGAPI WINBOOL WINAPI ChooseColorA(LPCHOOSECOLORA);
  WINCOMMDLGAPI WINBOOL WINAPI ChooseColorW(LPCHOOSECOLORW);

#define ChooseColor __MINGW_NAME_AW(ChooseColor)

#define CC_RGBINIT 0x1
#define CC_FULLOPEN 0x2
#define CC_PREVENTFULLOPEN 0x4
#define CC_SHOWHELP 0x8
#define CC_ENABLEHOOK 0x10
#define CC_ENABLETEMPLATE 0x20
#define CC_ENABLETEMPLATEHANDLE 0x40
#define CC_SOLIDCOLOR 0x80
#define CC_ANYCOLOR 0x100

  typedef UINT_PTR (CALLBACK *LPFRHOOKPROC) (HWND,UINT,WPARAM,LPARAM);

  typedef struct tagFINDREPLACEA {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    DWORD Flags;
    LPSTR lpstrFindWhat;
    LPSTR lpstrReplaceWith;
    WORD wFindWhatLen;
    WORD wReplaceWithLen;
    LPARAM lCustData;
    LPFRHOOKPROC lpfnHook;
    LPCSTR lpTemplateName;
  } FINDREPLACEA,*LPFINDREPLACEA;

  typedef struct tagFINDREPLACEW {
    DWORD lStructSize;
    HWND hwndOwner;
    HINSTANCE hInstance;
    DWORD Flags;
    LPWSTR lpstrFindWhat;
    LPWSTR lpstrReplaceWith;
    WORD wFindWhatLen;
    WORD wReplaceWithLen;
    LPARAM lCustData;
    LPFRHOOKPROC lpfnHook;
    LPCWSTR lpTemplateName;
  } FINDREPLACEW,*LPFINDREPLACEW;

  __MINGW_TYPEDEF_AW(FINDREPLACE)
  __MINGW_TYPEDEF_AW(LPFINDREPLACE)

#define FR_DOWN 0x1
#define FR_WHOLEWORD 0x2
#define FR_MATCHCASE 0x4
#define FR_FINDNEXT 0x8
#define FR_REPLACE 0x10
#define FR_REPLACEALL 0x20
#define FR_DIALOGTERM 0x40
#define FR_SHOWHELP 0x80
#define FR_ENABLEHOOK 0x100
#define FR_ENABLETEMPLATE 0x200
#define FR_NOUPDOWN 0x400
#define FR_NOMATCHCASE 0x800
#define FR_NOWHOLEWORD 0x1000
#define FR_ENABLETEMPLATEHANDLE 0x2000
#define FR_HIDEUPDOWN 0x4000
#define FR_HIDEMATCHCASE 0x8000
#define FR_HIDEWHOLEWORD 0x10000
#define FR_RAW 0x20000
#define FR_MATCHDIAC 0x20000000
#define FR_MATCHKASHIDA 0x40000000
#define FR_MATCHALEFHAMZA 0x80000000

  WINCOMMDLGAPI HWND WINAPI FindTextA(LPFINDREPLACEA);
  WINCOMMDLGAPI HWND WINAPI FindTextW(LPFINDREPLACEW);

#define FindText __MINGW_NAME_AW(FindText)

  WINCOMMDLGAPI HWND WINAPI ReplaceTextA(LPFINDREPLACEA);
  WINCOMMDLGAPI HWND WINAPI ReplaceTextW(LPFINDREPLACEW);

#define ReplaceText __MINGW_NAME_AW(ReplaceText)

  typedef UINT_PTR (CALLBACK *LPCFHOOKPROC) (HWND,UINT,WPARAM,LPARAM);

  typedef struct tagCHOOSEFONTA {
    DWORD lStructSize;
    HWND hwndOwner;
    HDC hDC;
    LPLOGFONTA lpLogFont;
    INT iPointSize;
    DWORD Flags;
    COLORREF rgbColors;
    LPARAM lCustData;
    LPCFHOOKPROC lpfnHook;
    LPCSTR lpTemplateName;
    HINSTANCE hInstance;
    LPSTR lpszStyle;
    WORD nFontType;
    WORD ___MISSING_ALIGNMENT__;
    INT nSizeMin;
    INT nSizeMax;
  } CHOOSEFONTA,*LPCHOOSEFONTA;

  typedef struct tagCHOOSEFONTW {
    DWORD lStructSize;
    HWND hwndOwner;
    HDC hDC;
    LPLOGFONTW lpLogFont;
    INT iPointSize;
    DWORD Flags;
    COLORREF rgbColors;
    LPARAM lCustData;
    LPCFHOOKPROC lpfnHook;
    LPCWSTR lpTemplateName;
    HINSTANCE hInstance;
    LPWSTR lpszStyle;
    WORD nFontType;
    WORD ___MISSING_ALIGNMENT__;
    INT nSizeMin;
    INT nSizeMax;
  } CHOOSEFONTW,*LPCHOOSEFONTW;

  __MINGW_TYPEDEF_AW(CHOOSEFONT)
  __MINGW_TYPEDEF_AW(LPCHOOSEFONT)

  WINCOMMDLGAPI WINBOOL WINAPI ChooseFontA(LPCHOOSEFONTA);
  WINCOMMDLGAPI WINBOOL WINAPI ChooseFontW(LPCHOOSEFONTW);

#define ChooseFont __MINGW_NAME_AW(ChooseFont)

#define CF_SCREENFONTS 0x1
#define CF_PRINTERFONTS 0x2
#define CF_BOTH (CF_SCREENFONTS | CF_PRINTERFONTS)
#define CF_SHOWHELP __MSABI_LONG(0x4)
#define CF_ENABLEHOOK __MSABI_LONG(0x8)
#define CF_ENABLETEMPLATE __MSABI_LONG(0x10)
#define CF_ENABLETEMPLATEHANDLE __MSABI_LONG(0x20)
#define CF_INITTOLOGFONTSTRUCT __MSABI_LONG(0x40)
#define CF_USESTYLE __MSABI_LONG(0x80)
#define CF_EFFECTS __MSABI_LONG(0x100)
#define CF_APPLY __MSABI_LONG(0x200)
#define CF_ANSIONLY __MSABI_LONG(0x400)
#define CF_SCRIPTSONLY CF_ANSIONLY
#define CF_NOVECTORFONTS __MSABI_LONG(0x800)
#define CF_NOOEMFONTS CF_NOVECTORFONTS
#define CF_NOSIMULATIONS __MSABI_LONG(0x1000)
#define CF_LIMITSIZE __MSABI_LONG(0x2000)
#define CF_FIXEDPITCHONLY __MSABI_LONG(0x4000)
#define CF_WYSIWYG __MSABI_LONG(0x8000)
#define CF_FORCEFONTEXIST __MSABI_LONG(0x10000)
#define CF_SCALABLEONLY __MSABI_LONG(0x20000)
#define CF_TTONLY __MSABI_LONG(0x40000)
#define CF_NOFACESEL __MSABI_LONG(0x80000)
#define CF_NOSTYLESEL __MSABI_LONG(0x100000)
#define CF_NOSIZESEL __MSABI_LONG(0x200000)
#define CF_SELECTSCRIPT __MSABI_LONG(0x400000)
#define CF_NOSCRIPTSEL __MSABI_LONG(0x800000)
#define CF_NOVERTFONTS __MSABI_LONG(0x1000000)
#if WINVER >= 0x0601
#define CF_INACTIVEFONTS __MSABI_LONG (0x02000000)
#endif

#define SIMULATED_FONTTYPE 0x8000
#define PRINTER_FONTTYPE 0x4000
#define SCREEN_FONTTYPE 0x2000
#define BOLD_FONTTYPE 0x100
#define ITALIC_FONTTYPE 0x200
#define REGULAR_FONTTYPE 0x400

#ifdef WINNT
#define PS_OPENTYPE_FONTTYPE 0x10000
#define TT_OPENTYPE_FONTTYPE 0x20000
#define TYPE1_FONTTYPE 0x40000
#if WINVER >= 0x0601
#define SYMBOL_FONTTYPE 0x80000
#endif
#endif

#define WM_CHOOSEFONT_GETLOGFONT (WM_USER + 1)
#define WM_CHOOSEFONT_SETLOGFONT (WM_USER + 101)
#define WM_CHOOSEFONT_SETFLAGS (WM_USER + 102)

#define LBSELCHSTRINGA "commdlg_LBSelChangedNotify"
#define SHAREVISTRINGA "commdlg_ShareViolation"
#define FILEOKSTRINGA "commdlg_FileNameOK"
#define COLOROKSTRINGA "commdlg_ColorOK"
#define SETRGBSTRINGA "commdlg_SetRGBColor"
#define HELPMSGSTRINGA "commdlg_help"
#define FINDMSGSTRINGA "commdlg_FindReplace"

#define LBSELCHSTRINGW L"commdlg_LBSelChangedNotify"
#define SHAREVISTRINGW L"commdlg_ShareViolation"
#define FILEOKSTRINGW L"commdlg_FileNameOK"
#define COLOROKSTRINGW L"commdlg_ColorOK"
#define SETRGBSTRINGW L"commdlg_SetRGBColor"
#define HELPMSGSTRINGW L"commdlg_help"
#define FINDMSGSTRINGW L"commdlg_FindReplace"

#define LBSELCHSTRING __MINGW_NAME_AW(LBSELCHSTRING)
#define SHAREVISTRING __MINGW_NAME_AW(SHAREVISTRING)
#define FILEOKSTRING __MINGW_NAME_AW(FILEOKSTRING)
#define COLOROKSTRING __MINGW_NAME_AW(COLOROKSTRING)
#define SETRGBSTRING __MINGW_NAME_AW(SETRGBSTRING)
#define HELPMSGSTRING __MINGW_NAME_AW(HELPMSGSTRING)
#define FINDMSGSTRING __MINGW_NAME_AW(FINDMSGSTRING)

#define CD_LBSELNOITEMS -1
#define CD_LBSELCHANGE 0
#define CD_LBSELSUB 1
#define CD_LBSELADD 2

  typedef UINT_PTR (CALLBACK *LPPRINTHOOKPROC) (HWND,UINT,WPARAM,LPARAM);
  typedef UINT_PTR (CALLBACK *LPSETUPHOOKPROC) (HWND,UINT,WPARAM,LPARAM);

  typedef struct tagPDA {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    HDC hDC;
    DWORD Flags;
    WORD nFromPage;
    WORD nToPage;
    WORD nMinPage;
    WORD nMaxPage;
    WORD nCopies;
    HINSTANCE hInstance;
    LPARAM lCustData;
    LPPRINTHOOKPROC lpfnPrintHook;
    LPSETUPHOOKPROC lpfnSetupHook;
    LPCSTR lpPrintTemplateName;
    LPCSTR lpSetupTemplateName;
    HGLOBAL hPrintTemplate;
    HGLOBAL hSetupTemplate;
  } PRINTDLGA,*LPPRINTDLGA;

  typedef struct tagPDW {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    HDC hDC;
    DWORD Flags;
    WORD nFromPage;
    WORD nToPage;
    WORD nMinPage;
    WORD nMaxPage;
    WORD nCopies;
    HINSTANCE hInstance;
    LPARAM lCustData;
    LPPRINTHOOKPROC lpfnPrintHook;
    LPSETUPHOOKPROC lpfnSetupHook;
    LPCWSTR lpPrintTemplateName;
    LPCWSTR lpSetupTemplateName;
    HGLOBAL hPrintTemplate;
    HGLOBAL hSetupTemplate;
  } PRINTDLGW,*LPPRINTDLGW;

  __MINGW_TYPEDEF_AW(PRINTDLG)
  __MINGW_TYPEDEF_AW(LPPRINTDLG)

  WINCOMMDLGAPI WINBOOL WINAPI PrintDlgA(LPPRINTDLGA);
  WINCOMMDLGAPI WINBOOL WINAPI PrintDlgW(LPPRINTDLGW);

#define PrintDlg __MINGW_NAME_AW(PrintDlg)

#ifdef STDMETHOD
#undef INTERFACE
#define INTERFACE IPrintDialogCallback

  DECLARE_INTERFACE_(IPrintDialogCallback,IUnknown) {
#ifndef __cplusplus
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
#endif
    STDMETHOD(InitDone) (THIS) PURE;
    STDMETHOD(SelectionChange) (THIS) PURE;
    STDMETHOD(HandleMessage) (THIS_ HWND hDlg,UINT uMsg,WPARAM wParam,LPARAM lParam,LRESULT *pResult) PURE;
  };

#undef INTERFACE
#define INTERFACE IPrintDialogServices
  DECLARE_INTERFACE_(IPrintDialogServices,IUnknown) {
#ifndef __cplusplus
    STDMETHOD(QueryInterface) (THIS_ REFIID riid,LPVOID *ppvObj) PURE;
    STDMETHOD_(ULONG,AddRef) (THIS) PURE;
    STDMETHOD_(ULONG,Release) (THIS) PURE;
#endif
    STDMETHOD(GetCurrentDevMode) (THIS_ LPDEVMODE pDevMode,UINT *pcbSize) PURE;
    STDMETHOD(GetCurrentPrinterName) (THIS_ LPTSTR pPrinterName,UINT *pcchSize) PURE;
    STDMETHOD(GetCurrentPortName) (THIS_ LPTSTR pPortName,UINT *pcchSize) PURE;
  };

  typedef struct tagPRINTPAGERANGE {
    DWORD nFromPage;
    DWORD nToPage;
  } PRINTPAGERANGE,*LPPRINTPAGERANGE;

  typedef struct tagPDEXA {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    HDC hDC;
    DWORD Flags;
    DWORD Flags2;
    DWORD ExclusionFlags;
    DWORD nPageRanges;
    DWORD nMaxPageRanges;
    LPPRINTPAGERANGE lpPageRanges;
    DWORD nMinPage;
    DWORD nMaxPage;
    DWORD nCopies;
    HINSTANCE hInstance;
    LPCSTR lpPrintTemplateName;
    LPUNKNOWN lpCallback;
    DWORD nPropertyPages;
    HPROPSHEETPAGE *lphPropertyPages;
    DWORD nStartPage;
    DWORD dwResultAction;
  } PRINTDLGEXA,*LPPRINTDLGEXA;

  typedef struct tagPDEXW {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    HDC hDC;
    DWORD Flags;
    DWORD Flags2;
    DWORD ExclusionFlags;
    DWORD nPageRanges;
    DWORD nMaxPageRanges;
    LPPRINTPAGERANGE lpPageRanges;
    DWORD nMinPage;
    DWORD nMaxPage;
    DWORD nCopies;
    HINSTANCE hInstance;
    LPCWSTR lpPrintTemplateName;
    LPUNKNOWN lpCallback;
    DWORD nPropertyPages;
    HPROPSHEETPAGE *lphPropertyPages;
    DWORD nStartPage;
    DWORD dwResultAction;
  } PRINTDLGEXW,*LPPRINTDLGEXW;

  __MINGW_TYPEDEF_AW(PRINTDLGEX)
  __MINGW_TYPEDEF_AW(LPPRINTDLGEX)

  WINCOMMDLGAPI HRESULT WINAPI PrintDlgExA(LPPRINTDLGEXA);
  WINCOMMDLGAPI HRESULT WINAPI PrintDlgExW(LPPRINTDLGEXW);

#define PrintDlgEx __MINGW_NAME_AW(PrintDlgEx)
#endif

#define PD_ALLPAGES 0x0
#define PD_SELECTION 0x1
#define PD_PAGENUMS 0x2
#define PD_NOSELECTION 0x4
#define PD_NOPAGENUMS 0x8
#define PD_COLLATE 0x10
#define PD_PRINTTOFILE 0x20
#define PD_PRINTSETUP 0x40
#define PD_NOWARNING 0x80
#define PD_RETURNDC 0x100
#define PD_RETURNIC 0x200
#define PD_RETURNDEFAULT 0x400
#define PD_SHOWHELP 0x800
#define PD_ENABLEPRINTHOOK 0x1000
#define PD_ENABLESETUPHOOK 0x2000
#define PD_ENABLEPRINTTEMPLATE 0x4000
#define PD_ENABLESETUPTEMPLATE 0x8000
#define PD_ENABLEPRINTTEMPLATEHANDLE 0x10000
#define PD_ENABLESETUPTEMPLATEHANDLE 0x20000
#define PD_USEDEVMODECOPIES 0x40000
#define PD_USEDEVMODECOPIESANDCOLLATE 0x40000
#define PD_DISABLEPRINTTOFILE 0x80000
#define PD_HIDEPRINTTOFILE 0x100000
#define PD_NONETWORKBUTTON 0x200000
#define PD_CURRENTPAGE 0x400000
#define PD_NOCURRENTPAGE 0x800000
#define PD_EXCLUSIONFLAGS 0x1000000
#define PD_USELARGETEMPLATE 0x10000000

#define PD_EXCL_COPIESANDCOLLATE (DM_COPIES | DM_COLLATE)
#define START_PAGE_GENERAL 0xffffffff

#define PD_RESULT_CANCEL 0
#define PD_RESULT_PRINT 1
#define PD_RESULT_APPLY 2

  typedef struct tagDEVNAMES {
    WORD wDriverOffset;
    WORD wDeviceOffset;
    WORD wOutputOffset;
    WORD wDefault;
  } DEVNAMES,*LPDEVNAMES;

#define DN_DEFAULTPRN 0x1

  WINCOMMDLGAPI DWORD WINAPI CommDlgExtendedError(VOID);

#define WM_PSD_PAGESETUPDLG (WM_USER)
#define WM_PSD_FULLPAGERECT (WM_USER+1)
#define WM_PSD_MINMARGINRECT (WM_USER+2)
#define WM_PSD_MARGINRECT (WM_USER+3)
#define WM_PSD_GREEKTEXTRECT (WM_USER+4)
#define WM_PSD_ENVSTAMPRECT (WM_USER+5)
#define WM_PSD_YAFULLPAGERECT (WM_USER+6)

  typedef UINT_PTR (CALLBACK *LPPAGEPAINTHOOK)(HWND,UINT,WPARAM,LPARAM);
  typedef UINT_PTR (CALLBACK *LPPAGESETUPHOOK)(HWND,UINT,WPARAM,LPARAM);

  typedef struct tagPSDA {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    DWORD Flags;
    POINT ptPaperSize;
    RECT rtMinMargin;
    RECT rtMargin;
    HINSTANCE hInstance;
    LPARAM lCustData;
    LPPAGESETUPHOOK lpfnPageSetupHook;
    LPPAGEPAINTHOOK lpfnPagePaintHook;
    LPCSTR lpPageSetupTemplateName;
    HGLOBAL hPageSetupTemplate;
  } PAGESETUPDLGA,*LPPAGESETUPDLGA;

  typedef struct tagPSDW {
    DWORD lStructSize;
    HWND hwndOwner;
    HGLOBAL hDevMode;
    HGLOBAL hDevNames;
    DWORD Flags;
    POINT ptPaperSize;
    RECT rtMinMargin;
    RECT rtMargin;
    HINSTANCE hInstance;
    LPARAM lCustData;
    LPPAGESETUPHOOK lpfnPageSetupHook;
    LPPAGEPAINTHOOK lpfnPagePaintHook;
    LPCWSTR lpPageSetupTemplateName;
    HGLOBAL hPageSetupTemplate;
  } PAGESETUPDLGW,*LPPAGESETUPDLGW;

  __MINGW_TYPEDEF_AW(PAGESETUPDLG)
  __MINGW_TYPEDEF_AW(LPPAGESETUPDLG)

  WINCOMMDLGAPI WINBOOL WINAPI PageSetupDlgA(LPPAGESETUPDLGA);
  WINCOMMDLGAPI WINBOOL WINAPI PageSetupDlgW(LPPAGESETUPDLGW);

#define PageSetupDlg __MINGW_NAME_AW(PageSetupDlg)

#define PSD_DEFAULTMINMARGINS 0x0
#define PSD_INWININIINTLMEASURE 0x0
#define PSD_MINMARGINS 0x1
#define PSD_MARGINS 0x2
#define PSD_INTHOUSANDTHSOFINCHES 0x4
#define PSD_INHUNDREDTHSOFMILLIMETERS 0x8
#define PSD_DISABLEMARGINS 0x10
#define PSD_DISABLEPRINTER 0x20
#define PSD_NOWARNING 0x80
#define PSD_DISABLEORIENTATION 0x100
#define PSD_RETURNDEFAULT 0x400
#define PSD_DISABLEPAPER 0x200
#define PSD_SHOWHELP 0x800
#define PSD_ENABLEPAGESETUPHOOK 0x2000
#define PSD_ENABLEPAGESETUPTEMPLATE 0x8000
#define PSD_ENABLEPAGESETUPTEMPLATEHANDLE 0x20000
#define PSD_ENABLEPAGEPAINTHOOK 0x40000
#define PSD_DISABLEPAGEPAINTING 0x80000
#define PSD_NONETWORKBUTTON 0x200000

#ifdef __cplusplus
}
#endif

#endif

#ifndef _WIN64
#include <poppack.h>
#endif
#endif
#endif
