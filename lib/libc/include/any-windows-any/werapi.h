/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _INC_WERAPI
#define _INC_WERAPI
#if (_WIN32_WINNT >= 0x0600)

#ifdef __cplusplus
extern "C" {
#endif

typedef enum _WER_FILE_TYPE {
  WerFileTypeMicrodump = 1,
  WerFileTypeMinidump,
  WerFileTypeHeapdump,
  WerFileTypeUserDocument,
  WerFileTypeOther,
  WerFileTypeMax
} WER_FILE_TYPE;

typedef enum _WER_REGISTER_FILE_TYPE {
  WerRegFileTypeUserDocument = 1,
  WerRegFileTypeOther,
  WerRegFileTypeMax
} WER_REGISTER_FILE_TYPE;

typedef enum _WER_DUMP_TYPE {
  WerDumpTypeMicroDump = 1,
  WerDumpTypeMiniDump,
  WerDumpTypeHeapDump,
  WerDumpTypeMax
} WER_DUMP_TYPE;

typedef enum _WER_REPORT_UI {
  WerUIAdditionalDataDlgHeader = 1,
  WerUIIconFilePath,
  WerUIConsentDlgHeader,
  WerUIConsentDlgBody,
  WerUIOnlineSolutionCheckText,
  WerUIOfflineSolutionCheckText,
  WerUICloseText,
  WerUICloseDlgHeader,
  WerUICloseDlgBody,
  WerUICloseDlgButtonText,
  WerUICustomActionButtonText,
  WerUIMax
} WER_REPORT_UI;

typedef enum _WER_CONSENT {
  WerConsentNotAsked = 1,
  WerConsentApproved,
  WerConsentDenied,
  WerConsentAlwaysPrompt,
  WerConsentMax
} WER_CONSENT;

typedef enum _WER_SUBMIT_RESULT {
  WerReportQueued = 1,
  WerReportUploaded,
  WerReportDebug,
  WerReportFailed,
  WerDisabled,
  WerReportCancelled,
  WerDisabledQueue,
  WerReportAsync,
  WerCustomAction
} WER_SUBMIT_RESULT;

typedef enum _WER_REPORT_TYPE {
  WerReportNonCritical = 0,
  WerReportCritical,
  WerReportApplicationCrash,
  WerReportApplicationHang,
  WerReportKernel,
  WerReportInvalid
} WER_REPORT_TYPE;

typedef struct _WER_DUMP_CUSTOM_OPTIONS {
  DWORD dwSize;
  DWORD dwMask;
  DWORD dwDumpFlags;
  WINBOOL bOnlyThisThread;
  DWORD dwExceptionThreadFlags;
  DWORD dwOtherThreadFlags;
  DWORD dwExceptionThreadExFlags;
  DWORD dwOtherThreadExFlags;
  DWORD dwPreferredModuleFlags;
  DWORD dwOtherModuleFlags;
  WCHAR wzPreferredModuleList[WER_MAX_PREFERRED_MODULES_BUFFER];
} WER_DUMP_CUSTOM_OPTIONS, *PWER_DUMP_CUSTOM_OPTIONS;

typedef struct _WER_EXCEPTION_INFORMATION {
  PEXCEPTION_POINTERS pExceptionPointers;
  WINBOOL             bClientPointers;
} WER_EXCEPTION_INFORMATION, *PWER_EXCEPTION_INFORMATION;

typedef struct _WER_REPORT_INFORMATION {
  DWORD  dwSize;
  HANDLE hProcess;
  WCHAR  wzConsentKey[64];
  WCHAR  wzFriendlyEventName[128];
  WCHAR  wzApplicationName[128];
  WCHAR  wzApplicationPath[MAX_PATH];
  WCHAR  wzDescription[512];
  HWND   hwndParent;
} WER_REPORT_INFORMATION, *PWER_REPORT_INFORMATION;

HRESULT WINAPI WerAddExcludedApplication(PCWSTR pwzExeName,WINBOOL bAllUsers);
HRESULT WINAPI WerGetFlags(HANDLE hProcess,PDWORD pdwFlags);
HRESULT WINAPI WerRegisterFile(PCWSTR pwzFile,WER_REGISTER_FILE_TYPE regFileType,DWORD dwFlags);
HRESULT WINAPI WerRegisterMemoryBlock(PVOID pvAddress,DWORD dwSize);
HRESULT WINAPI WerRemoveExcludedApplication(PCWSTR pwzExeName,WINBOOL bAllUsers);
HRESULT WINAPI WerReportAddDump(HREPORT hReportHandle,HANDLE hProcess,HANDLE hThread,WER_DUMP_TYPE dumpType,PWER_EXCEPTION_INFORMATION pExceptionParam,PWER_DUMP_CUSTOM_OPTIONS pDumpCustomOptions,DWORD dwFlags);
HRESULT WINAPI WerReportAddFile(HREPORT hReportHandle,PCWSTR pwzPath,WER_FILE_TYPE repFileType,DWORD dwFileFlags);
HRESULT WINAPI WerReportCloseHandle(HREPORT hReportHandle);
HRESULT WINAPI WerReportCreate(PCWSTR pwzEventType,WER_REPORT_TYPE repType,PWER_REPORT_INFORMATION pReportInformation,HREPORT *phReportHandle);
HRESULT WINAPI WerReportHang(HWND hwndHungWindow,PCWSTR wszHungApplicationName);
HRESULT WINAPI WerReportSetParameter(HREPORT hReportHandle,DWORD dwparamID,PCWSTR pwzName,PCWSTR pwzValue);
HRESULT WINAPI WerReportSetUIOption(HREPORT hReportHandle,WER_REPORT_UI repUITypeID,PCWSTR pwzValue);
HRESULT WINAPI WerReportSubmit(HREPORT hReportHandle,WER_CONSENT consent,DWORD dwFlags,PWER_SUBMIT_RESULT pSubmitResult);
HRESULT WINAPI WerSetFlags(DWORD dwFlags);
HRESULT WINAPI WerUnregisterFile(PCWSTR pwzFilePath);
HRESULT WINAPI WerUnregisterMemoryBlock(PVOID pvAddress);

#if (_WIN32_WINNT >= 0x0601)
typedef struct _WER_RUNTIME_EXCEPTION_INFORMATION {
  DWORD            dwSize;
  HANDLE           hProcess;
  HANDLE           hThread;
  EXCEPTION_RECORD exceptionRecord;
  CONTEXT          context;
  PCWSTR           pwszReportId;
} WER_RUNTIME_EXCEPTION_INFORMATION, *PWER_RUNTIME_EXCEPTION_INFORMATION;

typedef HRESULT (WINAPI *PFN_WER_RUNTIME_EXCEPTION_EVENT)(
  PVOID pContext,
  const PWER_RUNTIME_EXCEPTION_INFORMATION pExceptionInformation,
  WINBOOL *pbOwnershipClaimed,
  PWSTR pwszEventName,
  PDWORD pchSize,
  PDWORD pdwSignatureCount
);

typedef HRESULT (WINAPI *PFN_WER_RUNTIME_EXCEPTION_DEBUGGER_LAUNCH)(
  PVOID pContext,
  const PWER_RUNTIME_EXCEPTION_INFORMATION pExceptionInformation,
  PBOOL pbIsCustomDebugger,
  PWSTR pwszDebuggerLaunch,
  PDWORD pchDebuggerLaunch,
  PBOOL pbIsDebuggerAutolaunch
);

typedef HRESULT (WINAPI *PFN_WER_RUNTIME_EXCEPTION_EVENT_SIGNATURE)(
  PVOID pContext,
  const PWER_RUNTIME_EXCEPTION_INFORMATION pExceptionInformation,
  DWORD dwIndex,
  PWSTR pwszName,
  PDWORD pchName,
  PWSTR pwszValue,
  PDWORD pchValue
);

HRESULT WINAPI WerRegisterRuntimeExceptionModule(
  PCWSTR pwszOutOfProcessCallbackDll,
  PVOID pContext
);

HRESULT WINAPI WerUnregisterRuntimeExceptionModule(
  PCWSTR pwszOutOfProcessCallbackDll,
  PVOID pContext
);

#endif /*(_WIN32_WINNT >= 0x0601)*/

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WERAPI*/
