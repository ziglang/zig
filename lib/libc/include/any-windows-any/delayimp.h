/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#define _DELAY_IMP_VER 2

#if defined(__cplusplus)
#define ExternC extern "C"
#else
#define ExternC extern
#endif

typedef IMAGE_THUNK_DATA *PImgThunkData;
typedef const IMAGE_THUNK_DATA *PCImgThunkData;
typedef DWORD RVA;

typedef struct ImgDelayDescr {
  DWORD grAttrs;
  RVA rvaDLLName;
  RVA rvaHmod;
  RVA rvaIAT;
  RVA rvaINT;
  RVA rvaBoundIAT;
  RVA rvaUnloadIAT;
  DWORD dwTimeStamp;
} ImgDelayDescr,*PImgDelayDescr;

typedef const ImgDelayDescr *PCImgDelayDescr;

enum DLAttr {
  dlattrRva = 0x1
};

enum {
  dliStartProcessing,dliNoteStartProcessing = dliStartProcessing,dliNotePreLoadLibrary,dliNotePreGetProcAddress,dliFailLoadLib,
  dliFailGetProc,dliNoteEndProcessing
};

typedef struct DelayLoadProc {
  WINBOOL fImportByName;
  __C89_NAMELESS union {
    LPCSTR szProcName;
    DWORD dwOrdinal;
  };
} DelayLoadProc;

typedef struct DelayLoadInfo {
  DWORD cb;
  PCImgDelayDescr pidd;
  FARPROC *ppfn;
  LPCSTR szDll;
  DelayLoadProc dlp;
  HMODULE hmodCur;
  FARPROC pfnCur;
  DWORD dwLastError;
} DelayLoadInfo,*PDelayLoadInfo;

typedef FARPROC (WINAPI *PfnDliHook)(unsigned dliNotify,PDelayLoadInfo pdli);

ExternC WINBOOL WINAPI __FUnloadDelayLoadedDLL2(LPCSTR szDll);
ExternC HRESULT WINAPI __HrLoadAllImportsForDll(LPCSTR szDll);

#ifndef FACILITY_VISUALCPP
#define FACILITY_VISUALCPP ((LONG)0x6d)
#endif
#define VcppException(sev,err) ((sev) | (FACILITY_VISUALCPP<<16) | err)

ExternC PfnDliHook __pfnDliNotifyHook2;
ExternC PfnDliHook __pfnDliFailureHook2;
