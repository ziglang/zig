/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _SHFOLDER_H_
#define _SHFOLDER_H_

#include <_mingw_unicode.h>

#ifndef SHFOLDERAPI
#if defined(_SHFOLDER_)
#define SHFOLDERAPI STDAPI
#else
#define SHFOLDERAPI EXTERN_C DECLSPEC_IMPORT HRESULT WINAPI
#endif
#endif

#ifndef CSIDL_PERSONAL
#define CSIDL_PERSONAL 0x0005
#endif

#ifndef CSIDL_MYMUSIC
#define CSIDL_MYMUSIC 0x000d
#endif

#ifndef CSIDL_APPDATA
#define CSIDL_APPDATA 0x001A
#endif

#ifndef CSIDL_LOCAL_APPDATA

#define CSIDL_LOCAL_APPDATA 0x001C
#define CSIDL_INTERNET_CACHE 0x0020
#define CSIDL_COOKIES 0x0021
#define CSIDL_HISTORY 0x0022
#define CSIDL_COMMON_APPDATA 0x0023
#define CSIDL_WINDOWS 0x0024
#define CSIDL_SYSTEM 0x0025
#define CSIDL_PROGRAM_FILES 0x0026
#define CSIDL_MYPICTURES 0x0027
#define CSIDL_PROGRAM_FILES_COMMON 0x002b
#define CSIDL_COMMON_DOCUMENTS 0x002e
#define CSIDL_RESOURCES 0x0038
#define CSIDL_RESOURCES_LOCALIZED 0x0039

#define CSIDL_FLAG_CREATE 0x8000

#define CSIDL_COMMON_ADMINTOOLS 0x002f
#define CSIDL_ADMINTOOLS 0x0030
#endif

#define SHGetFolderPath __MINGW_NAME_AW(SHGetFolderPath)
#define PFNSHGETFOLDERPATH __MINGW_NAME_AW(PFNSHGETFOLDERPATH)

SHFOLDERAPI SHGetFolderPathA(HWND hwnd,int csidl,HANDLE hToken,DWORD dwFlags,LPSTR pszPath);
SHFOLDERAPI SHGetFolderPathW(HWND hwnd,int csidl,HANDLE hToken,DWORD dwFlags,LPWSTR pszPath);

typedef HRESULT (__stdcall *PFNSHGETFOLDERPATHA)(HWND,int,HANDLE,DWORD,LPSTR);
typedef HRESULT (__stdcall *PFNSHGETFOLDERPATHW)(HWND,int,HANDLE,DWORD,LPWSTR);

#endif
