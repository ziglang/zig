/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef __ROUTING_RTUTILS_H__
#define __ROUTING_RTUTILS_H__

#include <_mingw_unicode.h>

#ifdef __cplusplus
extern "C" {
#endif

#define TRACE_USE_FILE 0x00000001
#define TRACE_USE_CONSOLE 0x00000002
#define TRACE_NO_SYNCH 0x00000004

#define TRACE_NO_STDINFO 0x00000001
#define TRACE_USE_MASK 0x00000002
#define TRACE_USE_MSEC 0x00000004
#define TRACE_USE_DATE 0x00000008

#define INVALID_TRACEID 0xFFFFFFFF

  DWORD WINAPI TraceRegisterExA(LPCSTR lpszCallerName,DWORD dwFlags);
  DWORD WINAPI TraceDeregisterA(DWORD dwTraceID);
  DWORD WINAPI TraceDeregisterExA(DWORD dwTraceID,DWORD dwFlags);
  DWORD WINAPI TraceGetConsoleA(DWORD dwTraceID,LPHANDLE lphConsole);
  DWORD __cdecl TracePrintfA(DWORD dwTraceID,LPCSTR lpszFormat,...);
  DWORD __cdecl TracePrintfExA(DWORD dwTraceID,DWORD dwFlags,LPCSTR lpszFormat,...);
  DWORD WINAPI TraceVprintfExA(DWORD dwTraceID,DWORD dwFlags,LPCSTR lpszFormat,va_list arglist);
  DWORD WINAPI TracePutsExA(DWORD dwTraceID,DWORD dwFlags,LPCSTR lpszString);
  DWORD WINAPI TraceDumpExA(DWORD dwTraceID,DWORD dwFlags,LPBYTE lpbBytes,DWORD dwByteCount,DWORD dwGroupSize,WINBOOL bAddressPrefix,LPCSTR lpszPrefix);

#define TraceRegisterA(a) TraceRegisterExA(a,0)
#define TraceVprintfA(a,b,c) TraceVprintfExA(a,0,b,c)
#define TracePutsA(a,b) TracePutsExA(a,0,b)
#define TraceDumpA(a,b,c,d,e,f) TraceDumpExA(a,0,b,c,d,e,f)

  DWORD WINAPI TraceRegisterExW(LPCWSTR lpszCallerName,DWORD dwFlags);
  DWORD WINAPI TraceDeregisterW(DWORD dwTraceID);
  DWORD WINAPI TraceDeregisterExW(DWORD dwTraceID,DWORD dwFlags);
  DWORD WINAPI TraceGetConsoleW(DWORD dwTraceID,LPHANDLE lphConsole);
  DWORD __cdecl TracePrintfW(DWORD dwTraceID,LPCWSTR lpszFormat,...);
  DWORD __cdecl TracePrintfExW(DWORD dwTraceID,DWORD dwFlags,LPCWSTR lpszFormat,...);
  DWORD WINAPI TraceVprintfExW(DWORD dwTraceID,DWORD dwFlags,LPCWSTR lpszFormat,va_list arglist);
  DWORD WINAPI TracePutsExW(DWORD dwTraceID,DWORD dwFlags,LPCWSTR lpszString);
  DWORD WINAPI TraceDumpExW(DWORD dwTraceID,DWORD dwFlags,LPBYTE lpbBytes,DWORD dwByteCount,DWORD dwGroupSize,WINBOOL bAddressPrefix,LPCWSTR lpszPrefix);

#define TraceRegisterW(a) TraceRegisterExW(a,0)
#define TraceVprintfW(a,b,c) TraceVprintfExW(a,0,b,c)
#define TracePutsW(a,b) TracePutsExW(a,0,b)
#define TraceDumpW(a,b,c,d,e,f) TraceDumpExW(a,0,b,c,d,e,f)

#define TraceRegister __MINGW_NAME_AW(TraceRegister)
#define TraceDeregister __MINGW_NAME_AW(TraceDeregister)
#define TraceDeregisterEx __MINGW_NAME_AW(TraceDeregisterEx)
#define TraceGetConsole __MINGW_NAME_AW(TraceGetConsole)
#define TracePrintf __MINGW_NAME_AW(TracePrintf)
#define TraceVprintf __MINGW_NAME_AW(TraceVprintf)
#define TracePuts __MINGW_NAME_AW(TracePuts)
#define TraceDump __MINGW_NAME_AW(TraceDump)
#define TraceRegisterEx __MINGW_NAME_AW(TraceRegisterEx)
#define TracePrintfEx __MINGW_NAME_AW(TracePrintfEx)
#define TraceVprintfEx __MINGW_NAME_AW(TraceVprintfEx)
#define TracePutsEx __MINGW_NAME_AW(TracePutsEx)
#define TraceDumpEx __MINGW_NAME_AW(TraceDumpEx)

  VOID WINAPI LogErrorA(DWORD dwMessageId,DWORD cNumberOfSubStrings,LPSTR *plpwsSubStrings,DWORD dwErrorCode);
  VOID WINAPI LogEventA(DWORD wEventType,DWORD dwMessageId,DWORD cNumberOfSubStrings,LPSTR *plpwsSubStrings);
  VOID LogErrorW(DWORD dwMessageId,DWORD cNumberOfSubStrings,LPWSTR *plpwsSubStrings,DWORD dwErrorCode);
  VOID LogEventW(DWORD wEventType,DWORD dwMessageId,DWORD cNumberOfSubStrings,LPWSTR *plpwsSubStrings);

#define LogError __MINGW_NAME_AW(LogError)
#define LogEvent __MINGW_NAME_AW(LogEvent)

  HANDLE RouterLogRegisterA(LPCSTR lpszSource);
  VOID RouterLogDeregisterA(HANDLE hLogHandle);
  VOID RouterLogEventA(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPSTR *plpszSubStringArray,DWORD dwErrorCode);
  VOID RouterLogEventDataA(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPSTR *plpszSubStringArray,DWORD dwDataBytes,LPBYTE lpDataBytes);
  VOID RouterLogEventStringA(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPSTR *plpszSubStringArray,DWORD dwErrorCode,DWORD dwErrorIndex);
  VOID __cdecl RouterLogEventExA(HANDLE hLogHandle,DWORD dwEventType,DWORD dwErrorCode,DWORD dwMessageId,LPCSTR ptszFormat,...);
  VOID RouterLogEventValistExA(HANDLE hLogHandle,DWORD dwEventType,DWORD dwErrorCode,DWORD dwMessageId,LPCSTR ptszFormat,va_list arglist);
  DWORD RouterGetErrorStringA(DWORD dwErrorCode,LPSTR *lplpszErrorString);

#define RouterLogErrorA(h,msg,count,array,err) RouterLogEventA(h,EVENTLOG_ERROR_TYPE,msg,count,array,err)
#define RouterLogWarningA(h,msg,count,array,err) RouterLogEventA(h,EVENTLOG_WARNING_TYPE,msg,count,array,err)
#define RouterLogInformationA(h,msg,count,array,err) RouterLogEventA(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,err)

#define RouterLogErrorDataA(h,msg,count,array,c,buf) RouterLogEventDataA(h,EVENTLOG_ERROR_TYPE,msg,count,array,c,buf)
#define RouterLogWarningDataA(h,msg,count,array,c,buf) RouterLogEventDataA(h,EVENTLOG_WARNING_TYPE,msg,count,array,c,buf)
#define RouterLogInformationDataA(h,msg,count,array,c,buf) RouterLogEventDataA(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,c,buf)

#define RouterLogErrorStringA(h,msg,count,array,err,index) RouterLogEventStringA(h,EVENTLOG_ERROR_TYPE,msg,count,array,err,index)
#define RouterLogWarningStringA(h,msg,count,array,err,index) RouterLogEventStringA(h,EVENTLOG_WARNING_TYPE,msg,count,array,err,index)
#define RouterLogInformationStringA(h,msg,count,array,err,index) RouterLogEventStringA(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,err,index)

  HANDLE RouterLogRegisterW(LPCWSTR lpszSource);
  VOID RouterLogDeregisterW(HANDLE hLogHandle);
  VOID RouterLogEventW(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPWSTR *plpszSubStringArray,DWORD dwErrorCode);
  VOID RouterLogEventDataW(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPWSTR *plpszSubStringArray,DWORD dwDataBytes,LPBYTE lpDataBytes);
  VOID RouterLogEventStringW(HANDLE hLogHandle,DWORD dwEventType,DWORD dwMessageId,DWORD dwSubStringCount,LPWSTR *plpszSubStringArray,DWORD dwErrorCode,DWORD dwErrorIndex);
  VOID __cdecl RouterLogEventExW(HANDLE hLogHandle,DWORD dwEventType,DWORD dwErrorCode,DWORD dwMessageId,LPCWSTR ptszFormat,...);
  VOID RouterLogEventValistExW(HANDLE hLogHandle,DWORD dwEventType,DWORD dwErrorCode,DWORD dwMessageId,LPCWSTR ptszFormat,va_list arglist);
  DWORD RouterGetErrorStringW(DWORD dwErrorCode,LPWSTR *lplpwszErrorString);

#define RouterLogErrorW(h,msg,count,array,err) RouterLogEventW(h,EVENTLOG_ERROR_TYPE,msg,count,array,err)
#define RouterLogWarningW(h,msg,count,array,err) RouterLogEventW(h,EVENTLOG_WARNING_TYPE,msg,count,array,err)
#define RouterLogInformationW(h,msg,count,array,err) RouterLogEventW(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,err)

#define RouterLogErrorDataW(h,msg,count,array,c,buf) RouterLogEventDataW(h,EVENTLOG_ERROR_TYPE,msg,count,array,c,buf)
#define RouterLogWarningDataW(h,msg,count,array,c,buf) RouterLogEventDataW(h,EVENTLOG_WARNING_TYPE,msg,count,array,c,buf)
#define RouterLogInformationDataW(h,msg,count,array,c,buf) RouterLogEventDataW(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,c,buf)

#define RouterLogErrorStringW(h,msg,count,array,err,index) RouterLogEventStringW(h,EVENTLOG_ERROR_TYPE,msg,count,array,err,index)
#define RouterLogWarningStringW(h,msg,count,array,err,index) RouterLogEventStringW(h,EVENTLOG_WARNING_TYPE,msg,count,array,err,index)
#define RouterLogInformationStringW(h,msg,count,array,err,index) RouterLogEventStringW(h,EVENTLOG_INFORMATION_TYPE,msg,count,array,err,index)

#define RouterLogRegister __MINGW_NAME_AW(RouterLogRegister)
#define RouterLogDeregister __MINGW_NAME_AW(RouterLogDeregister)
#define RouterLogEvent __MINGW_NAME_AW(RouterLogEvent)
#define RouterLogError __MINGW_NAME_AW(RouterLogError)
#define RouterLogWarning __MINGW_NAME_AW(RouterLogWarning)
#define RouterLogInformation __MINGW_NAME_AW(RouterLogInformation)

#define RouterLogEventData __MINGW_NAME_AW(RouterLogEventData)
#define RouterLogErrorData __MINGW_NAME_AW(RouterLogErrorData)
#define RouterLogWarningData __MINGW_NAME_AW(RouterLogWarningData)
#define RouterLogInformationData __MINGW_NAME_AW(RouterLogInformationData)
#define RouterLogEventString __MINGW_NAME_AW(RouterLogEventString)
#define RouterLogEventEx __MINGW_NAME_AW(RouterLogEventEx)
#define RouterLogEventValistEx __MINGW_NAME_AW(RouterLogEventValistEx)
#define RouterLogErrorString __MINGW_NAME_AW(RouterLogErrorString)
#define RouterLogWarningString __MINGW_NAME_AW(RouterLogWarningString)
#define RouterLogInformationString __MINGW_NAME_AW(RouterLogInformationString)
#define RouterGetErrorString __MINGW_NAME_AW(RouterGetErrorString)

  typedef VOID (WINAPI *WORKERFUNCTION)(PVOID);

  DWORD WINAPI QueueWorkItem(WORKERFUNCTION functionptr,PVOID context,WINBOOL serviceinalertablethread);
  DWORD WINAPI SetIoCompletionProc(HANDLE FileHandle,LPOVERLAPPED_COMPLETION_ROUTINE CompletionProc);

#define NUM_ALERTABLE_THREADS 2
#define MAX_WORKER_THREADS 10
#define WORK_QUEUE_TIMEOUT 1
#define THREAD_IDLE_TIMEOUT 10

  VOID RouterAssert(PSTR pszFailedAssertion,PSTR pszFileName,DWORD dwLineNumber,PSTR pszMessage);

#define RTASSERT(exp)
#define RTASSERTMSG(msg,exp)

#define RTUTILS_MAX_PROTOCOL_NAME_LEN 40
#define RTUTILS_MAX_PROTOCOL_DLL_LEN 48

#ifndef MAX_PROTOCOL_NAME_LEN
#define MAX_PROTOCOL_NAME_LEN RTUTILS_MAX_PROTOCOL_NAME_LEN
#else
#undef MAX_PROTOCOL_NAME_LEN
#endif
#define MAX_PROTOCOL_DLL_LEN RTUTILS_MAX_PROTOCOL_DLL_LEN

  typedef struct _MPR_PROTOCOL_0 {
    DWORD dwProtocolId;
    WCHAR wszProtocol[RTUTILS_MAX_PROTOCOL_NAME_LEN+1];
    WCHAR wszDLLName[RTUTILS_MAX_PROTOCOL_DLL_LEN+1];
  } MPR_PROTOCOL_0;

  DWORD WINAPI MprSetupProtocolEnum(DWORD dwTransportId,LPBYTE *lplpBuffer,LPDWORD lpdwEntriesRead);
  DWORD WINAPI MprSetupProtocolFree(LPVOID lpBuffer);

#define ROUTING_RESERVED
#define OPT1_1
#define OPT1_2
#define OPT2_1
#define OPT2_2
#define OPT3_1
#define OPT3_2

  struct _WAIT_THREAD_ENTRY;
  struct _WT_EVENT_ENTRY;

#define TIMER_INACTIVE 3
#define TIMER_ACTIVE 4

  typedef struct _WT_TIMER_ENTRY {
    LONGLONG te_Timeout;
    WORKERFUNCTION te_Function;
    PVOID te_Context;
    DWORD te_ContextSz;
    WINBOOL te_RunInServer;
    DWORD te_Status;
    DWORD te_ServerId;
    struct _WAIT_THREAD_ENTRY *teP_wte;
    LIST_ENTRY te_ServerLinks;
    LIST_ENTRY te_Links;
    WINBOOL te_Flag;
    DWORD te_TimerId;
  } WT_TIMER_ENTRY,*PWT_TIMER_ENTRY;

  typedef struct _WT_WORK_ITEM {
    WORKERFUNCTION wi_Function;
    PVOID wi_Context;
    DWORD wi_ContextSz;
    WINBOOL wi_RunInServer;
    struct _WT_EVENT_ENTRY *wiP_ee;
    LIST_ENTRY wi_ServerLinks;
    LIST_ENTRY wi_Links;
  } WT_WORK_ITEM,*PWT_WORK_ITEM;

#define WT_EVENT_BINDING WT_WORK_ITEM
#define PWT_EVENT_BINDING PWT_WORK_ITEM

  typedef struct _WT_EVENT_ENTRY {
    HANDLE ee_Event;
    WINBOOL ee_bManualReset;
    WINBOOL ee_bInitialState;
    WINBOOL ee_bDeleteEvent;
    DWORD ee_Status;
    WINBOOL ee_bHighPriority;

    LIST_ENTRY eeL_wi;
    WINBOOL ee_bSignalSingle;
    WINBOOL ee_bOwnerSelf;
    INT ee_ArrayIndex;
    DWORD ee_ServerId;
    struct _WAIT_THREAD_ENTRY *eeP_wte;
    LIST_ENTRY ee_ServerLinks;
    LIST_ENTRY ee_Links;
    DWORD ee_RefCount;
    WINBOOL ee_bFlag;
    DWORD ee_EventId;
  } WT_EVENT_ENTRY,*PWT_EVENT_ENTRY;

  PWT_EVENT_ENTRY WINAPI CreateWaitEvent(HANDLE pEvent OPT1_1,LPSECURITY_ATTRIBUTES lpEventAttributes OPT1_2,WINBOOL bManualReset,WINBOOL bInitialState,LPCTSTR lpName OPT1_2,WINBOOL bHighPriority,WORKERFUNCTION pFunction OPT2_1,PVOID pContext OPT2_1,DWORD dwContextSz OPT2_1,WINBOOL bRunInServerContext OPT2_1);
  PWT_EVENT_BINDING WINAPI CreateWaitEventBinding(PWT_EVENT_ENTRY pee,WORKERFUNCTION pFunction,PVOID pContext,DWORD dwContextSz,WINBOOL bRunInServerContext);
  PWT_TIMER_ENTRY WINAPI CreateWaitTimer(WORKERFUNCTION pFunction,PVOID pContext,DWORD dwContextSz,WINBOOL bRunInServerContext);
  DWORD WINAPI DeRegisterWaitEventBindingSelf(PWT_EVENT_BINDING pwiWorkItem);
  DWORD WINAPI DeRegisterWaitEventBinding(PWT_EVENT_BINDING pwiWorkItem);
  DWORD WINAPI DeRegisterWaitEventsTimers (PLIST_ENTRY pLEvents,PLIST_ENTRY pLTimers);
  DWORD WINAPI DeRegisterWaitEventsTimersSelf(PLIST_ENTRY pLEvents,PLIST_ENTRY pLTimers);
  DWORD WINAPI RegisterWaitEventBinding(PWT_EVENT_BINDING pwiWorkItem);
  DWORD WINAPI RegisterWaitEventsTimers(PLIST_ENTRY pLEventsToAdd,PLIST_ENTRY pLTimersToAdd);
  DWORD WINAPI UpdateWaitTimer(PWT_TIMER_ENTRY pte,LONGLONG *time);
  VOID WINAPI WTFree (PVOID ptr);
  VOID WINAPI WTFreeEvent(PWT_EVENT_ENTRY peeEvent);
  VOID WINAPI WTFreeTimer(PWT_TIMER_ENTRY pteTimer);
  VOID WINAPI DebugPrintWaitWorkerThreads (DWORD dwDebugLevel);

#define DEBUGPRINT_FILTER_NONCLIENT_EVENTS 0x2
#define DEBUGPRINT_FILTER_EVENTS 0x4
#define DEBUGPRINT_FILTER_TIMERS 0x8

#define ERROR_WAIT_THREAD_UNAVAILABLE 1
#define ERROR_WT_EVENT_ALREADY_DELETED 2
#define TIMER_HIGH(time) (((LARGE_INTEGER*)&time)->HighPart)
#define TIMER_LOW(time) (((LARGE_INTEGER*)&time)->LowPart)

#ifdef __cplusplus
}
#endif
#endif
