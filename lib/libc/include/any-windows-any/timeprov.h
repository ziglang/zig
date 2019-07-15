/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef TIMEPROV_H
#define TIMEPROV_H

#ifdef __cplusplus
extern "C" {
#endif

#define wszW32TimeRegKeyTimeProviders L"System\\CurrentControlSet\\Services\\W32Time\\TimeProviders"
#define wszW32TimeRegKeyPolicyTimeProviders L"Software\\Policies\\Microsoft\\W32Time\\TimeProviders"
#define wszW32TimeRegValueEnabled L"Enabled"
#define wszW32TimeRegValueDllName L"DllName"
#define wszW32TimeRegValueInputProvider L"InputProvider"

#define TSF_Hardware 0x00000001
#define TSF_Authenticated 0x00000002

  typedef enum TimeProvCmd {
    TPC_TimeJumped,TPC_UpdateConfig,TPC_PollIntervalChanged,TPC_GetSamples,TPC_NetTopoChange,TPC_Query,TPC_Shutdown
  } TimeProvCmd;

  typedef enum TimeSysInfo {
    TSI_LastSyncTime,TSI_ClockTickSize,TSI_ClockPrecision,TSI_CurrentTime,TSI_PhaseOffset,TSI_TickCount,TSI_LeapFlags,TSI_Stratum,
    TSI_ReferenceIdentifier,TSI_PollInterval,TSI_RootDelay,TSI_RootDispersion,TSI_TSFlags
  } TimeSysInfo;

  typedef enum TimeJumpedFlags {
    TJF_Default=0,TJF_UserRequested=1
  } TimeJumpedFlags;

  typedef enum NetTopoChangeFlags {
    NTC_Default=0,NTC_UserRequested=1
  } NetTopoChangeFlags;

  typedef enum TimeProvState {
    TPS_Running,TPS_Error
  } TimeProvState;

  struct SetProviderStatusInfo;

  typedef void (WINAPI SetProviderStatusInfoFreeFunc)(struct SetProviderStatusInfo *pspsi);

  typedef struct SetProviderStatusInfo {
    TimeProvState tpsCurrentState;
    DWORD dwStratum;
    LPWSTR wszProvName;
    HANDLE hWaitEvent;
    SetProviderStatusInfoFreeFunc *pfnFree;
    HRESULT *pHr;
    DWORD *pdwSysStratum;
  } SetProviderStatusInfo;

  typedef HRESULT (WINAPI GetTimeSysInfoFunc)(TimeSysInfo eInfo,void *pvInfo);
  typedef HRESULT (WINAPI LogTimeProvEventFunc)(WORD wType,WCHAR *wszProvName,WCHAR *wszMessage);
  typedef HRESULT (WINAPI AlertSamplesAvailFunc)(void);
  typedef HRESULT (WINAPI SetProviderStatusFunc)(SetProviderStatusInfo *pspsi);

  typedef struct TimeProvSysCallbacks {
    DWORD dwSize;
    GetTimeSysInfoFunc *pfnGetTimeSysInfo;
    LogTimeProvEventFunc *pfnLogTimeProvEvent;
    AlertSamplesAvailFunc *pfnAlertSamplesAvail;
    SetProviderStatusFunc *pfnSetProviderStatus;
  } TimeProvSysCallbacks;

  typedef void *TimeProvArgs;

  typedef struct TimeSample {
    DWORD dwSize;
    DWORD dwRefid;
    __MINGW_EXTENSION signed __int64 toOffset;
    __MINGW_EXTENSION signed __int64 toDelay;
    __MINGW_EXTENSION unsigned __int64 tpDispersion;
    __MINGW_EXTENSION unsigned __int64 nSysTickCount;
    __MINGW_EXTENSION signed __int64 nSysPhaseOffset;
    BYTE nLeapFlags;
    BYTE nStratum;
    DWORD dwTSFlags;
    WCHAR wszUniqueName[256];
  } TimeSample;

  typedef struct TpcGetSamplesArgs {
    BYTE *pbSampleBuf;
    DWORD cbSampleBuf;
    DWORD dwSamplesReturned;
    DWORD dwSamplesAvailable;
  } TpcGetSamplesArgs;

  typedef struct TpcTimeJumpedArgs {
    TimeJumpedFlags tjfFlags;
  } TpcTimeJumpedArgs;

  typedef struct TpcNetTopoChangeArgs {
    NetTopoChangeFlags ntcfFlags;
  } TpcNetTopoChangeArgs;

  typedef void *TimeProvHandle;

  HRESULT WINAPI TimeProvOpen(WCHAR *wszName,TimeProvSysCallbacks *pSysCallbacks,TimeProvHandle *phTimeProv);
  HRESULT WINAPI TimeProvCommand(TimeProvHandle hTimeProv,TimeProvCmd eCmd,TimeProvArgs pvArgs);
  HRESULT WINAPI TimeProvClose(TimeProvHandle hTimeProv);

#ifdef __cplusplus
}
#endif
#endif
