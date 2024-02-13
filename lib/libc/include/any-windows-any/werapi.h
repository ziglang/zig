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

typedef HANDLE HREPORT;

#define WER_FAULT_REPORTING_FLAG_NOHEAP 1
#define WER_FAULT_REPORTING_FLAG_QUEUE 2
#define WER_FAULT_REPORTING_FLAG_DISABLE_THREAD_SUSPENSION 4
#define WER_FAULT_REPORTING_FLAG_QUEUE_UPLOAD 8
#define WER_FAULT_REPORTING_ALWAYS_SHOW_UI 16
#define WER_FAULT_REPORTING_NO_UI 32
#define WER_FAULT_REPORTING_FLAG_NO_HEAP_ON_QUEUE 64
#define WER_FAULT_REPORTING_DISABLE_SNAPSHOT_CRASH 128
#define WER_FAULT_REPORTING_DISABLE_SNAPSHOT_HANG 256
#define WER_FAULT_REPORTING_CRITICAL 512
#define WER_FAULT_REPORTING_DURABLE 1024
#define WER_MAX_TOTAL_PARAM_LENGTH 1720
#define WER_MAX_PREFERRED_MODULES 128
#define WER_MAX_PREFERRED_MODULES_BUFFER 256

#define WER_MAX_MEM_BLOCK_SIZE (64 * 1024)

#define APPCRASH_EVENT L"APPCRASH"
#define PACKAGED_APPCRASH_EVENT L"MoAppCrash"

#define WER_P0 0
#define WER_P1 1
#define WER_P2 2
#define WER_P3 3
#define WER_P4 4
#define WER_P5 5
#define WER_P6 6
#define WER_P7 7
#define WER_P8 8
#define WER_P9 9

#define WER_E_INSUFFICIENT_BUFFER (HRESULT_FROM_WIN32(ERROR_INSUFFICIENT_BUFFER))
#define WER_E_NOT_FOUND (HRESULT_FROM_WIN32(ERROR_NOT_FOUND))
#define WER_E_LENGTH_EXCEEDED (HRESULT_FROM_WIN32(ERROR_PARAMETER_QUOTA_EXCEEDED))
#define WER_E_INVALID_STATE (HRESULT_FROM_WIN32(ERROR_INVALID_STATE))
#define WER_E_MISSING_DUMP (HRESULT_FROM_WIN32(ERROR_MISSING_SYSTEMFILE))
#define WER_E_CABBING_FAILURE (HRESULT_FROM_WIN32(ERROR_GEN_FAILURE))

#define WER_FILE_DELETE_WHEN_DONE 1
#define WER_FILE_ANONYMOUS_DATA 2
#define WER_FILE_COMPRESSED 4

#define WER_SUBMIT_HONOR_RECOVERY 1
#define WER_SUBMIT_HONOR_RESTART 2
#define WER_SUBMIT_QUEUE 4
#define WER_SUBMIT_SHOW_DEBUG 8
#define WER_SUBMIT_ADD_REGISTERED_DATA 16
#define WER_SUBMIT_OUTOFPROCESS 32
#define WER_SUBMIT_NO_CLOSE_UI 64
#define WER_SUBMIT_NO_QUEUE 128
#define WER_SUBMIT_NO_ARCHIVE 256
#define WER_SUBMIT_START_MINIMIZED 512
#define WER_SUBMIT_OUTOFPROCESS_ASYNC 1024
#define WER_SUBMIT_BYPASS_DATA_THROTTLING 2048
#define WER_SUBMIT_ARCHIVE_PARAMETERS_ONLY 4096
#define WER_SUBMIT_REPORT_MACHINE_ID 8192
#define WER_SUBMIT_BYPASS_POWER_THROTTLING 16384
#define WER_SUBMIT_BYPASS_NETWORK_COST_THROTTLING 32768
#define WER_SUBMIT_DISCARD_IF_QUEUED WER_SUBMIT_NO_QUEUE

#define WER_DUMP_MASK_START 1
#define WER_DUMP_MASK_DUMPTYPE (WER_DUMP_MASK_START << 0)
#define WER_DUMP_MASK_ONLY_THISTHREAD (WER_DUMP_MASK_START << 1)
#define WER_DUMP_MASK_THREADFLAGS (WER_DUMP_MASK_START << 2)
#define WER_DUMP_MASK_THREADFLAGS_EX (WER_DUMP_MASK_START << 3)
#define WER_DUMP_MASK_OTHERTHREADFLAGS (WER_DUMP_MASK_START << 4)
#define WER_DUMP_MASK_OTHERTHREADFLAGS_EX (WER_DUMP_MASK_START << 5)
#define WER_DUMP_MASK_PREFERRED_MODULESFLAGS (WER_DUMP_MASK_START << 6)
#define WER_DUMP_MASK_OTHER_MODULESFLAGS (WER_DUMP_MASK_START << 7)
#define WER_DUMP_MASK_PREFERRED_MODULE_LIST (WER_DUMP_MASK_START << 8)

#define WER_DUMP_NOHEAP_ONQUEUE 1
#define WER_DUMP_AUXILIARY 2

#define WER_MAX_REGISTERED_ENTRIES 512
#define WER_MAX_REGISTERED_METADATA 8
#define WER_MAX_REGISTERED_DUMPCOLLECTION 4

#define WER_METADATA_KEY_MAX_LENGTH 64
#define WER_METADATA_VALUE_MAX_LENGTH 128

#define WER_MAX_SIGNATURE_NAME_LENGTH 128
#define WER_MAX_EVENT_NAME_LENGTH 64
#define WER_MAX_PARAM_LENGTH MAX_PATH
#define WER_MAX_PARAM_COUNT 10
#define WER_MAX_FRIENDLY_EVENT_NAME_LENGTH 128
#define WER_MAX_APPLICATION_NAME_LENGTH 128
#define WER_MAX_DESCRIPTION_LENGTH 512
#define WER_MAX_BUCKET_ID_STRING_LENGTH MAX_PATH
#define WER_MAX_LOCAL_DUMP_SUBPATH_LENGTH 64

#define WER_MAX_REGISTERED_RUNTIME_EXCEPTION_MODULES 16

#define WER_RUNTIME_EXCEPTION_EVENT_FUNCTION "OutOfProcessExceptionEventCallback"
#define WER_RUNTIME_EXCEPTION_EVENT_SIGNATURE_FUNCTION "OutOfProcessExceptionEventSignatureCallback"
#define WER_RUNTIME_EXCEPTION_DEBUGGER_LAUNCH "OutOfProcessExceptionEventDebuggerLaunchCallback"

typedef enum _WER_FILE_TYPE {
  WerFileTypeMicrodump = 1,
  WerFileTypeMinidump,
  WerFileTypeHeapdump,
  WerFileTypeUserDocument,
  WerFileTypeOther,
  WerFileTypeTriagedump,
  WerFileTypeCustomDump,
  WerFileTypeAuxiliaryDump,
  WerFileTypeEtlTrace,
  WerFileTypeMax
} WER_FILE_TYPE;

typedef enum _WER_REGISTER_FILE_TYPE {
  WerRegFileTypeUserDocument = 1,
  WerRegFileTypeOther,
  WerRegFileTypeMax
} WER_REGISTER_FILE_TYPE;

typedef enum _WER_DUMP_TYPE {
  WerDumpTypeNone = 0,
  WerDumpTypeMicroDump,
  WerDumpTypeMiniDump,
  WerDumpTypeHeapDump,
  WerDumpTypeTriageDump,
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
#if NTDDI_VERSION >= NTDDI_WIN8
, WerThrottled = 10
#endif
#if NTDDI_VERSION >= NTDDI_WIN10
, WerReportUploadedCab = 11
, WerStorageLocationNotFound = 12
#endif
, WerSubmitResultMax
} WER_SUBMIT_RESULT, *PWER_SUBMIT_RESULT;

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

typedef struct _WER_DUMP_CUSTOM_OPTIONS_V2 {
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
  DWORD dwPreferredModuleResetFlags;
  DWORD dwOtherModuleResetFlags;
} WER_DUMP_CUSTOM_OPTIONS_V2, *PWER_DUMP_CUSTOM_OPTIONS_V2;

#if NTDDI_VERSION >= NTDDI_WINBLUE
typedef struct _WER_DUMP_CUSTOM_OPTIONS_V3 {
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
  DWORD dwPreferredModuleResetFlags;
  DWORD dwOtherModuleResetFlags;
  PVOID pvDumpKey;
  HANDLE hSnapshot;
  DWORD dwThreadID;
} WER_DUMP_CUSTOM_OPTIONS_V3, *PWER_DUMP_CUSTOM_OPTIONS_V3;

typedef WER_DUMP_CUSTOM_OPTIONS_V3 const *PCWER_DUMP_CUSTOM_OPTIONS_V3;
#endif

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

#if NTDDI_VERSION >= NTDDI_WIN8
typedef struct _WER_REPORT_INFORMATION_V3 {
  DWORD dwSize;
  HANDLE hProcess;
  WCHAR wzConsentKey[64];
  WCHAR wzFriendlyEventName[128];
  WCHAR wzApplicationName[128];
  WCHAR wzApplicationPath[MAX_PATH];
  WCHAR wzDescription[512];
  HWND hwndParent;
  WCHAR wzNamespacePartner[64];
  WCHAR wzNamespaceGroup[64];
} WER_REPORT_INFORMATION_V3, *PWER_REPORT_INFORMATION_V3;
#endif

#if NTDDI_VERSION >= NTDDI_WINBLUE
typedef struct _WER_REPORT_INFORMATION_V4 {
  DWORD dwSize;
  HANDLE hProcess;
  WCHAR wzConsentKey[64];
  WCHAR wzFriendlyEventName[128];
  WCHAR wzApplicationName[128];
  WCHAR wzApplicationPath[MAX_PATH];
  WCHAR wzDescription[512];
  HWND hwndParent;
  WCHAR wzNamespacePartner[64];
  WCHAR wzNamespaceGroup[64];
  BYTE rgbApplicationIdentity[16];
  HANDLE hSnapshot;
  HANDLE hDeleteFilesImpersonationToken;
} WER_REPORT_INFORMATION_V4, *PWER_REPORT_INFORMATION_V4;

typedef WER_REPORT_INFORMATION_V4 const *PCWER_REPORT_INFORMATION_V4;
#endif

#if NTDDI_VERSION >= NTDDI_WIN10
typedef struct _WER_REPORT_INFORMATION_V5 {
  DWORD dwSize;
  HANDLE hProcess;
  WCHAR wzConsentKey[64];
  WCHAR wzFriendlyEventName[128];
  WCHAR wzApplicationName[128];
  WCHAR wzApplicationPath[MAX_PATH];
  WCHAR wzDescription[512];
  HWND hwndParent;
  WCHAR wzNamespacePartner[64];
  WCHAR wzNamespaceGroup[64];
  BYTE rgbApplicationIdentity[16];
  HANDLE hSnapshot;
  HANDLE hDeleteFilesImpersonationToken;
  WER_SUBMIT_RESULT submitResultMax;
} WER_REPORT_INFORMATION_V5, *PWER_REPORT_INFORMATION_V5;

typedef WER_REPORT_INFORMATION_V5 const *PCWER_REPORT_INFORMATION_V5;
#endif

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
HRESULT WINAPI WerRegisterExcludedMemoryBlock(const void* address, DWORD size);
HRESULT WINAPI WerUnregisterExcludedMemoryBlock(const void* address);
HRESULT WINAPI WerRegisterCustomMetadata(PCWSTR key, PCWSTR value);
HRESULT WINAPI WerUnregisterCustomMetadata(PCWSTR key);
HRESULT WINAPI WerRegisterAdditionalProcess(DWORD processId, DWORD captureExtraInfoForThreadId);
HRESULT WINAPI WerUnregisterAdditionalProcess(DWORD processId);
HRESULT WINAPI WerRegisterAppLocalDump(PCWSTR localAppDataRelativePath);
HRESULT WINAPI WerUnregisterAppLocalDump(void);
HRESULT WINAPI WerSetMaxProcessHoldMilliseconds(DWORD dwMilliseconds);

#if (_WIN32_WINNT >= 0x0601)
typedef struct _WER_RUNTIME_EXCEPTION_INFORMATION {
  DWORD            dwSize;
  HANDLE           hProcess;
  HANDLE           hThread;
  EXCEPTION_RECORD exceptionRecord;
  CONTEXT          context;
  PCWSTR           pwszReportId;
  WINBOOL          bIsFatal;
  DWORD            dwReserved;
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

typedef enum _REPORT_STORE_TYPES {
  E_STORE_USER_ARCHIVE = 0,
  E_STORE_USER_QUEUE,
  E_STORE_MACHINE_ARCHIVE,
  E_STORE_MACHINE_QUEUE,
  E_STORE_INVALID
} REPORT_STORE_TYPES;

typedef PVOID HREPORTSTORE, *PHREPORTSTORE;

typedef struct _WER_REPORT_PARAMETER {
  WCHAR Name[WER_MAX_SIGNATURE_NAME_LENGTH + 1];
  WCHAR Value[WER_MAX_PARAM_LENGTH];
}WER_REPORT_PARAMETER, PWER_REPORT_PARAMETER;

typedef struct _WER_REPORT_SIGNATURE {
  WCHAR EventName[WER_MAX_EVENT_NAME_LENGTH + 1];
  WER_REPORT_PARAMETER Parameters[WER_MAX_PARAM_COUNT];
} WER_REPORT_SIGNATURE, *PWER_REPORT_SIGNATURE;

typedef struct _WER_REPORT_METADATA_V1 {
  WER_REPORT_SIGNATURE Signature;
  GUID BucketId;
  GUID ReportId;
  FILETIME CreationTime;
  ULONGLONG SizeInBytes;
} WER_REPORT_METADATA_V1, *PWER_REPORT_METADATA_V1;

typedef struct _WER_REPORT_METADATA_V2 {
  WER_REPORT_SIGNATURE Signature;
  GUID BucketId;
  GUID ReportId;
  FILETIME CreationTime;
  ULONGLONG SizeInBytes;
  WCHAR CabId[MAX_PATH];
  DWORD ReportStatus;
  GUID ReportIntegratorId;
  DWORD NumberOfFiles;
  DWORD SizeOfFileNames;
  WCHAR *FileNames;
} WER_REPORT_METADATA_V2, *PWER_REPORT_METADATA_V2;

typedef struct _WER_REPORT_METADATA_V3 {
  WER_REPORT_SIGNATURE Signature;
  GUID BucketId;
  GUID ReportId;
  FILETIME CreationTime;
  ULONGLONG SizeInBytes;
  WCHAR CabId[MAX_PATH];
  DWORD ReportStatus;
  GUID ReportIntegratorId;
  DWORD NumberOfFiles;
  DWORD SizeOfFileNames;
  WCHAR *FileNames;
  WCHAR FriendlyEventName[WER_MAX_FRIENDLY_EVENT_NAME_LENGTH];
  WCHAR ApplicationName[WER_MAX_APPLICATION_NAME_LENGTH];
  WCHAR ApplicationPath[MAX_PATH];
  WCHAR Description[WER_MAX_DESCRIPTION_LENGTH];
  WCHAR BucketIdString[WER_MAX_BUCKET_ID_STRING_LENGTH];
  ULONGLONG LegacyBucketId;
} WER_REPORT_METADATA_V3, *PWER_REPORT_METADATA_V3;

HRESULT WINAPI WerStoreOpen(REPORT_STORE_TYPES repStoreType, PHREPORTSTORE phReportStore);
VOID WINAPI WerStoreClose(HREPORTSTORE hReportStore);
HRESULT WINAPI WerStoreGetFirstReportKey(HREPORTSTORE hReportStore, PCWSTR *ppszReportKey);
HRESULT WINAPI WerStoreGetNextReportKey(HREPORTSTORE hReportStore, PCWSTR *ppszReportKey);
HRESULT WINAPI WerStoreQueryReportMetadataV1(HREPORTSTORE hReportStore, PCWSTR pszReportKey, PWER_REPORT_METADATA_V1 pReportMetadata);
HRESULT WINAPI WerStoreQueryReportMetadataV2(HREPORTSTORE hReportStore, PCWSTR pszReportKey, PWER_REPORT_METADATA_V2 pReportMetadata);
HRESULT WINAPI WerStoreQueryReportMetadataV3(HREPORTSTORE hReportStore, PCWSTR pszReportKey, PWER_REPORT_METADATA_V3 pReportMetadata);
VOID WINAPI WerFreeString(PCWSTR pwszStr);
HRESULT WINAPI WerStorePurge(void);
HRESULT WINAPI WerStoreGetReportCount(HREPORTSTORE hReportStore, DWORD *pdwReportCount);
HRESULT WINAPI WerStoreGetSizeOnDisk(HREPORTSTORE hReportStore, ULONGLONG *pqwSizeInBytes);
HRESULT WINAPI WerStoreUploadReport(HREPORTSTORE hReportStore, PCWSTR pszReportKey, DWORD dwFlags, PWER_SUBMIT_RESULT pSubmitResult);

#ifdef __cplusplus
}
#endif
#endif /*(_WIN32_WINNT >= 0x0600)*/
#endif /*_INC_WERAPI*/
