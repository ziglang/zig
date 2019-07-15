/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ADVPUB_H_
#define _ADVPUB_H_

#ifdef __cplusplus
extern "C" {
#endif

#ifndef S_ASYNCHRONOUS
#define S_ASYNCHRONOUS _HRESULT_TYPEDEF_(0x401e8)
#endif

#define achRUNSETUPCOMMANDFUNCTION "RunSetupCommand"

  HRESULT WINAPI RunSetupCommand(HWND hWnd,LPCSTR szCmdName,LPCSTR szInfSection,LPCSTR szDir,LPCSTR lpszTitle,HANDLE *phEXE,DWORD dwFlags,LPVOID pvReserved);

  typedef HRESULT (WINAPI *RUNSETUPCOMMAND)(HWND hWnd,LPCSTR szCmdName,LPCSTR szInfSection,LPCSTR szDir,LPCSTR szTitle,HANDLE *phEXE,DWORD dwFlags,LPVOID pvReserved);

#define RSC_FLAG_INF 1
#define RSC_FLAG_SKIPDISKSPACECHECK 2
#define RSC_FLAG_QUIET 4
#define RSC_FLAG_NGCONV 8
#define RSC_FLAG_UPDHLPDLLS 16
#define RSC_FLAG_DELAYREGISTEROCX 512
#define RSC_FLAG_SETUPAPI 1024

#define achNEEDREBOOTINITFUNCTION "NeedRebootInit"

  DWORD WINAPI NeedRebootInit(VOID);

  typedef DWORD (WINAPI *NEEDREBOOTINIT)(VOID);

#define achNEEDREBOOTFUNCTION "NeedReboot"

  WINBOOL WINAPI NeedReboot(DWORD dwRebootCheck);

  typedef WINBOOL (WINAPI *NEEDREBOOT)(DWORD dwRebootCheck);

#define achPRECHECKREBOOT "RebootCheckOnInstall"

  HRESULT WINAPI RebootCheckOnInstall(HWND hwnd,PCSTR pszINF,PCSTR pszSec,DWORD dwReserved);

  typedef HRESULT (WINAPI *REBOOTCHECKONINSTALL)(HWND,PCSTR,PCSTR,DWORD);

#define c_szTRANSLATEINFSTRING "TranslateInfString"

  HRESULT WINAPI TranslateInfString(PCSTR pszInfFilename,PCSTR pszInstallSection,PCSTR pszTranslateSection,PCSTR pszTranslateKey,PSTR pszBuffer,DWORD dwBufferSize,PDWORD pdwRequiredSize,PVOID pvReserved);

  typedef HRESULT (WINAPI *TRANSLATEINFSTRING)(PCSTR pszInfFilename,PCSTR pszInstallSection,PCSTR pszTranslateSection,PCSTR pszTranslateKey,PSTR pszBuffer,DWORD dwBufferSize,PDWORD pdwRequiredSize,PVOID pvReserved);

#define achREGINSTALL "RegInstall"

  typedef struct _StrEntry {
    LPSTR pszName;
    LPSTR pszValue;
  } STRENTRY,*LPSTRENTRY;

  typedef const STRENTRY CSTRENTRY;
  typedef CSTRENTRY *LPCSTRENTRY;

  typedef struct _StrTable {
    DWORD cEntries;
    LPSTRENTRY pse;
  } STRTABLE,*LPSTRTABLE;

  typedef const STRTABLE CSTRTABLE;
  typedef CSTRTABLE *LPCSTRTABLE;

  HRESULT WINAPI RegInstall(HMODULE hm,LPCSTR pszSection,LPCSTRTABLE pstTable);

  typedef HRESULT (WINAPI *REGINSTALL)(HMODULE hm,LPCSTR pszSection,LPCSTRTABLE pstTable);

#define achLAUNCHINFSECTIONEX "LaunchINFSectionEx"

  HRESULT WINAPI LaunchINFSectionEx(HWND hwnd,HINSTANCE hInstance,PSTR pszParms,INT nShow);

  typedef HRESULT (WINAPI *LAUNCHINFSECTIONEX)(HWND hwnd,HINSTANCE hInst,PSTR pszParams,INT nShow);

#define ALINF_QUIET 4
#define ALINF_NGCONV 8
#define ALINF_UPDHLPDLLS 16
#define ALINF_BKINSTALL 32
#define ALINF_ROLLBACK 64
#define ALINF_CHECKBKDATA 128
#define ALINF_ROLLBKDOALL 256
#define ALINF_DELAYREGISTEROCX 512

#define achEXECUTECAB "ExecuteCab"

  typedef struct _CabInfo {
    PSTR pszCab;
    PSTR pszInf;
    PSTR pszSection;
    char szSrcPath[MAX_PATH];
    DWORD dwFlags;
  } CABINFO,*PCABINFO;

  HRESULT WINAPI ExecuteCab(HWND hwnd,PCABINFO pCab,LPVOID pReserved);

  typedef HRESULT (WINAPI *EXECUTECAB)(HWND hwnd,PCABINFO pCab,LPVOID pReserved);

#define AIF_WARNIFSKIP 0x00000001
#define AIF_NOSKIP 0x00000002
#define AIF_NOVERSIONCHECK 0x00000004
#define AIF_FORCE_FILE_IN_USE 0x00000008
#define AIF_NOOVERWRITE 0x00000010

#define AIF_NO_VERSION_DIALOG 0x00000020
#define AIF_REPLACEONLY 0x00000400

#define AIF_NOLANGUAGECHECK 0x10000000

#define AIF_QUIET 0x20000000

#define achADVINSTALLFILE "AdvInstallFile"

  HRESULT WINAPI AdvInstallFile(HWND hwnd,LPCSTR lpszSourceDir,LPCSTR lpszSourceFile,LPCSTR lpszDestDir,LPCSTR lpszDestFile,DWORD dwFlags,DWORD dwReserved);

  typedef HRESULT (WINAPI *ADVINSTALLFILE)(HWND hwnd,LPCSTR lpszSourceDir,LPCSTR lpszSourceFile,LPCSTR lpszDestDir,LPCSTR lpszDestFile,DWORD dwFlags,DWORD dwReserved);

#define IE4_RESTORE 0x00000001
#define IE4_BACKNEW 0x00000002
#define IE4_NODELETENEW 0x00000004
#define IE4_NOMESSAGES 0x00000008
#define IE4_NOPROGRESS 0x00000010
#define IE4_NOENUMKEY 0x00000020
#define IE4_NO_CRC_MAPPING 0x00000040

#define IE4_REGSECTION 0x00000080
#define IE4_FRDOALL 0x00000100
#define IE4_UPDREFCNT 0x00000200
#define IE4_USEREFCNT 0x00000400
#define IE4_EXTRAINCREFCNT 0x00000800

#define IE4_REMOVREGBKDATA 0x00001000

  HRESULT WINAPI RegSaveRestore(HWND hWnd,PCSTR pszTitleString,HKEY hkBckupKey,PCSTR pcszRootKey,PCSTR pcszSubKey,PCSTR pcszValueName,DWORD dwFlags);

  typedef HRESULT (WINAPI *REGSAVERESTORE)(HWND hWnd,PCSTR pszTitleString,HKEY hkBckupKey,PCSTR pcszRootKey,PCSTR pcszSubKey,PCSTR pcszValueName,DWORD dwFlags);

  HRESULT WINAPI RegSaveRestoreOnINF(HWND hWnd,PCSTR pszTitle,PCSTR pszINF,PCSTR pszSection,HKEY hHKLMBackKey,HKEY hHKCUBackKey,DWORD dwFlags);

  typedef HRESULT (WINAPI *REGSAVERESTOREONINF)(HWND hWnd,PCSTR pszTitle,PCSTR pszINF,PCSTR pszSection,HKEY hHKLMBackKey,HKEY hHKCUBackKey,DWORD dwFlags);

#define ARSR_RESTORE IE4_RESTORE
#define ARSR_NOMESSAGES IE4_NOMESSAGES
#define ARSR_REGSECTION IE4_REGSECTION
#define ARSR_REMOVREGBKDATA IE4_REMOVREGBKDATA

#define REG_SAVE_LOG_KEY "RegSaveLogFile"
#define REG_RESTORE_LOG_KEY "RegRestoreLogFile"

  HRESULT WINAPI RegRestoreAll(HWND hWnd,PSTR pszTitleString,HKEY hkBckupKey);
  typedef HRESULT (WINAPI *REGRESTOREALL)(HWND hWnd,PSTR pszTitleString,HKEY hkBckupKey);

  HRESULT WINAPI FileSaveRestore(HWND hDlg,LPSTR lpFileList,LPSTR lpDir,LPSTR lpBaseName,DWORD dwFlags);

  typedef HRESULT (WINAPI *FILESAVERESTORE)(HWND hDlg,LPSTR lpFileList,LPSTR lpDir,LPSTR lpBaseName,DWORD dwFlags);

  HRESULT WINAPI FileSaveRestoreOnINF(HWND hWnd,PCSTR pszTitle,PCSTR pszINF,PCSTR pszSection,PCSTR pszBackupDir,PCSTR pszBaseBackupFile,DWORD dwFlags);

  typedef HRESULT (WINAPI *FILESAVERESTOREONINF)(HWND hDlg,PCSTR pszTitle,PCSTR pszINF,PCSTR pszSection,PCSTR pszBackupDir,PCSTR pszBaseBackFile,DWORD dwFlags);

#define AFSR_RESTORE IE4_RESTORE
#define AFSR_BACKNEW IE4_BACKNEW
#define AFSR_NODELETENEW IE4_NODELETENEW
#define AFSR_NOMESSAGES IE4_NOMESSAGES
#define AFSR_NOPROGRESS IE4_NOPROGRESS
#define AFSR_UPDREFCNT IE4_UPDREFCNT
#define AFSR_USEREFCNT IE4_USEREFCNT
#define AFSR_EXTRAINCREFCNT IE4_EXTRAINCREFCNT

  HRESULT WINAPI AddDelBackupEntry(LPCSTR lpcszFileList,LPCSTR lpcszBackupDir,LPCSTR lpcszBaseName,DWORD dwFlags);

  typedef HRESULT (WINAPI *ADDDELBACKUPENTRY)(LPCSTR lpcszFileList,LPCSTR lpcszBackupDir,LPCSTR lpcszBaseName,DWORD dwFlags);

#define AADBE_ADD_ENTRY 0x01
#define AADBE_DEL_ENTRY 0x02

  HRESULT WINAPI FileSaveMarkNotExist(LPSTR lpFileList,LPSTR lpDir,LPSTR lpBaseName);

  typedef HRESULT (WINAPI *FILESAVEMARKNOTEXIST)(LPSTR lpFileList,LPSTR lpDir,LPSTR lpBaseName);

  HRESULT WINAPI GetVersionFromFile(LPSTR lpszFilename,LPDWORD pdwMSVer,LPDWORD pdwLSVer,WINBOOL bVersion);

  typedef HRESULT (WINAPI *GETVERSIONFROMFILE)(LPSTR lpszFilename,LPDWORD pdwMSVer,LPDWORD pdwLSVer,WINBOOL bVersion);

  HRESULT WINAPI GetVersionFromFileEx(LPSTR lpszFilename,LPDWORD pdwMSVer,LPDWORD pdwLSVer,WINBOOL bVersion);

  typedef HRESULT (WINAPI *GETVERSIONFROMFILE)(LPSTR lpszFilename,LPDWORD pdwMSVer,LPDWORD pdwLSVer,WINBOOL bVersion);

#define achISNTADMIN "IsNTAdmin"

  WINBOOL WINAPI IsNTAdmin(DWORD dwReserved,DWORD *lpdwReserved);

  typedef WINBOOL (WINAPI *ISNTADMIN)(DWORD,DWORD *);

#define ADN_DEL_IF_EMPTY 0x00000001
#define ADN_DONT_DEL_SUBDIRS 0x00000002
#define ADN_DONT_DEL_DIR 0x00000004
#define ADN_DEL_UNC_PATHS 0x00000008

#define achDELNODE "DelNode"

  HRESULT WINAPI DelNode(LPCSTR pszFileOrDirName,DWORD dwFlags);

  typedef HRESULT (WINAPI *DELNODE)(LPCSTR pszFileOrDirName,DWORD dwFlags);

#define achDELNODERUNDLL32 "DelNodeRunDLL32"

  HRESULT WINAPI DelNodeRunDLL32(HWND hwnd,HINSTANCE hInstance,PSTR pszParms,INT nShow);

  typedef HRESULT (WINAPI *DELNODERUNDLL32)(HWND hwnd,HINSTANCE hInst,PSTR pszParams,INT nShow);
  typedef PVOID HINF;

  HRESULT WINAPI OpenINFEngine(PCSTR pszInfFilename,PCSTR pszInstallSection,DWORD dwFlags,HINF *phInf,PVOID pvReserved);
  HRESULT WINAPI TranslateInfStringEx(HINF hInf,PCSTR pszInfFilename,PCSTR pszTranslateSection,PCSTR pszTranslateKey,PSTR pszBuffer,DWORD dwBufferSize,PDWORD pdwRequiredSize,PVOID pvReserved);
  HRESULT WINAPI CloseINFEngine(HINF hInf);
  HRESULT WINAPI ExtractFiles(LPCSTR pszCabName,LPCSTR pszExpandDir,DWORD dwFlags,LPCSTR pszFileList,LPVOID lpReserved,DWORD dwReserved);
  INT WINAPI LaunchINFSection(HWND,HINSTANCE,PSTR,INT);

#define LIS_QUIET 0x0001
#define LIS_NOGRPCONV 0x0002

#define RUNCMDS_QUIET 0x00000001
#define RUNCMDS_NOWAIT 0x00000002
#define RUNCMDS_DELAYPOSTCMD 0x00000004

#define awchMSIE4GUID L"{89820200-ECBD-11cf-8B85-00AA005B4383}"
#define achUserInstStubWrapper "UserInstStubWrapper"
#define achUserUnInstStubWrapper "UserUnInstStubWrapper"

  typedef HRESULT (WINAPI *USERINSTSTUBWRAPPER)(HWND hwnd,HINSTANCE hInst,PSTR pszParams,INT nShow);
  typedef HRESULT (WINAPI *USERUNINSTSTUBWRAPPER)(HWND hwnd,HINSTANCE hInst,PSTR pszParams,INT nShow);

  HRESULT WINAPI UserInstStubWrapper(HWND hwnd,HINSTANCE hInstance,PSTR pszParms,INT nShow);
  HRESULT WINAPI UserUnInstStubWrapper(HWND hwnd,HINSTANCE hInstance,PSTR pszParms,INT nShow);

  typedef struct _PERUSERSECTION {
    char szGUID[39+20];
    char szDispName[128];
    char szLocale[10];
    char szStub[MAX_PATH*4];
    char szVersion[32];
    char szCompID[128];
    DWORD dwIsInstalled;
    WINBOOL bRollback;
  } PERUSERSECTION,*PPERUSERSECTION;

  HRESULT WINAPI SetPerUserSecValues(PPERUSERSECTION pPerUser);

#define achSetPerUserSecValues "SetPerUserSecValues"

  typedef HRESULT (WINAPI *SETPERUSERSECVALUES)(PPERUSERSECTION pPerUser);

#ifdef __cplusplus
}
#endif
#endif
