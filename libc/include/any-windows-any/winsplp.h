/*
 * winsplp.h
 *
 * This file is part of the ReactOS PSDK package.
 *
 * Contributors:
 *   Created by Amine Khaldi.
 *
 * THIS SOFTWARE IS NOT COPYRIGHTED
 *
 * This source code is offered for use in the public domain. You may
 * use, modify or distribute it freely.
 *
 * This code is distributed in the hope that it will be useful but
 * WITHOUT ANY WARRANTY. ALL WARRANTIES, EXPRESS OR IMPLIED ARE HEREBY
 * DISCLAIMED. This includes but is not limited to warranties of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if (STRICT && (NTDDI_VERSION >= NTDDI_VISTA))
#define HKEYMONITOR HKEY
#else
#define HKEYMONITOR HANDLE
#endif

#define PRINTER_NOTIFY_STATUS_ENDPOINT  1
#define PRINTER_NOTIFY_STATUS_POLL      2
#define PRINTER_NOTIFY_STATUS_INFO      4

#define ROUTER_UNKNOWN      0
#define ROUTER_SUCCESS      1
#define ROUTER_STOP_ROUTING 2

#if (NTDDI_VERSION >= NTDDI_WINXP)
#define MONITOR2_SIZE_WIN2K (sizeof(DWORD) + (sizeof(PVOID)*18))
#endif

#define COPYFILE_EVENT_SET_PRINTER_DATAEX           1
#define COPYFILE_EVENT_DELETE_PRINTER               2
#define COPYFILE_EVENT_ADD_PRINTER_CONNECTION       3
#define COPYFILE_EVENT_DELETE_PRINTER_CONNECTION    4
#define COPYFILE_EVENT_FILES_CHANGED                5

#define COPYFILE_FLAG_CLIENT_SPOOLER             0x00000001
#define COPYFILE_FLAG_SERVER_SPOOLER             0x00000002

#define PRINTER_NOTIFY_INFO_DATA_COMPACT         1

typedef struct _PRINTER_NOTIFY_INIT {
  DWORD Size;
  DWORD Reserved;
  DWORD PollTime;
} PRINTER_NOTIFY_INIT, *LPPRINTER_NOTIFY_INIT, *PPRINTER_NOTIFY_INIT;

typedef struct _SPLCLIENT_INFO_1 {
  DWORD dwSize;
  LPWSTR pMachineName;
  LPWSTR pUserName;
  DWORD dwBuildNum;
  DWORD dwMajorVersion;
  DWORD dwMinorVersion;
  WORD wProcessorArchitecture;
} SPLCLIENT_INFO_1, *LPSPLCLIENT_INFO_1, *PSPLCLIENT_INFO_1;

typedef struct _SPLCLIENT_INFO_2_V1{
  ULONG_PTR hSplPrinter;
} SPLCLIENT_INFO_2_W2K;

typedef struct _SPLCLIENT_INFO_2_V2{
#ifdef _WIN64
  DWORD64 hSplPrinter;
#else
  DWORD32 hSplPrinter;
#endif
} SPLCLIENT_INFO_2_WINXP;

typedef struct _SPLCLIENT_INFO_2_V3{
  UINT64 hSplPrinter;
} SPLCLIENT_INFO_2_LONGHORN;

typedef struct _PRINTPROVIDOR {
  WINBOOL (WINAPI *fpOpenPrinter)(PWSTR lpPrinterName, HANDLE *phPrinter,
                               PPRINTER_DEFAULTSW pDefault);
  WINBOOL (WINAPI *fpSetJob)(HANDLE hPrinter, DWORD JobID, DWORD Level,
                          LPBYTE pJob, DWORD Command);
  WINBOOL (WINAPI *fpGetJob)(HANDLE hPrinter, DWORD JobID, DWORD Level,
                          LPBYTE pJob, DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpEnumJobs)(HANDLE hPrinter, DWORD FirstJob, DWORD NoJobs,
                            DWORD Level, LPBYTE pJob, DWORD cbBuf, LPDWORD pcbNeeded,
                            LPDWORD pcReturned);
  HANDLE (WINAPI *fpAddPrinter)(LPWSTR pName, DWORD Level, LPBYTE pPrinter);
  WINBOOL (WINAPI *fpDeletePrinter)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpSetPrinter)(HANDLE hPrinter, DWORD Level, LPBYTE pPrinter,
                              DWORD Command);
  WINBOOL (WINAPI *fpGetPrinter)(HANDLE hPrinter, DWORD Level, LPBYTE pPrinter,
                              DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpEnumPrinters)(DWORD dwType, LPWSTR lpszName, DWORD dwLevel,
                                LPBYTE lpbPrinters, DWORD cbBuf, LPDWORD lpdwNeeded,
                                LPDWORD lpdwReturned);
  WINBOOL (WINAPI *fpAddPrinterDriver)(LPWSTR pName, DWORD Level, LPBYTE pDriverInfo);
  WINBOOL (WINAPI *fpEnumPrinterDrivers)(LPWSTR pName, LPWSTR pEnvironment,
                                      DWORD Level, LPBYTE pDriverInfo, DWORD cbBuf,
                                      LPDWORD pcbNeeded, LPDWORD pcbReturned);
  WINBOOL (WINAPI *fpGetPrinterDriver)(HANDLE hPrinter, LPWSTR pEnvironment,
                                    DWORD Level, LPBYTE pDriverInfo, DWORD cbBuf,
                                    LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpGetPrinterDriverDirectory)(LPWSTR pName, LPWSTR pEnvironment,
                                             DWORD Level, LPBYTE pDriverDirectory,
                                             DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpDeletePrinterDriver)(LPWSTR pName, LPWSTR pEnvironment,
                                       LPWSTR pDriverName);
  WINBOOL (WINAPI *fpAddPrintProcessor)(LPWSTR pName, LPWSTR pEnvironment,
                                     LPWSTR pPathName, LPWSTR pPrintProcessorName);
  WINBOOL (WINAPI *fpEnumPrintProcessors)(LPWSTR pName, LPWSTR pEnvironment,
                                       DWORD Level, LPBYTE pPrintProcessorInfo,
                                       DWORD cbBuf, LPDWORD pcbNeeded,
                                       LPDWORD pcbReturned);
  WINBOOL (WINAPI *fpGetPrintProcessorDirectory)(LPWSTR pName, LPWSTR pEnvironment,
                                              DWORD Level, LPBYTE pPrintProcessorInfo,
                                              DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpDeletePrintProcessor)(LPWSTR pName, LPWSTR pEnvironment,
                 LPWSTR pPrintProcessorName);
  WINBOOL (WINAPI *fpEnumPrintProcessorDatatypes)(LPWSTR pName,
                                               LPWSTR pPrintProcessorName,
                                               DWORD Level, LPBYTE pDatatypes,
                                               DWORD cbBuf, LPDWORD pcbNeeded,
                                               LPDWORD pcbReturned);
  DWORD (WINAPI *fpStartDocPrinter)(HANDLE hPrinter, DWORD Level, LPBYTE pDocInfo);
  WINBOOL (WINAPI *fpStartPagePrinter)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpWritePrinter)(HANDLE hPrinter, LPVOID pBuf, DWORD cbBuf,
                                LPDWORD pcWritten);
  WINBOOL (WINAPI *fpEndPagePrinter)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpAbortPrinter)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpReadPrinter)(HANDLE hPrinter, LPVOID pBuf, DWORD cbBuf,
                               LPDWORD pNoBytesRead);
  WINBOOL (WINAPI *fpEndDocPrinter)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpAddJob)(HANDLE hPrinter, DWORD Level, LPBYTE pData,
                          DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpScheduleJob)(HANDLE hPrinter, DWORD JobID);
  DWORD (WINAPI *fpGetPrinterData)(HANDLE hPrinter, LPWSTR pValueName,
                                   LPDWORD pType, LPBYTE pData, DWORD nSize,
                                   LPDWORD pcbNeeded);
  DWORD (WINAPI *fpSetPrinterData)(HANDLE hPrinter, LPWSTR pValueName,
                                   DWORD Type, LPBYTE pData, DWORD cbData);
  DWORD (WINAPI *fpWaitForPrinterChange)(HANDLE hPrinter, DWORD Flags);
  WINBOOL (WINAPI *fpClosePrinter)(HANDLE phPrinter);
  WINBOOL (WINAPI *fpAddForm)(HANDLE hPrinter, DWORD Level, LPBYTE pForm);
  WINBOOL (WINAPI *fpDeleteForm)(HANDLE hPrinter, LPWSTR pFormName);
  WINBOOL (WINAPI *fpGetForm)(HANDLE hPrinter, LPWSTR pFormName, DWORD Level,
                           LPBYTE pForm, DWORD cbBuf, LPDWORD pcbNeeded);
  WINBOOL (WINAPI *fpSetForm)(HANDLE hPrinter, LPWSTR pFormName, DWORD Level,
                           LPBYTE pForm);
  WINBOOL (WINAPI *fpEnumForms)(HANDLE hPrinter, DWORD Level, LPBYTE pForm,
                             DWORD cbBuf, LPDWORD pcbNeeded, LPDWORD pcReturned);
  WINBOOL (WINAPI *fpEnumMonitors)(LPWSTR pName, DWORD Level, LPBYTE pMonitors,
                                DWORD cbBuf, LPDWORD pcbNeeded,
                                LPDWORD pcReturned);
  WINBOOL (WINAPI *fpEnumPorts)(LPWSTR pName, DWORD Level, LPBYTE pPorts,
                             DWORD cbBuf, LPDWORD pcbNeeded, LPDWORD pcReturned);
  WINBOOL (WINAPI *fpAddPort)(LPWSTR pName, HWND hWnd, LPWSTR pMonitorName);
  WINBOOL (WINAPI *fpConfigurePort)(LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  WINBOOL (WINAPI *fpDeletePort)(LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  HANDLE (WINAPI *fpCreatePrinterIC)(HANDLE hPrinter, LPDEVMODEW pDevMode);
  WINBOOL (WINAPI *fpPlayGdiScriptOnPrinterIC)(HANDLE hPrinterIC, LPBYTE pIn,
                                            DWORD cIn, LPBYTE pOut, DWORD cOut,
                                            DWORD ul);
  WINBOOL (WINAPI *fpDeletePrinterIC)(HANDLE hPrinterIC);
  WINBOOL (WINAPI *fpAddPrinterConnection)(LPWSTR pName);
  WINBOOL (WINAPI *fpDeletePrinterConnection)(LPWSTR pName);
  DWORD (WINAPI *fpPrinterMessageBox)(HANDLE hPrinter, DWORD Error, HWND hWnd,
                                      LPWSTR pText, LPWSTR pCaption,
                                      DWORD dwType);
  WINBOOL (WINAPI *fpAddMonitor)(LPWSTR pName, DWORD Level, LPBYTE pMonitors);
  WINBOOL (WINAPI *fpDeleteMonitor)(LPWSTR pName, LPWSTR pEnvironment,
                                 LPWSTR pMonitorName);
  WINBOOL (WINAPI *fpResetPrinter)(HANDLE hPrinter, LPPRINTER_DEFAULTSW pDefault);
  WINBOOL (WINAPI *fpGetPrinterDriverEx)(HANDLE hPrinter, LPWSTR pEnvironment,
                                      DWORD Level, LPBYTE pDriverInfo,
                                      DWORD cbBuf, LPDWORD pcbNeeded,
                                      DWORD dwClientMajorVersion,
                                      DWORD dwClientMinorVersion,
                                      PDWORD pdwServerMajorVersion,
                                      PDWORD pdwServerMinorVersion);
  HANDLE (WINAPI *fpFindFirstPrinterChangeNotification)(HANDLE hPrinter,
                                                        DWORD fdwFlags,
                                                        DWORD fdwOptions,
                                                        LPVOID pPrinterNotifyOptions);
  WINBOOL (WINAPI *fpFindClosePrinterChangeNotification)(HANDLE hChange);
  WINBOOL (WINAPI *fpAddPortEx)(LPWSTR pName, DWORD Level, LPBYTE lpBuffer,
                             LPWSTR lpMonitorName);
  WINBOOL (WINAPI *fpShutDown)(LPVOID pvReserved);
  WINBOOL (WINAPI *fpRefreshPrinterChangeNotification)(HANDLE hPrinter,
                                                    DWORD Reserved,
                                                    PVOID pvReserved,
                                                    PVOID pPrinterNotifyInfo);
  WINBOOL (WINAPI *fpOpenPrinterEx)(LPWSTR pPrinterName, LPHANDLE phPrinter,
                                 LPPRINTER_DEFAULTSW pDefault, LPBYTE pClientInfo,
                                 DWORD Level);
  HANDLE (WINAPI *fpAddPrinterEx)(LPWSTR pName, DWORD Level, LPBYTE pPrinter,
                                  LPBYTE pClientInfo, DWORD ClientInfoLevel);
  WINBOOL (WINAPI *fpSetPort)(LPWSTR pName, LPWSTR pPortName, DWORD dwLevel,
                           LPBYTE pPortInfo);
  DWORD (WINAPI *fpEnumPrinterData)(HANDLE hPrinter, DWORD dwIndex,
                                    LPWSTR pValueName, DWORD cbValueName,
                                    LPDWORD pcbValueName, LPDWORD pType,
                                    LPBYTE pData, DWORD cbData, LPDWORD pcbData);
  DWORD (WINAPI *fpDeletePrinterData)(HANDLE hPrinter, LPWSTR pValueName);
  DWORD (WINAPI *fpClusterSplOpen)(LPCWSTR pszServer, LPCWSTR pszResource,
                                   PHANDLE phSpooler, LPCWSTR pszName,
                                   LPCWSTR pszAddress);
  DWORD (WINAPI *fpClusterSplClose)(HANDLE hSpooler);
  DWORD (WINAPI *fpClusterSplIsAlive)(HANDLE hSpooler);
  DWORD (WINAPI *fpSetPrinterDataEx)(HANDLE hPrinter, LPCWSTR pKeyName,
                                     LPCWSTR pValueName, DWORD Type,
                                     LPBYTE pData, DWORD cbData);
  DWORD (WINAPI *fpGetPrinterDataEx)(HANDLE hPrinter, LPCWSTR pKeyName,
                                     LPCWSTR pValueName, LPDWORD pType,
                                     LPBYTE pData, DWORD nSize, LPDWORD pcbNeeded);
  DWORD (WINAPI *fpEnumPrinterDataEx)(HANDLE hPrinter, LPCWSTR pKeyName,
                                      LPBYTE pEnumValues, DWORD cbEnumValues,
                                      LPDWORD pcbEnumValues, LPDWORD pnEnumValues);
  DWORD (WINAPI *fpEnumPrinterKey)(HANDLE hPrinter, LPCWSTR pKeyName,
                                   LPWSTR pSubkey, DWORD cbSubkey, LPDWORD pcbSubkey);
  DWORD (WINAPI *fpDeletePrinterDataEx)(HANDLE hPrinter, LPCWSTR pKeyName,
                                        LPCWSTR pValueName);
  DWORD (WINAPI *fpDeletePrinterKey)(HANDLE hPrinter, LPCWSTR pKeyName);
  WINBOOL (WINAPI *fpSeekPrinter)(HANDLE hPrinter, LARGE_INTEGER liDistanceToMove,
                               PLARGE_INTEGER pliNewPointer, DWORD dwMoveMethod,
                               WINBOOL bWrite);
  WINBOOL (WINAPI *fpDeletePrinterDriverEx)(LPWSTR pName, LPWSTR pEnvironment,
                                         LPWSTR pDriverName, DWORD dwDeleteFlag,
                                         DWORD dwVersionNum);
  WINBOOL (WINAPI *fpAddPerMachineConnection)(LPCWSTR pServer,
                                           LPCWSTR pPrinterName, LPCWSTR pPrintServer,
                                           LPCWSTR pProvider);
  WINBOOL (WINAPI *fpDeletePerMachineConnection)(LPCWSTR pServer,
                                              LPCWSTR pPrinterName);
  WINBOOL (WINAPI *fpEnumPerMachineConnections)(LPCWSTR pServer,
                                             LPBYTE pPrinterEnum, DWORD cbBuf,
                                             LPDWORD pcbNeeded,
                 LPDWORD pcReturned);
  WINBOOL (WINAPI *fpXcvData)(HANDLE hXcv, LPCWSTR pszDataName, PBYTE pInputData,
                           DWORD cbInputData, PBYTE pOutputData, DWORD cbOutputData,
                           PDWORD pcbOutputNeeded, PDWORD pdwStatus);
  WINBOOL (WINAPI *fpAddPrinterDriverEx)(LPWSTR pName, DWORD Level,
                                      LPBYTE pDriverInfo, DWORD dwFileCopyFlags);
  WINBOOL (WINAPI *fpSplReadPrinter)(HANDLE hPrinter, LPBYTE *pBuf, DWORD cbBuf);
  WINBOOL (WINAPI *fpDriverUnloadComplete)(LPWSTR pDriverFile);
  WINBOOL (WINAPI *fpGetSpoolFileInfo)(HANDLE hPrinter, LPWSTR *pSpoolDir,
                                    LPHANDLE phFile, HANDLE hSpoolerProcess,
                                    HANDLE hAppProcess);
  WINBOOL (WINAPI *fpCommitSpoolData)(HANDLE hPrinter, DWORD cbCommit);
  WINBOOL (WINAPI *fpCloseSpoolFileHandle)(HANDLE hPrinter);
  WINBOOL (WINAPI *fpFlushPrinter)(HANDLE hPrinter, LPBYTE pBuf, DWORD cbBuf,
                                LPDWORD pcWritten, DWORD cSleep);
  DWORD (WINAPI *fpSendRecvBidiData)(HANDLE hPort, LPCWSTR pAction,
                                     LPBIDI_REQUEST_CONTAINER pReqData,
                                     LPBIDI_RESPONSE_CONTAINER *ppResData);
  WINBOOL (WINAPI *fpAddDriverCatalog)(HANDLE hPrinter, DWORD dwLevel,
                                    VOID *pvDriverInfCatInfo, DWORD dwCatalogCopyFlags);
} PRINTPROVIDOR, *LPPRINTPROVIDOR;

typedef struct _PRINTPROCESSOROPENDATA {
  PDEVMODEW pDevMode;
  LPWSTR pDatatype;
  LPWSTR pParameters;
  LPWSTR pDocumentName;
  DWORD JobId;
  LPWSTR pOutputFile;
  LPWSTR pPrinterName;
} PRINTPROCESSOROPENDATA, *LPPRINTPROCESSOROPENDATA, *PPRINTPROCESSOROPENDATA;

typedef struct _MONITORREG {
  DWORD cbSize;
  LONG (WINAPI *fpCreateKey)(HANDLE hcKey, LPCWSTR pszSubKey, DWORD dwOptions,
                             REGSAM samDesired,
                             PSECURITY_ATTRIBUTES pSecurityAttributes,
                             PHANDLE phckResult, PDWORD pdwDisposition,
                             HANDLE hSpooler);
  LONG (WINAPI *fpOpenKey)(HANDLE hcKey, LPCWSTR pszSubKey, REGSAM samDesired,
                           PHANDLE phkResult, HANDLE hSpooler);
  LONG (WINAPI *fpCloseKey)(HANDLE hcKey, HANDLE hSpooler);
  LONG (WINAPI *fpDeleteKey)(HANDLE hcKey, LPCWSTR pszSubKey, HANDLE hSpooler);
  LONG (WINAPI *fpEnumKey)(HANDLE hcKey, DWORD dwIndex, LPWSTR pszName,
                           PDWORD pcchName, PFILETIME pftLastWriteTime,
                           HANDLE hSpooler);
  LONG (WINAPI *fpQueryInfoKey)(HANDLE hcKey, PDWORD pcSubKeys, PDWORD pcbKey,
                                PDWORD pcValues, PDWORD pcbValue, PDWORD pcbData,
                                PDWORD pcbSecurityDescriptor,
                                PFILETIME pftLastWriteTime,
                                HANDLE hSpooler);
  LONG (WINAPI *fpSetValue)(HANDLE hcKey, LPCWSTR pszValue, DWORD dwType,
                const BYTE* pData, DWORD cbData, HANDLE hSpooler);
  LONG (WINAPI *fpDeleteValue)(HANDLE hcKey, LPCWSTR pszValue, HANDLE hSpooler);
  LONG (WINAPI *fpEnumValue)(HANDLE hcKey, DWORD dwIndex, LPWSTR pszValue,
                             PDWORD pcbValue, PDWORD pType, PBYTE pData, PDWORD pcbData,
                             HANDLE hSpooler);
  LONG (WINAPI *fpQueryValue)(HANDLE hcKey, LPCWSTR pszValue, PDWORD pType,
                              PBYTE pData, PDWORD pcbData, HANDLE hSpooler);
} MONITORREG, *PMONITORREG;

typedef struct _MONITORINIT {
  DWORD cbSize;
  HANDLE hSpooler;
  HKEYMONITOR hckRegistryRoot;
  PMONITORREG pMonitorReg;
  WINBOOL bLocal;
  LPCWSTR pszServerName;
} MONITORINIT, *PMONITORINIT;

typedef struct _MONITOR {
  WINBOOL (WINAPI *pfnEnumPorts)(LPWSTR pName, DWORD Level, LPBYTE pPorts,
                              DWORD cbBuf, LPDWORD pcbNeeded, LPDWORD pcReturned);
  WINBOOL (WINAPI *pfnOpenPort)(LPWSTR pName, PHANDLE pHandle);
  WINBOOL (WINAPI *pfnOpenPortEx)(LPWSTR pPortName, LPWSTR pPrinterName,
                               PHANDLE pHandle, struct _MONITOR *pMonitor);
  WINBOOL (WINAPI *pfnStartDocPort)(HANDLE hPort, LPWSTR pPrinterName,
                                 DWORD JobId, DWORD Level, LPBYTE pDocInfo);
  WINBOOL (WINAPI *pfnWritePort)(HANDLE hPort, LPBYTE pBuffer, DWORD cbBuf,
                              LPDWORD pcbWritten);
  WINBOOL (WINAPI *pfnReadPort)(HANDLE hPort, LPBYTE pBuffer, DWORD cbBuffer,
                             LPDWORD pcbRead);
  WINBOOL (WINAPI *pfnEndDocPort)(HANDLE hPort);
  WINBOOL (WINAPI *pfnClosePort)(HANDLE hPort);
  WINBOOL (WINAPI *pfnAddPort)(LPWSTR pName, HWND hWnd, LPWSTR pMonitorName);
  WINBOOL (WINAPI *pfnAddPortEx)(LPWSTR pName, DWORD Level, LPBYTE lpBuffer,
                              LPWSTR lpMonitorName);
  WINBOOL (WINAPI *pfnConfigurePort)(LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  WINBOOL (WINAPI *pfnDeletePort)(LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  WINBOOL (WINAPI *pfnGetPrinterDataFromPort)(HANDLE hPort, DWORD ControlID,
                                           LPWSTR pValueName, LPWSTR lpInBuffer,
                                           DWORD cbInBuffer, LPWSTR lpOutBuffer,
                                           DWORD cbOutBuffer, LPDWORD lpcbReturned);
  WINBOOL (WINAPI *pfnSetPortTimeOuts)(HANDLE hPort, LPCOMMTIMEOUTS lpCTO,
                                    DWORD reserved);
  WINBOOL (WINAPI *pfnXcvOpenPort)(LPCWSTR pszObject, ACCESS_MASK GrantedAccess, PHANDLE phXcv);
  DWORD (WINAPI *pfnXcvDataPort)(HANDLE hXcv, LPCWSTR pszDataName,
                                 PBYTE pInputData, DWORD cbInputData,
                                 PBYTE pOutputData, DWORD cbOutputData,
                                 PDWORD pcbOutputNeeded);
  WINBOOL (WINAPI *pfnXcvClosePort)(HANDLE hXcv);
} MONITOR, *LPMONITOR;

typedef struct _MONITOREX {
  DWORD dwMonitorSize;
  MONITOR Monitor;
} MONITOREX, *LPMONITOREX;

typedef struct _MONITOR2 {
  DWORD cbSize;
  WINBOOL (WINAPI *pfnEnumPorts)(HANDLE hMonitor, LPWSTR pName, DWORD Level, LPBYTE pPorts,
                              DWORD cbBuf, LPDWORD pcbNeeded,
                              LPDWORD pcReturned);
  WINBOOL (WINAPI *pfnOpenPort)(HANDLE hMonitor, LPWSTR pName, PHANDLE pHandle);
  WINBOOL (WINAPI *pfnOpenPortEx)(HANDLE hMonitor, HANDLE hMonitorPort, LPWSTR pPortName, LPWSTR pPrinterName,
                               PHANDLE pHandle, struct _MONITOR2 *pMonitor2);
  WINBOOL (WINAPI *pfnStartDocPort)(HANDLE hPort, LPWSTR pPrinterName,
                                 DWORD JobId, DWORD Level, LPBYTE pDocInfo);
  WINBOOL (WINAPI *pfnWritePort)(HANDLE hPort, LPBYTE pBuffer, DWORD cbBuf,
                              LPDWORD pcbWritten);
  WINBOOL (WINAPI *pfnReadPort)(HANDLE hPort, LPBYTE pBuffer, DWORD cbBuffer,
                             LPDWORD pcbRead);
  WINBOOL (WINAPI *pfnEndDocPort)(HANDLE hPort);
  WINBOOL (WINAPI *pfnClosePort)(HANDLE hPort);
  WINBOOL (WINAPI *pfnAddPort)(HANDLE hMonitor, LPWSTR pName, HWND hWnd, LPWSTR pMonitorName);
  WINBOOL (WINAPI *pfnAddPortEx)(HANDLE hMonitor, LPWSTR pName, DWORD Level, LPBYTE lpBuffer,
                              LPWSTR lpMonitorName);
  WINBOOL (WINAPI *pfnConfigurePort)(HANDLE hMonitor, LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  WINBOOL (WINAPI *pfnDeletePort)(HANDLE hMonitor, LPWSTR pName, HWND hWnd, LPWSTR pPortName);
  WINBOOL (WINAPI *pfnGetPrinterDataFromPort)(HANDLE hPort, DWORD ControlID,
                                           LPWSTR pValueName, LPWSTR lpInBuffer,
                                           DWORD cbInBuffer, LPWSTR lpOutBuffer,
                                           DWORD cbOutBuffer, LPDWORD lpcbReturned);
  WINBOOL (WINAPI *pfnSetPortTimeOuts)(HANDLE hPort, LPCOMMTIMEOUTS lpCTO,
                                    DWORD reserved);
  WINBOOL (WINAPI *pfnXcvOpenPort)(HANDLE hMonitor, LPCWSTR pszObject,
                                ACCESS_MASK GrantedAccess, PHANDLE phXcv);
  DWORD (WINAPI *pfnXcvDataPort)(HANDLE hXcv, LPCWSTR pszDataName,
                                 PBYTE pInputData, DWORD cbInputData,
                                 PBYTE pOutputData, DWORD cbOutputData,
                                 PDWORD pcbOutputNeeded);
  WINBOOL (WINAPI *pfnXcvClosePort)(HANDLE hXcv);
  VOID (WINAPI *pfnShutdown)(HANDLE hMonitor);
#if (NTDDI_VERSION >= NTDDI_WINXP)
 DWORD (WINAPI *pfnSendRecvBidiDataFromPort)(HANDLE hPort, DWORD dwAccessBit,
                                             LPCWSTR pAction,
                                             PBIDI_REQUEST_CONTAINER pReqData,
                                             PBIDI_RESPONSE_CONTAINER *ppResData);
#endif
#if (NTDDI_VERSION >= NTDDI_WIN7)
  DWORD (WINAPI *pfnNotifyUsedPorts)(HANDLE hMonitor, DWORD cPorts,
                                   PCWSTR *ppszPorts);

  DWORD (WINAPI *pfnNotifyUnusedPorts)(HANDLE hMonitor, DWORD cPorts,
                                       PCWSTR *ppszPorts);
#endif
} MONITOR2, *LPMONITOR2, *PMONITOR2;

typedef struct _MONITORUI {
  DWORD dwMonitorUISize;
  WINBOOL (WINAPI *pfnAddPortUI)(PCWSTR pszServer, HWND hWnd,
                              PCWSTR pszPortNameIn, PWSTR *ppszPortNameOut);
  WINBOOL (WINAPI *pfnConfigurePortUI)(PCWSTR pName, HWND hWnd, PCWSTR pPortName);
  WINBOOL (WINAPI *pfnDeletePortUI)(PCWSTR pszServer, HWND hWnd, PCWSTR pszPortName);
} MONITORUI, *PMONITORUI;

#if (NTDDI_VERSION >= NTDDI_WINXP)

typedef enum {
  kMessageBox = 0
} UI_TYPE;

typedef struct {
  DWORD cbSize;
  LPWSTR pTitle;
  LPWSTR pMessage;
  DWORD Style;
  DWORD dwTimeout;
  WINBOOL bWait;
} MESSAGEBOX_PARAMS, *PMESSAGEBOX_PARAMS;

typedef struct {
  UI_TYPE UIType;
  MESSAGEBOX_PARAMS MessageBoxParams;
} SHOWUIPARAMS, *PSHOWUIPARAMS;

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03)
#ifndef __ATTRIBUTE_INFO_3__
#define __ATTRIBUTE_INFO_3__
typedef struct _ATTRIBUTE_INFO_3 {
  DWORD dwJobNumberOfPagesPerSide;
  DWORD dwDrvNumberOfPagesPerSide;
  DWORD dwNupBorderFlags;
  DWORD dwJobPageOrderFlags;
  DWORD dwDrvPageOrderFlags;
  DWORD dwJobNumberOfCopies;
  DWORD dwDrvNumberOfCopies;
  DWORD dwColorOptimization;
  short dmPrintQuality;
  short dmYResolution;
} ATTRIBUTE_INFO_3, *PATTRIBUTE_INFO_3;
#endif /* __ATTRIBUTE_INFO_3__ */
#endif /* (NTDDI_VERSION >= NTDDI_WS03) */

#if (NTDDI_VERSION >= NTDDI_VISTA)

typedef WINBOOL
(CALLBACK *ROUTER_NOTIFY_CALLBACK)(
  DWORD dwCommand,
  PVOID pContext,
  DWORD dwColor,
  PPRINTER_NOTIFY_INFO pNofityInfo,
  DWORD fdwFlags,
  PDWORD pdwResult);

typedef enum _NOTIFICATION_CALLBACK_COMMANDS {
  NOTIFICATION_COMMAND_NOTIFY,
  NOTIFICATION_COMMAND_CONTEXT_ACQUIRE,
  NOTIFICATION_COMMAND_CONTEXT_RELEASE
} NOTIFICATION_CALLBACK_COMMANDS;

typedef struct _NOTIFICATION_CONFIG_1 {
  UINT cbSize;
  DWORD fdwFlags;
  ROUTER_NOTIFY_CALLBACK pfnNotifyCallback;
  PVOID pContext;
} NOTIFICATION_CONFIG_1, *PNOTIFICATION_CONFIG_1;

typedef enum _NOTIFICATION_CONFIG_FLAGS {
  NOTIFICATION_CONFIG_CREATE_EVENT = 1 << 0,
  NOTIFICATION_CONFIG_REGISTER_CALLBACK = 1 << 1,
  NOTIFICATION_CONFIG_EVENT_TRIGGER = 1 << 2,
  NOTIFICATION_CONFIG_ASYNC_CHANNEL = 1 << 3
} NOTIFICATION_CONFIG_FLAGS;

typedef struct _SPLCLIENT_INFO_3 {
  UINT cbSize;
  DWORD dwFlags;
  DWORD dwSize;
  PWSTR pMachineName;
  PWSTR pUserName;
  DWORD dwBuildNum;
  DWORD dwMajorVersion;
  DWORD dwMinorVersion;
  WORD wProcessorArchitecture;
  UINT64 hSplPrinter;
} SPLCLIENT_INFO_3, *PSPLCLIENT_INFO_3, *LPSPLCLIENT_INFO_3;

#ifndef __ATTRIBUTE_INFO_4__
#define __ATTRIBUTE_INFO_4__

typedef struct _ATTRIBUTE_INFO_4 {
  DWORD dwJobNumberOfPagesPerSide;
  DWORD dwDrvNumberOfPagesPerSide;
  DWORD dwNupBorderFlags;
  DWORD dwJobPageOrderFlags;
  DWORD dwDrvPageOrderFlags;
  DWORD dwJobNumberOfCopies;
  DWORD dwDrvNumberOfCopies;
  DWORD dwColorOptimization;
  short dmPrintQuality;
  short dmYResolution;
  DWORD dwDuplexFlags;
  DWORD dwNupDirection;
  DWORD dwBookletFlags;
  DWORD dwScalingPercentX;
  DWORD dwScalingPercentY;
} ATTRIBUTE_INFO_4, *PATTRIBUTE_INFO_4;

#define REVERSE_PAGES_FOR_REVERSE_DUPLEX (0x00000001)
#define DONT_SEND_EXTRA_PAGES_FOR_DUPLEX (0x00000001 << 1)

#define RIGHT_THEN_DOWN                  (0x00000001)
#define DOWN_THEN_RIGHT                  (0x00000001 << 1)
#define LEFT_THEN_DOWN                   (0x00000001 << 2)
#define DOWN_THEN_LEFT                   (0x00000001 << 3)

#define BOOKLET_EDGE_LEFT                0x00000000
#define BOOKLET_EDGE_RIGHT               0x00000001

#endif /* __ATTRIBUTE_INFO_4__ */

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

#if (OSVER(NTDDI_VERSION) == NTDDI_W2K)
typedef SPLCLIENT_INFO_2_W2K SPLCLIENT_INFO_2, *PSPLCLIENT_INFO_2, *LPSPLCLIENT_INFO_2;
#elif ((OSVER(NTDDI_VERSION) == NTDDI_WINXP) || (OSVER(NTDDI_VERSION) == NTDDI_WS03))
typedef SPLCLIENT_INFO_2_WINXP SPLCLIENT_INFO_2, *PSPLCLIENT_INFO_2, *LPSPLCLIENT_INFO_2;
#else
typedef SPLCLIENT_INFO_2_LONGHORN SPLCLIENT_INFO_2, *PSPLCLIENT_INFO_2, *LPSPLCLIENT_INFO_2;
#endif /* (OSVER(NTDDI_VERSION) == NTDDI_W2K) */

WINBOOL
WINAPI
InitializePrintProvidor(
  LPPRINTPROVIDOR pPrintProvidor,
  DWORD cbPrintProvidor,
  LPWSTR pFullRegistryPath);

HANDLE
WINAPI
OpenPrintProcessor(
  LPWSTR pPrinterName,
  PPRINTPROCESSOROPENDATA pPrintProcessorOpenData);

WINBOOL
WINAPI
PrintDocumentOnPrintProcessor(
  HANDLE hPrintProcessor,
  LPWSTR pDocumentName);

WINBOOL
WINAPI
ClosePrintProcessor(
  HANDLE hPrintProcessor);

WINBOOL
WINAPI
ControlPrintProcessor(
  HANDLE hPrintProcessor,
  DWORD Command);

DWORD
WINAPI
GetPrintProcessorCapabilities(
  LPTSTR pValueName,
  DWORD dwAttributes,
  LPBYTE pData,
  DWORD nSize,
  LPDWORD pcbNeeded);

WINBOOL
WINAPI
InitializeMonitor(
  LPWSTR pRegistryRoot);

WINBOOL
WINAPI
OpenPort(
  LPWSTR pName,
  PHANDLE pHandle);

WINBOOL
WINAPI
WritePort(
  HANDLE hPort,
  LPBYTE pBuffer,
  DWORD cbBuf,
  LPDWORD pcbWritten);

WINBOOL
WINAPI
ReadPort(
  HANDLE hPort,
  LPBYTE pBuffer,
  DWORD cbBuffer,
  LPDWORD pcbRead);

WINBOOL
WINAPI
ClosePort(
  HANDLE hPort);

WINBOOL
WINAPI
XcvOpenPort(
  LPCWSTR pszObject,
  ACCESS_MASK GrantedAccess,
  PHANDLE phXcv);

DWORD
WINAPI
XcvDataPort(
  HANDLE hXcv,
  LPCWSTR pszDataName,
  PBYTE pInputData,
  DWORD cbInputData,
  PBYTE pOutputData,
  DWORD cbOutputData,
  PDWORD pcbOutputNeeded);

WINBOOL
WINAPI
XcvClosePort(
  HANDLE hXcv);

WINBOOL
WINAPI
AddPortUI(
  PCWSTR pszServer,
  HWND hWnd,
  PCWSTR pszMonitorNameIn,
  PWSTR *ppszPortNameOut);

WINBOOL
WINAPI
ConfigurePortUI(
  PCWSTR pszServer,
  HWND hWnd,
  PCWSTR pszPortName);

WINBOOL
WINAPI
DeletePortUI(
  PCWSTR pszServer,
  HWND hWnd,
  PCWSTR pszPortName);

WINBOOL
WINAPI
SplDeleteSpoolerPortStart(
  PCWSTR pPortName);

WINBOOL
WINAPI
SplDeleteSpoolerPortEnd(
  PCWSTR pName,
  WINBOOL bDeletePort);

WINBOOL
WINAPI
SpoolerCopyFileEvent(
  LPWSTR pszPrinterName,
  LPWSTR pszKey,
  DWORD dwCopyFileEvent);

DWORD
WINAPI
GenerateCopyFilePaths(
  LPCWSTR pszPrinterName,
  LPCWSTR pszDirectory,
  LPBYTE pSplClientInfo,
  DWORD dwLevel,
  LPWSTR pszSourceDir,
  LPDWORD pcchSourceDirSize,
  LPWSTR pszTargetDir,
  LPDWORD pcchTargetDirSize,
  DWORD dwFlags);

HANDLE WINAPI CreatePrinterIC(HANDLE hPrinter, LPDEVMODEW pDevMode);
WINBOOL WINAPI PlayGdiScriptOnPrinterIC(HANDLE hPrinterIC, LPBYTE pIn,
                                     DWORD cIn, LPBYTE pOut, DWORD cOut, DWORD ul);
WINBOOL WINAPI DeletePrinterIC(HANDLE hPrinterIC);
WINBOOL WINAPI DevQueryPrint(HANDLE hPrinter, LPDEVMODEW pDevMode, DWORD *pResID);
HANDLE WINAPI RevertToPrinterSelf(VOID);
WINBOOL WINAPI ImpersonatePrinterClient(HANDLE hToken);
WINBOOL WINAPI ReplyPrinterChangeNotification(HANDLE hNotify, DWORD fdwFlags,
                                           PDWORD pdwResult, PVOID pPrinterNotifyInfo);
WINBOOL WINAPI ReplyPrinterChangeNotificationEx(HANDLE hNotify, DWORD dwColor,
                                             DWORD fdwFlags, PDWORD pdwResult,
                                             PVOID pPrinterNotifyInfo);
WINBOOL WINAPI PartialReplyPrinterChangeNotification(HANDLE hNotify,
                                                  PPRINTER_NOTIFY_INFO_DATA pInfoDataSrc);
PPRINTER_NOTIFY_INFO WINAPI RouterAllocPrinterNotifyInfo(DWORD cPrinterNotifyInfoData);
WINBOOL WINAPI RouterFreePrinterNotifyInfo(PPRINTER_NOTIFY_INFO pInfo);

WINBOOL WINAPI AppendPrinterNotifyInfoData(PPRINTER_NOTIFY_INFO pInfoDest,
                                        PPRINTER_NOTIFY_INFO_DATA pInfoDataSrc,
                                        DWORD fdwFlags);
DWORD WINAPI CallRouterFindFirstPrinterChangeNotification(HANDLE hPrinter,
                                                          DWORD fdwFlags,
                                                          DWORD fdwOptions,
                                                          HANDLE hNotify,
                                                          PPRINTER_NOTIFY_OPTIONS pPrinterNotifyOptions);
WINBOOL WINAPI ProvidorFindFirstPrinterChangeNotification(HANDLE hPrinter,
                                                       DWORD fdwFlags,
                                                       DWORD fdwOptions,
                                                       HANDLE hNotify,
                                                       PVOID pvReserved0,
                                                       PVOID pvReserved1);
WINBOOL WINAPI ProvidorFindClosePrinterChangeNotification(HANDLE hPrinter);

/* Spooler */
WINBOOL WINAPI SpoolerFindFirstPrinterChangeNotification(HANDLE hPrinter,
                                                      DWORD fdwFlags,
                                                      DWORD fdwOptions,
                                                      PHANDLE phEvent,
                                                      PVOID pPrinterNotifyOptions,
                                                      PVOID pvReserved);
WINBOOL WINAPI SpoolerFindNextPrinterChangeNotification(HANDLE hPrinter,
                                                     LPDWORD pfdwChange,
                                                     PVOID pvReserved0,
                                                     PVOID ppPrinterNotifyInfo);
VOID WINAPI SpoolerFreePrinterNotifyInfo(PPRINTER_NOTIFY_INFO pInfo);
WINBOOL WINAPI SpoolerFindClosePrinterChangeNotification(HANDLE hPrinter);

/* Port monitor / Language monitor / Print monitor */
LPMONITOR2 WINAPI InitializePrintMonitor2(PMONITORINIT pMonitorInit,
                                          PHANDLE phMonitor);
PMONITORUI WINAPI InitializePrintMonitorUI(VOID);
LPMONITOREX WINAPI InitializePrintMonitor(LPWSTR pRegistryRoot);
WINBOOL WINAPI InitializeMonitorEx(LPWSTR pRegistryRoot, LPMONITOR pMonitor);

#if (NTDDI_VERSION >= NTDDI_WINXP)

PBIDI_RESPONSE_CONTAINER WINAPI RouterAllocBidiResponseContainer(DWORD Count);
PVOID WINAPI RouterAllocBidiMem(size_t NumBytes);
DWORD WINAPI RouterFreeBidiResponseContainer(PBIDI_RESPONSE_CONTAINER pData);
VOID WINAPI RouterFreeBidiMem(PVOID pMemPointer);

WINBOOL
WINAPI
SplPromptUIInUsersSession(
  HANDLE hPrinter,
  DWORD JobId,
  PSHOWUIPARAMS pUIParams,
  DWORD *pResponse);

DWORD
WINAPI
SplIsSessionZero(
  HANDLE hPrinter,
  DWORD JobId,
  WINBOOL *pIsSessionZero);

#endif /* (NTDDI_VERSION >= NTDDI_WINXP) */

#if (NTDDI_VERSION >= NTDDI_WS03)
WINBOOL
WINAPI
GetJobAttributes(
  LPWSTR pPrinterName,
  LPDEVMODEW pDevmode,
  PATTRIBUTE_INFO_3 pAttributeInfo);
#endif

#if (NTDDI_VERSION >= NTDDI_VISTA)

#define FILL_WITH_DEFAULTS   0x1

WINBOOL
WINAPI
GetJobAttributesEx(
  LPWSTR pPrinterName,
  LPDEVMODEW pDevmode,
  DWORD dwLevel,
  LPBYTE pAttributeInfo,
  DWORD nSize,
  DWORD dwFlags);

WINBOOL WINAPI SpoolerRefreshPrinterChangeNotification(HANDLE hPrinter,
                                                    DWORD dwColor,
                                                    PPRINTER_NOTIFY_OPTIONS pOptions,
                                                    PPRINTER_NOTIFY_INFO *ppInfo);

#endif /* (NTDDI_VERSION >= NTDDI_VISTA) */

/* FIXME : The following declarations are not present in the official header */

WINBOOL WINAPI OpenPrinterToken(PHANDLE phToken);
WINBOOL WINAPI SetPrinterToken(HANDLE hToken);
WINBOOL WINAPI ClosePrinterToken(HANDLE hToken);
WINBOOL WINAPI InstallPrintProcessor(HWND hWnd);

#ifdef __cplusplus
}
#endif
