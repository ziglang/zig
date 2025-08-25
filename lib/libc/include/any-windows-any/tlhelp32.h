/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_TOOLHELP32
#define _INC_TOOLHELP32

#ifdef __cplusplus
extern "C" {
#endif

#define MAX_MODULE_NAME32 255

  HANDLE WINAPI CreateToolhelp32Snapshot(DWORD dwFlags,DWORD th32ProcessID);

#define TH32CS_SNAPHEAPLIST 0x00000001
#define TH32CS_SNAPPROCESS 0x00000002
#define TH32CS_SNAPTHREAD 0x00000004
#define TH32CS_SNAPMODULE 0x00000008
#define TH32CS_SNAPMODULE32 0x00000010
#define TH32CS_SNAPALL (TH32CS_SNAPHEAPLIST | TH32CS_SNAPPROCESS | TH32CS_SNAPTHREAD | TH32CS_SNAPMODULE)
#define TH32CS_INHERIT 0x80000000

  typedef struct tagHEAPLIST32 {
    SIZE_T dwSize;
    DWORD th32ProcessID;
    ULONG_PTR th32HeapID;
    DWORD dwFlags;
  } HEAPLIST32;
  typedef HEAPLIST32 *PHEAPLIST32;
  typedef HEAPLIST32 *LPHEAPLIST32;

#define HF32_DEFAULT 1
#define HF32_SHARED 2

  WINBOOL WINAPI Heap32ListFirst(HANDLE hSnapshot,LPHEAPLIST32 lphl);
  WINBOOL WINAPI Heap32ListNext(HANDLE hSnapshot,LPHEAPLIST32 lphl);

  typedef struct tagHEAPENTRY32 {
    SIZE_T dwSize;
    HANDLE hHandle;
    ULONG_PTR dwAddress;
    SIZE_T dwBlockSize;
    DWORD dwFlags;
    DWORD dwLockCount;
    DWORD dwResvd;
    DWORD th32ProcessID;
    ULONG_PTR th32HeapID;
  } HEAPENTRY32;
  typedef HEAPENTRY32 *PHEAPENTRY32;
  typedef HEAPENTRY32 *LPHEAPENTRY32;

#define LF32_FIXED 0x00000001
#define LF32_FREE 0x00000002
#define LF32_MOVEABLE 0x00000004

  WINBOOL WINAPI Heap32First(LPHEAPENTRY32 lphe,DWORD th32ProcessID,ULONG_PTR th32HeapID);
  WINBOOL WINAPI Heap32Next(LPHEAPENTRY32 lphe);
  WINBOOL WINAPI Toolhelp32ReadProcessMemory(DWORD th32ProcessID,LPCVOID lpBaseAddress,LPVOID lpBuffer,SIZE_T cbRead,SIZE_T *lpNumberOfBytesRead);

  typedef struct tagPROCESSENTRY32W {
    DWORD dwSize;
    DWORD cntUsage;
    DWORD th32ProcessID;
    ULONG_PTR th32DefaultHeapID;
    DWORD th32ModuleID;
    DWORD cntThreads;
    DWORD th32ParentProcessID;
    LONG pcPriClassBase;
    DWORD dwFlags;
    WCHAR szExeFile[MAX_PATH];
  } PROCESSENTRY32W;
  typedef PROCESSENTRY32W *PPROCESSENTRY32W;
  typedef PROCESSENTRY32W *LPPROCESSENTRY32W;

  WINBOOL WINAPI Process32FirstW(HANDLE hSnapshot,LPPROCESSENTRY32W lppe);
  WINBOOL WINAPI Process32NextW(HANDLE hSnapshot,LPPROCESSENTRY32W lppe);

  typedef struct tagPROCESSENTRY32 {
    DWORD dwSize;
    DWORD cntUsage;
    DWORD th32ProcessID;
    ULONG_PTR th32DefaultHeapID;
    DWORD th32ModuleID;
    DWORD cntThreads;
    DWORD th32ParentProcessID;
    LONG pcPriClassBase;
    DWORD dwFlags;
    CHAR szExeFile[MAX_PATH];
  } PROCESSENTRY32;
  typedef PROCESSENTRY32 *PPROCESSENTRY32;
  typedef PROCESSENTRY32 *LPPROCESSENTRY32;

  WINBOOL WINAPI Process32First(HANDLE hSnapshot,LPPROCESSENTRY32 lppe);
  WINBOOL WINAPI Process32Next(HANDLE hSnapshot,LPPROCESSENTRY32 lppe);

#if defined(UNICODE)
#define Process32First Process32FirstW
#define Process32Next Process32NextW
#define PROCESSENTRY32 PROCESSENTRY32W
#define PPROCESSENTRY32 PPROCESSENTRY32W
#define LPPROCESSENTRY32 LPPROCESSENTRY32W
#endif

  typedef struct tagTHREADENTRY32 {
    DWORD dwSize;
    DWORD cntUsage;
    DWORD th32ThreadID;
    DWORD th32OwnerProcessID;
    LONG tpBasePri;
    LONG tpDeltaPri;
    DWORD dwFlags;
  } THREADENTRY32;
  typedef THREADENTRY32 *PTHREADENTRY32;
  typedef THREADENTRY32 *LPTHREADENTRY32;

  WINBOOL WINAPI Thread32First(HANDLE hSnapshot,LPTHREADENTRY32 lpte);
  WINBOOL WINAPI Thread32Next(HANDLE hSnapshot,LPTHREADENTRY32 lpte);

  typedef struct tagMODULEENTRY32W {
    DWORD dwSize;
    DWORD th32ModuleID;
    DWORD th32ProcessID;
    DWORD GlblcntUsage;
    DWORD ProccntUsage;
    BYTE *modBaseAddr;
    DWORD modBaseSize;
    HMODULE hModule;
    WCHAR szModule[MAX_MODULE_NAME32 + 1];
    WCHAR szExePath[MAX_PATH];
  } MODULEENTRY32W;
  typedef MODULEENTRY32W *PMODULEENTRY32W;
  typedef MODULEENTRY32W *LPMODULEENTRY32W;

  WINBOOL WINAPI Module32FirstW(HANDLE hSnapshot,LPMODULEENTRY32W lpme);
  WINBOOL WINAPI Module32NextW(HANDLE hSnapshot,LPMODULEENTRY32W lpme);

  typedef struct tagMODULEENTRY32 {
    DWORD dwSize;
    DWORD th32ModuleID;
    DWORD th32ProcessID;
    DWORD GlblcntUsage;
    DWORD ProccntUsage;
    BYTE *modBaseAddr;
    DWORD modBaseSize;
    HMODULE hModule;
    char szModule[MAX_MODULE_NAME32 + 1];
    char szExePath[MAX_PATH];
  } MODULEENTRY32;
  typedef MODULEENTRY32 *PMODULEENTRY32;
  typedef MODULEENTRY32 *LPMODULEENTRY32;

  WINBOOL WINAPI Module32First(HANDLE hSnapshot,LPMODULEENTRY32 lpme);
  WINBOOL WINAPI Module32Next(HANDLE hSnapshot,LPMODULEENTRY32 lpme);

#if defined(UNICODE)
#define Module32First Module32FirstW
#define Module32Next Module32NextW
#define MODULEENTRY32 MODULEENTRY32W
#define PMODULEENTRY32 PMODULEENTRY32W
#define LPMODULEENTRY32 LPMODULEENTRY32W
#endif

#ifdef __cplusplus
}
#endif
#endif
