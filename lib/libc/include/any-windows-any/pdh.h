/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _PDH_H_
#define _PDH_H_

#include <_mingw_unicode.h>
#include <windows.h>
#include <winperf.h>

#ifdef __cplusplus
extern "C" {
#endif

  typedef LONG PDH_STATUS;

#define PDH_FUNCTION PDH_STATUS WINAPI

#define PDH_CVERSION_WIN40 ((DWORD)(0x0400))
#define PDH_CVERSION_WIN50 ((DWORD)(0x0500))

#define PDH_VERSION ((DWORD)((PDH_CVERSION_WIN50) + 0x0003))

#define IsSuccessSeverity(ErrorCode) ((!((DWORD)(ErrorCode) & 0xC0000000)) ? TRUE : FALSE)
#define IsInformationalSeverity(ErrorCode) ((((DWORD)(ErrorCode) & 0xC0000000)==(DWORD)0x40000000) ? TRUE : FALSE)
#define IsWarningSeverity(ErrorCode) ((((DWORD)(ErrorCode) & 0xC0000000)==(DWORD)0x80000000) ? TRUE : FALSE)
#define IsErrorSeverity(ErrorCode) ((((DWORD)(ErrorCode) & 0xC0000000)==(DWORD)0xC0000000) ? TRUE : FALSE)

#define MAX_COUNTER_PATH 256

#define PDH_MAX_COUNTER_NAME 1024
#define PDH_MAX_INSTANCE_NAME 1024
#define PDH_MAX_COUNTER_PATH 2048
#define PDH_MAX_DATASOURCE_PATH 1024

  typedef HANDLE PDH_HCOUNTER;
  typedef HANDLE PDH_HQUERY;
  typedef HANDLE PDH_HLOG;

  typedef PDH_HCOUNTER HCOUNTER;
  typedef PDH_HQUERY HQUERY;
#ifndef _LMHLOGDEFINED_
  typedef PDH_HLOG HLOG;
#endif

#ifdef INVALID_HANDLE_VALUE
#undef INVALID_HANDLE_VALUE
#define INVALID_HANDLE_VALUE ((HANDLE)((LONG_PTR)-1))
#endif

#define H_REALTIME_DATASOURCE NULL
#define H_WBEM_DATASOURCE INVALID_HANDLE_VALUE

  typedef struct _PDH_RAW_COUNTER {
    DWORD CStatus;
    FILETIME TimeStamp;
    LONGLONG FirstValue;
    LONGLONG SecondValue;
    DWORD MultiCount;
  } PDH_RAW_COUNTER,*PPDH_RAW_COUNTER;

  typedef struct _PDH_RAW_COUNTER_ITEM_A {
    LPSTR szName;
    PDH_RAW_COUNTER RawValue;
  } PDH_RAW_COUNTER_ITEM_A,*PPDH_RAW_COUNTER_ITEM_A;

  typedef struct _PDH_RAW_COUNTER_ITEM_W {
    LPWSTR szName;
    PDH_RAW_COUNTER RawValue;
  } PDH_RAW_COUNTER_ITEM_W,*PPDH_RAW_COUNTER_ITEM_W;

  typedef struct _PDH_FMT_COUNTERVALUE {
    DWORD CStatus;
    __C89_NAMELESS union {
      LONG longValue;
      double doubleValue;
      LONGLONG largeValue;
      LPCSTR AnsiStringValue;
      LPCWSTR WideStringValue;
    };
  } PDH_FMT_COUNTERVALUE,*PPDH_FMT_COUNTERVALUE;

  typedef struct _PDH_FMT_COUNTERVALUE_ITEM_A {
    LPSTR szName;
    PDH_FMT_COUNTERVALUE FmtValue;
  } PDH_FMT_COUNTERVALUE_ITEM_A,*PPDH_FMT_COUNTERVALUE_ITEM_A;

  typedef struct _PDH_FMT_COUNTERVALUE_ITEM_W {
    LPWSTR szName;
    PDH_FMT_COUNTERVALUE FmtValue;
  } PDH_FMT_COUNTERVALUE_ITEM_W,*PPDH_FMT_COUNTERVALUE_ITEM_W;

  typedef struct _PDH_STATISTICS {
    DWORD dwFormat;
    DWORD count;
    PDH_FMT_COUNTERVALUE min;
    PDH_FMT_COUNTERVALUE max;
    PDH_FMT_COUNTERVALUE mean;
  } PDH_STATISTICS,*PPDH_STATISTICS;

  typedef struct _PDH_COUNTER_PATH_ELEMENTS_A {
    LPSTR szMachineName;
    LPSTR szObjectName;
    LPSTR szInstanceName;
    LPSTR szParentInstance;
    DWORD dwInstanceIndex;
    LPSTR szCounterName;
  } PDH_COUNTER_PATH_ELEMENTS_A,*PPDH_COUNTER_PATH_ELEMENTS_A;

  typedef struct _PDH_COUNTER_PATH_ELEMENTS_W {
    LPWSTR szMachineName;
    LPWSTR szObjectName;
    LPWSTR szInstanceName;
    LPWSTR szParentInstance;
    DWORD dwInstanceIndex;
    LPWSTR szCounterName;
  } PDH_COUNTER_PATH_ELEMENTS_W,*PPDH_COUNTER_PATH_ELEMENTS_W;

  typedef struct _PDH_DATA_ITEM_PATH_ELEMENTS_A {
    LPSTR szMachineName;
    GUID ObjectGUID;
    DWORD dwItemId;
    LPSTR szInstanceName;
  } PDH_DATA_ITEM_PATH_ELEMENTS_A,*PPDH_DATA_ITEM_PATH_ELEMENTS_A;

  typedef struct _PDH_DATA_ITEM_PATH_ELEMENTS_W {
    LPWSTR szMachineName;
    GUID ObjectGUID;
    DWORD dwItemId;
    LPWSTR szInstanceName;
  } PDH_DATA_ITEM_PATH_ELEMENTS_W,*PPDH_DATA_ITEM_PATH_ELEMENTS_W;

  typedef struct _PDH_COUNTER_INFO_A {
    DWORD dwLength;
    DWORD dwType;
    DWORD CVersion;
    DWORD CStatus;
    LONG lScale;
    LONG lDefaultScale;
    DWORD_PTR dwUserData;
    DWORD_PTR dwQueryUserData;
    LPSTR szFullPath;
    __C89_NAMELESS union {
      PDH_DATA_ITEM_PATH_ELEMENTS_A DataItemPath;
      PDH_COUNTER_PATH_ELEMENTS_A CounterPath;
      __C89_NAMELESS struct {
	LPSTR szMachineName;
	LPSTR szObjectName;
	LPSTR szInstanceName;
	LPSTR szParentInstance;
	DWORD dwInstanceIndex;
	LPSTR szCounterName;
      };
    };
    LPSTR szExplainText;
    DWORD DataBuffer[1];
  } PDH_COUNTER_INFO_A,*PPDH_COUNTER_INFO_A;

  typedef struct _PDH_COUNTER_INFO_W {
    DWORD dwLength;
    DWORD dwType;
    DWORD CVersion;
    DWORD CStatus;
    LONG lScale;
    LONG lDefaultScale;
    DWORD_PTR dwUserData;
    DWORD_PTR dwQueryUserData;
    LPWSTR szFullPath;
    __C89_NAMELESS union {
      PDH_DATA_ITEM_PATH_ELEMENTS_W DataItemPath;
      PDH_COUNTER_PATH_ELEMENTS_W CounterPath;
      __C89_NAMELESS struct {
	LPWSTR szMachineName;
	LPWSTR szObjectName;
	LPWSTR szInstanceName;
	LPWSTR szParentInstance;
	DWORD dwInstanceIndex;
	LPWSTR szCounterName;
      };
    };
    LPWSTR szExplainText;
    DWORD DataBuffer[1];
  } PDH_COUNTER_INFO_W,*PPDH_COUNTER_INFO_W;

  typedef struct _PDH_TIME_INFO {
    LONGLONG StartTime;
    LONGLONG EndTime;
    DWORD SampleCount;
  } PDH_TIME_INFO,*PPDH_TIME_INFO;

  typedef struct _PDH_RAW_LOG_RECORD {
    DWORD dwStructureSize;
    DWORD dwRecordType;
    DWORD dwItems;
    UCHAR RawBytes[1];
  } PDH_RAW_LOG_RECORD,*PPDH_RAW_LOG_RECORD;

  typedef struct _PDH_LOG_SERVICE_QUERY_INFO_A {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwLogQuota;
    LPSTR szLogFileCaption;
    LPSTR szDefaultDir;
    LPSTR szBaseFileName;
    DWORD dwFileType;
    DWORD dwReserved;
    __C89_NAMELESS union {
      __C89_NAMELESS struct {
	DWORD PdlAutoNameInterval;
	DWORD PdlAutoNameUnits;
	LPSTR PdlCommandFilename;
	LPSTR PdlCounterList;
	DWORD PdlAutoNameFormat;
	DWORD PdlSampleInterval;
	FILETIME PdlLogStartTime;
	FILETIME PdlLogEndTime;
      };
      __C89_NAMELESS struct {
	DWORD TlNumberOfBuffers;
	DWORD TlMinimumBuffers;
	DWORD TlMaximumBuffers;
	DWORD TlFreeBuffers;
	DWORD TlBufferSize;
	DWORD TlEventsLost;
	DWORD TlLoggerThreadId;
	DWORD TlBuffersWritten;
	DWORD TlLogHandle;
	LPSTR TlLogFileName;
      };
    };
  } PDH_LOG_SERVICE_QUERY_INFO_A,*PPDH_LOG_SERVICE_QUERY_INFO_A;

  typedef struct _PDH_LOG_SERVICE_QUERY_INFO_W {
    DWORD dwSize;
    DWORD dwFlags;
    DWORD dwLogQuota;
    LPWSTR szLogFileCaption;
    LPWSTR szDefaultDir;
    LPWSTR szBaseFileName;
    DWORD dwFileType;
    DWORD dwReserved;
    __C89_NAMELESS union {
      __C89_NAMELESS struct {
	DWORD PdlAutoNameInterval;
	DWORD PdlAutoNameUnits;
	LPWSTR PdlCommandFilename;
	LPWSTR PdlCounterList;
	DWORD PdlAutoNameFormat;
	DWORD PdlSampleInterval;
	FILETIME PdlLogStartTime;
	FILETIME PdlLogEndTime;
      };
      __C89_NAMELESS struct {
	DWORD TlNumberOfBuffers;
	DWORD TlMinimumBuffers;
	DWORD TlMaximumBuffers;
	DWORD TlFreeBuffers;
	DWORD TlBufferSize;
	DWORD TlEventsLost;
	DWORD TlLoggerThreadId;
	DWORD TlBuffersWritten;
	DWORD TlLogHandle;
	LPWSTR TlLogFileName;
      };
    };
  } PDH_LOG_SERVICE_QUERY_INFO_W,*PPDH_LOG_SERVICE_QUERY_INFO_W;

#define MAX_TIME_VALUE ((LONGLONG) 0x7FFFFFFFFFFFFFFF)
#define MIN_TIME_VALUE ((LONGLONG) 0)

  PDH_FUNCTION PdhGetDllVersion(LPDWORD lpdwVersion);
  PDH_FUNCTION PdhOpenQueryW(LPCWSTR szDataSource,DWORD_PTR dwUserData,PDH_HQUERY *phQuery);
  PDH_FUNCTION PdhOpenQueryA(LPCSTR szDataSource,DWORD_PTR dwUserData,PDH_HQUERY *phQuery);
  PDH_FUNCTION PdhAddCounterW(PDH_HQUERY hQuery,LPCWSTR szFullCounterPath,DWORD_PTR dwUserData,PDH_HCOUNTER *phCounter);
  PDH_FUNCTION PdhAddCounterA(PDH_HQUERY hQuery,LPCSTR szFullCounterPath,DWORD_PTR dwUserData,PDH_HCOUNTER *phCounter);
  PDH_FUNCTION PdhRemoveCounter(PDH_HCOUNTER hCounter);
  PDH_FUNCTION PdhCollectQueryData(PDH_HQUERY hQuery);
  PDH_FUNCTION PdhCloseQuery(PDH_HQUERY hQuery);
  PDH_FUNCTION PdhGetFormattedCounterValue(PDH_HCOUNTER hCounter,DWORD dwFormat,LPDWORD lpdwType,PPDH_FMT_COUNTERVALUE pValue);
  PDH_FUNCTION PdhGetFormattedCounterArrayA(PDH_HCOUNTER hCounter,DWORD dwFormat,LPDWORD lpdwBufferSize,LPDWORD lpdwItemCount,PPDH_FMT_COUNTERVALUE_ITEM_A ItemBuffer);
  PDH_FUNCTION PdhGetFormattedCounterArrayW(PDH_HCOUNTER hCounter,DWORD dwFormat,LPDWORD lpdwBufferSize,LPDWORD lpdwItemCount,PPDH_FMT_COUNTERVALUE_ITEM_W ItemBuffer);

#define PDH_FMT_RAW ((DWORD) 0x00000010)
#define PDH_FMT_ANSI ((DWORD) 0x00000020)
#define PDH_FMT_UNICODE ((DWORD) 0x00000040)
#define PDH_FMT_LONG ((DWORD) 0x00000100)
#define PDH_FMT_DOUBLE ((DWORD) 0x00000200)
#define PDH_FMT_LARGE ((DWORD) 0x00000400)
#define PDH_FMT_NOSCALE ((DWORD) 0x00001000)
#define PDH_FMT_1000 ((DWORD) 0x00002000)
#define PDH_FMT_NODATA ((DWORD) 0x00004000)
#define PDH_FMT_NOCAP100 ((DWORD) 0x00008000)
#define PERF_DETAIL_COSTLY ((DWORD) 0x00010000)
#define PERF_DETAIL_STANDARD ((DWORD) 0x0000FFFF)

  PDH_FUNCTION PdhGetRawCounterValue(PDH_HCOUNTER hCounter,LPDWORD lpdwType,PPDH_RAW_COUNTER pValue);
  PDH_FUNCTION PdhGetRawCounterArrayA(PDH_HCOUNTER hCounter,LPDWORD lpdwBufferSize,LPDWORD lpdwItemCount,PPDH_RAW_COUNTER_ITEM_A ItemBuffer);
  PDH_FUNCTION PdhGetRawCounterArrayW(PDH_HCOUNTER hCounter,LPDWORD lpdwBufferSize,LPDWORD lpdwItemCount,PPDH_RAW_COUNTER_ITEM_W ItemBuffer);
  PDH_FUNCTION PdhCalculateCounterFromRawValue(PDH_HCOUNTER hCounter,DWORD dwFormat,PPDH_RAW_COUNTER rawValue1,PPDH_RAW_COUNTER rawValue2,PPDH_FMT_COUNTERVALUE fmtValue);
  PDH_FUNCTION PdhComputeCounterStatistics(PDH_HCOUNTER hCounter,DWORD dwFormat,DWORD dwFirstEntry,DWORD dwNumEntries,PPDH_RAW_COUNTER lpRawValueArray,PPDH_STATISTICS data);
  PDH_FUNCTION PdhGetCounterInfoW(PDH_HCOUNTER hCounter,BOOLEAN bRetrieveExplainText,LPDWORD pdwBufferSize,PPDH_COUNTER_INFO_W lpBuffer);
  PDH_FUNCTION PdhGetCounterInfoA(PDH_HCOUNTER hCounter,BOOLEAN bRetrieveExplainText,LPDWORD pdwBufferSize,PPDH_COUNTER_INFO_A lpBuffer);

#define PDH_MAX_SCALE (__MSABI_LONG(7))
#define PDH_MIN_SCALE (__MSABI_LONG(-7))

  PDH_FUNCTION PdhSetCounterScaleFactor(PDH_HCOUNTER hCounter,LONG lFactor);
  PDH_FUNCTION PdhConnectMachineW(LPCWSTR szMachineName);
  PDH_FUNCTION PdhConnectMachineA(LPCSTR szMachineName);
  PDH_FUNCTION PdhEnumMachinesW(LPCWSTR szDataSource,LPWSTR mszMachineList,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhEnumMachinesA(LPCSTR szDataSource,LPSTR mszMachineList,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhEnumObjectsW(LPCWSTR szDataSource,LPCWSTR szMachineName,LPWSTR mszObjectList,LPDWORD pcchBufferSize,DWORD dwDetailLevel,WINBOOL bRefresh);
  PDH_FUNCTION PdhEnumObjectsA(LPCSTR szDataSource,LPCSTR szMachineName,LPSTR mszObjectList,LPDWORD pcchBufferSize,DWORD dwDetailLevel,WINBOOL bRefresh);
  PDH_FUNCTION PdhEnumObjectItemsW(LPCWSTR szDataSource,LPCWSTR szMachineName,LPCWSTR szObjectName,LPWSTR mszCounterList,LPDWORD pcchCounterListLength,LPWSTR mszInstanceList,LPDWORD pcchInstanceListLength,DWORD dwDetailLevel,DWORD dwFlags);
  PDH_FUNCTION PdhEnumObjectItemsA(LPCSTR szDataSource,LPCSTR szMachineName,LPCSTR szObjectName,LPSTR mszCounterList,LPDWORD pcchCounterListLength,LPSTR mszInstanceList,LPDWORD pcchInstanceListLength,DWORD dwDetailLevel,DWORD dwFlags);

#define PDH_OBJECT_HAS_INSTANCES ((DWORD) 0x00000001)

  PDH_FUNCTION PdhMakeCounterPathW(PPDH_COUNTER_PATH_ELEMENTS_W pCounterPathElements,LPWSTR szFullPathBuffer,LPDWORD pcchBufferSize,DWORD dwFlags);
  PDH_FUNCTION PdhMakeCounterPathA(PPDH_COUNTER_PATH_ELEMENTS_A pCounterPathElements,LPSTR szFullPathBuffer,LPDWORD pcchBufferSize,DWORD dwFlags);
  PDH_FUNCTION PdhParseCounterPathW(LPCWSTR szFullPathBuffer,PPDH_COUNTER_PATH_ELEMENTS_W pCounterPathElements,LPDWORD pdwBufferSize,DWORD dwFlags);
  PDH_FUNCTION PdhParseCounterPathA(LPCSTR szFullPathBuffer,PPDH_COUNTER_PATH_ELEMENTS_A pCounterPathElements,LPDWORD pdwBufferSize,DWORD dwFlags);

#define PDH_PATH_WBEM_RESULT ((DWORD) 0x00000001)
#define PDH_PATH_WBEM_INPUT ((DWORD) 0x00000002)

#define PDH_PATH_LANG_FLAGS(LangId,Flags) ((DWORD)(((LangId & 0x0000FFFF) << 16) | (Flags & 0x0000FFFF)))

  PDH_FUNCTION PdhParseInstanceNameW(LPCWSTR szInstanceString,LPWSTR szInstanceName,LPDWORD pcchInstanceNameLength,LPWSTR szParentName,LPDWORD pcchParentNameLength,LPDWORD lpIndex);
  PDH_FUNCTION PdhParseInstanceNameA(LPCSTR szInstanceString,LPSTR szInstanceName,LPDWORD pcchInstanceNameLength,LPSTR szParentName,LPDWORD pcchParentNameLength,LPDWORD lpIndex);
  PDH_FUNCTION PdhValidatePathW(LPCWSTR szFullPathBuffer);
  PDH_FUNCTION PdhValidatePathA(LPCSTR szFullPathBuffer);
  PDH_FUNCTION PdhGetDefaultPerfObjectW(LPCWSTR szDataSource,LPCWSTR szMachineName,LPWSTR szDefaultObjectName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfObjectA(LPCSTR szDataSource,LPCSTR szMachineName,LPSTR szDefaultObjectName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfCounterW(LPCWSTR szDataSource,LPCWSTR szMachineName,LPCWSTR szObjectName,LPWSTR szDefaultCounterName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfCounterA(LPCSTR szDataSource,LPCSTR szMachineName,LPCSTR szObjectName,LPSTR szDefaultCounterName,LPDWORD pcchBufferSize);

  typedef PDH_STATUS (WINAPI *CounterPathCallBack)(DWORD_PTR);

  typedef struct _BrowseDlgConfig_HW {
    DWORD bIncludeInstanceIndex : 1,bSingleCounterPerAdd : 1,bSingleCounterPerDialog : 1,bLocalCountersOnly : 1,bWildCardInstances : 1,bHideDetailBox : 1,bInitializePath : 1,bDisableMachineSelection : 1,bIncludeCostlyObjects : 1,bShowObjectBrowser : 1,bReserved : 22;
    HWND hWndOwner;
    PDH_HLOG hDataSource;
    LPWSTR szReturnPathBuffer;
    DWORD cchReturnPathLength;
    CounterPathCallBack pCallBack;
    DWORD_PTR dwCallBackArg;
    PDH_STATUS CallBackStatus;
    DWORD dwDefaultDetailLevel;
    LPWSTR szDialogBoxCaption;
  } PDH_BROWSE_DLG_CONFIG_HW,*PPDH_BROWSE_DLG_CONFIG_HW;

  typedef struct _BrowseDlgConfig_HA {
    DWORD bIncludeInstanceIndex : 1,bSingleCounterPerAdd : 1,bSingleCounterPerDialog : 1,bLocalCountersOnly : 1,bWildCardInstances : 1,bHideDetailBox : 1,bInitializePath : 1,bDisableMachineSelection : 1,bIncludeCostlyObjects : 1,bShowObjectBrowser : 1,bReserved:22;
    HWND hWndOwner;
    PDH_HLOG hDataSource;
    LPSTR szReturnPathBuffer;
    DWORD cchReturnPathLength;
    CounterPathCallBack pCallBack;
    DWORD_PTR dwCallBackArg;
    PDH_STATUS CallBackStatus;
    DWORD dwDefaultDetailLevel;
    LPSTR szDialogBoxCaption;
  } PDH_BROWSE_DLG_CONFIG_HA,*PPDH_BROWSE_DLG_CONFIG_HA;

  typedef struct _BrowseDlgConfig_W {
    DWORD bIncludeInstanceIndex : 1,bSingleCounterPerAdd : 1,bSingleCounterPerDialog : 1,bLocalCountersOnly : 1,bWildCardInstances : 1,bHideDetailBox : 1,bInitializePath : 1,bDisableMachineSelection : 1,bIncludeCostlyObjects : 1,bShowObjectBrowser : 1,bReserved:22;
    HWND hWndOwner;
    LPWSTR szDataSource;
    LPWSTR szReturnPathBuffer;
    DWORD cchReturnPathLength;
    CounterPathCallBack pCallBack;
    DWORD_PTR dwCallBackArg;
    PDH_STATUS CallBackStatus;
    DWORD dwDefaultDetailLevel;
    LPWSTR szDialogBoxCaption;
  } PDH_BROWSE_DLG_CONFIG_W,*PPDH_BROWSE_DLG_CONFIG_W;

  typedef struct _BrowseDlgConfig_A {
    DWORD bIncludeInstanceIndex : 1,bSingleCounterPerAdd : 1,bSingleCounterPerDialog : 1,bLocalCountersOnly : 1,bWildCardInstances : 1,bHideDetailBox : 1,bInitializePath : 1,bDisableMachineSelection : 1,bIncludeCostlyObjects : 1,bShowObjectBrowser : 1,bReserved:22;
    HWND hWndOwner;
    LPSTR szDataSource;
    LPSTR szReturnPathBuffer;
    DWORD cchReturnPathLength;
    CounterPathCallBack pCallBack;
    DWORD_PTR dwCallBackArg;
    PDH_STATUS CallBackStatus;
    DWORD dwDefaultDetailLevel;
    LPSTR szDialogBoxCaption;
  } PDH_BROWSE_DLG_CONFIG_A,*PPDH_BROWSE_DLG_CONFIG_A;

  PDH_FUNCTION PdhBrowseCountersW(PPDH_BROWSE_DLG_CONFIG_W pBrowseDlgData);
  PDH_FUNCTION PdhBrowseCountersA(PPDH_BROWSE_DLG_CONFIG_A pBrowseDlgData);
  PDH_FUNCTION PdhExpandCounterPathW(LPCWSTR szWildCardPath,LPWSTR mszExpandedPathList,LPDWORD pcchPathListLength);
  PDH_FUNCTION PdhExpandCounterPathA(LPCSTR szWildCardPath,LPSTR mszExpandedPathList,LPDWORD pcchPathListLength);
  PDH_FUNCTION PdhLookupPerfNameByIndexW(LPCWSTR szMachineName,DWORD dwNameIndex,LPWSTR szNameBuffer,LPDWORD pcchNameBufferSize);
  PDH_FUNCTION PdhLookupPerfNameByIndexA(LPCSTR szMachineName,DWORD dwNameIndex,LPSTR szNameBuffer,LPDWORD pcchNameBufferSize);
  PDH_FUNCTION PdhLookupPerfIndexByNameW(LPCWSTR szMachineName,LPCWSTR szNameBuffer,LPDWORD pdwIndex);
  PDH_FUNCTION PdhLookupPerfIndexByNameA(LPCSTR szMachineName,LPCSTR szNameBuffer,LPDWORD pdwIndex);

#define PDH_NOEXPANDCOUNTERS 1
#define PDH_NOEXPANDINSTANCES 2
#define PDH_REFRESHCOUNTERS 4

  PDH_FUNCTION PdhExpandWildCardPathA(LPCSTR szDataSource,LPCSTR szWildCardPath,LPSTR mszExpandedPathList,LPDWORD pcchPathListLength,DWORD dwFlags);
  PDH_FUNCTION PdhExpandWildCardPathW(LPCWSTR szDataSource,LPCWSTR szWildCardPath,LPWSTR mszExpandedPathList,LPDWORD pcchPathListLength,DWORD dwFlags);

#define PDH_LOG_READ_ACCESS ((DWORD) 0x00010000)
#define PDH_LOG_WRITE_ACCESS ((DWORD) 0x00020000)
#define PDH_LOG_UPDATE_ACCESS ((DWORD) 0x00040000)
#define PDH_LOG_ACCESS_MASK ((DWORD) 0x000F0000)

#define PDH_LOG_CREATE_NEW ((DWORD) 0x00000001)
#define PDH_LOG_CREATE_ALWAYS ((DWORD) 0x00000002)
#define PDH_LOG_OPEN_ALWAYS ((DWORD) 0x00000003)
#define PDH_LOG_OPEN_EXISTING ((DWORD) 0x00000004)
#define PDH_LOG_CREATE_MASK ((DWORD) 0x0000000F)

#define PDH_LOG_OPT_USER_STRING ((DWORD) 0x01000000)
#define PDH_LOG_OPT_CIRCULAR ((DWORD) 0x02000000)
#define PDH_LOG_OPT_MAX_IS_BYTES ((DWORD) 0x04000000)
#define PDH_LOG_OPT_APPEND ((DWORD) 0x08000000)
#define PDH_LOG_OPT_MASK ((DWORD) 0x0F000000)

#define PDH_LOG_TYPE_UNDEFINED 0
#define PDH_LOG_TYPE_CSV 1
#define PDH_LOG_TYPE_TSV 2

#define PDH_LOG_TYPE_TRACE_KERNEL 4
#define PDH_LOG_TYPE_TRACE_GENERIC 5
#define PDH_LOG_TYPE_PERFMON 6
#define PDH_LOG_TYPE_SQL 7
#define PDH_LOG_TYPE_BINARY 8

  PDH_FUNCTION PdhOpenLogW(LPCWSTR szLogFileName,DWORD dwAccessFlags,LPDWORD lpdwLogType,PDH_HQUERY hQuery,DWORD dwMaxSize,LPCWSTR szUserCaption,PDH_HLOG *phLog);
  PDH_FUNCTION PdhOpenLogA(LPCSTR szLogFileName,DWORD dwAccessFlags,LPDWORD lpdwLogType,PDH_HQUERY hQuery,DWORD dwMaxSize,LPCSTR szUserCaption,PDH_HLOG *phLog);
  PDH_FUNCTION PdhUpdateLogW(PDH_HLOG hLog,LPCWSTR szUserString);
  PDH_FUNCTION PdhUpdateLogA(PDH_HLOG hLog,LPCSTR szUserString);
  PDH_FUNCTION PdhUpdateLogFileCatalog(PDH_HLOG hLog);
  PDH_FUNCTION PdhGetLogFileSize(PDH_HLOG hLog,LONGLONG *llSize);
  PDH_FUNCTION PdhCloseLog(PDH_HLOG hLog,DWORD dwFlags);

#define PDH_FLAGS_CLOSE_QUERY ((DWORD) 0x00000001)
#define PDH_FLAGS_FILE_BROWSER_ONLY ((DWORD) 0x00000001)

  PDH_FUNCTION PdhSelectDataSourceW(HWND hWndOwner,DWORD dwFlags,LPWSTR szDataSource,LPDWORD pcchBufferLength);
  PDH_FUNCTION PdhSelectDataSourceA(HWND hWndOwner,DWORD dwFlags,LPSTR szDataSource,LPDWORD pcchBufferLength);
  WINBOOL PdhIsRealTimeQuery(PDH_HQUERY hQuery);
  PDH_FUNCTION PdhSetQueryTimeRange(PDH_HQUERY hQuery,PPDH_TIME_INFO pInfo);
  PDH_FUNCTION PdhGetDataSourceTimeRangeW(LPCWSTR szDataSource,LPDWORD pdwNumEntries,PPDH_TIME_INFO pInfo,LPDWORD pdwBufferSize);
  PDH_FUNCTION PdhGetDataSourceTimeRangeA(LPCSTR szDataSource,LPDWORD pdwNumEntries,PPDH_TIME_INFO pInfo,LPDWORD dwBufferSize);
  PDH_FUNCTION PdhCollectQueryDataEx(PDH_HQUERY hQuery,DWORD dwIntervalTime,HANDLE hNewDataEvent);
  PDH_FUNCTION PdhFormatFromRawValue(DWORD dwCounterType,DWORD dwFormat,LONGLONG *pTimeBase,PPDH_RAW_COUNTER pRawValue1,PPDH_RAW_COUNTER pRawValue2,PPDH_FMT_COUNTERVALUE pFmtValue);
  PDH_FUNCTION PdhGetCounterTimeBase(PDH_HCOUNTER hCounter,LONGLONG *pTimeBase);
  PDH_FUNCTION PdhReadRawLogRecord(PDH_HLOG hLog,FILETIME ftRecord,PPDH_RAW_LOG_RECORD pRawLogRecord,LPDWORD pdwBufferLength);

#define DATA_SOURCE_REGISTRY ((DWORD) 0x00000001)
#define DATA_SOURCE_LOGFILE ((DWORD) 0x00000002)
#define DATA_SOURCE_WBEM ((DWORD) 0x00000004)

  PDH_FUNCTION PdhSetDefaultRealTimeDataSource(DWORD dwDataSourceId);
  PDH_FUNCTION PdhBindInputDataSourceW(PDH_HLOG *phDataSource,LPCWSTR LogFileNameList);
  PDH_FUNCTION PdhBindInputDataSourceA(PDH_HLOG *phDataSource,LPCSTR LogFileNameList);
  PDH_FUNCTION PdhOpenQueryH(PDH_HLOG hDataSource,DWORD_PTR dwUserData,PDH_HQUERY *phQuery);
  PDH_FUNCTION PdhEnumMachinesHW(PDH_HLOG hDataSource,LPWSTR mszMachineList,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhEnumMachinesHA(PDH_HLOG hDataSource,LPSTR mszMachineList,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhEnumObjectsHW(PDH_HLOG hDataSource,LPCWSTR szMachineName,LPWSTR mszObjectList,LPDWORD pcchBufferSize,DWORD dwDetailLevel,WINBOOL bRefresh);
  PDH_FUNCTION PdhEnumObjectsHA(PDH_HLOG hDataSource,LPCSTR szMachineName,LPSTR mszObjectList,LPDWORD pcchBufferSize,DWORD dwDetailLevel,WINBOOL bRefresh);
  PDH_FUNCTION PdhEnumObjectItemsHW(PDH_HLOG hDataSource,LPCWSTR szMachineName,LPCWSTR szObjectName,LPWSTR mszCounterList,LPDWORD pcchCounterListLength,LPWSTR mszInstanceList,LPDWORD pcchInstanceListLength,DWORD dwDetailLevel,DWORD dwFlags);
  PDH_FUNCTION PdhEnumObjectItemsHA(PDH_HLOG hDataSource,LPCSTR szMachineName,LPCSTR szObjectName,LPSTR mszCounterList,LPDWORD pcchCounterListLength,LPSTR mszInstanceList,LPDWORD pcchInstanceListLength,DWORD dwDetailLevel,DWORD dwFlags);
  PDH_FUNCTION PdhExpandWildCardPathHW(PDH_HLOG hDataSource,LPCWSTR szWildCardPath,LPWSTR mszExpandedPathList,LPDWORD pcchPathListLength,DWORD dwFlags);
  PDH_FUNCTION PdhExpandWildCardPathHA(PDH_HLOG hDataSource,LPCSTR szWildCardPath,LPSTR mszExpandedPathList,LPDWORD pcchPathListLength,DWORD dwFlags);
  PDH_FUNCTION PdhGetDataSourceTimeRangeH(PDH_HLOG hDataSource,LPDWORD pdwNumEntries,PPDH_TIME_INFO pInfo,LPDWORD pdwBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfObjectHW(PDH_HLOG hDataSource,LPCWSTR szMachineName,LPWSTR szDefaultObjectName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfObjectHA(PDH_HLOG hDataSource,LPCSTR szMachineName,LPSTR szDefaultObjectName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfCounterHW(PDH_HLOG hDataSource,LPCWSTR szMachineName,LPCWSTR szObjectName,LPWSTR szDefaultCounterName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhGetDefaultPerfCounterHA(PDH_HLOG hDataSource,LPCSTR szMachineName,LPCSTR szObjectName,LPSTR szDefaultCounterName,LPDWORD pcchBufferSize);
  PDH_FUNCTION PdhBrowseCountersHW(PPDH_BROWSE_DLG_CONFIG_HW pBrowseDlgData);
  PDH_FUNCTION PdhBrowseCountersHA(PPDH_BROWSE_DLG_CONFIG_HA pBrowseDlgData);
  PDH_FUNCTION PdhVerifySQLDBW(LPCWSTR szDataSource);
  PDH_FUNCTION PdhVerifySQLDBA(LPCSTR szDataSource);
  PDH_FUNCTION PdhCreateSQLTablesW(LPCWSTR szDataSource);
  PDH_FUNCTION PdhCreateSQLTablesA(LPCSTR szDataSource);
  PDH_FUNCTION PdhEnumLogSetNamesW(LPCWSTR szDataSource,LPWSTR mszDataSetNameList,LPDWORD pcchBufferLength);
  PDH_FUNCTION PdhEnumLogSetNamesA(LPCSTR szDataSource,LPSTR mszDataSetNameList,LPDWORD pcchBufferLength);
  PDH_FUNCTION PdhGetLogSetGUID(PDH_HLOG hLog,GUID *pGuid,int *pRunId);
  PDH_FUNCTION PdhSetLogSetRunID(PDH_HLOG hLog,int RunId);

#if defined(UNICODE)
#ifndef _UNICODE
#define _UNICODE
#endif
#endif

#if defined(_UNICODE)
#if !defined(UNICODE)
#define UNICODE
#endif
#endif

#define PDH_COUNTER_INFO __MINGW_NAME_UAW(PDH_COUNTER_INFO)
#define PPDH_COUNTER_INFO __MINGW_NAME_UAW(PPDH_COUNTER_INFO)
#define PDH_COUNTER_PATH_ELEMENTS __MINGW_NAME_UAW(PDH_COUNTER_PATH_ELEMENTS)
#define PPDH_COUNTER_PATH_ELEMENTS __MINGW_NAME_UAW(PPDH_COUNTER_PATH_ELEMENTS)
#define PDH_BROWSE_DLG_CONFIG __MINGW_NAME_UAW(PDH_BROWSE_DLG_CONFIG)
#define PPDH_BROWSE_DLG_CONFIG __MINGW_NAME_UAW(PPDH_BROWSE_DLG_CONFIG)
#define PDH_FMT_COUNTERVALUE_ITEM __MINGW_NAME_UAW(PDH_FMT_COUNTERVALUE_ITEM)
#define PPDH_FMT_COUNTERVALUE_ITEM __MINGW_NAME_UAW(PPDH_FMT_COUNTERVALUE_ITEM)
#define PDH_RAW_COUNTER_ITEM __MINGW_NAME_UAW(PDH_RAW_COUNTER_ITEM)
#define PPDH_RAW_COUNTER_ITEM __MINGW_NAME_UAW(PPDH_RAW_COUNTER_ITEM)
#define PDH_LOG_SERVICE_QUERY_INFO __MINGW_NAME_UAW(PDH_LOG_SERVICE_QUERY_INFO)
#define PPDH_LOG_SERVICE_QUERY_INFO __MINGW_NAME_UAW(PPDH_LOG_SERVICE_QUERY_INFO)

#define PDH_BROWSE_DLG_CONFIG_H __MINGW_NAME_AW(PDH_BROWSE_DLG_CONFIG_H)
#define PPDH_BROWSE_DLG_CONFIG_H __MINGW_NAME_AW(PPDH_BROWSE_DLG_CONFIG_H)

#define PdhOpenQuery __MINGW_NAME_AW(PdhOpenQuery)
#define PdhAddCounter __MINGW_NAME_AW(PdhAddCounter)
#define PdhGetCounterInfo __MINGW_NAME_AW(PdhGetCounterInfo)
#define PdhConnectMachine __MINGW_NAME_AW(PdhConnectMachine)
#define PdhEnumMachines __MINGW_NAME_AW(PdhEnumMachines)
#define PdhEnumObjects __MINGW_NAME_AW(PdhEnumObjects)
#define PdhEnumObjectItems __MINGW_NAME_AW(PdhEnumObjectItems)
#define PdhMakeCounterPath __MINGW_NAME_AW(PdhMakeCounterPath)
#define PdhParseCounterPath __MINGW_NAME_AW(PdhParseCounterPath)
#define PdhParseInstanceName __MINGW_NAME_AW(PdhParseInstanceName)
#define PdhValidatePath __MINGW_NAME_AW(PdhValidatePath)
#define PdhGetDefaultPerfObject __MINGW_NAME_AW(PdhGetDefaultPerfObject)
#define PdhGetDefaultPerfCounter __MINGW_NAME_AW(PdhGetDefaultPerfCounter)
#define PdhBrowseCounters __MINGW_NAME_AW(PdhBrowseCounters)
#define PdhBrowseCountersH __MINGW_NAME_AW(PdhBrowseCountersH)
#define PdhExpandCounterPath __MINGW_NAME_AW(PdhExpandCounterPath)
#define PdhGetFormattedCounterArray __MINGW_NAME_AW(PdhGetFormattedCounterArray)
#define PdhGetRawCounterArray __MINGW_NAME_AW(PdhGetRawCounterArray)
#define PdhLookupPerfNameByIndex __MINGW_NAME_AW(PdhLookupPerfNameByIndex)
#define PdhLookupPerfIndexByName __MINGW_NAME_AW(PdhLookupPerfIndexByName)
#define PdhOpenLog __MINGW_NAME_AW(PdhOpenLog)
#define PdhUpdateLog __MINGW_NAME_AW(PdhUpdateLog)
#define PdhSelectDataSource __MINGW_NAME_AW(PdhSelectDataSource)
#define PdhGetDataSourceTimeRange __MINGW_NAME_AW(PdhGetDataSourceTimeRange)
#define PdhLogServiceControl __MINGW_NAME_AW(PdhLogServiceControl)
#define PdhLogServiceQuery __MINGW_NAME_AW(PdhLogServiceQuery)
#define PdhExpandWildCardPath __MINGW_NAME_AW(PdhExpandWildCardPath)
#define PdhBindInputDataSource __MINGW_NAME_AW(PdhBindInputDataSource)
#define PdhEnumMachinesH __MINGW_NAME_AW(PdhEnumMachinesH)
#define PdhEnumObjectsH __MINGW_NAME_AW(PdhEnumObjectsH)
#define PdhEnumObjectItemsH __MINGW_NAME_AW(PdhEnumObjectItemsH)
#define PdhExpandWildCardPathH __MINGW_NAME_AW(PdhExpandWildCardPathH)
#define PdhGetDefaultPerfObjectH __MINGW_NAME_AW(PdhGetDefaultPerfObjectH)
#define PdhGetDefaultPerfCounterH __MINGW_NAME_AW(PdhGetDefaultPerfCounterH)
#define PdhEnumLogSetNames __MINGW_NAME_AW(PdhEnumLogSetNames)
#define PdhCreateSQLTables __MINGW_NAME_AW(PdhCreateSQLTables)
#define PdhVerifySQLDB __MINGW_NAME_AW(PdhVerifySQLDB)

#if (_WIN32_WINNT >= 0x0600)
PDH_FUNCTION PdhAddEnglishCounterW(PDH_HQUERY hQuery,LPCWSTR szFullCounterPath,DWORD_PTR dwUserData,PDH_HCOUNTER *phCounter);
PDH_FUNCTION PdhAddEnglishCounterA(PDH_HQUERY hQuery,LPCSTR szFullCounterPath,DWORD_PTR dwUserData,PDH_HCOUNTER *phCounter);

#define PdhAddEnglishCounter __MINGW_NAME_AW(PdhAddEnglishCounter)

PDH_FUNCTION PdhCollectQueryDataWithTime(PDH_HQUERY hQuery,LONGLONG *pllTimeStamp);

PDH_FUNCTION PdhValidatePathExW(PDH_HLOG hDataSource,LPCWSTR szFullPathBuffer);
PDH_FUNCTION PdhValidatePathExA(PDH_HLOG hDataSource,LPCSTR szFullPathBuffer);

#define PdhValidatePathEx __MINGW_NAME_AW(PdhValidatePathEx)

#endif /*(_WIN32_WINNT >= 0x0600)*/

#ifdef __cplusplus
}
#endif
#endif
