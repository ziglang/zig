/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _APISETLIBLOADER_
#define _APISETLIBLOADER_

#include <apiset.h>
#include <apisetcconv.h>
#include <minwindef.h>
#include <minwinbase.h>

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef struct tagENUMUILANG {
    ULONG NumOfEnumUILang;
    ULONG SizeOfEnumUIBuffer;
    LANGID *pEnumUIBuffer;
  } ENUMUILANG, *PENUMUILANG;

#ifdef STRICT
  typedef WINBOOL (CALLBACK *ENUMRESLANGPROCA) (HMODULE hModule, LPCSTR lpType, LPCSTR lpName, WORD wLanguage, LONG_PTR lParam);
  typedef WINBOOL (CALLBACK *ENUMRESLANGPROCW) (HMODULE hModule, LPCWSTR lpType, LPCWSTR lpName, WORD wLanguage, LONG_PTR lParam);
  typedef WINBOOL (CALLBACK *ENUMRESNAMEPROCA) (HMODULE hModule, LPCSTR lpType, LPSTR lpName, LONG_PTR lParam);
  typedef WINBOOL (CALLBACK *ENUMRESNAMEPROCW) (HMODULE hModule, LPCWSTR lpType, LPWSTR lpName, LONG_PTR lParam);
  typedef WINBOOL (CALLBACK *ENUMRESTYPEPROCA) (HMODULE hModule, LPSTR lpType, LONG_PTR lParam);
  typedef WINBOOL (CALLBACK *ENUMRESTYPEPROCW) (HMODULE hModule, LPWSTR lpType, LONG_PTR lParam);
#else
  typedef FARPROC ENUMRESTYPEPROCA;
  typedef FARPROC ENUMRESTYPEPROCW;
  typedef FARPROC ENUMRESNAMEPROCA;
  typedef FARPROC ENUMRESNAMEPROCW;
  typedef FARPROC ENUMRESLANGPROCA;
  typedef FARPROC ENUMRESLANGPROCW;
#endif

#ifndef RC_INVOKED
  typedef WINBOOL (WINAPI *PGET_MODULE_HANDLE_EXA) (DWORD dwFlags, LPCSTR lpModuleName, HMODULE *phModule);
  typedef WINBOOL (WINAPI *PGET_MODULE_HANDLE_EXW) (DWORD dwFlags, LPCWSTR lpModuleName, HMODULE *phModule);
#endif

  typedef PVOID DLL_DIRECTORY_COOKIE, *PDLL_DIRECTORY_COOKIE;

#define FIND_RESOURCE_DIRECTORY_TYPES (0x0100)
#define FIND_RESOURCE_DIRECTORY_NAMES (0x0200)
#define FIND_RESOURCE_DIRECTORY_LANGUAGES (0x0400)

#define RESOURCE_ENUM_LN (0x0001)
#define RESOURCE_ENUM_MUI (0x0002)
#define RESOURCE_ENUM_MUI_SYSTEM (0x0004)
#define RESOURCE_ENUM_VALIDATE (0x0008)
#define RESOURCE_ENUM_MODULE_EXACT (0x0010)

#define SUPPORT_LANG_NUMBER 32

#define DONT_RESOLVE_DLL_REFERENCES 0x1
#define LOAD_LIBRARY_AS_DATAFILE 0x2
#define LOAD_WITH_ALTERED_SEARCH_PATH 0x8
#define LOAD_IGNORE_CODE_AUTHZ_LEVEL 0x10
#define LOAD_LIBRARY_AS_IMAGE_RESOURCE 0x20
#define LOAD_LIBRARY_AS_DATAFILE_EXCLUSIVE 0x40
#define LOAD_LIBRARY_REQUIRE_SIGNED_TARGET 0x80
#define LOAD_LIBRARY_SEARCH_DLL_LOAD_DIR 0x100
#define LOAD_LIBRARY_SEARCH_APPLICATION_DIR 0x200
#define LOAD_LIBRARY_SEARCH_USER_DIRS 0x400
#define LOAD_LIBRARY_SEARCH_SYSTEM32 0x800
#define LOAD_LIBRARY_SEARCH_DEFAULT_DIRS 0x1000

#define GET_MODULE_HANDLE_EX_FLAG_PIN (0x1)
#define GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT (0x2)
#define GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS (0x4)

#define ENUMRESLANGPROC __MINGW_NAME_AW(ENUMRESLANGPROC)
#define ENUMRESNAMEPROC __MINGW_NAME_AW(ENUMRESNAMEPROC)
#define ENUMRESTYPEPROC __MINGW_NAME_AW(ENUMRESTYPEPROC)

  WINBASEAPI HRSRC WINAPI FindResourceExW (HMODULE hModule, LPCWSTR lpType, LPCWSTR lpName, WORD wLanguage);
  WINBASEAPI DECLSPEC_NORETURN VOID WINAPI FreeLibraryAndExitThread (HMODULE hLibModule, DWORD dwExitCode);
  WINBASEAPI WINBOOL WINAPI FreeResource (HGLOBAL hResData);
  WINBASEAPI HMODULE WINAPI GetModuleHandleA (LPCSTR lpModuleName);
  WINBASEAPI HMODULE WINAPI GetModuleHandleW (LPCWSTR lpModuleName);
  WINBASEAPI HMODULE WINAPI LoadLibraryExA (LPCSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
  WINBASEAPI HMODULE WINAPI LoadLibraryExW (LPCWSTR lpLibFileName, HANDLE hFile, DWORD dwFlags);
  WINBASEAPI HGLOBAL WINAPI LoadResource (HMODULE hModule, HRSRC hResInfo);
  WINUSERAPI int WINAPI LoadStringA (HINSTANCE hInstance, UINT uID, LPSTR lpBuffer, int cchBufferMax);
  WINUSERAPI int WINAPI LoadStringW (HINSTANCE hInstance, UINT uID, LPWSTR lpBuffer, int cchBufferMax);
  WINBASEAPI LPVOID WINAPI LockResource (HGLOBAL hResData);
  WINBASEAPI DWORD WINAPI SizeofResource (HMODULE hModule, HRSRC hResInfo);
  WINBASEAPI DLL_DIRECTORY_COOKIE WINAPI AddDllDirectory (PCWSTR NewDirectory);
  WINBASEAPI WINBOOL WINAPI RemoveDllDirectory (DLL_DIRECTORY_COOKIE Cookie);
  WINBASEAPI WINBOOL WINAPI SetDefaultDllDirectories (DWORD DirectoryFlags);
  WINBASEAPI WINBOOL WINAPI GetModuleHandleExA (DWORD dwFlags, LPCSTR lpModuleName, HMODULE *phModule);
  WINBASEAPI WINBOOL WINAPI GetModuleHandleExW (DWORD dwFlags, LPCWSTR lpModuleName, HMODULE *phModule);

#define PGET_MODULE_HANDLE_EX __MINGW_NAME_AW(PGET_MODULE_HANDLE_EX)
#define GetModuleHandleEx __MINGW_NAME_AW(GetModuleHandleEx)

#ifdef UNICODE
#define FindResourceEx FindResourceExW
#endif

#define LoadString __MINGW_NAME_AW(LoadString)
#define GetModuleHandle __MINGW_NAME_AW(GetModuleHandle)
#define LoadLibraryEx __MINGW_NAME_AW(LoadLibraryEx)

#define EnumResourceLanguages __MINGW_NAME_AW(EnumResourceLanguages)
  WINBASEAPI WINBOOL WINAPI EnumResourceLanguagesA(HMODULE hModule,LPCSTR lpType,LPCSTR lpName,ENUMRESLANGPROCA lpEnumFunc,LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceLanguagesW(HMODULE hModule,LPCWSTR lpType,LPCWSTR lpName,ENUMRESLANGPROCW lpEnumFunc,LONG_PTR lParam);


#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL APIENTRY EnumResourceLanguagesExA (HMODULE hModule, LPCSTR lpType, LPCSTR lpName, ENUMRESLANGPROCA lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL APIENTRY EnumResourceLanguagesExW (HMODULE hModule, LPCWSTR lpType, LPCWSTR lpName, ENUMRESLANGPROCW lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL WINAPI EnumResourceNamesExA (HMODULE hModule, LPCSTR lpType, ENUMRESNAMEPROCA lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL WINAPI EnumResourceNamesExW (HMODULE hModule, LPCWSTR lpType, ENUMRESNAMEPROCW lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL WINAPI EnumResourceTypesExA (HMODULE hModule, ENUMRESTYPEPROCA lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL WINAPI EnumResourceTypesExW (HMODULE hModule, ENUMRESTYPEPROCW lpEnumFunc, LONG_PTR lParam, DWORD dwFlags, LANGID LangId);
  WINBASEAPI WINBOOL WINAPI QueryOptionalDelayLoadedAPI (HMODULE CallerModule, LPCSTR lpDllName, LPCSTR lpProcName, DWORD Reserved);

#define EnumResourceLanguagesEx __MINGW_NAME_AW(EnumResourceLanguagesEx)
#define EnumResourceNamesEx __MINGW_NAME_AW(EnumResourceNamesEx)
#define EnumResourceTypesEx __MINGW_NAME_AW(EnumResourceTypesEx)
#endif
#elif defined(WINSTORECOMPAT)
WINBASEAPI HMODULE WINAPI GetModuleHandleA (LPCSTR lpModuleName);
WINBASEAPI HMODULE WINAPI GetModuleHandleW (LPCWSTR lpModuleName);
#define GetModuleHandle __MINGW_NAME_AW(GetModuleHandle)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI DisableThreadLibraryCalls (HMODULE hLibModule);
  WINBASEAPI WINBOOL WINAPI FreeLibrary (HMODULE hLibModule);
  WINBASEAPI FARPROC WINAPI GetProcAddress (HMODULE hModule, LPCSTR lpProcName);
  WINBASEAPI DWORD WINAPI GetModuleFileNameA (HMODULE hModule, LPSTR lpFilename, DWORD nSize);
  WINBASEAPI DWORD WINAPI GetModuleFileNameW (HMODULE hModule, LPWSTR lpFilename, DWORD nSize);
  #define GetModuleFileName __MINGW_NAME_AW(GetModuleFileName)

#if WINVER >= 0x0601
  WINBASEAPI int WINAPI FindStringOrdinal (DWORD dwFindStringOrdinalFlags, LPCWSTR lpStringSource, int cchSource, LPCWSTR lpStringValue, int cchValue, WINBOOL bIgnoreCase);
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif
