/**
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
#ifndef _ALERT_
#define _ALERT_

#ifdef __cplusplus
extern "C" {
#endif

  NET_API_STATUS WINAPI NetAlertRaise(LPCWSTR AlertEventName,LPVOID Buffer,DWORD BufferSize);
  NET_API_STATUS WINAPI NetAlertRaiseEx(LPCWSTR AlertEventName,LPVOID VariableInfo,DWORD VariableInfoSize,LPCWSTR ServiceName);

  typedef struct _STD_ALERT {
    DWORD alrt_timestamp;
    WCHAR alrt_eventname[EVLEN + 1];
    WCHAR alrt_servicename[SNLEN + 1];
  } STD_ALERT,*PSTD_ALERT,*LPSTD_ALERT;

  typedef struct _ADMIN_OTHER_INFO {
    DWORD alrtad_errcode;
    DWORD alrtad_numstrings;
  } ADMIN_OTHER_INFO,*PADMIN_OTHER_INFO,*LPADMIN_OTHER_INFO;

  typedef struct _ERRLOG_OTHER_INFO {
    DWORD alrter_errcode;
    DWORD alrter_offset;
  } ERRLOG_OTHER_INFO,*PERRLOG_OTHER_INFO,*LPERRLOG_OTHER_INFO;

  typedef struct _PRINT_OTHER_INFO {
    DWORD alrtpr_jobid;
    DWORD alrtpr_status;
    DWORD alrtpr_submitted;
    DWORD alrtpr_size;
  } PRINT_OTHER_INFO,*PPRINT_OTHER_INFO,*LPPRINT_OTHER_INFO;

  typedef struct _USER_OTHER_INFO {
    DWORD alrtus_errcode;
    DWORD alrtus_numstrings;
  } USER_OTHER_INFO,*PUSER_OTHER_INFO,*LPUSER_OTHER_INFO;

#define ALERTER_MAILSLOT L"\\\\.\\MAILSLOT\\Alerter"
#define ALERT_OTHER_INFO(x) ((LPBYTE)(x) + sizeof(STD_ALERT))
#define ALERT_VAR_DATA(p) ((LPBYTE)(p) + sizeof(*p))

#define ALERT_PRINT_EVENT L"PRINTING"
#define ALERT_MESSAGE_EVENT L"MESSAGE"
#define ALERT_ERRORLOG_EVENT L"ERRORLOG"
#define ALERT_ADMIN_EVENT L"ADMIN"
#define ALERT_USER_EVENT L"USER"

#define PRJOB_QSTATUS 0x3
#define PRJOB_DEVSTATUS 0x1fc
#define PRJOB_COMPLETE 0x4
#define PRJOB_INTERV 0x8
#define PRJOB_ERROR 0x10
#define PRJOB_DESTOFFLINE 0x20
#define PRJOB_DESTPAUSED 0x40
#define PRJOB_NOTIFY 0x80
#define PRJOB_DESTNOPAPER 0x100
#define PRJOB_DELETED 0x8000

#define PRJOB_QS_QUEUED 0
#define PRJOB_QS_PAUSED 1
#define PRJOB_QS_SPOOLING 2
#define PRJOB_QS_PRINTING 3

#ifdef __cplusplus
}
#endif
#endif
