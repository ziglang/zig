/**
 * This file is part of the mingw-w64 runtime package.
 * No warranty is given; refer to the file DISCLAIMER within this package.
 */
#ifndef _WINBASE_
#define _WINBASE_

#include <_mingw_unicode.h>

#include <apisetcconv.h>
#include <winapifamily.h>

#include <minwinbase.h>
#include <bemapiset.h>
#include <debugapi.h>
#include <errhandlingapi.h>
#include <fibersapi.h>
#include <fileapi.h>
#include <handleapi.h>
#include <heapapi.h>
#include <ioapiset.h>
#include <interlockedapi.h>
#include <jobapi.h>
#include <libloaderapi.h>
#include <memoryapi.h>
#include <namedpipeapi.h>
#include <namespaceapi.h>
#include <processenv.h>
#include <processthreadsapi.h>
#include <processtopologyapi.h>
#include <profileapi.h>
#include <realtimeapiset.h>
#include <securityappcontainer.h>
#include <securitybaseapi.h>
#include <synchapi.h>
#include <sysinfoapi.h>
#include <systemtopologyapi.h>
#include <threadpoolapiset.h>
#include <threadpoollegacyapiset.h>
#include <utilapiset.h>
#include <wow64apiset.h>

#ifdef __WIDL__
#define NOWINBASEINTERLOCK 1
#endif

#ifndef NOWINBASEINTERLOCK
#define __INTRINSIC_GROUP_WINBASE /* only define the intrinsics in this file */
#include <psdk_inc/intrin-impl.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#define GetCurrentTime() GetTickCount ()
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define DefineHandleTable(w) ( { (VOID)(w); TRUE; } )
#define LimitEmsPages(dw)
#define SetSwapAreaSize(w) (w)
#define LockSegment(w) GlobalFix((HANDLE)(w))
#define UnlockSegment(w) GlobalUnfix((HANDLE)(w))

#define Yield()

#define FILE_BEGIN 0
#define FILE_CURRENT 1
#define FILE_END 2

#define WAIT_FAILED ((DWORD)0xffffffff)
#define WAIT_OBJECT_0 ((STATUS_WAIT_0) + 0)

#define WAIT_ABANDONED ((STATUS_ABANDONED_WAIT_0) + 0)
#define WAIT_ABANDONED_0 ((STATUS_ABANDONED_WAIT_0) + 0)

#define WAIT_IO_COMPLETION STATUS_USER_APC

#define SecureZeroMemory RtlSecureZeroMemory
#define CaptureStackBackTrace RtlCaptureStackBackTrace

#define FILE_FLAG_WRITE_THROUGH 0x80000000
#define FILE_FLAG_OVERLAPPED 0x40000000
#define FILE_FLAG_NO_BUFFERING 0x20000000
#define FILE_FLAG_RANDOM_ACCESS 0x10000000
#define FILE_FLAG_SEQUENTIAL_SCAN 0x8000000
#define FILE_FLAG_DELETE_ON_CLOSE 0x4000000
#define FILE_FLAG_BACKUP_SEMANTICS 0x2000000
#define FILE_FLAG_POSIX_SEMANTICS 0x1000000
#define FILE_FLAG_SESSION_AWARE 0x800000
#define FILE_FLAG_OPEN_REPARSE_POINT 0x200000
#define FILE_FLAG_OPEN_NO_RECALL 0x100000
#define FILE_FLAG_FIRST_PIPE_INSTANCE 0x80000
#if _WIN32_WINNT >= 0x0602
#define FILE_FLAG_OPEN_REQUIRING_OPLOCK 0x40000
#endif

#define PROGRESS_CONTINUE 0
#define PROGRESS_CANCEL 1
#define PROGRESS_STOP 2
#define PROGRESS_QUIET 3

#define CALLBACK_CHUNK_FINISHED 0x0
#define CALLBACK_STREAM_SWITCH 0x1

#define COPY_FILE_FAIL_IF_EXISTS 0x1
#define COPY_FILE_RESTARTABLE 0x2
#define COPY_FILE_OPEN_SOURCE_FOR_WRITE 0x4
#define COPY_FILE_ALLOW_DECRYPTED_DESTINATION 0x8
#if _WIN32_WINNT >= 0x0600
#define COPY_FILE_COPY_SYMLINK 0x800
#define COPY_FILE_NO_BUFFERING 0x1000
#endif
#if _WIN32_WINNT >= 0x0602
#define COPY_FILE_REQUEST_SECURITY_PRIVILEGES 0x2000
#define COPY_FILE_RESUME_FROM_PAUSE 0x4000
#define COPY_FILE_NO_OFFLOAD 0x40000
#endif

#define REPLACEFILE_WRITE_THROUGH 0x1
#define REPLACEFILE_IGNORE_MERGE_ERRORS 0x2
#if _WIN32_WINNT >= 0x0600
#define REPLACEFILE_IGNORE_ACL_ERRORS 0x4
#endif

#define PIPE_ACCESS_INBOUND 0x1
#define PIPE_ACCESS_OUTBOUND 0x2
#define PIPE_ACCESS_DUPLEX 0x3

#define PIPE_CLIENT_END 0x0
#define PIPE_SERVER_END 0x1

#define PIPE_WAIT 0x0
#define PIPE_NOWAIT 0x1
#define PIPE_READMODE_BYTE 0x0
#define PIPE_READMODE_MESSAGE 0x2
#define PIPE_TYPE_BYTE 0x0
#define PIPE_TYPE_MESSAGE 0x4
#define PIPE_ACCEPT_REMOTE_CLIENTS 0x0
#define PIPE_REJECT_REMOTE_CLIENTS 0x8

#define PIPE_UNLIMITED_INSTANCES 255

#define SECURITY_ANONYMOUS (SecurityAnonymous << 16)
#define SECURITY_IDENTIFICATION (SecurityIdentification << 16)
#define SECURITY_IMPERSONATION (SecurityImpersonation << 16)
#define SECURITY_DELEGATION (SecurityDelegation << 16)

#define SECURITY_CONTEXT_TRACKING 0x40000
#define SECURITY_EFFECTIVE_ONLY 0x80000

#define SECURITY_SQOS_PRESENT 0x100000
#define SECURITY_VALID_SQOS_FLAGS 0x1f0000

#define FAIL_FAST_GENERATE_EXCEPTION_ADDRESS 0x1
#define FAIL_FAST_NO_HARD_ERROR_DLG 0x2

  typedef VOID (WINAPI *PFIBER_START_ROUTINE) (LPVOID lpFiberParameter);
  typedef PFIBER_START_ROUTINE LPFIBER_START_ROUTINE;

#if defined (__i386__)
  typedef PLDT_ENTRY LPLDT_ENTRY;
#else
  typedef LPVOID LPLDT_ENTRY;
#endif

#define SP_SERIALCOMM ((DWORD)0x1)
#define PST_UNSPECIFIED ((DWORD)0x0)
#define PST_RS232 ((DWORD)0x1)
#define PST_PARALLELPORT ((DWORD)0x2)
#define PST_RS422 ((DWORD)0x3)
#define PST_RS423 ((DWORD)0x4)
#define PST_RS449 ((DWORD)0x5)
#define PST_MODEM ((DWORD)0x6)
#define PST_FAX ((DWORD)0x21)
#define PST_SCANNER ((DWORD)0x22)
#define PST_NETWORK_BRIDGE ((DWORD)0x100)
#define PST_LAT ((DWORD)0x101)
#define PST_TCPIP_TELNET ((DWORD)0x102)
#define PST_X25 ((DWORD)0x103)

#define PCF_DTRDSR ((DWORD)0x1)
#define PCF_RTSCTS ((DWORD)0x2)
#define PCF_RLSD ((DWORD)0x4)
#define PCF_PARITY_CHECK ((DWORD)0x8)
#define PCF_XONXOFF ((DWORD)0x10)
#define PCF_SETXCHAR ((DWORD)0x20)
#define PCF_TOTALTIMEOUTS ((DWORD)0x40)
#define PCF_INTTIMEOUTS ((DWORD)0x80)
#define PCF_SPECIALCHARS ((DWORD)0x100)
#define PCF_16BITMODE ((DWORD)0x200)

#define SP_PARITY ((DWORD)0x1)
#define SP_BAUD ((DWORD)0x2)
#define SP_DATABITS ((DWORD)0x4)
#define SP_STOPBITS ((DWORD)0x8)
#define SP_HANDSHAKING ((DWORD)0x10)
#define SP_PARITY_CHECK ((DWORD)0x20)
#define SP_RLSD ((DWORD)0x40)

#define BAUD_075 ((DWORD)0x1)
#define BAUD_110 ((DWORD)0x2)
#define BAUD_134_5 ((DWORD)0x4)
#define BAUD_150 ((DWORD)0x8)
#define BAUD_300 ((DWORD)0x10)
#define BAUD_600 ((DWORD)0x20)
#define BAUD_1200 ((DWORD)0x40)
#define BAUD_1800 ((DWORD)0x80)
#define BAUD_2400 ((DWORD)0x100)
#define BAUD_4800 ((DWORD)0x200)
#define BAUD_7200 ((DWORD)0x400)
#define BAUD_9600 ((DWORD)0x800)
#define BAUD_14400 ((DWORD)0x1000)
#define BAUD_19200 ((DWORD)0x2000)
#define BAUD_38400 ((DWORD)0x4000)
#define BAUD_56K ((DWORD)0x8000)
#define BAUD_128K ((DWORD)0x10000)
#define BAUD_115200 ((DWORD)0x20000)
#define BAUD_57600 ((DWORD)0x40000)
#define BAUD_USER ((DWORD)0x10000000)

#define DATABITS_5 ((WORD)0x1)
#define DATABITS_6 ((WORD)0x2)
#define DATABITS_7 ((WORD)0x4)
#define DATABITS_8 ((WORD)0x8)
#define DATABITS_16 ((WORD)0x10)
#define DATABITS_16X ((WORD)0x20)

#define STOPBITS_10 ((WORD)0x1)
#define STOPBITS_15 ((WORD)0x2)
#define STOPBITS_20 ((WORD)0x4)
#define PARITY_NONE ((WORD)0x100)
#define PARITY_ODD ((WORD)0x200)
#define PARITY_EVEN ((WORD)0x400)
#define PARITY_MARK ((WORD)0x800)
#define PARITY_SPACE ((WORD)0x1000)

  typedef struct _COMMPROP {
    WORD wPacketLength;
    WORD wPacketVersion;
    DWORD dwServiceMask;
    DWORD dwReserved1;
    DWORD dwMaxTxQueue;
    DWORD dwMaxRxQueue;
    DWORD dwMaxBaud;
    DWORD dwProvSubType;
    DWORD dwProvCapabilities;
    DWORD dwSettableParams;
    DWORD dwSettableBaud;
    WORD wSettableData;
    WORD wSettableStopParity;
    DWORD dwCurrentTxQueue;
    DWORD dwCurrentRxQueue;
    DWORD dwProvSpec1;
    DWORD dwProvSpec2;
    WCHAR wcProvChar[1];
  } COMMPROP,*LPCOMMPROP;

#define COMMPROP_INITIALIZED ((DWORD)0xe73cf52e)

  typedef struct _COMSTAT {
    DWORD fCtsHold : 1;
    DWORD fDsrHold : 1;
    DWORD fRlsdHold : 1;
    DWORD fXoffHold : 1;
    DWORD fXoffSent : 1;
    DWORD fEof : 1;
    DWORD fTxim : 1;
    DWORD fReserved : 25;
    DWORD cbInQue;
    DWORD cbOutQue;
  } COMSTAT,*LPCOMSTAT;

#define DTR_CONTROL_DISABLE 0x0
#define DTR_CONTROL_ENABLE 0x1
#define DTR_CONTROL_HANDSHAKE 0x2

#define RTS_CONTROL_DISABLE 0x0
#define RTS_CONTROL_ENABLE 0x1
#define RTS_CONTROL_HANDSHAKE 0x2
#define RTS_CONTROL_TOGGLE 0x3

  typedef struct _DCB {
    DWORD DCBlength;
    DWORD BaudRate;
    DWORD fBinary: 1;
    DWORD fParity: 1;
    DWORD fOutxCtsFlow:1;
    DWORD fOutxDsrFlow:1;
    DWORD fDtrControl:2;
    DWORD fDsrSensitivity:1;
    DWORD fTXContinueOnXoff: 1;
    DWORD fOutX: 1;
    DWORD fInX: 1;
    DWORD fErrorChar: 1;
    DWORD fNull: 1;
    DWORD fRtsControl:2;
    DWORD fAbortOnError:1;
    DWORD fDummy2:17;
    WORD wReserved;
    WORD XonLim;
    WORD XoffLim;
    BYTE ByteSize;
    BYTE Parity;
    BYTE StopBits;
    char XonChar;
    char XoffChar;
    char ErrorChar;
    char EofChar;
    char EvtChar;
    WORD wReserved1;
  } DCB,*LPDCB;

  typedef struct _COMMTIMEOUTS {
    DWORD ReadIntervalTimeout;
    DWORD ReadTotalTimeoutMultiplier;
    DWORD ReadTotalTimeoutConstant;
    DWORD WriteTotalTimeoutMultiplier;
    DWORD WriteTotalTimeoutConstant;
  } COMMTIMEOUTS,*LPCOMMTIMEOUTS;

  typedef struct _COMMCONFIG {
    DWORD dwSize;
    WORD wVersion;
    WORD wReserved;
    DCB dcb;
    DWORD dwProviderSubType;
    DWORD dwProviderOffset;
    DWORD dwProviderSize;
    WCHAR wcProviderData[1];
  } COMMCONFIG,*LPCOMMCONFIG;

#define FreeModule(hLibModule) FreeLibrary((hLibModule))
#define MakeProcInstance(lpProc,hInstance) (lpProc)
#define FreeProcInstance(lpProc) (lpProc)

#define GMEM_FIXED 0x0
#define GMEM_MOVEABLE 0x2
#define GMEM_NOCOMPACT 0x10
#define GMEM_NODISCARD 0x20
#define GMEM_ZEROINIT 0x40
#define GMEM_MODIFY 0x80
#define GMEM_DISCARDABLE 0x100
#define GMEM_NOT_BANKED 0x1000
#define GMEM_SHARE 0x2000
#define GMEM_DDESHARE 0x2000
#define GMEM_NOTIFY 0x4000
#define GMEM_LOWER GMEM_NOT_BANKED
#define GMEM_VALID_FLAGS 0x7f72
#define GMEM_INVALID_HANDLE 0x8000

#define GHND (GMEM_MOVEABLE | GMEM_ZEROINIT)
#define GPTR (GMEM_FIXED | GMEM_ZEROINIT)

#define GlobalLRUNewest(h) ((HANDLE)(h))
#define GlobalLRUOldest(h) ((HANDLE)(h))
#define GlobalDiscard(h) GlobalReAlloc ((h), 0, GMEM_MOVEABLE)

#define GMEM_DISCARDED 0x4000
#define GMEM_LOCKCOUNT 0x00ff

  typedef struct _MEMORYSTATUS {
    DWORD dwLength;
    DWORD dwMemoryLoad;
    SIZE_T dwTotalPhys;
    SIZE_T dwAvailPhys;
    SIZE_T dwTotalPageFile;
    SIZE_T dwAvailPageFile;
    SIZE_T dwTotalVirtual;
    SIZE_T dwAvailVirtual;
  } MEMORYSTATUS,*LPMEMORYSTATUS;

#define NUMA_NO_PREFERRED_NODE ((DWORD) -1)

#define DEBUG_PROCESS 0x1
#define DEBUG_ONLY_THIS_PROCESS 0x2
#define CREATE_SUSPENDED 0x4
#define DETACHED_PROCESS 0x8
#define CREATE_NEW_CONSOLE 0x10
#define NORMAL_PRIORITY_CLASS 0x20
#define IDLE_PRIORITY_CLASS 0x40
#define HIGH_PRIORITY_CLASS 0x80
#define REALTIME_PRIORITY_CLASS 0x100
#define CREATE_NEW_PROCESS_GROUP 0x200
#define CREATE_UNICODE_ENVIRONMENT 0x400
#define CREATE_SEPARATE_WOW_VDM 0x800
#define CREATE_SHARED_WOW_VDM 0x1000
#define CREATE_FORCEDOS 0x2000
#define BELOW_NORMAL_PRIORITY_CLASS 0x4000
#define ABOVE_NORMAL_PRIORITY_CLASS 0x8000
#define INHERIT_PARENT_AFFINITY 0x10000
#define INHERIT_CALLER_PRIORITY 0x20000
#define CREATE_PROTECTED_PROCESS 0x40000
#define EXTENDED_STARTUPINFO_PRESENT 0x80000
#define PROCESS_MODE_BACKGROUND_BEGIN 0x100000
#define PROCESS_MODE_BACKGROUND_END 0x200000
#define CREATE_BREAKAWAY_FROM_JOB 0x1000000
#define CREATE_PRESERVE_CODE_AUTHZ_LEVEL 0x2000000
#define CREATE_DEFAULT_ERROR_MODE 0x4000000
#define CREATE_NO_WINDOW 0x8000000
#define PROFILE_USER 0x10000000
#define PROFILE_KERNEL 0x20000000
#define PROFILE_SERVER 0x40000000
#define CREATE_IGNORE_SYSTEM_DEFAULT 0x80000000

#define STACK_SIZE_PARAM_IS_A_RESERVATION 0x10000

#define THREAD_PRIORITY_LOWEST THREAD_BASE_PRIORITY_MIN
#define THREAD_PRIORITY_BELOW_NORMAL (THREAD_PRIORITY_LOWEST+1)
#define THREAD_PRIORITY_NORMAL 0
#define THREAD_PRIORITY_HIGHEST THREAD_BASE_PRIORITY_MAX
#define THREAD_PRIORITY_ABOVE_NORMAL (THREAD_PRIORITY_HIGHEST-1)
#define THREAD_PRIORITY_ERROR_RETURN (MAXLONG)

#define THREAD_PRIORITY_TIME_CRITICAL THREAD_BASE_PRIORITY_LOWRT
#define THREAD_PRIORITY_IDLE THREAD_BASE_PRIORITY_IDLE

#define THREAD_MODE_BACKGROUND_BEGIN 0x00010000
#define THREAD_MODE_BACKGROUND_END 0x00020000

#define VOLUME_NAME_DOS 0x0
#define VOLUME_NAME_GUID 0x1
#define VOLUME_NAME_NT 0x2
#define VOLUME_NAME_NONE 0x4

#define FILE_NAME_NORMALIZED 0x0
#define FILE_NAME_OPENED 0x8

  typedef struct _JIT_DEBUG_INFO {
    DWORD dwSize;
    DWORD dwProcessorArchitecture;
    DWORD dwThreadID;
    DWORD dwReserved0;
    ULONG64 lpExceptionAddress;
    ULONG64 lpExceptionRecord;
    ULONG64 lpContextRecord;
  } JIT_DEBUG_INFO,*LPJIT_DEBUG_INFO;

  typedef JIT_DEBUG_INFO JIT_DEBUG_INFO32, *LPJIT_DEBUG_INFO32;
  typedef JIT_DEBUG_INFO JIT_DEBUG_INFO64, *LPJIT_DEBUG_INFO64;

#ifndef __WIDL__
  typedef PEXCEPTION_RECORD LPEXCEPTION_RECORD;
  typedef PEXCEPTION_POINTERS LPEXCEPTION_POINTERS;
#endif

#define DRIVE_UNKNOWN 0
#define DRIVE_NO_ROOT_DIR 1
#define DRIVE_REMOVABLE 2
#define DRIVE_FIXED 3
#define DRIVE_REMOTE 4
#define DRIVE_CDROM 5
#define DRIVE_RAMDISK 6

#define GetFreeSpace(w) (__MSABI_LONG(0x100000))

#define FILE_TYPE_UNKNOWN 0x0
#define FILE_TYPE_DISK 0x1
#define FILE_TYPE_CHAR 0x2
#define FILE_TYPE_PIPE 0x3
#define FILE_TYPE_REMOTE 0x8000

#define STD_INPUT_HANDLE ((DWORD)-10)
#define STD_OUTPUT_HANDLE ((DWORD)-11)
#define STD_ERROR_HANDLE ((DWORD)-12)

#define NOPARITY 0
#define ODDPARITY 1
#define EVENPARITY 2
#define MARKPARITY 3
#define SPACEPARITY 4

#define ONESTOPBIT 0
#define ONE5STOPBITS 1
#define TWOSTOPBITS 2

#define IGNORE 0
#define INFINITE 0xffffffff

#define CBR_110 110
#define CBR_300 300
#define CBR_600 600
#define CBR_1200 1200
#define CBR_2400 2400
#define CBR_4800 4800
#define CBR_9600 9600
#define CBR_14400 14400
#define CBR_19200 19200
#define CBR_38400 38400
#define CBR_56000 56000
#define CBR_57600 57600
#define CBR_115200 115200
#define CBR_128000 128000
#define CBR_256000 256000

#define CE_RXOVER 0x1
#define CE_OVERRUN 0x2
#define CE_RXPARITY 0x4
#define CE_FRAME 0x8
#define CE_BREAK 0x10
#define CE_TXFULL 0x100
#define CE_PTO 0x200
#define CE_IOE 0x400
#define CE_DNS 0x800
#define CE_OOP 0x1000
#define CE_MODE 0x8000

#define IE_BADID (-1)
#define IE_OPEN (-2)
#define IE_NOPEN (-3)
#define IE_MEMORY (-4)
#define IE_DEFAULT (-5)
#define IE_HARDWARE (-10)
#define IE_BYTESIZE (-11)
#define IE_BAUDRATE (-12)

#define EV_RXCHAR 0x1
#define EV_RXFLAG 0x2
#define EV_TXEMPTY 0x4
#define EV_CTS 0x8
#define EV_DSR 0x10
#define EV_RLSD 0x20
#define EV_BREAK 0x40
#define EV_ERR 0x80
#define EV_RING 0x100
#define EV_PERR 0x200
#define EV_RX80FULL 0x400
#define EV_EVENT1 0x800
#define EV_EVENT2 0x1000

#define SETXOFF 1
#define SETXON 2
#define SETRTS 3
#define CLRRTS 4
#define SETDTR 5
#define CLRDTR 6
#define RESETDEV 7
#define SETBREAK 8
#define CLRBREAK 9

#define PURGE_TXABORT 0x1
#define PURGE_RXABORT 0x2
#define PURGE_TXCLEAR 0x4
#define PURGE_RXCLEAR 0x8

#define LPTx 0x80

#define MS_CTS_ON ((DWORD)0x10)
#define MS_DSR_ON ((DWORD)0x20)
#define MS_RING_ON ((DWORD)0x40)
#define MS_RLSD_ON ((DWORD)0x80)

#define S_QUEUEEMPTY 0
#define S_THRESHOLD 1
#define S_ALLTHRESHOLD 2

#define S_NORMAL 0
#define S_LEGATO 1
#define S_STACCATO 2

#define S_PERIOD512 0
#define S_PERIOD1024 1
#define S_PERIOD2048 2
#define S_PERIODVOICE 3
#define S_WHITE512 4
#define S_WHITE1024 5
#define S_WHITE2048 6
#define S_WHITEVOICE 7

#define S_SERDVNA (-1)
#define S_SEROFM (-2)
#define S_SERMACT (-3)
#define S_SERQFUL (-4)
#define S_SERBDNT (-5)
#define S_SERDLN (-6)
#define S_SERDCC (-7)
#define S_SERDTP (-8)
#define S_SERDVL (-9)
#define S_SERDMD (-10)
#define S_SERDSH (-11)
#define S_SERDPT (-12)
#define S_SERDFQ (-13)
#define S_SERDDR (-14)
#define S_SERDSR (-15)
#define S_SERDST (-16)

#define NMPWAIT_WAIT_FOREVER 0xffffffff
#define NMPWAIT_NOWAIT 0x1
#define NMPWAIT_USE_DEFAULT_WAIT 0x0

#define FS_CASE_IS_PRESERVED FILE_CASE_PRESERVED_NAMES
#define FS_CASE_SENSITIVE FILE_CASE_SENSITIVE_SEARCH
#define FS_UNICODE_STORED_ON_DISK FILE_UNICODE_ON_DISK
#define FS_PERSISTENT_ACLS FILE_PERSISTENT_ACLS
#define FS_VOL_IS_COMPRESSED FILE_VOLUME_IS_COMPRESSED
#define FS_FILE_COMPRESSION FILE_FILE_COMPRESSION
#define FS_FILE_ENCRYPTION FILE_SUPPORTS_ENCRYPTION

#define OF_READ 0x0
#define OF_WRITE 0x1
#define OF_READWRITE 0x2
#define OF_SHARE_COMPAT 0x0
#define OF_SHARE_EXCLUSIVE 0x10
#define OF_SHARE_DENY_WRITE 0x20
#define OF_SHARE_DENY_READ 0x30
#define OF_SHARE_DENY_NONE 0x40
#define OF_PARSE 0x100
#define OF_DELETE 0x200
#define OF_VERIFY 0x400
#define OF_CANCEL 0x800
#define OF_CREATE 0x1000
#define OF_PROMPT 0x2000
#define OF_EXIST 0x4000
#define OF_REOPEN 0x8000

#define OFS_MAXPATHNAME 128

  typedef struct _OFSTRUCT {
    BYTE cBytes;
    BYTE fFixedDisk;
    WORD nErrCode;
    WORD Reserved1;
    WORD Reserved2;
    CHAR szPathName[OFS_MAXPATHNAME];
  } OFSTRUCT, *LPOFSTRUCT,*POFSTRUCT;

#ifndef NOWINBASEINTERLOCK
#ifndef _NTOS_
#if defined (__ia64__) && !defined (RC_INVOKED)

#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire _InterlockedIncrement_acq
#define InterlockedIncrementRelease _InterlockedIncrement_rel
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire _InterlockedDecrement_acq
#define InterlockedDecrementRelease _InterlockedDecrement_rel
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire _InterlockedCompareExchange_acq
#define InterlockedCompareExchangeRelease _InterlockedCompareExchange_rel
#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease _InterlockedCompareExchangePointer_rel
#define InterlockedCompareExchangePointerAcquire _InterlockedCompareExchangePointer_acq

#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAcquire64 _InterlockedExchange64_acq
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 _InterlockedCompareExchange64_acq
#define InterlockedCompareExchangeRelease64 _InterlockedCompareExchange64_rel
#define InterlockedCompare64Exchange128 _InterlockedCompare64Exchange128
#define InterlockedCompare64ExchangeAcquire128 _InterlockedCompare64Exchange128_acq
#define InterlockedCompare64ExchangeRelease128 _InterlockedCompare64Exchange128_rel

#define InterlockedOr _InterlockedOr
#define InterlockedOrAcquire _InterlockedOr_acq
#define InterlockedOrRelease _InterlockedOr_rel
#define InterlockedOr8 _InterlockedOr8
#define InterlockedOr8Acquire _InterlockedOr8_acq
#define InterlockedOr8Release _InterlockedOr8_rel
#define InterlockedOr16 _InterlockedOr16
#define InterlockedOr16Acquire _InterlockedOr16_acq
#define InterlockedOr16Release _InterlockedOr16_rel
#define InterlockedOr64 _InterlockedOr64
#define InterlockedOr64Acquire _InterlockedOr64_acq
#define InterlockedOr64Release _InterlockedOr64_rel
#define InterlockedXor _InterlockedXor
#define InterlockedXorAcquire _InterlockedXor_acq
#define InterlockedXorRelease _InterlockedXor_rel
#define InterlockedXor8 _InterlockedXor8
#define InterlockedXor8Acquire _InterlockedXor8_acq
#define InterlockedXor8Release _InterlockedXor8_rel
#define InterlockedXor16 _InterlockedXor16
#define InterlockedXor16Acquire _InterlockedXor16_acq
#define InterlockedXor16Release _InterlockedXor16_rel
#define InterlockedXor64 _InterlockedXor64
#define InterlockedXor64Acquire _InterlockedXor64_acq
#define InterlockedXor64Release _InterlockedXor64_rel
#define InterlockedAnd _InterlockedAnd
#define InterlockedAndAcquire _InterlockedAnd_acq
#define InterlockedAndRelease _InterlockedAnd_rel
#define InterlockedAnd8 _InterlockedAnd8
#define InterlockedAnd8Acquire _InterlockedAnd8_acq
#define InterlockedAnd8Release _InterlockedAnd8_rel
#define InterlockedAnd16 _InterlockedAnd16
#define InterlockedAnd16Acquire _InterlockedAnd16_acq
#define InterlockedAnd16Release _InterlockedAnd16_rel
#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedAnd64Acquire _InterlockedAnd64_acq
#define InterlockedAnd64Release _InterlockedAnd64_rel

  LONG __cdecl InterlockedOr (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedOrAcquire (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedOrRelease (LONG volatile *Destination, LONG Value);
  char __cdecl InterlockedOr8 (char volatile *Destination, char Value);
  char __cdecl InterlockedOr8Acquire (char volatile *Destination, char Value);
  char __cdecl InterlockedOr8Release (char volatile *Destination, char Value);
  SHORT __cdecl InterlockedOr16 (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedOr16Acquire (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedOr16Release (SHORT volatile *Destination, SHORT Value);
  LONGLONG __cdecl InterlockedOr64 (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedOr64Acquire (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedOr64Release (LONGLONG volatile *Destination, LONGLONG Value);
  LONG __cdecl InterlockedXor (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedXorAcquire (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedXorRelease (LONG volatile *Destination, LONG Value);
  char __cdecl InterlockedXor8 (char volatile *Destination, char Value);
  char __cdecl InterlockedXor8Acquire (char volatile *Destination, char Value);
  char __cdecl InterlockedXor8Release (char volatile *Destination, char Value);
  SHORT __cdecl InterlockedXor16 (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedXor16Acquire (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedXor16Release (SHORT volatile *Destination, SHORT Value);
  LONGLONG __cdecl InterlockedXor64 (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedXor64Acquire (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedXor64Release (LONGLONG volatile *Destination, LONGLONG Value);
  LONG __cdecl InterlockedAnd (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedAndAcquire (LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedAndRelease (LONG volatile *Destination, LONG Value);
  char __cdecl InterlockedAnd8 (char volatile *Destination, char Value);
  char __cdecl InterlockedAnd8Acquire (char volatile *Destination, char Value);
  char __cdecl InterlockedAnd8Release (char volatile *Destination, char Value);
  SHORT __cdecl InterlockedAnd16 (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedAnd16Acquire (SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedAnd16Release (SHORT volatile *Destination, SHORT Value);
  LONGLONG __cdecl InterlockedAnd64 (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedAnd64Acquire (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedAnd64Release (LONGLONG volatile *Destination, LONGLONG Value);
  LONGLONG __cdecl InterlockedIncrement64 (LONGLONG volatile *Addend);
  LONGLONG __cdecl InterlockedDecrement64 (LONGLONG volatile *Addend);
  LONG __cdecl InterlockedIncrementAcquire (LONG volatile *Addend);
  LONG __cdecl InterlockedDecrementAcquire (LONG volatile *Addend);
  LONG __cdecl InterlockedIncrementRelease (LONG volatile *Addend);
  LONG __cdecl InterlockedDecrementRelease (LONG volatile *Addend);
  LONGLONG __cdecl InterlockedExchange64 (LONGLONG volatile *Target, LONGLONG Value);
  LONGLONG __cdecl InterlockedExchangeAcquire64 (LONGLONG volatile *Target, LONGLONG Value);
  LONGLONG __cdecl InterlockedExchangeAdd64 (LONGLONG volatile *Addend, LONGLONG Value);
  LONGLONG __cdecl InterlockedCompareExchange64 (LONGLONG volatile *Destination, LONGLONG ExChange, LONGLONG Comperand);
  LONGLONG __cdecl InterlockedCompareExchangeAcquire64 (LONGLONG volatile *Destination, LONGLONG ExChange, LONGLONG Comperand);
  LONGLONG __cdecl InterlockedCompareExchangeRelease64 (LONGLONG volatile *Destination, LONGLONG ExChange, LONGLONG Comperand);
  LONG64 __cdecl InterlockedCompare64Exchange128 (LONG64 volatile *Destination, LONG64 ExchangeHigh, LONG64 ExchangeLow, LONG64 Comperand);
  LONG64 __cdecl InterlockedCompare64ExchangeAcquire128 (LONG64 volatile *Destination, LONG64 ExchangeHigh, LONG64 ExchangeLow, LONG64 Comperand);
  LONG64 __cdecl InterlockedCompare64ExchangeRelease128 (LONG64 volatile *Destination, LONG64 ExchangeHigh, LONG64 ExchangeLow, LONG64 Comperand);
  LONG __cdecl InterlockedIncrement (LONG volatile *lpAddend);
  LONG __cdecl InterlockedDecrement (LONG volatile *lpAddend);
  LONG __cdecl InterlockedExchange (LONG volatile *Target, LONG Value);
  LONG __cdecl InterlockedExchangeAdd (LONG volatile *Addend, LONG Value);
  LONG __cdecl InterlockedCompareExchange (LONG volatile *Destination, LONG ExChange, LONG Comperand);
  LONG __cdecl InterlockedCompareExchangeRelease (LONG volatile *Destination, LONG ExChange, LONG Comperand);
  LONG __cdecl InterlockedCompareExchangeAcquire (LONG volatile *Destination, LONG ExChange, LONG Comperand);
  PVOID __cdecl InterlockedExchangePointer (PVOID volatile *Target, PVOID Value);
  PVOID __cdecl InterlockedCompareExchangePointer (PVOID volatile *Destination, PVOID ExChange, PVOID Comperand);
  PVOID __cdecl InterlockedCompareExchangePointerAcquire (PVOID volatile *Destination, PVOID Exchange, PVOID Comperand);
  PVOID __cdecl InterlockedCompareExchangePointerRelease (PVOID volatile *Destination, PVOID Exchange, PVOID Comperand);

#if !defined(__WIDL__) && !defined(__CRT__NO_INLINE)
#ifndef InterlockedAnd
#define InterlockedAnd InterlockedAnd_Inline

  FORCEINLINE LONG InterlockedAnd_Inline(LONG volatile *Target, LONG Set) {
    LONG i, j = *Target;

    do {
      i = j;
      j = InterlockedCompareExchange (Target, i &Set, i);
    } while (i != j);
    return j;
  }
#endif

#ifndef InterlockedOr
#define InterlockedOr InterlockedOr_Inline

  FORCEINLINE LONG InterlockedOr_Inline(LONG volatile *Target, LONG Set) {
    LONG i, j = *Target;

    do {
      i = j;
      j = InterlockedCompareExchange (Target, i | Set, i);
    } while (i != j);
    return j;
  }
#endif

#ifndef InterlockedXor
#define InterlockedXor InterlockedXor_Inline

  FORCEINLINE LONG InterlockedXor_Inline(LONG volatile *Target, LONG Set) {
    LONG i, j = *Target;

    do {
      i = j;
      j = InterlockedCompareExchange (Target, i ^ Set, i);
    } while (i != j);
    return j;
  }
#endif

#ifndef InterlockedAnd64
#define InterlockedAnd64 InterlockedAnd64_Inline

  FORCEINLINE LONGLONG InterlockedAnd64_Inline(LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old &Value, Old) != Old);
    return Old;
  }
#endif

#ifndef InterlockedOr64
#define InterlockedOr64 InterlockedOr64_Inline

  FORCEINLINE LONGLONG InterlockedOr64_Inline(LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old | Value, Old) != Old);
    return Old;
  }
#endif

#ifndef InterlockedXor64
#define InterlockedXor64 InterlockedXor64_Inline

  FORCEINLINE LONGLONG InterlockedXor64_Inline(LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old ^ Value, Old) != Old);
    return Old;
  }
#endif

#ifndef InterlockedBitTestAndSet
#define InterlockedBitTestAndSet InterlockedBitTestAndSet_Inline

  FORCEINLINE BOOLEAN InterlockedBitTestAndSet_Inline(LONG volatile *Base, LONG Bit) {
    LONG tBit = 1 << (Bit & (sizeof (*Base) * 8 - 1));

    return (BOOLEAN) ((InterlockedOr (&Base[Bit / (sizeof (*Base) * 8)], tBit) & tBit) != 0);
  }
#endif

#ifndef InterlockedBitTestAndReset
#define InterlockedBitTestAndReset InterlockedBitTestAndReset_Inline

  FORCEINLINE BOOLEAN InterlockedBitTestAndReset_Inline(LONG volatile *Base, LONG Bit) {
    LONG tBit = 1 << (Bit & (sizeof (*Base) * 8 - 1));

    return (BOOLEAN) ((InterlockedAnd (&Base[Bit / (sizeof (*Base) * 8)], ~tBit) & tBit) != 0);
  }
#endif

#ifndef InterlockedBitTestAndComplement
#define InterlockedBitTestAndComplement InterlockedBitTestAndComplement_Inline

  FORCEINLINE BOOLEAN InterlockedBitTestAndComplement_Inline(LONG volatile *Base, LONG Bit) {
    LONG tBit = 1 << (Bit & (sizeof (*Base) * 8 - 1));

    return (BOOLEAN) ((InterlockedXor (&Base[Bit / (sizeof (*Base) * 8)], tBit) & tBit) != 0);
  }
#endif
#endif

#elif defined (__x86_64__) && !defined (RC_INVOKED)
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange
#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerAcquire _InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease _InterlockedCompareExchangePointer
#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64

#define InterlockedAnd8 _InterlockedAnd8
#define InterlockedOr8 _InterlockedOr8
#define InterlockedXor8 _InterlockedXor8
#define InterlockedAnd16 _InterlockedAnd16
#define InterlockedOr16 _InterlockedOr16
#define InterlockedXor16 _InterlockedXor16

  LONG __cdecl InterlockedAnd(LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedOr(LONG volatile *Destination, LONG Value);
  LONG __cdecl InterlockedXor(LONG volatile *Destination, LONG Value);
  /* moved to psdk_inc/intrin-impl.h
  LONG __cdecl InterlockedIncrement(LONG volatile *Addend);
  LONG __cdecl InterlockedDecrement(LONG volatile *Addend);
  LONG __cdecl InterlockedExchange(LONG volatile *Target, LONG Value);
  LONG __cdecl InterlockedExchangeAdd(LONG volatile *Addend, LONG Value);
  LONG __cdecl InterlockedCompareExchange(LONG volatile *Destination, LONG ExChange, LONG Comperand);
  PVOID __cdecl InterlockedCompareExchangePointer(PVOID volatile *Destination, PVOID Exchange, PVOID Comperand);
  PVOID __cdecl InterlockedExchangePointer(PVOID volatile *Target, PVOID Value);
  LONG64 __cdecl InterlockedAnd64(LONG64 volatile *Destination, LONG64 Value);
  LONG64 __cdecl InterlockedOr64(LONG64 volatile *Destination, LONG64 Value);
  LONG64 __cdecl InterlockedXor64(LONG64 volatile *Destination, LONG64 Value);
  LONG64 __cdecl InterlockedIncrement64(LONG64 volatile *Addend);
  LONG64 __cdecl InterlockedDecrement64(LONG64 volatile *Addend);
  LONG64 __cdecl InterlockedExchange64(LONG64 volatile *Target, LONG64 Value);
  LONG64 __cdecl InterlockedExchangeAdd64(LONG64 volatile *Addend, LONG64 Value);
  LONG64 __cdecl InterlockedCompareExchange64(LONG64 volatile *Destination, LONG64 ExChange, LONG64 Comperand); */

  char __cdecl InterlockedAnd8(char volatile *Destination, char Value);
  char __cdecl InterlockedOr8(char volatile *Destination, char Value);
  char __cdecl InterlockedXor8(char volatile *Destination, char Value);
  SHORT __cdecl InterlockedAnd16(SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedOr16(SHORT volatile *Destination, SHORT Value);
  SHORT __cdecl InterlockedXor16(SHORT volatile *Destination, SHORT Value);

#elif defined (__aarch64__) && !defined (RC_INVOKED)
#define InterlockedAnd _InterlockedAnd
#define InterlockedOr _InterlockedOr
#define InterlockedXor _InterlockedXor
#define InterlockedIncrement _InterlockedIncrement
#define InterlockedDecrement _InterlockedDecrement
#define InterlockedExchange _InterlockedExchange
#define InterlockedExchangeAdd _InterlockedExchangeAdd
#define InterlockedExchangePointer _InterlockedExchangePointer
#define InterlockedCompareExchange _InterlockedCompareExchange
#define InterlockedCompareExchangePointer _InterlockedCompareExchangePointer
#define InterlockedAnd64 _InterlockedAnd64
#define InterlockedOr64 _InterlockedOr64
#define InterlockedXor64 _InterlockedXor64
#define InterlockedIncrement64 _InterlockedIncrement64
#define InterlockedDecrement64 _InterlockedDecrement64
#define InterlockedExchange64 _InterlockedExchange64
#define InterlockedExchangeAdd64 _InterlockedExchangeAdd64
#define InterlockedCompareExchange64 _InterlockedCompareExchange64

  LONG InterlockedIncrement (LONG volatile *Addend);
  LONG InterlockedDecrement (LONG volatile *Addend);
  LONG InterlockedExchange (LONG volatile *Target, LONG Value);
  LONG InterlockedExchangeAdd (LONG volatile *Addend, LONG Value);
  LONG InterlockedCompareExchange (LONG volatile *Destination, LONG ExChange, LONG Comperand);
  PVOID InterlockedCompareExchangePointer (PVOID volatile *Destination, PVOID Exchange, PVOID Comperand);
  PVOID InterlockedExchangePointer (PVOID volatile *Target, PVOID Value);
  LONG64 InterlockedAnd64 (LONG64 volatile *Destination, LONG64 Value);
  LONG64 InterlockedOr64 (LONG64 volatile *Destination, LONG64 Value);
  LONG64 InterlockedXor64 (LONG64 volatile *Destination, LONG64 Value);
  LONG64 InterlockedIncrement64 (LONG64 volatile *Addend);
  LONG64 InterlockedDecrement64 (LONG64 volatile *Addend);
  LONG64 InterlockedExchange64 (LONG64 volatile *Target, LONG64 Value);
  LONG64 InterlockedExchangeAdd64 (LONG64 volatile *Addend, LONG64 Value);
  LONG64 InterlockedCompareExchange64 (LONG64 volatile *Destination, LONG64 ExChange, LONG64 Comperand);
#else
#if !defined (__WIDL__) && defined (__MINGW_INTRIN_INLINE)

/* Clang has support for some MSVC builtins if building with -fms-extensions,
 * GCC doesn't. */
#pragma push_macro("__has_builtin")
#ifndef __has_builtin
  #define __has_builtin(x) 0
#endif

#if !__has_builtin(_InterlockedAnd64)
  FORCEINLINE LONGLONG InterlockedAnd64 (LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old &Value, Old) != Old);
    return Old;
  }
#endif

#if !__has_builtin(_InterlockedOr64)
  FORCEINLINE LONGLONG InterlockedOr64 (LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old | Value, Old) != Old);
    return Old;
  }
#endif

#if !__has_builtin(_InterlockedXor64)
  FORCEINLINE LONGLONG InterlockedXor64 (LONGLONG volatile *Destination, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Destination;
    } while (InterlockedCompareExchange64 (Destination, Old ^ Value, Old) != Old);
    return Old;
  }
#endif

#if !__has_builtin(_InterlockedIncrement64)
  FORCEINLINE LONGLONG InterlockedIncrement64 (LONGLONG volatile *Addend) {
    LONGLONG Old;

    do {
      Old = *Addend;
    } while (InterlockedCompareExchange64 (Addend, Old + 1, Old) != Old);
    return Old + 1;
  }
#endif

#if !__has_builtin(_InterlockedDecrement64)
  FORCEINLINE LONGLONG InterlockedDecrement64 (LONGLONG volatile *Addend) {
    LONGLONG Old;

    do {
      Old = *Addend;
    } while (InterlockedCompareExchange64 (Addend, Old - 1, Old) != Old);
    return Old - 1;
  }
#endif

#if !__has_builtin(_InterlockedExchange64)
  FORCEINLINE LONGLONG InterlockedExchange64 (LONGLONG volatile *Target, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Target;
    } while (InterlockedCompareExchange64 (Target, Value, Old) != Old);
    return Old;
  }
#endif

#if !__has_builtin(_InterlockedExchangeAdd64)
  FORCEINLINE LONGLONG InterlockedExchangeAdd64 (LONGLONG volatile *Addend, LONGLONG Value) {
    LONGLONG Old;

    do {
      Old = *Addend;
    } while (InterlockedCompareExchange64 (Addend, Old + Value, Old) != Old);
    return Old;
  }
#endif

#pragma pop_macro("__has_builtin")

#endif

#ifdef __cplusplus
  FORCEINLINE PVOID __cdecl __InlineInterlockedCompareExchangePointer (PVOID volatile *Destination, PVOID ExChange, PVOID Comperand) {
    return ((PVOID) (LONG_PTR)InterlockedCompareExchange ((LONG volatile *)Destination,(LONG) (LONG_PTR)ExChange,(LONG) (LONG_PTR)Comperand));
  }

#define InterlockedCompareExchangePointer __InlineInterlockedCompareExchangePointer
#else
#define InterlockedCompareExchangePointer(Destination, ExChange, Comperand) (PVOID) (LONG_PTR)InterlockedCompareExchange ((LONG volatile *) (Destination),(LONG) (LONG_PTR) (ExChange),(LONG) (LONG_PTR) (Comperand))
#endif

#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedDecrementAcquire InterlockedDecrement
#define InterlockedDecrementRelease InterlockedDecrement
#define InterlockedIncrementAcquire InterlockedIncrement
#define InterlockedIncrementRelease InterlockedIncrement
#define InterlockedCompareExchangeAcquire InterlockedCompareExchange
#define InterlockedCompareExchangeRelease InterlockedCompareExchange
#define InterlockedCompareExchangeAcquire64 InterlockedCompareExchange64
#define InterlockedCompareExchangeRelease64 InterlockedCompareExchange64
#define InterlockedCompareExchangePointerAcquire InterlockedCompareExchangePointer
#define InterlockedCompareExchangePointerRelease InterlockedCompareExchangePointer
#endif
#endif
#endif

#define UnlockResource(hResData) ( { (VOID)(hResData); 0; } )
#define MAXINTATOM 0xc000
#define MAKEINTATOM(i) (LPTSTR) ((ULONG_PTR)((WORD)(i)))
#define INVALID_ATOM ((ATOM)0)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI HLOCAL WINAPI LocalAlloc (UINT uFlags, SIZE_T uBytes);
  WINBASEAPI HLOCAL WINAPI LocalFree (HLOCAL hMem);
  int WINAPI WinMain (HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nShowCmd);
  int WINAPI wWinMain (HINSTANCE hInstance, HINSTANCE hPrevInstance, LPWSTR lpCmdLine, int nShowCmd);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI UINT WINAPI GlobalFlags (HGLOBAL hMem);
  WINBASEAPI HGLOBAL WINAPI GlobalHandle (LPCVOID pMem);
  WINBASEAPI SIZE_T WINAPI GlobalCompact (DWORD dwMinFree);
  WINBASEAPI VOID WINAPI GlobalFix (HGLOBAL hMem);
  WINBASEAPI VOID WINAPI GlobalUnfix (HGLOBAL hMem);
  WINBASEAPI LPVOID WINAPI GlobalWire (HGLOBAL hMem);
  WINBASEAPI WINBOOL WINAPI GlobalUnWire (HGLOBAL hMem);
  WINBASEAPI VOID WINAPI GlobalMemoryStatus (LPMEMORYSTATUS lpBuffer);
  WINBASEAPI LPVOID WINAPI LocalLock (HLOCAL hMem);
  WINBASEAPI HLOCAL WINAPI LocalHandle (LPCVOID pMem);
  WINBASEAPI WINBOOL WINAPI LocalUnlock (HLOCAL hMem);
  WINBASEAPI SIZE_T WINAPI LocalSize (HLOCAL hMem);
  WINBASEAPI UINT WINAPI LocalFlags (HLOCAL hMem);
  WINBASEAPI SIZE_T WINAPI LocalShrink (HLOCAL hMem, UINT cbNewSize);
  WINBASEAPI SIZE_T WINAPI LocalCompact (UINT uMinFree);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI LPVOID WINAPI VirtualAllocExNuma (HANDLE hProcess, LPVOID lpAddress, SIZE_T dwSize, DWORD flAllocationType, DWORD flProtect, DWORD nndPreferred);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI GetProcessorSystemCycleTime (USHORT Group, PSYSTEM_PROCESSOR_CYCLE_TIME_INFORMATION Buffer, PDWORD ReturnedLength);
  WINBASEAPI WINBOOL WINAPI GetPhysicallyInstalledSystemMemory (PULONGLONG TotalMemoryInKilobytes);
#endif

#define SCS_32BIT_BINARY 0
#define SCS_DOS_BINARY 1
#define SCS_WOW_BINARY 2
#define SCS_PIF_BINARY 3
#define SCS_POSIX_BINARY 4
#define SCS_OS216_BINARY 5
#define SCS_64BIT_BINARY 6

#ifdef _WIN64
#define SCS_THIS_PLATFORM_BINARY SCS_64BIT_BINARY
#else
#define SCS_THIS_PLATFORM_BINARY SCS_32BIT_BINARY
#endif

  WINBASEAPI WINBOOL WINAPI GetBinaryTypeA (LPCSTR lpApplicationName, LPDWORD lpBinaryType);
  WINBASEAPI WINBOOL WINAPI GetBinaryTypeW (LPCWSTR lpApplicationName, LPDWORD lpBinaryType);
  WINBASEAPI DWORD WINAPI GetShortPathNameA (LPCSTR lpszLongPath, LPSTR lpszShortPath, DWORD cchBuffer);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI DWORD WINAPI GetLongPathNameTransactedA (LPCSTR lpszShortPath, LPSTR lpszLongPath, DWORD cchBuffer, HANDLE hTransaction);
  WINBASEAPI DWORD WINAPI GetLongPathNameTransactedW (LPCWSTR lpszShortPath, LPWSTR lpszLongPath, DWORD cchBuffer, HANDLE hTransaction);
#endif
  WINBASEAPI WINBOOL WINAPI GetProcessIoCounters (HANDLE hProcess, PIO_COUNTERS lpIoCounters);
  WINBASEAPI WINBOOL WINAPI GetProcessWorkingSetSize (HANDLE hProcess, PSIZE_T lpMinimumWorkingSetSize, PSIZE_T lpMaximumWorkingSetSize);
  WINBASEAPI WINBOOL WINAPI SetProcessWorkingSetSize (HANDLE hProcess, SIZE_T dwMinimumWorkingSetSize, SIZE_T dwMaximumWorkingSetSize);
  WINBASEAPI VOID WINAPI FatalExit (int ExitCode);
  WINBASEAPI WINBOOL WINAPI SetEnvironmentStringsA (LPCH NewEnvironment);

#ifndef UNICODE
#define SetEnvironmentStrings SetEnvironmentStringsA
#define GetShortPathName GetShortPathNameA
#endif

#define GetBinaryType __MINGW_NAME_AW(GetBinaryType)
#if _WIN32_WINNT >= 0x0600
#define GetLongPathNameTransacted __MINGW_NAME_AW(GetLongPathNameTransacted)
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI HGLOBAL WINAPI GlobalAlloc (UINT uFlags, SIZE_T dwBytes);
  WINBASEAPI HGLOBAL WINAPI GlobalReAlloc (HGLOBAL hMem, SIZE_T dwBytes, UINT uFlags);
  WINBASEAPI SIZE_T WINAPI GlobalSize (HGLOBAL hMem);
  WINBASEAPI LPVOID WINAPI GlobalLock (HGLOBAL hMem);
  WINBASEAPI WINBOOL WINAPI GlobalUnlock (HGLOBAL hMem);
  WINBASEAPI HGLOBAL WINAPI GlobalFree (HGLOBAL hMem);
  WINBASEAPI HLOCAL WINAPI LocalReAlloc (HLOCAL hMem, SIZE_T uBytes, UINT uFlags);

  WINBASEAPI WINBOOL WINAPI GetProcessAffinityMask (HANDLE hProcess, PDWORD_PTR lpProcessAffinityMask, PDWORD_PTR lpSystemAffinityMask);
  WINBASEAPI WINBOOL WINAPI SetProcessAffinityMask (HANDLE hProcess, DWORD_PTR dwProcessAffinityMask);
  WINBASEAPI DWORD_PTR WINAPI SetThreadAffinityMask (HANDLE hThread, DWORD_PTR dwThreadAffinityMask);

  WINBASEAPI VOID WINAPI RaiseFailFastException (PEXCEPTION_RECORD pExceptionRecord, PCONTEXT pContextRecord, DWORD dwFlags);
  WINBASEAPI DWORD WINAPI SetThreadIdealProcessor (HANDLE hThread, DWORD dwIdealProcessor);
  WINBASEAPI LPVOID WINAPI CreateFiberEx (SIZE_T dwStackCommitSize, SIZE_T dwStackReserveSize, DWORD dwFlags, LPFIBER_START_ROUTINE lpStartAddress, LPVOID lpParameter);
  WINBASEAPI VOID WINAPI DeleteFiber (LPVOID lpFiber);
  WINBASEAPI VOID WINAPI SwitchToFiber (LPVOID lpFiber);
  WINBASEAPI WINBOOL WINAPI ConvertFiberToThread (VOID);
  WINBASEAPI LPVOID WINAPI ConvertThreadToFiberEx (LPVOID lpParameter, DWORD dwFlags);
#endif

  typedef enum _THREAD_INFORMATION_CLASS {
    ThreadMemoryPriority,
    ThreadAbsoluteCpuPriority,
    ThreadInformationClassMax
  } THREAD_INFORMATION_CLASS;

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

#define FIBER_FLAG_FLOAT_SWITCH 0x1

  WINBASEAPI LPVOID WINAPI CreateFiber (SIZE_T dwStackSize, LPFIBER_START_ROUTINE lpStartAddress, LPVOID lpParameter);
  WINBASEAPI LPVOID WINAPI ConvertThreadToFiber (LPVOID lpParameter);

  /* TODO: Add RTL_UMS... to winnt.h header and add UMS-base API.  */

#if _WIN32_WINNT >= 0x0602
  WINBASEAPI WINBOOL WINAPI GetThreadInformation (HANDLE hThread, THREAD_INFORMATION_CLASS ThreadInformationClass, LPVOID ThreadInformation, DWORD ThreadInformationSize);
#endif

#if _WIN32_WINNT >= 0x0600
#define PROCESS_DEP_ENABLE 0x00000001
#define PROCESS_DEP_DISABLE_ATL_THUNK_EMULATION 0x00000002

  WINBASEAPI WINBOOL WINAPI SetProcessDEPPolicy (DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI GetProcessDEPPolicy (HANDLE hProcess, LPDWORD lpFlags, PBOOL lpPermanent);
#endif

  WINBASEAPI WINBOOL WINAPI RequestWakeupLatency (LATENCY_TIME latency);
  WINBASEAPI WINBOOL WINAPI IsSystemResumeAutomatic (VOID);
  WINBASEAPI WINBOOL WINAPI GetThreadIOPendingFlag (HANDLE hThread, PBOOL lpIOIsPending);
  WINBASEAPI WINBOOL WINAPI GetThreadSelectorEntry (HANDLE hThread, DWORD dwSelector, LPLDT_ENTRY lpSelectorEntry);
  WINBASEAPI EXECUTION_STATE WINAPI SetThreadExecutionState (EXECUTION_STATE esFlags);

#if _WIN32_WINNT >= 0x0601
  typedef REASON_CONTEXT POWER_REQUEST_CONTEXT,*PPOWER_REQUEST_CONTEXT,*LPPOWER_REQUEST_CONTEXT;

  WINBASEAPI HANDLE WINAPI PowerCreateRequest (PREASON_CONTEXT Context);
  WINBASEAPI WINBOOL WINAPI PowerSetRequest (HANDLE PowerRequest, POWER_REQUEST_TYPE RequestType);
  WINBASEAPI WINBOOL WINAPI PowerClearRequest (HANDLE PowerRequest, POWER_REQUEST_TYPE RequestType);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#if _WIN32_WINNT >= 0x0600
#define FILE_SKIP_COMPLETION_PORT_ON_SUCCESS 0x1
#define FILE_SKIP_SET_EVENT_ON_HANDLE 0x2

  WINBASEAPI WINBOOL WINAPI SetFileCompletionNotificationModes (HANDLE FileHandle, UCHAR Flags);
#endif
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI WINBOOL WINAPI SetThreadInformation (HANDLE hThread, THREAD_INFORMATION_CLASS ThreadInformationClass, LPVOID ThreadInformation, DWORD ThreadInformationSize);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if !defined (RC_INVOKED) && defined (WINBASE_DECLARE_RESTORE_LAST_ERROR)
  WINBASEAPI VOID WINAPI RestoreLastError (DWORD dwErrCode);

  typedef VOID (WINAPI *PRESTORE_LAST_ERROR) (DWORD);

#define RESTORE_LAST_ERROR_NAME_A "RestoreLastError"
#define RESTORE_LAST_ERROR_NAME_W L"RestoreLastError"
#define RESTORE_LAST_ERROR_NAME TEXT ("RestoreLastError")
#endif

#define HasOverlappedIoCompleted(lpOverlapped) (((DWORD) (lpOverlapped)->Internal) != STATUS_PENDING)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI SetFileIoOverlappedRange (HANDLE FileHandle, PUCHAR OverlappedRangeStart, ULONG Length);
#endif

#if !defined (__WIDL__) && _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI Wow64GetThreadContext (HANDLE hThread, PWOW64_CONTEXT lpContext);
  WINBASEAPI WINBOOL WINAPI Wow64SetThreadContext (HANDLE hThread, CONST WOW64_CONTEXT *lpContext);
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WINBOOL WINAPI Wow64GetThreadSelectorEntry (HANDLE hThread, DWORD dwSelector, PWOW64_LDT_ENTRY lpSelectorEntry);
#endif
#endif

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI DWORD WINAPI Wow64SuspendThread (HANDLE hThread);
#endif
  WINBASEAPI WINBOOL WINAPI DebugSetProcessKillOnExit (WINBOOL KillOnExit);
  WINBASEAPI WINBOOL WINAPI DebugBreakProcess (HANDLE Process);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define CRITICAL_SECTION_NO_DEBUG_INFO RTL_CRITICAL_SECTION_FLAG_NO_DEBUG_INFO
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI DWORD WINAPI WaitForMultipleObjects (DWORD nCount, CONST HANDLE *lpHandles, WINBOOL bWaitAll, DWORD dwMilliseconds);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef enum _DEP_SYSTEM_POLICY_TYPE {
    DEPPolicyAlwaysOff = 0,
    DEPPolicyAlwaysOn,
    DEPPolicyOptIn,
    DEPPolicyOptOut,
    DEPTotalPolicyCount
  } DEP_SYSTEM_POLICY_TYPE;

#define HANDLE_FLAG_INHERIT 0x1
#define HANDLE_FLAG_PROTECT_FROM_CLOSE 0x2

#define HINSTANCE_ERROR 32

#define GET_TAPE_MEDIA_INFORMATION 0
#define GET_TAPE_DRIVE_INFORMATION 1

#define SET_TAPE_MEDIA_INFORMATION 0
#define SET_TAPE_DRIVE_INFORMATION 1

  WINBASEAPI WINBOOL WINAPI PulseEvent (HANDLE hEvent);
  WINBASEAPI ATOM WINAPI GlobalDeleteAtom (ATOM nAtom);
  WINBASEAPI WINBOOL WINAPI InitAtomTable (DWORD nSize);
  WINBASEAPI ATOM WINAPI DeleteAtom (ATOM nAtom);
  WINBASEAPI UINT WINAPI SetHandleCount (UINT uNumber);
  WINBASEAPI WINBOOL WINAPI RequestDeviceWakeup (HANDLE hDevice);
  WINBASEAPI WINBOOL WINAPI CancelDeviceWakeupRequest (HANDLE hDevice);
  WINBASEAPI WINBOOL WINAPI GetDevicePowerState (HANDLE hDevice, WINBOOL *pfOn);
  WINBASEAPI WINBOOL WINAPI SetMessageWaitingIndicator (HANDLE hMsgIndicator, ULONG ulMsgCount);
  WINBASEAPI WINBOOL WINAPI SetFileShortNameA (HANDLE hFile, LPCSTR lpShortName);
  WINBASEAPI WINBOOL WINAPI SetFileShortNameW (HANDLE hFile, LPCWSTR lpShortName);
  WINBASEAPI DWORD WINAPI LoadModule (LPCSTR lpModuleName, LPVOID lpParameterBlock);
  WINBASEAPI UINT WINAPI WinExec (LPCSTR lpCmdLine, UINT uCmdShow);
  WINBASEAPI DWORD WINAPI SetTapePosition (HANDLE hDevice, DWORD dwPositionMethod, DWORD dwPartition, DWORD dwOffsetLow, DWORD dwOffsetHigh, WINBOOL bImmediate);
  WINBASEAPI DWORD WINAPI GetTapePosition (HANDLE hDevice, DWORD dwPositionType, LPDWORD lpdwPartition, LPDWORD lpdwOffsetLow, LPDWORD lpdwOffsetHigh);
  WINBASEAPI DWORD WINAPI PrepareTape (HANDLE hDevice, DWORD dwOperation, WINBOOL bImmediate);
  WINBASEAPI DWORD WINAPI EraseTape (HANDLE hDevice, DWORD dwEraseType, WINBOOL bImmediate);
  WINBASEAPI DWORD WINAPI CreateTapePartition (HANDLE hDevice, DWORD dwPartitionMethod, DWORD dwCount, DWORD dwSize);
  WINBASEAPI DWORD WINAPI WriteTapemark (HANDLE hDevice, DWORD dwTapemarkType, DWORD dwTapemarkCount, WINBOOL bImmediate);
  WINBASEAPI DWORD WINAPI GetTapeStatus (HANDLE hDevice);
  WINBASEAPI DWORD WINAPI GetTapeParameters (HANDLE hDevice, DWORD dwOperation, LPDWORD lpdwSize, LPVOID lpTapeInformation);
  WINBASEAPI DWORD WINAPI SetTapeParameters (HANDLE hDevice, DWORD dwOperation, LPVOID lpTapeInformation);
  WINBASEAPI DEP_SYSTEM_POLICY_TYPE WINAPI GetSystemDEPPolicy (VOID);
  WINBASEAPI WINBOOL WINAPI GetSystemRegistryQuota (PDWORD pdwQuotaAllowed, PDWORD pdwQuotaUsed);
  WINBASEAPI WINBOOL WINAPI FileTimeToDosDateTime (CONST FILETIME *lpFileTime, LPWORD lpFatDate, LPWORD lpFatTime);
  WINBASEAPI WINBOOL WINAPI DosDateTimeToFileTime (WORD wFatDate, WORD wFatTime, LPFILETIME lpFileTime);
  WINBASEAPI WINBOOL WINAPI SetSystemTimeAdjustment (DWORD dwTimeAdjustment, WINBOOL bTimeAdjustmentDisabled);

#define SetFileShortName __MINGW_NAME_AW(SetFileShortName)

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define SEM_FAILCRITICALERRORS 0x0001
#define SEM_NOGPFAULTERRORBOX 0x0002
#define SEM_NOALIGNMENTFAULTEXCEPT 0x0004
#define SEM_NOOPENFILEERRORBOX 0x8000

  WINBASEAPI DWORD WINAPI GetThreadErrorMode (VOID);
  WINBASEAPI WINBOOL WINAPI SetThreadErrorMode (DWORD dwNewMode, LPDWORD lpOldMode);

  WINBASEAPI WINBOOL WINAPI ClearCommBreak (HANDLE hFile);
  WINBASEAPI WINBOOL WINAPI ClearCommError (HANDLE hFile, LPDWORD lpErrors, LPCOMSTAT lpStat);
  WINBASEAPI WINBOOL WINAPI SetupComm (HANDLE hFile, DWORD dwInQueue, DWORD dwOutQueue);
  WINBASEAPI WINBOOL WINAPI EscapeCommFunction (HANDLE hFile, DWORD dwFunc);
  WINBASEAPI WINBOOL WINAPI GetCommConfig (HANDLE hCommDev, LPCOMMCONFIG lpCC, LPDWORD lpdwSize);
  WINBASEAPI WINBOOL WINAPI GetCommMask (HANDLE hFile, LPDWORD lpEvtMask);
  WINBASEAPI WINBOOL WINAPI GetCommProperties (HANDLE hFile, LPCOMMPROP lpCommProp);
  WINBASEAPI WINBOOL WINAPI GetCommModemStatus (HANDLE hFile, LPDWORD lpModemStat);
  WINBASEAPI WINBOOL WINAPI GetCommState (HANDLE hFile, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI GetCommTimeouts (HANDLE hFile, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI PurgeComm (HANDLE hFile, DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI SetCommBreak (HANDLE hFile);
  WINBASEAPI WINBOOL WINAPI SetCommConfig (HANDLE hCommDev, LPCOMMCONFIG lpCC, DWORD dwSize);
  WINBASEAPI WINBOOL WINAPI SetCommMask (HANDLE hFile, DWORD dwEvtMask);
  WINBASEAPI WINBOOL WINAPI SetCommState (HANDLE hFile, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI SetCommTimeouts (HANDLE hFile, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI TransmitCommChar (HANDLE hFile, char cChar);
  WINBASEAPI WINBOOL WINAPI WaitCommEvent (HANDLE hFile, LPDWORD lpEvtMask, LPOVERLAPPED lpOverlapped);

  WINBASEAPI WINBOOL WINAPI GetProcessPriorityBoost (HANDLE hProcess, PBOOL pDisablePriorityBoost);
  WINBASEAPI WINBOOL WINAPI SetProcessPriorityBoost (HANDLE hProcess, WINBOOL bDisablePriorityBoost);
  WINBASEAPI int WINAPI MulDiv (int nNumber, int nNumerator, int nDenominator);

#ifndef __WIDL__
  WINBASEAPI DWORD WINAPI FormatMessageA (DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPSTR lpBuffer, DWORD nSize, va_list *Arguments);
  WINBASEAPI DWORD WINAPI FormatMessageW (DWORD dwFlags, LPCVOID lpSource, DWORD dwMessageId, DWORD dwLanguageId, LPWSTR lpBuffer, DWORD nSize, va_list *Arguments);

#define FormatMessage __MINGW_NAME_AW(FormatMessage)
#endif

#define FORMAT_MESSAGE_IGNORE_INSERTS 0x00000200
#define FORMAT_MESSAGE_FROM_STRING 0x00000400
#define FORMAT_MESSAGE_FROM_HMODULE 0x00000800
#define FORMAT_MESSAGE_FROM_SYSTEM 0x00001000
#define FORMAT_MESSAGE_ARGUMENT_ARRAY 0x00002000
#define FORMAT_MESSAGE_MAX_WIDTH_MASK 0x000000ff
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef DWORD (WINAPI *PFE_EXPORT_FUNC) (PBYTE pbData, PVOID pvCallbackContext, ULONG ulLength);
  typedef DWORD (WINAPI *PFE_IMPORT_FUNC) (PBYTE pbData, PVOID pvCallbackContext, PULONG ulLength);

#define FILE_ENCRYPTABLE 0
#define FILE_IS_ENCRYPTED 1
#define FILE_SYSTEM_ATTR 2
#define FILE_ROOT_DIR 3
#define FILE_SYSTEM_DIR 4
#define FILE_UNKNOWN 5
#define FILE_SYSTEM_NOT_SUPPORT 6
#define FILE_USER_DISALLOWED 7
#define FILE_READ_ONLY 8
#define FILE_DIR_DISALLOWED 9

#define FORMAT_MESSAGE_ALLOCATE_BUFFER 0x00000100

#define EFS_USE_RECOVERY_KEYS (0x1)

#define CREATE_FOR_IMPORT (1)
#define CREATE_FOR_DIR (2)
#define OVERWRITE_HIDDEN (4)
#define EFSRPC_SECURE_ONLY (8)

  WINBASEAPI WINBOOL WINAPI GetNamedPipeInfo (HANDLE hNamedPipe, LPDWORD lpFlags, LPDWORD lpOutBufferSize, LPDWORD lpInBufferSize, LPDWORD lpMaxInstances);
  WINBASEAPI HANDLE WINAPI CreateMailslotA (LPCSTR lpName, DWORD nMaxMessageSize, DWORD lReadTimeout, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINBASEAPI HANDLE WINAPI CreateMailslotW (LPCWSTR lpName, DWORD nMaxMessageSize, DWORD lReadTimeout, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINBASEAPI WINBOOL WINAPI GetMailslotInfo (HANDLE hMailslot, LPDWORD lpMaxMessageSize, LPDWORD lpNextSize, LPDWORD lpMessageCount, LPDWORD lpReadTimeout);
  WINBASEAPI WINBOOL WINAPI SetMailslotInfo (HANDLE hMailslot, DWORD lReadTimeout);
  WINADVAPI WINBOOL WINAPI EncryptFileA (LPCSTR lpFileName);
  WINADVAPI WINBOOL WINAPI EncryptFileW (LPCWSTR lpFileName);
  WINADVAPI WINBOOL WINAPI DecryptFileA (LPCSTR lpFileName, DWORD dwReserved);
  WINADVAPI WINBOOL WINAPI DecryptFileW (LPCWSTR lpFileName, DWORD dwReserved);
  WINADVAPI WINBOOL WINAPI FileEncryptionStatusA (LPCSTR lpFileName, LPDWORD lpStatus);
  WINADVAPI WINBOOL WINAPI FileEncryptionStatusW (LPCWSTR lpFileName, LPDWORD lpStatus);
  WINADVAPI DWORD WINAPI OpenEncryptedFileRawA (LPCSTR lpFileName, ULONG ulFlags, PVOID *pvContext);
  WINADVAPI DWORD WINAPI OpenEncryptedFileRawW (LPCWSTR lpFileName, ULONG ulFlags, PVOID *pvContext);
  WINADVAPI DWORD WINAPI ReadEncryptedFileRaw (PFE_EXPORT_FUNC pfExportCallback, PVOID pvCallbackContext, PVOID pvContext);
  WINADVAPI DWORD WINAPI WriteEncryptedFileRaw (PFE_IMPORT_FUNC pfImportCallback, PVOID pvCallbackContext, PVOID pvContext);
  WINADVAPI VOID WINAPI CloseEncryptedFileRaw (PVOID pvContext);
  WINBASEAPI int WINAPI lstrcmpA (LPCSTR lpString1, LPCSTR lpString2);
  WINBASEAPI int WINAPI lstrcmpW (LPCWSTR lpString1, LPCWSTR lpString2);
  WINBASEAPI int WINAPI lstrcmpiA (LPCSTR lpString1, LPCSTR lpString2);
  WINBASEAPI int WINAPI lstrcmpiW (LPCWSTR lpString1, LPCWSTR lpString2);
  WINBASEAPI LPSTR WINAPI lstrcpynA (LPSTR lpString1, LPCSTR lpString2, int iMaxLength);
  WINBASEAPI LPWSTR WINAPI lstrcpynW (LPWSTR lpString1, LPCWSTR lpString2, int iMaxLength);
  WINBASEAPI LPSTR WINAPI lstrcpyA (LPSTR lpString1, LPCSTR lpString2);
  WINBASEAPI LPWSTR WINAPI lstrcpyW (LPWSTR lpString1, LPCWSTR lpString2);
  WINBASEAPI LPSTR WINAPI lstrcatA (LPSTR lpString1, LPCSTR lpString2);
  WINBASEAPI LPWSTR WINAPI lstrcatW (LPWSTR lpString1, LPCWSTR lpString2);
  WINBASEAPI int WINAPI lstrlenA (LPCSTR lpString);
  WINBASEAPI int WINAPI lstrlenW (LPCWSTR lpString);
  WINBASEAPI HFILE WINAPI OpenFile (LPCSTR lpFileName, LPOFSTRUCT lpReOpenBuff, UINT uStyle);
  WINBASEAPI HFILE WINAPI _lopen (LPCSTR lpPathName, int iReadWrite);
  WINBASEAPI HFILE WINAPI _lcreat (LPCSTR lpPathName, int iAttribute);
  WINBASEAPI UINT WINAPI _lread (HFILE hFile, LPVOID lpBuffer, UINT uBytes);
  WINBASEAPI UINT WINAPI _lwrite (HFILE hFile, LPCCH lpBuffer, UINT uBytes);
  WINBASEAPI __LONG32 WINAPI _hread (HFILE hFile, LPVOID lpBuffer, __LONG32 lBytes);
  WINBASEAPI __LONG32 WINAPI _hwrite (HFILE hFile, LPCCH lpBuffer, __LONG32 lBytes);
  WINBASEAPI HFILE WINAPI _lclose (HFILE hFile);
  WINBASEAPI LONG WINAPI _llseek (HFILE hFile, LONG lOffset, int iOrigin);
  WINADVAPI WINBOOL WINAPI IsTextUnicode (CONST VOID *lpv, int iSize, LPINT lpiResult);
  WINBASEAPI DWORD WINAPI SignalObjectAndWait (HANDLE hObjectToSignal, HANDLE hObjectToWaitOn, DWORD dwMilliseconds, WINBOOL bAlertable);
  WINBASEAPI WINBOOL WINAPI BackupRead (HANDLE hFile, LPBYTE lpBuffer, DWORD nNumberOfBytesToRead, LPDWORD lpNumberOfBytesRead, WINBOOL bAbort, WINBOOL bProcessSecurity, LPVOID *lpContext);
  WINBASEAPI WINBOOL WINAPI BackupSeek (HANDLE hFile, DWORD dwLowBytesToSeek, DWORD dwHighBytesToSeek, LPDWORD lpdwLowByteSeeked, LPDWORD lpdwHighByteSeeked, LPVOID *lpContext);
  WINBASEAPI WINBOOL WINAPI BackupWrite (HANDLE hFile, LPBYTE lpBuffer, DWORD nNumberOfBytesToWrite, LPDWORD lpNumberOfBytesWritten, WINBOOL bAbort, WINBOOL bProcessSecurity, LPVOID *lpContext);

#define CreateMailslot __MINGW_NAME_AW(CreateMailslot)
#define EncryptFile __MINGW_NAME_AW(EncryptFile)
#define DecryptFile __MINGW_NAME_AW(DecryptFile)
#define FileEncryptionStatus __MINGW_NAME_AW(FileEncryptionStatus)
#define OpenEncryptedFileRaw __MINGW_NAME_AW(OpenEncryptedFileRaw)
#define lstrcmp __MINGW_NAME_AW(lstrcmp)
#define lstrcmpi __MINGW_NAME_AW(lstrcmpi)
#define lstrcpyn __MINGW_NAME_AW(lstrcpyn)
#define lstrcpy __MINGW_NAME_AW(lstrcpy)
#define lstrcat __MINGW_NAME_AW(lstrcat)
#define lstrlen __MINGW_NAME_AW(lstrlen)

  typedef struct _WIN32_STREAM_ID {
    DWORD dwStreamId;
    DWORD dwStreamAttributes;
    LARGE_INTEGER Size;
    DWORD dwStreamNameSize;
    WCHAR cStreamName[ANYSIZE_ARRAY];
  } WIN32_STREAM_ID,*LPWIN32_STREAM_ID;

#define BACKUP_INVALID 0x00000000
#define BACKUP_DATA 0x00000001
#define BACKUP_EA_DATA 0x00000002
#define BACKUP_SECURITY_DATA 0x00000003
#define BACKUP_ALTERNATE_DATA 0x00000004
#define BACKUP_LINK 0x00000005
#define BACKUP_PROPERTY_DATA 0x00000006
#define BACKUP_OBJECT_ID 0x00000007
#define BACKUP_REPARSE_DATA 0x00000008
#define BACKUP_SPARSE_BLOCK 0x00000009
#define BACKUP_TXFS_DATA 0x0000000a

#define STREAM_NORMAL_ATTRIBUTE 0x00000000
#define STREAM_MODIFIED_WHEN_READ 0x00000001
#define STREAM_CONTAINS_SECURITY 0x00000002
#define STREAM_CONTAINS_PROPERTIES 0x00000004
#define STREAM_SPARSE_ATTRIBUTE 0x00000008

#define STARTF_USESHOWWINDOW 0x00000001
#define STARTF_USESIZE 0x00000002
#define STARTF_USEPOSITION 0x00000004
#define STARTF_USECOUNTCHARS 0x00000008
#define STARTF_USEFILLATTRIBUTE 0x00000010
#define STARTF_RUNFULLSCREEN 0x00000020
#define STARTF_FORCEONFEEDBACK 0x00000040
#define STARTF_FORCEOFFFEEDBACK 0x00000080
#define STARTF_USESTDHANDLES 0x00000100

#define STARTF_USEHOTKEY 0x00000200
#define STARTF_TITLEISLINKNAME 0x00000800
#define STARTF_TITLEISAPPID 0x00001000
#define STARTF_PREVENTPINNING 0x00002000

#if _WIN32_WINNT >= 0x0600
  typedef struct _STARTUPINFOEXA {
    STARTUPINFOA StartupInfo;
    LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
  } STARTUPINFOEXA,*LPSTARTUPINFOEXA;

  typedef struct _STARTUPINFOEXW {
    STARTUPINFOW StartupInfo;
    LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList;
  } STARTUPINFOEXW,*LPSTARTUPINFOEXW;

  __MINGW_TYPEDEF_AW(STARTUPINFOEX)
  __MINGW_TYPEDEF_AW(LPSTARTUPINFOEX)
#endif

#define SHUTDOWN_NORETRY 0x1
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBOOL WINAPI GetSystemTimes (LPFILETIME lpIdleTime, LPFILETIME lpKernelTime, LPFILETIME lpUserTime);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeInfo (HANDLE hNamedPipe, LPDWORD lpFlags, LPDWORD lpOutBufferSize, LPDWORD lpInBufferSize, LPDWORD lpMaxInstances);
#define CreateSemaphore __MINGW_NAME_AW(CreateSemaphore)
  WINBASEAPI HANDLE WINAPI CreateSemaphoreW (LPSECURITY_ATTRIBUTES lpSemaphoreAttributes, LONG lInitialCount, LONG lMaximumCount, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateWaitableTimerW (LPSECURITY_ATTRIBUTES lpTimerAttributes, WINBOOL bManualReset, LPCWSTR lpTimerName);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
#define LoadLibrary __MINGW_NAME_AW(LoadLibrary)
  WINBASEAPI HMODULE WINAPI LoadLibraryW (LPCWSTR lpLibFileName);
  WINBASEAPI HMODULE WINAPI LoadLibraryA (LPCSTR lpLibFileName);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI HANDLE WINAPI OpenMutexA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenSemaphoreA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateWaitableTimerA (LPSECURITY_ATTRIBUTES lpTimerAttributes, WINBOOL bManualReset, LPCSTR lpTimerName);
  WINBASEAPI HANDLE WINAPI OpenWaitableTimerA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpTimerName);
  WINBASEAPI HANDLE WINAPI CreateFileMappingA (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCSTR lpName);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI CreateWaitableTimerExA (LPSECURITY_ATTRIBUTES lpTimerAttributes, LPCSTR lpTimerName, DWORD dwFlags, DWORD dwDesiredAccess);
  WINBASEAPI HANDLE WINAPI CreateFileMappingNumaA (HANDLE hFile, LPSECURITY_ATTRIBUTES lpFileMappingAttributes, DWORD flProtect, DWORD dwMaximumSizeHigh, DWORD dwMaximumSizeLow, LPCSTR lpName, DWORD nndPreferred);
#endif
  WINBASEAPI HANDLE WINAPI OpenFileMappingA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpName);
  WINBASEAPI DWORD WINAPI GetLogicalDriveStringsA (DWORD nBufferLength, LPSTR lpBuffer);

#ifndef UNICODE
#define OpenMutex OpenMutexA
#define OpenSemaphore OpenSemaphoreA
#define OpenWaitableTimer OpenWaitableTimerA
#define CreateFileMapping CreateFileMappingA
#define OpenFileMapping OpenFileMappingA
#define GetLogicalDriveStrings GetLogicalDriveStringsA
#endif

#define CreateWaitableTimer __MINGW_NAME_AW(CreateWaitableTimer)

#if _WIN32_WINNT >= 0x0600
#ifndef UNICODE
#define CreateWaitableTimerEx CreateWaitableTimerExA
#define CreateFileMappingNuma CreateFileMappingNumaA
#endif
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI HANDLE WINAPI CreateSemaphoreA (LPSECURITY_ATTRIBUTES lpSemaphoreAttributes, LONG lInitialCount, LONG lMaximumCount, LPCSTR lpName);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI CreateSemaphoreExA (LPSECURITY_ATTRIBUTES lpSemaphoreAttributes, LONG lInitialCount, LONG lMaximumCount, LPCSTR lpName, DWORD dwFlags, DWORD dwDesiredAccess);
#ifndef UNICODE
#define CreateSemaphoreEx CreateSemaphoreExA
#endif
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  typedef enum _PROCESS_INFORMATION_CLASS {
    ProcessMemoryPriority,
    ProcessInformationClassMax
  } PROCESS_INFORMATION_CLASS;
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) && _WIN32_WINNT >= 0x0602
  WINBASEAPI HMODULE WINAPI LoadPackagedLibrary (LPCWSTR lpwLibFileName, DWORD Reserved);
  WINBASEAPI WINBOOL WINAPI GetProcessInformation (HANDLE hProcess, PROCESS_INFORMATION_CLASS ProcessInformationClass, LPVOID ProcessInformation, DWORD ProcessInformationSize);
  WINBASEAPI WINBOOL WINAPI SetProcessInformation (HANDLE hProcess, PROCESS_INFORMATION_CLASS ProcessInformationClass, LPVOID ProcessInformation, DWORD ProcessInformationSize);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if _WIN32_WINNT >= 0x0600

#define PROCESS_NAME_NATIVE 0x00000001

  WINBASEAPI WINBOOL WINAPI QueryFullProcessImageNameA (HANDLE hProcess, DWORD dwFlags, LPSTR lpExeName, PDWORD lpdwSize);
  WINBASEAPI WINBOOL WINAPI QueryFullProcessImageNameW (HANDLE hProcess, DWORD dwFlags, LPWSTR lpExeName, PDWORD lpdwSize);

#define QueryFullProcessImageName __MINGW_NAME_AW(QueryFullProcessImageName)

#define PROC_THREAD_ATTRIBUTE_NUMBER 0x0000ffff
#define PROC_THREAD_ATTRIBUTE_THREAD 0x00010000
#define PROC_THREAD_ATTRIBUTE_INPUT 0x00020000
#define PROC_THREAD_ATTRIBUTE_ADDITIVE 0x00040000

#ifndef _USE_FULL_PROC_THREAD_ATTRIBUTE
  typedef enum _PROC_THREAD_ATTRIBUTE_NUM {
    ProcThreadAttributeParentProcess = 0,
    ProcThreadAttributeHandleList = 2
#if _WIN32_WINNT >= 0x0601
    ,ProcThreadAttributeGroupAffinity = 3,
    ProcThreadAttributePreferredNode = 4,
    ProcThreadAttributeIdealProcessor = 5,
    ProcThreadAttributeUmsThread = 6,
    ProcThreadAttributeMitigationPolicy = 7
#endif
#if _WIN32_WINNT >= 0x0602
    ,ProcThreadAttributeSecurityCapabilities = 9
#endif
    ,ProcThreadAttributeProtectionLevel = 11
#if _WIN32_WINNT >= 0x0603
#endif
#if _WIN32_WINNT >= 0x0A00
    ,ProcThreadAttributeJobList = 13
    ,ProcThreadAttributeChildProcessPolicy = 14
    ,ProcThreadAttributeAllApplicationPackagesPolicy = 15
    ,ProcThreadAttributeWin32kFilter = 16
#endif
#if NTDDI_VERSION >= 0x0A000002
    ,ProcThreadAttributeSafeOpenPromptOriginClaim = 17
#endif
#if NTDDI_VERSION >= 0x0A000003
    ,ProcThreadAttributeDesktopAppPolicy = 18
#endif
#if NTDDI_VERSION >= 0x0A000006
    ,ProcThreadAttributePseudoConsole = 22
#endif
  } PROC_THREAD_ATTRIBUTE_NUM;
#endif

#define ProcThreadAttributeValue(Number, Thread, Input, Additive) (((Number) &PROC_THREAD_ATTRIBUTE_NUMBER) | ((Thread != FALSE) ? PROC_THREAD_ATTRIBUTE_THREAD : 0) | ((Input != FALSE) ? PROC_THREAD_ATTRIBUTE_INPUT : 0) | ((Additive != FALSE) ? PROC_THREAD_ATTRIBUTE_ADDITIVE : 0))

#define PROC_THREAD_ATTRIBUTE_PARENT_PROCESS ProcThreadAttributeValue (ProcThreadAttributeParentProcess, FALSE, TRUE, FALSE)
#define PROC_THREAD_ATTRIBUTE_HANDLE_LIST ProcThreadAttributeValue (ProcThreadAttributeHandleList, FALSE, TRUE, FALSE)
#endif

#if _WIN32_WINNT >= 0x0601
#define PROC_THREAD_ATTRIBUTE_GROUP_AFFINITY ProcThreadAttributeValue (ProcThreadAttributeGroupAffinity, TRUE, TRUE, FALSE)
#define PROC_THREAD_ATTRIBUTE_PREFERRED_NODE ProcThreadAttributeValue (ProcThreadAttributePreferredNode, FALSE, TRUE, FALSE)
#define PROC_THREAD_ATTRIBUTE_IDEAL_PROCESSOR ProcThreadAttributeValue (ProcThreadAttributeIdealProcessor, TRUE, TRUE, FALSE)
#define PROC_THREAD_ATTRIBUTE_UMS_THREAD ProcThreadAttributeValue (ProcThreadAttributeUmsThread, TRUE, TRUE, FALSE)
#define PROC_THREAD_ATTRIBUTE_MITIGATION_POLICY ProcThreadAttributeValue (ProcThreadAttributeMitigationPolicy, FALSE, TRUE, FALSE)
#endif

#if _WIN32_WINNT >= 0x0602
#define PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES ProcThreadAttributeValue (ProcThreadAttributeSecurityCapabilities, FALSE, TRUE, FALSE)
#endif

#define PROC_THREAD_ATTRIBUTE_PROTECTION_LEVEL ProcThreadAttributeValue (ProcThreadAttributeProtectionLevel, FALSE, TRUE, FALSE)

#if _WIN32_WINNT >= 0x0603
#endif

#if NTDDI_VERSION >= 0x0A000006
#define PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE ProcThreadAttributeValue (ProcThreadAttributePseudoConsole, FALSE, TRUE, FALSE)
#endif

#if _WIN32_WINNT >= 0x0601
#define PROCESS_CREATION_MITIGATION_POLICY_DEP_ENABLE 0x01
#define PROCESS_CREATION_MITIGATION_POLICY_DEP_ATL_THUNK_ENABLE 0x02
#define PROCESS_CREATION_MITIGATION_POLICY_SEHOP_ENABLE 0x04
#endif

#if _WIN32_WINNT >= 0x0602
#define PROC_THREAD_ATTRIBUTE_SECURITY_CAPABILITIES ProcThreadAttributeValue (ProcThreadAttributeSecurityCapabilities, FALSE, TRUE, FALSE)

#define PROCESS_CREATION_MITIGATION_POLICY_FORCE_RELOCATE_IMAGES_MASK (0x00000003 << 8)
#define PROCESS_CREATION_MITIGATION_POLICY_FORCE_RELOCATE_IMAGES_DEFER (0x00000000 << 8)
#define PROCESS_CREATION_MITIGATION_POLICY_FORCE_RELOCATE_IMAGES_ALWAYS_ON (0x00000001 << 8)
#define PROCESS_CREATION_MITIGATION_POLICY_FORCE_RELOCATE_IMAGES_ALWAYS_OFF (0x00000002 << 8)
#define PROCESS_CREATION_MITIGATION_POLICY_FORCE_RELOCATE_IMAGES_ALWAYS_ON_REQ_RELOCS (0x00000003 << 8)

#define PROCESS_CREATION_MITIGATION_POLICY_HEAP_TERMINATE_MASK (0x00000003 << 12)
#define PROCESS_CREATION_MITIGATION_POLICY_HEAP_TERMINATE_DEFER (0x00000000 << 12)
#define PROCESS_CREATION_MITIGATION_POLICY_HEAP_TERMINATE_ALWAYS_ON (0x00000001 << 12)
#define PROCESS_CREATION_MITIGATION_POLICY_HEAP_TERMINATE_ALWAYS_OFF (0x00000002 << 12)
#define PROCESS_CREATION_MITIGATION_POLICY_HEAP_TERMINATE_RESERVED (0x00000003 << 12)

#define PROCESS_CREATION_MITIGATION_POLICY_BOTTOM_UP_ASLR_MASK (0x00000003 << 16)
#define PROCESS_CREATION_MITIGATION_POLICY_BOTTOM_UP_ASLR_DEFER (0x00000000 << 16)
#define PROCESS_CREATION_MITIGATION_POLICY_BOTTOM_UP_ASLR_ALWAYS_ON (0x00000001 << 16)
#define PROCESS_CREATION_MITIGATION_POLICY_BOTTOM_UP_ASLR_ALWAYS_OFF (0x00000002 << 16)
#define PROCESS_CREATION_MITIGATION_POLICY_BOTTOM_UP_ASLR_RESERVED (0x00000003 << 16)

#define PROCESS_CREATION_MITIGATION_POLICY_HIGH_ENTROPY_ASLR_MASK (0x00000003 << 20)
#define PROCESS_CREATION_MITIGATION_POLICY_HIGH_ENTROPY_ASLR_DEFER (0x00000000 << 20)
#define PROCESS_CREATION_MITIGATION_POLICY_HIGH_ENTROPY_ASLR_ALWAYS_ON (0x00000001 << 20)
#define PROCESS_CREATION_MITIGATION_POLICY_HIGH_ENTROPY_ASLR_ALWAYS_OFF (0x00000002 << 20)
#define PROCESS_CREATION_MITIGATION_POLICY_HIGH_ENTROPY_ASLR_RESERVED (0x00000003 << 20)

#define PROCESS_CREATION_MITIGATION_POLICY_STRICT_HANDLE_CHECKS_MASK (0x00000003 << 24)
#define PROCESS_CREATION_MITIGATION_POLICY_STRICT_HANDLE_CHECKS_DEFER (0x00000000 << 24)
#define PROCESS_CREATION_MITIGATION_POLICY_STRICT_HANDLE_CHECKS_ALWAYS_ON (0x00000001 << 24)
#define PROCESS_CREATION_MITIGATION_POLICY_STRICT_HANDLE_CHECKS_ALWAYS_OFF (0x00000002 << 24)
#define PROCESS_CREATION_MITIGATION_POLICY_STRICT_HANDLE_CHECKS_RESERVED (0x00000003 << 24)

#define PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_MASK (0x00000003 << 28)
#define PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_DEFER (0x00000000 << 28)
#define PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_ON (0x00000001 << 28)
#define PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_ALWAYS_OFF (0x00000002 << 28)
#define PROCESS_CREATION_MITIGATION_POLICY_WIN32K_SYSTEM_CALL_DISABLE_RESERVED (0x00000003 << 28)

#define PROCESS_CREATION_MITIGATION_POLICY_EXTENSION_POINT_DISABLE_MASK (0x00000003ULL << 32)
#define PROCESS_CREATION_MITIGATION_POLICY_EXTENSION_POINT_DISABLE_DEFER (0x00000000ULL << 32)
#define PROCESS_CREATION_MITIGATION_POLICY_EXTENSION_POINT_DISABLE_ALWAYS_ON (0x00000001ULL << 32)
#define PROCESS_CREATION_MITIGATION_POLICY_EXTENSION_POINT_DISABLE_ALWAYS_OFF (0x00000002ULL << 32)
#define PROCESS_CREATION_MITIGATION_POLICY_EXTENSION_POINT_DISABLE_RESERVED (0x00000003ULL << 32)

#define PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_MASK (0x0003ULL << 36)
#define PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_DEFER (0x0000ULL << 36)
#define PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON (0x0001ULL << 36)
#define PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_OFF (0x0002ULL << 36)
#define PROCESS_CREATION_MITIGATION_POLICY_PROHIBIT_DYNAMIC_CODE_ALWAYS_ON_ALLOW_OPT_OUT (0x0003ULL << 36)

#define PROCESS_CREATION_MITIGATION_POLICY_CONTROL_FLOW_GUARD_MASK (0x0003ULL << 40)
#define PROCESS_CREATION_MITIGATION_POLICY_CONTROL_FLOW_GUARD_DEFER (0x0000ULL << 40)
#define PROCESS_CREATION_MITIGATION_POLICY_CONTROL_FLOW_GUARD_ALWAYS_ON (0x0001ULL << 40)
#define PROCESS_CREATION_MITIGATION_POLICY_CONTROL_FLOW_GUARD_ALWAYS_OFF (0x0002ULL << 40)
#define PROCESS_CREATION_MITIGATION_POLICY_CONTROL_FLOW_GUARD_EXPORT_SUPPRESSION (0x0003ULL << 40)

#define PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_MASK (0x0003ULL << 44)
#define PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_DEFER (0x0000ULL << 44)
#define PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALWAYS_ON (0x0001ULL << 44)
#define PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALWAYS_OFF (0x0002ULL << 44)
#define PROCESS_CREATION_MITIGATION_POLICY_BLOCK_NON_MICROSOFT_BINARIES_ALLOW_STORE (0x0003ULL << 44)

#define PROCESS_CREATION_MITIGATION_POLICY_FONT_DISABLE_MASK (0x0003ULL << 48)
#define PROCESS_CREATION_MITIGATION_POLICY_FONT_DISABLE_DEFER (0x0000ULL << 48)
#define PROCESS_CREATION_MITIGATION_POLICY_FONT_DISABLE_ALWAYS_ON (0x0001ULL << 48)
#define PROCESS_CREATION_MITIGATION_POLICY_FONT_DISABLE_ALWAYS_OFF (0x0002ULL << 48)
#define PROCESS_CREATION_MITIGATION_POLICY_AUDIT_NONSYSTEM_FONTS (0x0003ULL << 48)

#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_REMOTE_MASK (0x0003ULL << 52)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_REMOTE_DEFER (0x0000ULL << 52)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_REMOTE_ALWAYS_ON (0x0001ULL << 52)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_REMOTE_ALWAYS_OFF (0x0002ULL << 52)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_REMOTE_RESERVED (0x0003ULL << 52)

#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_LOW_LABEL_MASK (0x0003ULL << 56)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_LOW_LABEL_DEFER (0x0000ULL << 56)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_LOW_LABEL_ALWAYS_ON (0x0001ULL << 56)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_LOW_LABEL_ALWAYS_OFF (0x0002ULL << 56)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_NO_LOW_LABEL_RESERVED (0x0003ULL << 56)

#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_PREFER_SYSTEM32_MASK (0x0003ULL << 60)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_PREFER_SYSTEM32_DEFER (0x0000ULL << 60)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_PREFER_SYSTEM32_ALWAYS_ON (0x0001ULL << 60)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_PREFER_SYSTEM32_ALWAYS_OFF (0x0002ULL << 60)
#define PROCESS_CREATION_MITIGATION_POLICY_IMAGE_LOAD_PREFER_SYSTEM32_RESERVED (0x0003ULL << 60)

#define PROCESS_CREATION_MITIGATION_POLICY2_LOADER_INTEGRITY_CONTINUITY_MASK (0x0003ULL << 4)
#define PROCESS_CREATION_MITIGATION_POLICY2_LOADER_INTEGRITY_CONTINUITY_DEFER (0x0000ULL << 4)
#define PROCESS_CREATION_MITIGATION_POLICY2_LOADER_INTEGRITY_CONTINUITY_ALWAYS_ON (0x0001ULL << 4)
#define PROCESS_CREATION_MITIGATION_POLICY2_LOADER_INTEGRITY_CONTINUITY_ALWAYS_OFF (0x0002ULL << 4)
#define PROCESS_CREATION_MITIGATION_POLICY2_LOADER_INTEGRITY_CONTINUITY_AUDIT (0x0003ULL << 4)

#define PROCESS_CREATION_MITIGATION_POLICY2_STRICT_CONTROL_FLOW_GUARD_MASK (0x0003ULL << 8)
#define PROCESS_CREATION_MITIGATION_POLICY2_STRICT_CONTROL_FLOW_GUARD_DEFER (0x0000ULL << 8)
#define PROCESS_CREATION_MITIGATION_POLICY2_STRICT_CONTROL_FLOW_GUARD_ALWAYS_ON (0x0001ULL << 8)
#define PROCESS_CREATION_MITIGATION_POLICY2_STRICT_CONTROL_FLOW_GUARD_ALWAYS_OFF (0x0002ULL << 8)
#define PROCESS_CREATION_MITIGATION_POLICY2_STRICT_CONTROL_FLOW_GUARD_RESERVED (0x0003ULL << 8)

#define PROCESS_CREATION_MITIGATION_POLICY2_MODULE_TAMPERING_PROTECTION_MASK (0x0003ULL << 12)
#define PROCESS_CREATION_MITIGATION_POLICY2_MODULE_TAMPERING_PROTECTION_DEFER (0x0000ULL << 12)
#define PROCESS_CREATION_MITIGATION_POLICY2_MODULE_TAMPERING_PROTECTION_ALWAYS_ON (0x0001ULL << 12)
#define PROCESS_CREATION_MITIGATION_POLICY2_MODULE_TAMPERING_PROTECTION_ALWAYS_OFF (0x0002ULL << 12)
#define PROCESS_CREATION_MITIGATION_POLICY2_MODULE_TAMPERING_PROTECTION_NOINHERIT (0x0003ULL << 12)

#endif

#define ATOM_FLAG_GLOBAL 0x2

  WINBASEAPI WINBOOL WINAPI GetProcessShutdownParameters (LPDWORD lpdwLevel, LPDWORD lpdwFlags);
  WINBASEAPI VOID WINAPI FatalAppExitA (UINT uAction, LPCSTR lpMessageText);
  WINBASEAPI VOID WINAPI FatalAppExitW (UINT uAction, LPCWSTR lpMessageText);
  WINBASEAPI VOID WINAPI GetStartupInfoA (LPSTARTUPINFOA lpStartupInfo);
  WINBASEAPI HRSRC WINAPI FindResourceA (HMODULE hModule, LPCSTR lpName, LPCSTR lpType);
  WINBASEAPI HRSRC WINAPI FindResourceW (HMODULE hModule, LPCWSTR lpName, LPCWSTR lpType);
  WINBASEAPI HRSRC WINAPI FindResourceExA (HMODULE hModule, LPCSTR lpType, LPCSTR lpName, WORD wLanguage);
  WINBASEAPI WINBOOL WINAPI EnumResourceTypesA (HMODULE hModule, ENUMRESTYPEPROCA lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceTypesW (HMODULE hModule, ENUMRESTYPEPROCW lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceNamesA (HMODULE hModule, LPCSTR lpType, ENUMRESNAMEPROCA lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceNamesW (HMODULE hModule, LPCWSTR lpType, ENUMRESNAMEPROCW lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceLanguagesA (HMODULE hModule, LPCSTR lpType, LPCSTR lpName, ENUMRESLANGPROCA lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI WINBOOL WINAPI EnumResourceLanguagesW (HMODULE hModule, LPCWSTR lpType, LPCWSTR lpName, ENUMRESLANGPROCW lpEnumFunc, LONG_PTR lParam);
  WINBASEAPI HANDLE WINAPI BeginUpdateResourceA (LPCSTR pFileName, WINBOOL bDeleteExistingResources);
  WINBASEAPI HANDLE WINAPI BeginUpdateResourceW (LPCWSTR pFileName, WINBOOL bDeleteExistingResources);
  WINBASEAPI WINBOOL WINAPI UpdateResourceA (HANDLE hUpdate, LPCSTR lpType, LPCSTR lpName, WORD wLanguage, LPVOID lpData, DWORD cb);
  WINBASEAPI WINBOOL WINAPI UpdateResourceW (HANDLE hUpdate, LPCWSTR lpType, LPCWSTR lpName, WORD wLanguage, LPVOID lpData, DWORD cb);
  WINBASEAPI WINBOOL WINAPI EndUpdateResourceA (HANDLE hUpdate, WINBOOL fDiscard);
  WINBASEAPI WINBOOL WINAPI EndUpdateResourceW (HANDLE hUpdate, WINBOOL fDiscard);
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI WINBOOL WINAPI GetFirmwareType (PFIRMWARE_TYPE FirmwareType);
  WINBASEAPI WINBOOL WINAPI IsNativeVhdBoot (PBOOL NativeVhdBoot);
#endif
  WINBASEAPI ATOM WINAPI GlobalAddAtomA (LPCSTR lpString);
  WINBASEAPI ATOM WINAPI GlobalAddAtomW (LPCWSTR lpString);
  WINBASEAPI ATOM WINAPI GlobalAddAtomExA (LPCSTR lpString, DWORD Flags);
  WINBASEAPI ATOM WINAPI GlobalAddAtomExW (LPCWSTR lpString, DWORD Flags);
  WINBASEAPI ATOM WINAPI GlobalFindAtomA (LPCSTR lpString);
  WINBASEAPI ATOM WINAPI GlobalFindAtomW (LPCWSTR lpString);
  WINBASEAPI UINT WINAPI GlobalGetAtomNameA (ATOM nAtom, LPSTR lpBuffer, int nSize);
  WINBASEAPI UINT WINAPI GlobalGetAtomNameW (ATOM nAtom, LPWSTR lpBuffer, int nSize);
  WINBASEAPI ATOM WINAPI AddAtomA (LPCSTR lpString);
  WINBASEAPI ATOM WINAPI AddAtomW (LPCWSTR lpString);
  WINBASEAPI ATOM WINAPI FindAtomA (LPCSTR lpString);
  WINBASEAPI ATOM WINAPI FindAtomW (LPCWSTR lpString);
  WINBASEAPI UINT WINAPI GetAtomNameA (ATOM nAtom, LPSTR lpBuffer, int nSize);
  WINBASEAPI UINT WINAPI GetAtomNameW (ATOM nAtom, LPWSTR lpBuffer, int nSize);
  WINBASEAPI UINT WINAPI GetProfileIntA (LPCSTR lpAppName, LPCSTR lpKeyName, INT nDefault);
  WINBASEAPI UINT WINAPI GetProfileIntW (LPCWSTR lpAppName, LPCWSTR lpKeyName, INT nDefault);
  WINBASEAPI DWORD WINAPI GetProfileStringA (LPCSTR lpAppName, LPCSTR lpKeyName, LPCSTR lpDefault, LPSTR lpReturnedString, DWORD nSize);
  WINBASEAPI DWORD WINAPI GetProfileStringW (LPCWSTR lpAppName, LPCWSTR lpKeyName, LPCWSTR lpDefault, LPWSTR lpReturnedString, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI WriteProfileStringA (LPCSTR lpAppName, LPCSTR lpKeyName, LPCSTR lpString);
  WINBASEAPI WINBOOL WINAPI WriteProfileStringW (LPCWSTR lpAppName, LPCWSTR lpKeyName, LPCWSTR lpString);
  WINBASEAPI DWORD WINAPI GetProfileSectionA (LPCSTR lpAppName, LPSTR lpReturnedString, DWORD nSize);
  WINBASEAPI DWORD WINAPI GetProfileSectionW (LPCWSTR lpAppName, LPWSTR lpReturnedString, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI WriteProfileSectionA (LPCSTR lpAppName, LPCSTR lpString);
  WINBASEAPI WINBOOL WINAPI WriteProfileSectionW (LPCWSTR lpAppName, LPCWSTR lpString);
  WINBASEAPI UINT WINAPI GetPrivateProfileIntA (LPCSTR lpAppName, LPCSTR lpKeyName, INT nDefault, LPCSTR lpFileName);
  WINBASEAPI UINT WINAPI GetPrivateProfileIntW (LPCWSTR lpAppName, LPCWSTR lpKeyName, INT nDefault, LPCWSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileStringA (LPCSTR lpAppName, LPCSTR lpKeyName, LPCSTR lpDefault, LPSTR lpReturnedString, DWORD nSize, LPCSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileStringW (LPCWSTR lpAppName, LPCWSTR lpKeyName, LPCWSTR lpDefault, LPWSTR lpReturnedString, DWORD nSize, LPCWSTR lpFileName);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileStringA (LPCSTR lpAppName, LPCSTR lpKeyName, LPCSTR lpString, LPCSTR lpFileName);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileStringW (LPCWSTR lpAppName, LPCWSTR lpKeyName, LPCWSTR lpString, LPCWSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileSectionA (LPCSTR lpAppName, LPSTR lpReturnedString, DWORD nSize, LPCSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileSectionW (LPCWSTR lpAppName, LPWSTR lpReturnedString, DWORD nSize, LPCWSTR lpFileName);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileSectionA (LPCSTR lpAppName, LPCSTR lpString, LPCSTR lpFileName);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileSectionW (LPCWSTR lpAppName, LPCWSTR lpString, LPCWSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileSectionNamesA (LPSTR lpszReturnBuffer, DWORD nSize, LPCSTR lpFileName);
  WINBASEAPI DWORD WINAPI GetPrivateProfileSectionNamesW (LPWSTR lpszReturnBuffer, DWORD nSize, LPCWSTR lpFileName);
  WINBASEAPI WINBOOL WINAPI GetPrivateProfileStructA (LPCSTR lpszSection, LPCSTR lpszKey, LPVOID lpStruct, UINT uSizeStruct, LPCSTR szFile);
  WINBASEAPI WINBOOL WINAPI GetPrivateProfileStructW (LPCWSTR lpszSection, LPCWSTR lpszKey, LPVOID lpStruct, UINT uSizeStruct, LPCWSTR szFile);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileStructA (LPCSTR lpszSection, LPCSTR lpszKey, LPVOID lpStruct, UINT uSizeStruct, LPCSTR szFile);
  WINBASEAPI WINBOOL WINAPI WritePrivateProfileStructW (LPCWSTR lpszSection, LPCWSTR lpszKey, LPVOID lpStruct, UINT uSizeStruct, LPCWSTR szFile);

#ifndef UNICODE
#define GetStartupInfo GetStartupInfoA
#define FindResourceEx FindResourceExA
#endif

#define FatalAppExit __MINGW_NAME_AW(FatalAppExit)
#define GetFirmwareEnvironmentVariable __MINGW_NAME_AW(GetFirmwareEnvironmentVariable)
#define SetFirmwareEnvironmentVariable __MINGW_NAME_AW(SetFirmwareEnvironmentVariable)
#define FindResource __MINGW_NAME_AW(FindResource)
#define EnumResourceTypes __MINGW_NAME_AW(EnumResourceTypes)
#define EnumResourceNames __MINGW_NAME_AW(EnumResourceNames)
#define EnumResourceLanguages __MINGW_NAME_AW(EnumResourceLanguages)
#define BeginUpdateResource __MINGW_NAME_AW(BeginUpdateResource)
#define UpdateResource __MINGW_NAME_AW(UpdateResource)
#define EndUpdateResource __MINGW_NAME_AW(EndUpdateResource)
#define GlobalAddAtom __MINGW_NAME_AW(GlobalAddAtom)
#define GlobalAddAtomEx __MINGW_NAME_AW(GlobalAddAtomEx)
#define GlobalFindAtom __MINGW_NAME_AW(GlobalFindAtom)
#define GlobalGetAtomName __MINGW_NAME_AW(GlobalGetAtomName)
#define AddAtom __MINGW_NAME_AW(AddAtom)
#define FindAtom __MINGW_NAME_AW(FindAtom)
#define GetAtomName __MINGW_NAME_AW(GetAtomName)
#define GetProfileInt __MINGW_NAME_AW(GetProfileInt)
#define GetProfileString __MINGW_NAME_AW(GetProfileString)
#define WriteProfileString __MINGW_NAME_AW(WriteProfileString)
#define GetProfileSection __MINGW_NAME_AW(GetProfileSection)
#define WriteProfileSection __MINGW_NAME_AW(WriteProfileSection)
#define GetPrivateProfileInt __MINGW_NAME_AW(GetPrivateProfileInt)
#define GetPrivateProfileString __MINGW_NAME_AW(GetPrivateProfileString)
#define WritePrivateProfileString __MINGW_NAME_AW(WritePrivateProfileString)
#define GetPrivateProfileSection __MINGW_NAME_AW(GetPrivateProfileSection)
#define WritePrivateProfileSection __MINGW_NAME_AW(WritePrivateProfileSection)
#define GetPrivateProfileSectionNames __MINGW_NAME_AW(GetPrivateProfileSectionNames)
#define GetPrivateProfileStruct __MINGW_NAME_AW(GetPrivateProfileStruct)
#define WritePrivateProfileStruct __MINGW_NAME_AW(WritePrivateProfileStruct)

#if _WIN32_WINNT >= 0x0602
#define GetFirmwareEnvironmentVariableEx __MINGW_NAME_AW(GetFirmwareEnvironmentVariableEx)
#define SetFirmwareEnvironmentVariableEx __MINGW_NAME_AW(SetFirmwareEnvironmentVariableEx)
#endif

#ifndef RC_INVOKED
  WINBASEAPI UINT WINAPI GetSystemWow64DirectoryA (LPSTR lpBuffer, UINT uSize);
  WINBASEAPI UINT WINAPI GetSystemWow64DirectoryW (LPWSTR lpBuffer, UINT uSize);

#define GetSystemWow64Directory __MINGW_NAME_AW(GetSystemWow64Directory)

  WINBASEAPI BOOLEAN WINAPI Wow64EnableWow64FsRedirection (BOOLEAN Wow64FsEnableRedirection);

  typedef UINT (WINAPI *PGET_SYSTEM_WOW64_DIRECTORY_A) (LPSTR lpBuffer, UINT uSize);
  typedef UINT (WINAPI *PGET_SYSTEM_WOW64_DIRECTORY_W) (LPWSTR lpBuffer, UINT uSize);

#define GET_SYSTEM_WOW64_DIRECTORY_NAME_A_A "GetSystemWow64DirectoryA"
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_A_W L"GetSystemWow64DirectoryA"
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_A_T TEXT ("GetSystemWow64DirectoryA")
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_W_A "GetSystemWow64DirectoryW"
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_W_W L"GetSystemWow64DirectoryW"
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_W_T TEXT ("GetSystemWow64DirectoryW")

#define GET_SYSTEM_WOW64_DIRECTORY_NAME_T_A __MINGW_NAME_UAW_EXT(GET_SYSTEM_WOW64_DIRECTORY_NAME,A)
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_T_W __MINGW_NAME_UAW_EXT(GET_SYSTEM_WOW64_DIRECTORY_NAME,W)
#define GET_SYSTEM_WOW64_DIRECTORY_NAME_T_T __MINGW_NAME_UAW_EXT(GET_SYSTEM_WOW64_DIRECTORY_NAME,T)
#endif

  WINBASEAPI WINBOOL WINAPI SetDllDirectoryA (LPCSTR lpPathName);
  WINBASEAPI WINBOOL WINAPI SetDllDirectoryW (LPCWSTR lpPathName);
  WINBASEAPI DWORD WINAPI GetDllDirectoryA (DWORD nBufferLength, LPSTR lpBuffer);
  WINBASEAPI DWORD WINAPI GetDllDirectoryW (DWORD nBufferLength, LPWSTR lpBuffer);

#define SetDllDirectory __MINGW_NAME_AW(SetDllDirectory)
#define GetDllDirectory __MINGW_NAME_AW(GetDllDirectory)

#define BASE_SEARCH_PATH_ENABLE_SAFE_SEARCHMODE 0x1
#define BASE_SEARCH_PATH_DISABLE_SAFE_SEARCHMODE 0x10000
#define BASE_SEARCH_PATH_PERMANENT 0x8000
#define BASE_SEARCH_PATH_INVALID_FLAGS ~0x18001

  WINBASEAPI WINBOOL WINAPI SetSearchPathMode (DWORD Flags);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI DWORD WINAPI GetFirmwareEnvironmentVariableA (LPCSTR lpName, LPCSTR lpGuid, PVOID pBuffer, DWORD nSize);
  WINBASEAPI DWORD WINAPI GetFirmwareEnvironmentVariableW (LPCWSTR lpName, LPCWSTR lpGuid, PVOID pBuffer, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI SetFirmwareEnvironmentVariableA (LPCSTR lpName, LPCSTR lpGuid, PVOID pValue, DWORD nSize);
  WINBASEAPI WINBOOL WINAPI SetFirmwareEnvironmentVariableW (LPCWSTR lpName, LPCWSTR lpGuid, PVOID pValue, DWORD nSize);
#if _WIN32_WINNT >= 0x0602
  WINBASEAPI DWORD WINAPI GetFirmwareEnvironmentVariableExA (LPCSTR lpName, LPCSTR lpGuid, PVOID pBuffer, DWORD nSize, PDWORD pdwAttribubutes);
  WINBASEAPI DWORD WINAPI GetFirmwareEnvironmentVariableExW (LPCWSTR lpName, LPCWSTR lpGuid, PVOID pBuffer, DWORD nSize, PDWORD pdwAttribubutes);
  WINBASEAPI WINBOOL WINAPI SetFirmwareEnvironmentVariableExA (LPCSTR lpName, LPCSTR lpGuid, PVOID pValue, DWORD nSize, DWORD dwAttributes);
  WINBASEAPI WINBOOL WINAPI SetFirmwareEnvironmentVariableExW (LPCWSTR lpName, LPCWSTR lpGuid, PVOID pValue, DWORD nSize, DWORD dwAttributes);
#endif
#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) */


#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI CreateDirectoryExA (LPCSTR lpTemplateDirectory, LPCSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINBASEAPI WINBOOL WINAPI CreateDirectoryExW (LPCWSTR lpTemplateDirectory, LPCWSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes);

#define CreateDirectoryEx __MINGW_NAME_AW(CreateDirectoryEx)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI CreateDirectoryTransactedA (LPCSTR lpTemplateDirectory, LPCSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI CreateDirectoryTransactedW (LPCWSTR lpTemplateDirectory, LPCWSTR lpNewDirectory, LPSECURITY_ATTRIBUTES lpSecurityAttributes, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI RemoveDirectoryTransactedA (LPCSTR lpPathName, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI RemoveDirectoryTransactedW (LPCWSTR lpPathName, HANDLE hTransaction);
  WINBASEAPI DWORD WINAPI GetFullPathNameTransactedA (LPCSTR lpFileName, DWORD nBufferLength, LPSTR lpBuffer, LPSTR *lpFilePart, HANDLE hTransaction);
  WINBASEAPI DWORD WINAPI GetFullPathNameTransactedW (LPCWSTR lpFileName, DWORD nBufferLength, LPWSTR lpBuffer, LPWSTR *lpFilePart, HANDLE hTransaction);

#define CreateDirectoryTransacted __MINGW_NAME_AW(CreateDirectoryTransacted)
#define RemoveDirectoryTransacted __MINGW_NAME_AW(RemoveDirectoryTransacted)
#define GetFullPathNameTransacted __MINGW_NAME_AW(GetFullPathNameTransacted)

#endif

#define DDD_RAW_TARGET_PATH 0x00000001
#define DDD_REMOVE_DEFINITION 0x00000002
#define DDD_EXACT_MATCH_ON_REMOVE 0x00000004
#define DDD_NO_BROADCAST_SYSTEM 0x00000008
#define DDD_LUID_BROADCAST_DRIVE 0x00000010

  WINBASEAPI WINBOOL WINAPI DefineDosDeviceA (DWORD dwFlags, LPCSTR lpDeviceName, LPCSTR lpTargetPath);
  WINBASEAPI DWORD WINAPI QueryDosDeviceA (LPCSTR lpDeviceName, LPSTR lpTargetPath, DWORD ucchMax);

#ifndef UNICODE
#define DefineDosDevice DefineDosDeviceA
#define QueryDosDevice QueryDosDeviceA
#endif

#define EXPAND_LOCAL_DRIVES

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI CreateFileTransactedA (LPCSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile, HANDLE hTransaction, PUSHORT pusMiniVersion, PVOID lpExtendedParameter);
  WINBASEAPI HANDLE WINAPI CreateFileTransactedW (LPCWSTR lpFileName, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwCreationDisposition, DWORD dwFlagsAndAttributes, HANDLE hTemplateFile, HANDLE hTransaction, PUSHORT pusMiniVersion, PVOID lpExtendedParameter);

#define CreateFileTransacted __MINGW_NAME_AW(CreateFileTransacted)
#endif

  WINBASEAPI HANDLE WINAPI ReOpenFile (HANDLE hOriginalFile, DWORD dwDesiredAccess, DWORD dwShareMode, DWORD dwFlagsAndAttributes);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI SetFileAttributesTransactedA (LPCSTR lpFileName, DWORD dwFileAttributes, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI SetFileAttributesTransactedW (LPCWSTR lpFileName, DWORD dwFileAttributes, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI GetFileAttributesTransactedA (LPCSTR lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, LPVOID lpFileInformation, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI GetFileAttributesTransactedW (LPCWSTR lpFileName, GET_FILEEX_INFO_LEVELS fInfoLevelId, LPVOID lpFileInformation, HANDLE hTransaction);

#define SetFileAttributesTransacted __MINGW_NAME_AW(SetFileAttributesTransacted)
#define GetFileAttributesTransacted __MINGW_NAME_AW(GetFileAttributesTransacted)

#endif

  WINBASEAPI DWORD WINAPI GetCompressedFileSizeA (LPCSTR lpFileName, LPDWORD lpFileSizeHigh);
  WINBASEAPI DWORD WINAPI GetCompressedFileSizeW (LPCWSTR lpFileName, LPDWORD lpFileSizeHigh);

#define GetCompressedFileSize __MINGW_NAME_AW(GetCompressedFileSize)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI DWORD WINAPI GetCompressedFileSizeTransactedA (LPCSTR lpFileName, LPDWORD lpFileSizeHigh, HANDLE hTransaction);
  WINBASEAPI DWORD WINAPI GetCompressedFileSizeTransactedW (LPCWSTR lpFileName, LPDWORD lpFileSizeHigh, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI DeleteFileTransactedA (LPCSTR lpFileName, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI DeleteFileTransactedW (LPCWSTR lpFileName, HANDLE hTransaction);

#define DeleteFileTransacted __MINGW_NAME_AW(DeleteFileTransacted)
#define GetCompressedFileSizeTransacted __MINGW_NAME_AW(GetCompressedFileSizeTransacted)

#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  typedef DWORD (WINAPI *LPPROGRESS_ROUTINE) (LARGE_INTEGER TotalFileSize, LARGE_INTEGER TotalBytesTransferred, LARGE_INTEGER StreamSize, LARGE_INTEGER StreamBytesTransferred, DWORD dwStreamNumber, DWORD dwCallbackReason, HANDLE hSourceFile, HANDLE hDestinationFile, LPVOID lpData);

  WINBASEAPI WINBOOL WINAPI CopyFileExA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags);
  WINBASEAPI WINBOOL WINAPI CopyFileExW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags);

#define CopyFileEx __MINGW_NAME_AW(CopyFileEx)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI CheckNameLegalDOS8Dot3A (LPCSTR lpName, LPSTR lpOemName, DWORD OemNameSize, PBOOL pbNameContainsSpaces, PBOOL pbNameLegal);
  WINBASEAPI WINBOOL WINAPI CheckNameLegalDOS8Dot3W (LPCWSTR lpName, LPSTR lpOemName, DWORD OemNameSize, PBOOL pbNameContainsSpaces, PBOOL pbNameLegal);

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI FindFirstFileTransactedA (LPCSTR lpFileName, FINDEX_INFO_LEVELS fInfoLevelId, LPVOID lpFindFileData, FINDEX_SEARCH_OPS fSearchOp, LPVOID lpSearchFilter, DWORD dwAdditionalFlags, HANDLE hTransaction);
  WINBASEAPI HANDLE WINAPI FindFirstFileTransactedW (LPCWSTR lpFileName, FINDEX_INFO_LEVELS fInfoLevelId, LPVOID lpFindFileData, FINDEX_SEARCH_OPS fSearchOp, LPVOID lpSearchFilter, DWORD dwAdditionalFlags, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI CopyFileTransactedA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI CopyFileTransactedW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, LPBOOL pbCancel, DWORD dwCopyFlags, HANDLE hTransaction);

#define FindFirstFileTransacted __MINGW_NAME_AW(FindFirstFileTransacted)
#define CopyFileTransacted __MINGW_NAME_AW(CopyFileTransacted)
#endif

#define CheckNameLegalDOS8Dot3 __MINGW_NAME_AW(CheckNameLegalDOS8Dot3)
#define CopyFile __MINGW_NAME_AW(CopyFile)

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI CopyFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, WINBOOL bFailIfExists);
  WINBASEAPI WINBOOL WINAPI CopyFileW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, WINBOOL bFailIfExists);
#if _WIN32_WINNT >= 0x0601
  typedef enum _COPYFILE2_MESSAGE_TYPE {
    COPYFILE2_CALLBACK_NONE = 0,
    COPYFILE2_CALLBACK_CHUNK_STARTED,
    COPYFILE2_CALLBACK_CHUNK_FINISHED,
    COPYFILE2_CALLBACK_STREAM_STARTED,
    COPYFILE2_CALLBACK_STREAM_FINISHED,
    COPYFILE2_CALLBACK_POLL_CONTINUE,
    COPYFILE2_CALLBACK_ERROR,
    COPYFILE2_CALLBACK_MAX,
  } COPYFILE2_MESSAGE_TYPE;

  typedef enum _COPYFILE2_MESSAGE_ACTION {
    COPYFILE2_PROGRESS_CONTINUE = 0,
    COPYFILE2_PROGRESS_CANCEL,
    COPYFILE2_PROGRESS_STOP,
    COPYFILE2_PROGRESS_QUIET,
    COPYFILE2_PROGRESS_PAUSE,
  } COPYFILE2_MESSAGE_ACTION;

  typedef enum _COPYFILE2_COPY_PHASE {
    COPYFILE2_PHASE_NONE = 0,
    COPYFILE2_PHASE_PREPARE_SOURCE,
    COPYFILE2_PHASE_PREPARE_DEST,
    COPYFILE2_PHASE_READ_SOURCE,
    COPYFILE2_PHASE_WRITE_DESTINATION,
    COPYFILE2_PHASE_SERVER_COPY,
    COPYFILE2_PHASE_NAMEGRAFT_COPY,
    COPYFILE2_PHASE_MAX,
  } COPYFILE2_COPY_PHASE;

#define COPYFILE2_MESSAGE_COPY_OFFLOAD (__MSABI_LONG (0x00000001))

  typedef struct COPYFILE2_MESSAGE {
    COPYFILE2_MESSAGE_TYPE Type;
    DWORD dwPadding;
    union {
      struct {
    DWORD dwStreamNumber;
    DWORD dwReserved;
    HANDLE hSourceFile;
    HANDLE hDestinationFile;
    ULARGE_INTEGER uliChunkNumber;
    ULARGE_INTEGER uliChunkSize;
    ULARGE_INTEGER uliStreamSize;
    ULARGE_INTEGER uliTotalFileSize;
      } ChunkStarted;
      struct {
    DWORD dwStreamNumber;
    DWORD dwFlags;
    HANDLE hSourceFile;
    HANDLE hDestinationFile;
    ULARGE_INTEGER uliChunkNumber;
    ULARGE_INTEGER uliChunkSize;
    ULARGE_INTEGER uliStreamSize;
    ULARGE_INTEGER uliStreamBytesTransferred;
    ULARGE_INTEGER uliTotalFileSize;
    ULARGE_INTEGER uliTotalBytesTransferred;
      } ChunkFinished;
      struct {
    DWORD dwStreamNumber;
    DWORD dwReserved;
    HANDLE hSourceFile;
    HANDLE hDestinationFile;
    ULARGE_INTEGER uliStreamSize;
    ULARGE_INTEGER uliTotalFileSize;
      } StreamStarted;
      struct {
    DWORD dwStreamNumber;
    DWORD dwReserved;
    HANDLE hSourceFile;
    HANDLE hDestinationFile;
    ULARGE_INTEGER uliStreamSize;
    ULARGE_INTEGER uliStreamBytesTransferred;
    ULARGE_INTEGER uliTotalFileSize;
    ULARGE_INTEGER uliTotalBytesTransferred;
      } StreamFinished;
      struct {
    DWORD dwReserved;
      } PollContinue;
      struct {
    COPYFILE2_COPY_PHASE CopyPhase;
    DWORD dwStreamNumber;
    HRESULT hrFailure;
    DWORD dwReserved;
    ULARGE_INTEGER uliChunkNumber;
    ULARGE_INTEGER uliStreamSize;
    ULARGE_INTEGER uliStreamBytesTransferred;
    ULARGE_INTEGER uliTotalFileSize;
    ULARGE_INTEGER uliTotalBytesTransferred;
      } Error;
    } Info;
  } COPYFILE2_MESSAGE;

  typedef COPYFILE2_MESSAGE_ACTION (CALLBACK *PCOPYFILE2_PROGRESS_ROUTINE) (const COPYFILE2_MESSAGE *pMessage, PVOID pvCallbackContext);

  typedef struct COPYFILE2_EXTENDED_PARAMETERS {
    DWORD dwSize;
    DWORD dwCopyFlags;
    WINBOOL *pfCancel;
    PCOPYFILE2_PROGRESS_ROUTINE pProgressRoutine;
    PVOID pvCallbackContext;
  } COPYFILE2_EXTENDED_PARAMETERS;

  WINBASEAPI HRESULT WINAPI CopyFile2 (PCWSTR pwszExistingFileName, PCWSTR pwszNewFileName, COPYFILE2_EXTENDED_PARAMETERS *pExtendedParameters);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI MoveFileA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName);
  WINBASEAPI WINBOOL WINAPI MoveFileW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName);

#define MoveFile __MINGW_NAME_AW(MoveFile)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI MoveFileExA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI MoveFileExW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, DWORD dwFlags);

#define MoveFileEx __MINGW_NAME_AW(MoveFileEx)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI MoveFileWithProgressA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags);
  WINBASEAPI WINBOOL WINAPI MoveFileWithProgressW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags);

#define MoveFileWithProgress __MINGW_NAME_AW(MoveFileWithProgress)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI MoveFileTransactedA (LPCSTR lpExistingFileName, LPCSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI MoveFileTransactedW (LPCWSTR lpExistingFileName, LPCWSTR lpNewFileName, LPPROGRESS_ROUTINE lpProgressRoutine, LPVOID lpData, DWORD dwFlags, HANDLE hTransaction);

#define MoveFileTransacted __MINGW_NAME_AW(MoveFileTransacted)
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
#define MOVEFILE_REPLACE_EXISTING 0x00000001
#define MOVEFILE_COPY_ALLOWED 0x00000002
#define MOVEFILE_DELAY_UNTIL_REBOOT 0x00000004
#define MOVEFILE_WRITE_THROUGH 0x00000008
#define MOVEFILE_CREATE_HARDLINK 0x00000010
#define MOVEFILE_FAIL_IF_NOT_TRACKABLE 0x00000020
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI GetNamedPipeClientComputerNameA (HANDLE Pipe, LPSTR ClientComputerName, ULONG ClientComputerNameLength);
  WINBASEAPI WINBOOL WINAPI WaitNamedPipeA (LPCSTR lpNamedPipeName, DWORD nTimeOut);
  WINBASEAPI WINBOOL WINAPI CallNamedPipeA (LPCSTR lpNamedPipeName, LPVOID lpInBuffer, DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize, LPDWORD lpBytesRead, DWORD nTimeOut);
  WINBASEAPI WINBOOL WINAPI CallNamedPipeW (LPCWSTR lpNamedPipeName, LPVOID lpInBuffer, DWORD nInBufferSize, LPVOID lpOutBuffer, DWORD nOutBufferSize, LPDWORD lpBytesRead, DWORD nTimeOut);
  WINBASEAPI HANDLE WINAPI CreateNamedPipeA (LPCSTR lpName, DWORD dwOpenMode, DWORD dwPipeMode, DWORD nMaxInstances, DWORD nOutBufferSize, DWORD nInBufferSize, DWORD nDefaultTimeOut, LPSECURITY_ATTRIBUTES lpSecurityAttributes);

#ifndef UNICODE
#define WaitNamedPipe WaitNamedPipeA
#define CreateNamedPipe CreateNamedPipeA
#endif

#define CallNamedPipe __MINGW_NAME_AW(CallNamedPipe)

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI GetNamedPipeHandleStateA (HANDLE hNamedPipe, LPDWORD lpState, LPDWORD lpCurInstances, LPDWORD lpMaxCollectionCount, LPDWORD lpCollectDataTimeout, LPSTR lpUserName, DWORD nMaxUserNameSize);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeHandleStateW (HANDLE hNamedPipe, LPDWORD lpState, LPDWORD lpCurInstances, LPDWORD lpMaxCollectionCount, LPDWORD lpCollectDataTimeout, LPWSTR lpUserName, DWORD nMaxUserNameSize);
  WINBASEAPI WINBOOL WINAPI ReplaceFileA (LPCSTR lpReplacedFileName, LPCSTR lpReplacementFileName, LPCSTR lpBackupFileName, DWORD dwReplaceFlags, LPVOID lpExclude, LPVOID lpReserved);
  WINBASEAPI WINBOOL WINAPI ReplaceFileW (LPCWSTR lpReplacedFileName, LPCWSTR lpReplacementFileName, LPCWSTR lpBackupFileName, DWORD dwReplaceFlags, LPVOID lpExclude, LPVOID lpReserved);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI CreateHardLinkA (LPCSTR lpFileName, LPCSTR lpExistingFileName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);
  WINBASEAPI WINBOOL WINAPI CreateHardLinkW (LPCWSTR lpFileName, LPCWSTR lpExistingFileName, LPSECURITY_ATTRIBUTES lpSecurityAttributes);

#define ReplaceFile __MINGW_NAME_AW(ReplaceFile)
#define CreateHardLink __MINGW_NAME_AW(CreateHardLink)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI CreateHardLinkTransactedA (LPCSTR lpFileName, LPCSTR lpExistingFileName, LPSECURITY_ATTRIBUTES lpSecurityAttributes, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI CreateHardLinkTransactedW (LPCWSTR lpFileName, LPCWSTR lpExistingFileName, LPSECURITY_ATTRIBUTES lpSecurityAttributes, HANDLE hTransaction);

#define CreateHardLinkTransacted __MINGW_NAME_AW(CreateHardLinkTransacted)
#endif

  typedef enum _STREAM_INFO_LEVELS {
    FindStreamInfoStandard,
    FindStreamInfoMaxInfoLevel
  } STREAM_INFO_LEVELS;

  typedef struct _WIN32_FIND_STREAM_DATA {
    LARGE_INTEGER StreamSize;
    WCHAR cStreamName[MAX_PATH + 36];
  } WIN32_FIND_STREAM_DATA,*PWIN32_FIND_STREAM_DATA;

  WINBASEAPI HANDLE WINAPI FindFirstStreamW (LPCWSTR lpFileName, STREAM_INFO_LEVELS InfoLevel, LPVOID lpFindStreamData, DWORD dwFlags);
  WINBASEAPI WINBOOL APIENTRY FindNextStreamW (HANDLE hFindStream, LPVOID lpFindStreamData);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HANDLE WINAPI FindFirstStreamTransactedW (LPCWSTR lpFileName, STREAM_INFO_LEVELS InfoLevel, LPVOID lpFindStreamData, DWORD dwFlags, HANDLE hTransaction);
  WINBASEAPI HANDLE WINAPI FindFirstFileNameW (LPCWSTR lpFileName, DWORD dwFlags, LPDWORD StringLength, PWSTR LinkName);
  WINBASEAPI WINBOOL APIENTRY FindNextFileNameW (HANDLE hFindStream, LPDWORD StringLength, PWSTR LinkName);
  WINBASEAPI HANDLE WINAPI FindFirstFileNameTransactedW (LPCWSTR lpFileName, DWORD dwFlags, LPDWORD StringLength, PWSTR LinkName, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeClientProcessId (HANDLE Pipe, PULONG ClientProcessId);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeClientSessionId (HANDLE Pipe, PULONG ClientSessionId);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeServerProcessId (HANDLE Pipe, PULONG ServerProcessId);
  WINBASEAPI WINBOOL WINAPI GetNamedPipeServerSessionId (HANDLE Pipe, PULONG ServerSessionId);
  WINBASEAPI WINBOOL WINAPI SetFileBandwidthReservation (HANDLE hFile, DWORD nPeriodMilliseconds, DWORD nBytesPerPeriod, WINBOOL bDiscardable, LPDWORD lpTransferSize, LPDWORD lpNumOutstandingRequests);
  WINBASEAPI WINBOOL WINAPI GetFileBandwidthReservation (HANDLE hFile, LPDWORD lpPeriodMilliseconds, LPDWORD lpBytesPerPeriod, LPBOOL pDiscardable, LPDWORD lpTransferSize, LPDWORD lpNumOutstandingRequests);
#endif
  WINBASEAPI VOID WINAPI SetFileApisToOEM (VOID);
  WINBASEAPI VOID WINAPI SetFileApisToANSI (VOID);
  WINBASEAPI WINBOOL WINAPI AreFileApisANSI (VOID);
  WINADVAPI WINBOOL WINAPI ClearEventLogA (HANDLE hEventLog, LPCSTR lpBackupFileName);
  WINADVAPI WINBOOL WINAPI ClearEventLogW (HANDLE hEventLog, LPCWSTR lpBackupFileName);
  WINADVAPI WINBOOL WINAPI BackupEventLogA (HANDLE hEventLog, LPCSTR lpBackupFileName);
  WINADVAPI WINBOOL WINAPI BackupEventLogW (HANDLE hEventLog, LPCWSTR lpBackupFileName);
  WINADVAPI WINBOOL WINAPI CloseEventLog (HANDLE hEventLog);
  WINADVAPI WINBOOL WINAPI DeregisterEventSource (HANDLE hEventLog);
  WINADVAPI WINBOOL WINAPI NotifyChangeEventLog (HANDLE hEventLog, HANDLE hEvent);
  WINADVAPI WINBOOL WINAPI GetNumberOfEventLogRecords (HANDLE hEventLog, PDWORD NumberOfRecords);
  WINADVAPI WINBOOL WINAPI GetOldestEventLogRecord (HANDLE hEventLog, PDWORD OldestRecord);
  WINADVAPI HANDLE WINAPI OpenEventLogA (LPCSTR lpUNCServerName, LPCSTR lpSourceName);
  WINADVAPI HANDLE WINAPI OpenEventLogW (LPCWSTR lpUNCServerName, LPCWSTR lpSourceName);
  WINADVAPI HANDLE WINAPI RegisterEventSourceA (LPCSTR lpUNCServerName, LPCSTR lpSourceName);
  WINADVAPI HANDLE WINAPI RegisterEventSourceW (LPCWSTR lpUNCServerName, LPCWSTR lpSourceName);
  WINADVAPI HANDLE WINAPI OpenBackupEventLogA (LPCSTR lpUNCServerName, LPCSTR lpFileName);
  WINADVAPI HANDLE WINAPI OpenBackupEventLogW (LPCWSTR lpUNCServerName, LPCWSTR lpFileName);
  WINADVAPI WINBOOL WINAPI ReadEventLogA (HANDLE hEventLog, DWORD dwReadFlags, DWORD dwRecordOffset, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, DWORD *pnBytesRead, DWORD *pnMinNumberOfBytesNeeded);
  WINADVAPI WINBOOL WINAPI ReadEventLogW (HANDLE hEventLog, DWORD dwReadFlags, DWORD dwRecordOffset, LPVOID lpBuffer, DWORD nNumberOfBytesToRead, DWORD *pnBytesRead, DWORD *pnMinNumberOfBytesNeeded);
  WINADVAPI WINBOOL WINAPI ReportEventA (HANDLE hEventLog, WORD wType, WORD wCategory, DWORD dwEventID, PSID lpUserSid, WORD wNumStrings, DWORD dwDataSize, LPCSTR *lpStrings, LPVOID lpRawData);
  WINADVAPI WINBOOL WINAPI ReportEventW (HANDLE hEventLog, WORD wType, WORD wCategory, DWORD dwEventID, PSID lpUserSid, WORD wNumStrings, DWORD dwDataSize, LPCWSTR *lpStrings, LPVOID lpRawData);

#ifndef UNICODE
#define GetVolumeInformation GetVolumeInformationA
#endif

#define GetNamedPipeHandleState __MINGW_NAME_AW(GetNamedPipeHandleState)
#define ClearEventLog __MINGW_NAME_AW(ClearEventLog)
#define BackupEventLog __MINGW_NAME_AW(BackupEventLog)
#define OpenEventLog __MINGW_NAME_AW(OpenEventLog)
#define RegisterEventSource __MINGW_NAME_AW(RegisterEventSource)
#define OpenBackupEventLog __MINGW_NAME_AW(OpenBackupEventLog)
#define ReadEventLog __MINGW_NAME_AW(ReadEventLog)
#define ReportEvent __MINGW_NAME_AW(ReportEvent)

#if _WIN32_WINNT >= 0x0600 && !defined (UNICODE)
#define GetNamedPipeClientComputerName GetNamedPipeClientComputerNameA
#endif

#define EVENTLOG_FULL_INFO 0

  typedef struct _EVENTLOG_FULL_INFORMATION {
    DWORD dwFull;
  } EVENTLOG_FULL_INFORMATION,*LPEVENTLOG_FULL_INFORMATION;

  WINADVAPI WINBOOL WINAPI GetEventLogInformation (HANDLE hEventLog, DWORD dwInfoLevel, LPVOID lpBuffer, DWORD cbBufSize, LPDWORD pcbBytesNeeded);

#if _WIN32_WINNT >= 0x0602

#define OPERATION_API_VERSION 1

  typedef ULONG OPERATION_ID;

  typedef struct _OPERATION_START_PARAMETERS {
    ULONG Version;
    OPERATION_ID OperationId;
    ULONG Flags;
  } OPERATION_START_PARAMETERS,*POPERATION_START_PARAMETERS;

#define OPERATION_START_TRACE_CURRENT_THREAD 0x1

  typedef struct _OPERATION_END_PARAMETERS {
    ULONG Version;
    OPERATION_ID OperationId;
    ULONG Flags;
  } OPERATION_END_PARAMETERS,*POPERATION_END_PARAMETERS;

#define OPERATION_END_DISCARD 0x1

  WINADVAPI WINBOOL WINAPI OperationStart (OPERATION_START_PARAMETERS *OperationStartParams);
  WINADVAPI WINBOOL WINAPI OperationEnd (OPERATION_END_PARAMETERS *OperationEndParams);
#endif

#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI GetVolumeInformationA (LPCSTR lpRootPathName, LPSTR lpVolumeNameBuffer, DWORD nVolumeNameSize, LPDWORD lpVolumeSerialNumber, LPDWORD lpMaximumComponentLength, LPDWORD lpFileSystemFlags, LPSTR lpFileSystemNameBuffer, DWORD nFileSystemNameSize);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || _WIN32_WINNT >= _WIN32_WINNT_WIN10
  WINBASEAPI WINBOOL WINAPI ReadDirectoryChangesW (HANDLE hDirectory, LPVOID lpBuffer, DWORD nBufferLength, WINBOOL bWatchSubtree, DWORD dwNotifyFilter, LPDWORD lpBytesReturned, LPOVERLAPPED lpOverlapped, LPOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)

  WINADVAPI WINBOOL WINAPI AccessCheckAndAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, LPSTR ObjectTypeName, LPSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, DWORD DesiredAccess, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPBOOL AccessStatus, LPBOOL pfGenerateOnClose);
  WINADVAPI WINBOOL WINAPI AccessCheckByTypeAndAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, LPCSTR ObjectTypeName, LPCSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPBOOL AccessStatus, LPBOOL pfGenerateOnClose);
  WINADVAPI WINBOOL WINAPI AccessCheckByTypeResultListAndAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, LPCSTR ObjectTypeName, LPCSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPDWORD AccessStatusList, LPBOOL pfGenerateOnClose);
  WINADVAPI WINBOOL WINAPI AccessCheckByTypeResultListAndAuditAlarmByHandleA (LPCSTR SubsystemName, LPVOID HandleId, HANDLE ClientToken, LPCSTR ObjectTypeName, LPCSTR ObjectName, PSECURITY_DESCRIPTOR SecurityDescriptor, PSID PrincipalSelfSid, DWORD DesiredAccess, AUDIT_EVENT_TYPE AuditType, DWORD Flags, POBJECT_TYPE_LIST ObjectTypeList, DWORD ObjectTypeListLength, PGENERIC_MAPPING GenericMapping, WINBOOL ObjectCreation, LPDWORD GrantedAccess, LPDWORD AccessStatusList, LPBOOL pfGenerateOnClose);
  WINADVAPI WINBOOL WINAPI ObjectOpenAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, LPSTR ObjectTypeName, LPSTR ObjectName, PSECURITY_DESCRIPTOR pSecurityDescriptor, HANDLE ClientToken, DWORD DesiredAccess, DWORD GrantedAccess, PPRIVILEGE_SET Privileges, WINBOOL ObjectCreation, WINBOOL AccessGranted, LPBOOL GenerateOnClose);
  WINADVAPI WINBOOL WINAPI ObjectPrivilegeAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, HANDLE ClientToken, DWORD DesiredAccess, PPRIVILEGE_SET Privileges, WINBOOL AccessGranted);
  WINADVAPI WINBOOL WINAPI ObjectCloseAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, WINBOOL GenerateOnClose);
  WINADVAPI WINBOOL WINAPI ObjectDeleteAuditAlarmA (LPCSTR SubsystemName, LPVOID HandleId, WINBOOL GenerateOnClose);
  WINADVAPI WINBOOL WINAPI PrivilegedServiceAuditAlarmA (LPCSTR SubsystemName, LPCSTR ServiceName, HANDLE ClientToken, PPRIVILEGE_SET Privileges, WINBOOL AccessGranted);
  WINADVAPI WINBOOL WINAPI SetFileSecurityA (LPCSTR lpFileName, SECURITY_INFORMATION SecurityInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor);
  WINADVAPI WINBOOL WINAPI GetFileSecurityA (LPCSTR lpFileName, SECURITY_INFORMATION RequestedInformation, PSECURITY_DESCRIPTOR pSecurityDescriptor, DWORD nLength, LPDWORD lpnLengthNeeded);
  WINBASEAPI WINBOOL WINAPI IsBadReadPtr (CONST VOID *lp, UINT_PTR ucb);
  WINBASEAPI WINBOOL WINAPI IsBadWritePtr (LPVOID lp, UINT_PTR ucb);
  WINBASEAPI WINBOOL WINAPI IsBadHugeReadPtr (CONST VOID *lp, UINT_PTR ucb);
  WINBASEAPI WINBOOL WINAPI IsBadHugeWritePtr (LPVOID lp, UINT_PTR ucb);
  WINBASEAPI WINBOOL WINAPI IsBadCodePtr (FARPROC lpfn);
  WINBASEAPI WINBOOL WINAPI IsBadStringPtrA (LPCSTR lpsz, UINT_PTR ucchMax);
  WINBASEAPI WINBOOL WINAPI IsBadStringPtrW (LPCWSTR lpsz, UINT_PTR ucchMax);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI LPVOID WINAPI MapViewOfFileExNuma (HANDLE hFileMappingObject, DWORD dwDesiredAccess, DWORD dwFileOffsetHigh, DWORD dwFileOffsetLow, SIZE_T dwNumberOfBytesToMap, LPVOID lpBaseAddress, DWORD nndPreferred);
#endif
#if _WIN32_WINNT >= 0x0601
  WINADVAPI WINBOOL WINAPI AddConditionalAce (PACL pAcl, DWORD dwAceRevision, DWORD AceFlags, UCHAR AceType, DWORD AccessMask, PSID pSid, PWCHAR ConditionStr, DWORD *ReturnLength);
#endif

#ifndef UNICODE
#define AccessCheckAndAuditAlarm AccessCheckAndAuditAlarmA
#define AccessCheckByTypeAndAuditAlarm AccessCheckByTypeAndAuditAlarmA
#define AccessCheckByTypeResultListAndAuditAlarm AccessCheckByTypeResultListAndAuditAlarmA
#define AccessCheckByTypeResultListAndAuditAlarmByHandle AccessCheckByTypeResultListAndAuditAlarmByHandleA
#define ObjectOpenAuditAlarm ObjectOpenAuditAlarmA
#define ObjectPrivilegeAuditAlarm ObjectPrivilegeAuditAlarmA
#define ObjectCloseAuditAlarm ObjectCloseAuditAlarmA
#define ObjectDeleteAuditAlarm ObjectDeleteAuditAlarmA
#define PrivilegedServiceAuditAlarm PrivilegedServiceAuditAlarmA
#define SetFileSecurity SetFileSecurityA
#define GetFileSecurity GetFileSecurityA
#endif

#define IsBadStringPtr __MINGW_NAME_AW(IsBadStringPtr)

#if _WIN32_WINNT >= 0x0601
  WINADVAPI WINBOOL WINAPI LookupAccountNameLocalA (LPCSTR lpAccountName, PSID Sid, LPDWORD cbSid, LPSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountNameLocalW (LPCWSTR lpAccountName, PSID Sid, LPDWORD cbSid, LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountSidLocalA (PSID Sid, LPSTR Name, LPDWORD cchName, LPSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountSidLocalW (PSID Sid, LPWSTR Name, LPDWORD cchName, LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);

#define LookupAccountNameLocal __MINGW_NAME_AW(LookupAccountNameLocal)
#define LookupAccountSidLocal __MINGW_NAME_AW(LookupAccountSidLocal)
#else

#define LookupAccountNameLocalA(n, s, cs, d, cd, u) LookupAccountNameA (NULL, n, s, cs, d, cd, u)
#define LookupAccountNameLocalW(n, s, cs, d, cd, u) LookupAccountNameW (NULL, n, s, cs, d, cd, u)
#define LookupAccountNameLocal(n, s, cs, d, cd, u) __MINGW_NAME_AW(LookupAccountName) (NULL, n, s, cs, d, cd, u)

#define LookupAccountSidLocalA(s, n, cn, d, cd, u) LookupAccountSidA (NULL, s, n, cn, d, cd, u)
#define LookupAccountSidLocalW(s, n, cn, d, cd, u) LookupAccountSidW (NULL, s, n, cn, d, cd, u)
#define LookupAccountSidLocal(s, n, cn, d, cd, u) __MINGW_NAME_AW(LookupAccountSid) (NULL, s, n, cn, d, cd, u)

#endif

  WINBASEAPI WINBOOL WINAPI BuildCommDCBA (LPCSTR lpDef, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI BuildCommDCBW (LPCWSTR lpDef, LPDCB lpDCB);
  WINBASEAPI WINBOOL WINAPI BuildCommDCBAndTimeoutsA (LPCSTR lpDef, LPDCB lpDCB, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI BuildCommDCBAndTimeoutsW (LPCWSTR lpDef, LPDCB lpDCB, LPCOMMTIMEOUTS lpCommTimeouts);
  WINBASEAPI WINBOOL WINAPI CommConfigDialogA (LPCSTR lpszName, HWND hWnd, LPCOMMCONFIG lpCC);
  WINBASEAPI WINBOOL WINAPI CommConfigDialogW (LPCWSTR lpszName, HWND hWnd, LPCOMMCONFIG lpCC);
  WINBASEAPI WINBOOL WINAPI GetDefaultCommConfigA (LPCSTR lpszName, LPCOMMCONFIG lpCC, LPDWORD lpdwSize);
  WINBASEAPI WINBOOL WINAPI GetDefaultCommConfigW (LPCWSTR lpszName, LPCOMMCONFIG lpCC, LPDWORD lpdwSize);
  WINBASEAPI WINBOOL WINAPI SetDefaultCommConfigA (LPCSTR lpszName, LPCOMMCONFIG lpCC, DWORD dwSize);
  WINBASEAPI WINBOOL WINAPI SetDefaultCommConfigW (LPCWSTR lpszName, LPCOMMCONFIG lpCC, DWORD dwSize);

#define BuildCommDCB __MINGW_NAME_AW(BuildCommDCB)
#define BuildCommDCBAndTimeouts __MINGW_NAME_AW(BuildCommDCBAndTimeouts)
#define CommConfigDialog __MINGW_NAME_AW(CommConfigDialog)
#define GetDefaultCommConfig __MINGW_NAME_AW(GetDefaultCommConfig)
#define SetDefaultCommConfig __MINGW_NAME_AW(SetDefaultCommConfig)

#define MAX_COMPUTERNAME_LENGTH 15

  WINBASEAPI WINBOOL WINAPI SetComputerNameA (LPCSTR lpComputerName);
  WINBASEAPI WINBOOL WINAPI SetComputerNameW (LPCWSTR lpComputerName);
  WINBASEAPI WINBOOL WINAPI SetComputerNameExA (COMPUTER_NAME_FORMAT NameType, LPCTSTR lpBuffer);
  WINBASEAPI WINBOOL WINAPI DnsHostnameToComputerNameA (LPCSTR Hostname, LPSTR ComputerName, LPDWORD nSize);
  WINBASEAPI WINBOOL WINAPI DnsHostnameToComputerNameW (LPCWSTR Hostname, LPWSTR ComputerName, LPDWORD nSize);

#ifndef UNICODE
#define SetComputerNameEx SetComputerNameExA
#endif

#define SetComputerName __MINGW_NAME_AW(SetComputerName)
#define DnsHostnameToComputerName __MINGW_NAME_AW(DnsHostnameToComputerName)

#define LOGON32_LOGON_INTERACTIVE 2
#define LOGON32_LOGON_NETWORK 3
#define LOGON32_LOGON_BATCH 4
#define LOGON32_LOGON_SERVICE 5
#define LOGON32_LOGON_UNLOCK 7
#define LOGON32_LOGON_NETWORK_CLEARTEXT 8
#define LOGON32_LOGON_NEW_CREDENTIALS 9

#define LOGON32_PROVIDER_DEFAULT 0
#define LOGON32_PROVIDER_WINNT35 1
#define LOGON32_PROVIDER_WINNT40 2
#define LOGON32_PROVIDER_WINNT50 3
#if _WIN32_WINNT >= 0x0600
#define LOGON32_PROVIDER_VIRTUAL 4
#endif

  WINADVAPI WINBOOL WINAPI LogonUserA (LPCSTR lpszUsername, LPCSTR lpszDomain, LPCSTR lpszPassword, DWORD dwLogonType, DWORD dwLogonProvider, PHANDLE phToken);
  WINADVAPI WINBOOL WINAPI LogonUserW (LPCWSTR lpszUsername, LPCWSTR lpszDomain, LPCWSTR lpszPassword, DWORD dwLogonType, DWORD dwLogonProvider, PHANDLE phToken);
  WINADVAPI WINBOOL WINAPI LogonUserExA (LPCSTR lpszUsername, LPCSTR lpszDomain, LPCSTR lpszPassword, DWORD dwLogonType, DWORD dwLogonProvider, PHANDLE phToken, PSID *ppLogonSid, PVOID *ppProfileBuffer, LPDWORD pdwProfileLength, PQUOTA_LIMITS pQuotaLimits);
  WINADVAPI WINBOOL WINAPI LogonUserExW (LPCWSTR lpszUsername, LPCWSTR lpszDomain, LPCWSTR lpszPassword, DWORD dwLogonType, DWORD dwLogonProvider, PHANDLE phToken, PSID *ppLogonSid, PVOID *ppProfileBuffer, LPDWORD pdwProfileLength, PQUOTA_LIMITS pQuotaLimits);
  WINADVAPI WINBOOL WINAPI CreateProcessAsUserA (HANDLE hToken, LPCSTR lpApplicationName, LPSTR lpCommandLine, LPSECURITY_ATTRIBUTES lpProcessAttributes, LPSECURITY_ATTRIBUTES lpThreadAttributes, WINBOOL bInheritHandles, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCSTR lpCurrentDirectory, LPSTARTUPINFOA lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);

#ifndef UNICODE
#define CreateProcessAsUser CreateProcessAsUserA
#endif

#define LogonUser __MINGW_NAME_AW(LogonUser)
#define LogonUserEx __MINGW_NAME_AW(LogonUserEx)

#define LOGON_WITH_PROFILE 0x00000001
#define LOGON_NETCREDENTIALS_ONLY 0x00000002
#define LOGON_ZERO_PASSWORD_BUFFER 0x80000000

  WINADVAPI WINBOOL WINAPI CreateProcessWithLogonW (LPCWSTR lpUsername, LPCWSTR lpDomain, LPCWSTR lpPassword, DWORD dwLogonFlags, LPCWSTR lpApplicationName, LPWSTR lpCommandLine, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
  WINADVAPI WINBOOL WINAPI CreateProcessWithTokenW (HANDLE hToken, DWORD dwLogonFlags, LPCWSTR lpApplicationName, LPWSTR lpCommandLine, DWORD dwCreationFlags, LPVOID lpEnvironment, LPCWSTR lpCurrentDirectory, LPSTARTUPINFOW lpStartupInfo, LPPROCESS_INFORMATION lpProcessInformation);
  WINADVAPI WINBOOL WINAPI IsTokenUntrusted (HANDLE TokenHandle);
  WINBASEAPI WINBOOL WINAPI RegisterWaitForSingleObject (PHANDLE phNewWaitObject, HANDLE hObject, WAITORTIMERCALLBACK Callback, PVOID Context, ULONG dwMilliseconds, ULONG dwFlags);
  WINBASEAPI WINBOOL WINAPI UnregisterWait (HANDLE WaitHandle);
  WINBASEAPI WINBOOL WINAPI BindIoCompletionCallback (HANDLE FileHandle, LPOVERLAPPED_COMPLETION_ROUTINE Function, ULONG Flags);
  WINBASEAPI HANDLE WINAPI SetTimerQueueTimer (HANDLE TimerQueue, WAITORTIMERCALLBACK Callback, PVOID Parameter, DWORD DueTime, DWORD Period, WINBOOL PreferIo);
  WINBASEAPI WINBOOL WINAPI CancelTimerQueueTimer (HANDLE TimerQueue, HANDLE Timer);
  WINBASEAPI WINBOOL WINAPI DeleteTimerQueue (HANDLE TimerQueue);

#ifndef __WIDL__
  /* Add Tp... API to winnt.h header and Threadpool-base-API. */

  WINBASEAPI WINBOOL WINAPI AddIntegrityLabelToBoundaryDescriptor (HANDLE *BoundaryDescriptor, PSID IntegrityLabel);

#endif

#define HW_PROFILE_GUIDLEN 39
#define MAX_PROFILE_LEN 80

#define DOCKINFO_UNDOCKED (0x1)
#define DOCKINFO_DOCKED (0x2)
#define DOCKINFO_USER_SUPPLIED (0x4)
#define DOCKINFO_USER_UNDOCKED (DOCKINFO_USER_SUPPLIED | DOCKINFO_UNDOCKED)
#define DOCKINFO_USER_DOCKED (DOCKINFO_USER_SUPPLIED | DOCKINFO_DOCKED)

  typedef struct tagHW_PROFILE_INFOA {
    DWORD dwDockInfo;
    CHAR szHwProfileGuid[HW_PROFILE_GUIDLEN];
    CHAR szHwProfileName[MAX_PROFILE_LEN];
  } HW_PROFILE_INFOA,*LPHW_PROFILE_INFOA;

  typedef struct tagHW_PROFILE_INFOW {
    DWORD dwDockInfo;
    WCHAR szHwProfileGuid[HW_PROFILE_GUIDLEN];
    WCHAR szHwProfileName[MAX_PROFILE_LEN];
  } HW_PROFILE_INFOW,*LPHW_PROFILE_INFOW;

  __MINGW_TYPEDEF_AW(HW_PROFILE_INFO)
  __MINGW_TYPEDEF_AW(LPHW_PROFILE_INFO)

  WINADVAPI WINBOOL WINAPI GetCurrentHwProfileA (LPHW_PROFILE_INFOA lpHwProfileInfo);
  WINADVAPI WINBOOL WINAPI GetCurrentHwProfileW (LPHW_PROFILE_INFOW lpHwProfileInfo);
  WINBASEAPI WINBOOL WINAPI VerifyVersionInfoA (LPOSVERSIONINFOEXA lpVersionInformation, DWORD dwTypeMask, DWORDLONG dwlConditionMask);
  WINBASEAPI WINBOOL WINAPI VerifyVersionInfoW (LPOSVERSIONINFOEXW lpVersionInformation, DWORD dwTypeMask, DWORDLONG dwlConditionMask);

#define GetCurrentHwProfile __MINGW_NAME_AW(GetCurrentHwProfile)

#define VerifyVersionInfo __MINGW_NAME_AW(VerifyVersionInfo)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP) || defined(WINSTORECOMPAT)
  WINADVAPI WINBOOL WINAPI GetUserNameA (LPSTR lpBuffer, LPDWORD pcbBuffer);
  WINADVAPI WINBOOL WINAPI GetUserNameW (LPWSTR lpBuffer, LPDWORD pcbBuffer);
#define GetUserName __MINGW_NAME_AW(GetUserName)
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINADVAPI WINBOOL WINAPI LookupAccountNameA (LPCSTR lpSystemName, LPCSTR lpAccountName, PSID Sid, LPDWORD cbSid, LPSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountNameW (LPCWSTR lpSystemName, LPCWSTR lpAccountName, PSID Sid, LPDWORD cbSid, LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountSidA (LPCSTR lpSystemName, PSID Sid, LPSTR Name, LPDWORD cchName, LPSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupAccountSidW (LPCWSTR lpSystemName, PSID Sid, LPWSTR Name, LPDWORD cchName, LPWSTR ReferencedDomainName, LPDWORD cchReferencedDomainName, PSID_NAME_USE peUse);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeDisplayNameA (LPCSTR lpSystemName, LPCSTR lpName, LPSTR lpDisplayName, LPDWORD cchDisplayName, LPDWORD lpLanguageId);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeDisplayNameW (LPCWSTR lpSystemName, LPCWSTR lpName, LPWSTR lpDisplayName, LPDWORD cchDisplayName, LPDWORD lpLanguageId);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeNameA (LPCSTR lpSystemName, PLUID lpLuid, LPSTR lpName, LPDWORD cchName);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeNameW (LPCWSTR lpSystemName, PLUID lpLuid, LPWSTR lpName, LPDWORD cchName);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeValueA (LPCSTR lpSystemName, LPCSTR lpName, PLUID lpLuid);
  WINADVAPI WINBOOL WINAPI LookupPrivilegeValueW (LPCWSTR lpSystemName, LPCWSTR lpName, PLUID lpLuid);
#define LookupAccountSid __MINGW_NAME_AW(LookupAccountSid)
#define LookupAccountName __MINGW_NAME_AW(LookupAccountName)
#define LookupPrivilegeValue __MINGW_NAME_AW(LookupPrivilegeValue)
#define LookupPrivilegeName __MINGW_NAME_AW(LookupPrivilegeName)
#define LookupPrivilegeDisplayName __MINGW_NAME_AW(LookupPrivilegeDisplayName)

  WINBASEAPI WINBOOL WINAPI SetVolumeLabelA (LPCSTR lpRootPathName, LPCSTR lpVolumeName);
  WINBASEAPI HANDLE WINAPI CreatePrivateNamespaceA (LPSECURITY_ATTRIBUTES lpPrivateNamespaceAttributes, LPVOID lpBoundaryDescriptor, LPCSTR lpAliasPrefix);
  WINBASEAPI HANDLE WINAPI OpenPrivateNamespaceA (LPVOID lpBoundaryDescriptor, LPCSTR lpAliasPrefix);
  WINBASEAPI HANDLE APIENTRY CreateBoundaryDescriptorA (LPCSTR Name, ULONG Flags);
#ifndef UNICODE
#define CreatePrivateNamespace __MINGW_NAME_AW(CreatePrivateNamespace)
#endif
#define OpenPrivateNamespace __MINGW_NAME_AW(OpenPrivateNamespace)
#ifndef UNICODE
#define CreateBoundaryDescriptor __MINGW_NAME_AW(CreateBoundaryDescriptor)
#endif

  WINBASEAPI WINBOOL WINAPI SetVolumeLabelW (LPCWSTR lpRootPathName, LPCWSTR lpVolumeName);
#define SetVolumeLabel __MINGW_NAME_AW(SetVolumeLabel)
  WINBASEAPI WINBOOL WINAPI GetComputerNameA (LPSTR lpBuffer, LPDWORD nSize);
  WINBASEAPI WINBOOL WINAPI GetComputerNameW (LPWSTR lpBuffer, LPDWORD nSize);
#define GetComputerName __MINGW_NAME_AW(GetComputerName)
#endif

#include <winerror.h>
#include <timezoneapi.h>

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)

#define TC_NORMAL 0
#define TC_HARDERR 1
#define TC_GP_TRAP 2
#define TC_SIGNAL 3

#define AC_LINE_OFFLINE 0x00
#define AC_LINE_ONLINE 0x01
#define AC_LINE_BACKUP_POWER 0x02
#define AC_LINE_UNKNOWN 0xff

#define BATTERY_FLAG_HIGH 0x01
#define BATTERY_FLAG_LOW 0x02
#define BATTERY_FLAG_CRITICAL 0x04
#define BATTERY_FLAG_CHARGING 0x08
#define BATTERY_FLAG_NO_BATTERY 0x80
#define BATTERY_FLAG_UNKNOWN 0xff

#define BATTERY_PERCENTAGE_UNKNOWN 0xff

#define BATTERY_LIFE_UNKNOWN 0xffffffff

  typedef struct _SYSTEM_POWER_STATUS {
    BYTE ACLineStatus;
    BYTE BatteryFlag;
    BYTE BatteryLifePercent;
    BYTE Reserved1;
    DWORD BatteryLifeTime;
    DWORD BatteryFullLifeTime;
  } SYSTEM_POWER_STATUS,*LPSYSTEM_POWER_STATUS;

  WINBASEAPI WINBOOL WINAPI GetSystemPowerStatus (LPSYSTEM_POWER_STATUS lpSystemPowerStatus);
#endif
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI SetSystemPowerState (WINBOOL fSuspend, WINBOOL fForce);

#if _WIN32_WINNT >= 0x0602
  typedef VOID WINAPI BAD_MEMORY_CALLBACK_ROUTINE (VOID);
  typedef BAD_MEMORY_CALLBACK_ROUTINE *PBAD_MEMORY_CALLBACK_ROUTINE;

  WINBASEAPI PVOID WINAPI RegisterBadMemoryNotification (PBAD_MEMORY_CALLBACK_ROUTINE Callback);
  WINBASEAPI WINBOOL WINAPI UnregisterBadMemoryNotification (PVOID RegistrationHandle);
  WINBASEAPI WINBOOL WINAPI GetMemoryErrorHandlingCapabilities (PULONG Capabilities);

#define MEHC_PATROL_SCRUBBER_PRESENT 0x1

#endif

  WINBASEAPI WINBOOL WINAPI AllocateUserPhysicalPages (HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI WINBOOL WINAPI FreeUserPhysicalPages (HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI WINBOOL WINAPI MapUserPhysicalPages (PVOID VirtualAddress, ULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI WINBOOL WINAPI MapUserPhysicalPagesScatter (PVOID *VirtualAddresses, ULONG_PTR NumberOfPages, PULONG_PTR PageArray);
  WINBASEAPI HANDLE WINAPI CreateJobObjectA (LPSECURITY_ATTRIBUTES lpJobAttributes, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI CreateJobObjectW (LPSECURITY_ATTRIBUTES lpJobAttributes, LPCWSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenJobObjectA (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCSTR lpName);
  WINBASEAPI HANDLE WINAPI OpenJobObjectW (DWORD dwDesiredAccess, WINBOOL bInheritHandle, LPCWSTR lpName);
  WINBASEAPI WINBOOL WINAPI AssignProcessToJobObject (HANDLE hJob, HANDLE hProcess);
  WINBASEAPI WINBOOL WINAPI TerminateJobObject (HANDLE hJob, UINT uExitCode);
  WINBASEAPI WINBOOL WINAPI QueryInformationJobObject (HANDLE hJob, JOBOBJECTINFOCLASS JobObjectInformationClass, LPVOID lpJobObjectInformation, DWORD cbJobObjectInformationLength, LPDWORD lpReturnLength);
  WINBASEAPI WINBOOL WINAPI SetInformationJobObject (HANDLE hJob, JOBOBJECTINFOCLASS JobObjectInformationClass, LPVOID lpJobObjectInformation, DWORD cbJobObjectInformationLength);
  WINBASEAPI WINBOOL WINAPI CreateJobSet (ULONG NumJob, PJOB_SET_ARRAY UserJobSet, ULONG Flags);
  WINBASEAPI HANDLE WINAPI FindFirstVolumeA (LPSTR lpszVolumeName, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI FindNextVolumeA (HANDLE hFindVolume, LPSTR lpszVolumeName, DWORD cchBufferLength);
  WINBASEAPI HANDLE WINAPI FindFirstVolumeMountPointA (LPCSTR lpszRootPathName, LPSTR lpszVolumeMountPoint, DWORD cchBufferLength);
  WINBASEAPI HANDLE WINAPI FindFirstVolumeMountPointW (LPCWSTR lpszRootPathName, LPWSTR lpszVolumeMountPoint, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI FindNextVolumeMountPointA (HANDLE hFindVolumeMountPoint, LPSTR lpszVolumeMountPoint, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI FindNextVolumeMountPointW (HANDLE hFindVolumeMountPoint, LPWSTR lpszVolumeMountPoint, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI FindVolumeMountPointClose (HANDLE hFindVolumeMountPoint);
  WINBASEAPI WINBOOL WINAPI SetVolumeMountPointA (LPCSTR lpszVolumeMountPoint, LPCSTR lpszVolumeName);
  WINBASEAPI WINBOOL WINAPI SetVolumeMountPointW (LPCWSTR lpszVolumeMountPoint, LPCWSTR lpszVolumeName);
  WINBASEAPI WINBOOL WINAPI GetVolumeNameForVolumeMountPointA (LPCSTR lpszVolumeMountPoint, LPSTR lpszVolumeName, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI GetVolumePathNameA (LPCSTR lpszFileName, LPSTR lpszVolumePathName, DWORD cchBufferLength);
  WINBASEAPI WINBOOL WINAPI GetVolumePathNamesForVolumeNameA (LPCSTR lpszVolumeName, LPCH lpszVolumePathNames, DWORD cchBufferLength, PDWORD lpcchReturnLength);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI AllocateUserPhysicalPagesNuma (HANDLE hProcess, PULONG_PTR NumberOfPages, PULONG_PTR PageArray, DWORD nndPreferred);
#endif

#ifndef UNICODE
#define FindFirstVolume FindFirstVolumeA
#define FindNextVolume FindNextVolumeA
#define GetVolumeNameForVolumeMountPoint GetVolumeNameForVolumeMountPointA
#define GetVolumePathName GetVolumePathNameA
#define GetVolumePathNamesForVolumeName GetVolumePathNamesForVolumeNameA
#endif

#define CreateJobObject __MINGW_NAME_AW(CreateJobObject)
#define OpenJobObject __MINGW_NAME_AW(OpenJobObject)
#define FindFirstVolumeMountPoint __MINGW_NAME_AW(FindFirstVolumeMountPoint)
#define FindNextVolumeMountPoint __MINGW_NAME_AW(FindNextVolumeMountPoint)
#define SetVolumeMountPoint __MINGW_NAME_AW(SetVolumeMountPoint)

#define ACTCTX_FLAG_PROCESSOR_ARCHITECTURE_VALID (0x00000001)
#define ACTCTX_FLAG_LANGID_VALID (0x00000002)
#define ACTCTX_FLAG_ASSEMBLY_DIRECTORY_VALID (0x00000004)
#define ACTCTX_FLAG_RESOURCE_NAME_VALID (0x00000008)
#define ACTCTX_FLAG_SET_PROCESS_DEFAULT (0x00000010)
#define ACTCTX_FLAG_APPLICATION_NAME_VALID (0x00000020)
#define ACTCTX_FLAG_SOURCE_IS_ASSEMBLYREF (0x00000040)
#define ACTCTX_FLAG_HMODULE_VALID (0x00000080)

  typedef struct tagACTCTXA {
    ULONG cbSize;
    DWORD dwFlags;
    LPCSTR lpSource;
    USHORT wProcessorArchitecture;
    LANGID wLangId;
    LPCSTR lpAssemblyDirectory;
    LPCSTR lpResourceName;
    LPCSTR lpApplicationName;
    HMODULE hModule;
  } ACTCTXA,*PACTCTXA;

  typedef struct tagACTCTXW {
    ULONG cbSize;
    DWORD dwFlags;
    LPCWSTR lpSource;
    USHORT wProcessorArchitecture;
    LANGID wLangId;
    LPCWSTR lpAssemblyDirectory;
    LPCWSTR lpResourceName;
    LPCWSTR lpApplicationName;
    HMODULE hModule;
  } ACTCTXW,*PACTCTXW;

  __MINGW_TYPEDEF_AW(ACTCTX)
  __MINGW_TYPEDEF_AW(PACTCTX)

  typedef const ACTCTXA *PCACTCTXA;
  typedef const ACTCTXW *PCACTCTXW;

  __MINGW_TYPEDEF_AW(PCACTCTX)

  WINBASEAPI HANDLE WINAPI CreateActCtxA (PCACTCTXA pActCtx);
  WINBASEAPI HANDLE WINAPI CreateActCtxW (PCACTCTXW pActCtx);
  WINBASEAPI VOID WINAPI AddRefActCtx (HANDLE hActCtx);
  WINBASEAPI VOID WINAPI ReleaseActCtx (HANDLE hActCtx);
  WINBASEAPI WINBOOL WINAPI ZombifyActCtx (HANDLE hActCtx);
  WINBASEAPI WINBOOL WINAPI ActivateActCtx (HANDLE hActCtx, ULONG_PTR *lpCookie);
  WINBASEAPI WINBOOL WINAPI DeactivateActCtx (DWORD dwFlags, ULONG_PTR ulCookie);
  WINBASEAPI WINBOOL WINAPI GetCurrentActCtx (HANDLE *lphActCtx);

#define CreateActCtx __MINGW_NAME_AW(CreateActCtx)
#define DEACTIVATE_ACTCTX_FLAG_FORCE_EARLY_DEACTIVATION (0x00000001)

  typedef struct tagACTCTX_SECTION_KEYED_DATA_2600 {
    ULONG cbSize;
    ULONG ulDataFormatVersion;
    PVOID lpData;
    ULONG ulLength;
    PVOID lpSectionGlobalData;
    ULONG ulSectionGlobalDataLength;
    PVOID lpSectionBase;
    ULONG ulSectionTotalLength;
    HANDLE hActCtx;
    ULONG ulAssemblyRosterIndex;
  } ACTCTX_SECTION_KEYED_DATA_2600,*PACTCTX_SECTION_KEYED_DATA_2600;

  typedef const ACTCTX_SECTION_KEYED_DATA_2600 *PCACTCTX_SECTION_KEYED_DATA_2600;

  typedef struct tagACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA {
    PVOID lpInformation;
    PVOID lpSectionBase;
    ULONG ulSectionLength;
    PVOID lpSectionGlobalDataBase;
    ULONG ulSectionGlobalDataLength;
  } ACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA,*PACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA;

  typedef const ACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA *PCACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA;

  typedef struct tagACTCTX_SECTION_KEYED_DATA {
    ULONG cbSize;
    ULONG ulDataFormatVersion;
    PVOID lpData;
    ULONG ulLength;
    PVOID lpSectionGlobalData;
    ULONG ulSectionGlobalDataLength;
    PVOID lpSectionBase;
    ULONG ulSectionTotalLength;
    HANDLE hActCtx;
    ULONG ulAssemblyRosterIndex;
    ULONG ulFlags;
    ACTCTX_SECTION_KEYED_DATA_ASSEMBLY_METADATA AssemblyMetadata;
  } ACTCTX_SECTION_KEYED_DATA,*PACTCTX_SECTION_KEYED_DATA;

  typedef const ACTCTX_SECTION_KEYED_DATA *PCACTCTX_SECTION_KEYED_DATA;

#define FIND_ACTCTX_SECTION_KEY_RETURN_HACTCTX (0x00000001)
#define FIND_ACTCTX_SECTION_KEY_RETURN_FLAGS (0x00000002)
#define FIND_ACTCTX_SECTION_KEY_RETURN_ASSEMBLY_METADATA (0x00000004)

  WINBASEAPI WINBOOL WINAPI FindActCtxSectionStringA (DWORD dwFlags, const GUID *lpExtensionGuid, ULONG ulSectionId, LPCSTR lpStringToFind, PACTCTX_SECTION_KEYED_DATA ReturnedData);
  WINBASEAPI WINBOOL WINAPI FindActCtxSectionStringW (DWORD dwFlags, const GUID *lpExtensionGuid, ULONG ulSectionId, LPCWSTR lpStringToFind, PACTCTX_SECTION_KEYED_DATA ReturnedData);
  WINBASEAPI WINBOOL WINAPI FindActCtxSectionGuid (DWORD dwFlags, const GUID *lpExtensionGuid, ULONG ulSectionId, const GUID *lpGuidToFind, PACTCTX_SECTION_KEYED_DATA ReturnedData);

#define FindActCtxSectionString __MINGW_NAME_AW(FindActCtxSectionString)

#if !defined (RC_INVOKED) && !defined (ACTIVATION_CONTEXT_BASIC_INFORMATION_DEFINED)
  typedef struct _ACTIVATION_CONTEXT_BASIC_INFORMATION {
    HANDLE hActCtx;
    DWORD dwFlags;
  } ACTIVATION_CONTEXT_BASIC_INFORMATION,*PACTIVATION_CONTEXT_BASIC_INFORMATION;

  typedef const struct _ACTIVATION_CONTEXT_BASIC_INFORMATION *PCACTIVATION_CONTEXT_BASIC_INFORMATION;

#define ACTIVATION_CONTEXT_BASIC_INFORMATION_DEFINED 1
#endif

#define QUERY_ACTCTX_FLAG_USE_ACTIVE_ACTCTX (0x00000004)
#define QUERY_ACTCTX_FLAG_ACTCTX_IS_HMODULE (0x00000008)
#define QUERY_ACTCTX_FLAG_ACTCTX_IS_ADDRESS (0x00000010)
#define QUERY_ACTCTX_FLAG_NO_ADDREF (0x80000000)

  WINBASEAPI WINBOOL WINAPI QueryActCtxW (DWORD dwFlags, HANDLE hActCtx, PVOID pvSubInstance, ULONG ulInfoClass, PVOID pvBuffer, SIZE_T cbBuffer, SIZE_T *pcbWrittenOrRequired);

  typedef WINBOOL (WINAPI *PQUERYACTCTXW_FUNC) (DWORD dwFlags, HANDLE hActCtx, PVOID pvSubInstance, ULONG ulInfoClass, PVOID pvBuffer, SIZE_T cbBuffer, SIZE_T *pcbWrittenOrRequired);

  WINBASEAPI DWORD WINAPI WTSGetActiveConsoleSessionId (VOID);
  WINBASEAPI WINBOOL WINAPI GetNumaProcessorNode (UCHAR Processor, PUCHAR NodeNumber);
  WINBASEAPI WINBOOL WINAPI GetNumaNodeProcessorMask (UCHAR Node, PULONGLONG ProcessorMask);
  WINBASEAPI WINBOOL WINAPI GetNumaAvailableMemoryNode (UCHAR Node, PULONGLONG AvailableBytes);
#if _WIN32_WINNT >= 0x0600
  WINBASEAPI WINBOOL WINAPI GetNumaProximityNode (ULONG ProximityId, PUCHAR NodeNumber);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI WORD WINAPI GetActiveProcessorGroupCount (VOID);
  WINBASEAPI WORD WINAPI GetMaximumProcessorGroupCount (VOID);
  WINBASEAPI DWORD WINAPI GetActiveProcessorCount (WORD GroupNumber);
  WINBASEAPI DWORD WINAPI GetMaximumProcessorCount (WORD GroupNumber);
  WINBASEAPI WINBOOL WINAPI GetNumaNodeNumberFromHandle (HANDLE hFile, PUSHORT NodeNumber);
  WINBASEAPI WINBOOL WINAPI GetNumaProcessorNodeEx (PPROCESSOR_NUMBER Processor, PUSHORT NodeNumber);
  WINBASEAPI WINBOOL WINAPI GetNumaAvailableMemoryNodeEx (USHORT Node, PULONGLONG AvailableBytes);
  WINBASEAPI WINBOOL WINAPI GetNumaProximityNodeEx (ULONG ProximityId, PUSHORT NodeNumber);
#endif

  typedef DWORD (WINAPI *APPLICATION_RECOVERY_CALLBACK) (PVOID pvParameter);

#define RESTART_MAX_CMD_LINE 1024

#define RESTART_NO_CRASH 1
#define RESTART_NO_HANG 2
#define RESTART_NO_PATCH 4
#define RESTART_NO_REBOOT 8

#define RECOVERY_DEFAULT_PING_INTERVAL 5000
#define RECOVERY_MAX_PING_INTERVAL (5 *60 *1000)

#if _WIN32_WINNT >= 0x0600
  WINBASEAPI HRESULT WINAPI RegisterApplicationRecoveryCallback (APPLICATION_RECOVERY_CALLBACK pRecoveyCallback, PVOID pvParameter, DWORD dwPingInterval, DWORD dwFlags);
  WINBASEAPI HRESULT WINAPI UnregisterApplicationRecoveryCallback (void);
  WINBASEAPI HRESULT WINAPI RegisterApplicationRestart (PCWSTR pwzCommandline, DWORD dwFlags);
  WINBASEAPI HRESULT WINAPI UnregisterApplicationRestart (void);
  WINBASEAPI HRESULT WINAPI GetApplicationRecoveryCallback (HANDLE hProcess, APPLICATION_RECOVERY_CALLBACK *pRecoveryCallback, PVOID *ppvParameter, PDWORD pdwPingInterval, PDWORD pdwFlags);
  WINBASEAPI HRESULT WINAPI GetApplicationRestartSettings (HANDLE hProcess, PWSTR pwzCommandline, PDWORD pcchSize, PDWORD pdwFlags);
  WINBASEAPI HRESULT WINAPI ApplicationRecoveryInProgress (PBOOL pbCancelled);
  WINBASEAPI VOID WINAPI ApplicationRecoveryFinished (WINBOOL bSuccess);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI DeleteVolumeMountPointA (LPCSTR lpszVolumeMountPoint);
#ifndef UNICODE
#define DeleteVolumeMountPoint DeleteVolumeMountPointA
#endif
#endif /* WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP) */


#if _WIN32_WINNT >= 0x0600
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  typedef struct _FILE_BASIC_INFO {
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    DWORD FileAttributes;
  } FILE_BASIC_INFO,*PFILE_BASIC_INFO;

  typedef struct _FILE_STANDARD_INFO {
    LARGE_INTEGER AllocationSize;
    LARGE_INTEGER EndOfFile;
    DWORD NumberOfLinks;
    BOOLEAN DeletePending;
    BOOLEAN Directory;
  } FILE_STANDARD_INFO,*PFILE_STANDARD_INFO;

  typedef struct _FILE_NAME_INFO {
    DWORD FileNameLength;
    WCHAR FileName[1];
  } FILE_NAME_INFO,*PFILE_NAME_INFO;

  typedef struct _FILE_RENAME_INFO {
    BOOLEAN ReplaceIfExists;
    HANDLE RootDirectory;
    DWORD FileNameLength;
    WCHAR FileName[1];
  } FILE_RENAME_INFO,*PFILE_RENAME_INFO;

  typedef struct _FILE_ALLOCATION_INFO {
    LARGE_INTEGER AllocationSize;
  } FILE_ALLOCATION_INFO,*PFILE_ALLOCATION_INFO;

  typedef struct _FILE_END_OF_FILE_INFO {
    LARGE_INTEGER EndOfFile;
  } FILE_END_OF_FILE_INFO,*PFILE_END_OF_FILE_INFO;

  typedef struct _FILE_STREAM_INFO {
    DWORD NextEntryOffset;
    DWORD StreamNameLength;
    LARGE_INTEGER StreamSize;
    LARGE_INTEGER StreamAllocationSize;
    WCHAR StreamName[1];
  } FILE_STREAM_INFO,*PFILE_STREAM_INFO;

  typedef struct _FILE_COMPRESSION_INFO {
    LARGE_INTEGER CompressedFileSize;
    WORD CompressionFormat;
    UCHAR CompressionUnitShift;
    UCHAR ChunkShift;
    UCHAR ClusterShift;
    UCHAR Reserved[3];
  } FILE_COMPRESSION_INFO,*PFILE_COMPRESSION_INFO;

  typedef struct _FILE_ATTRIBUTE_TAG_INFO {
    DWORD FileAttributes;
    DWORD ReparseTag;
  } FILE_ATTRIBUTE_TAG_INFO,*PFILE_ATTRIBUTE_TAG_INFO;

  typedef struct _FILE_DISPOSITION_INFO {
    BOOLEAN DeleteFile;
  } FILE_DISPOSITION_INFO,*PFILE_DISPOSITION_INFO;

  typedef struct _FILE_ID_BOTH_DIR_INFO {
    DWORD NextEntryOffset;
    DWORD FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    DWORD FileAttributes;
    DWORD FileNameLength;
    DWORD EaSize;
    CCHAR ShortNameLength;
    WCHAR ShortName[12];
    LARGE_INTEGER FileId;
    WCHAR FileName[1];
  } FILE_ID_BOTH_DIR_INFO,*PFILE_ID_BOTH_DIR_INFO;

  typedef struct _FILE_FULL_DIR_INFO {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    WCHAR FileName[1];
  } FILE_FULL_DIR_INFO,*PFILE_FULL_DIR_INFO;

  typedef enum _PRIORITY_HINT {
    IoPriorityHintVeryLow = 0,
    IoPriorityHintLow,
    IoPriorityHintNormal,
    MaximumIoPriorityHintType
  } PRIORITY_HINT;

  typedef struct _FILE_IO_PRIORITY_HINT_INFO {
    PRIORITY_HINT PriorityHint;
  } FILE_IO_PRIORITY_HINT_INFO,*PFILE_IO_PRIORITY_HINT_INFO;
#if _WIN32_WINNT >= 0x0602
  typedef struct _FILE_ALIGNMENT_INFO {
    ULONG AlignmentRequirement;
  } FILE_ALIGNMENT_INFO,*PFILE_ALIGNMENT_INFO;

#define STORAGE_INFO_FLAGS_ALIGNED_DEVICE 0x00000001
#define STORAGE_INFO_FLAGS_PARTITION_ALIGNED_ON_DEVICE 0x00000002

#define STORAGE_INFO_OFFSET_UNKNOWN (0xffffffff)

  typedef struct _FILE_STORAGE_INFO {
    ULONG LogicalBytesPerSector;
    ULONG PhysicalBytesPerSectorForAtomicity;
    ULONG PhysicalBytesPerSectorForPerformance;
    ULONG FileSystemEffectivePhysicalBytesPerSectorForAtomicity;
    ULONG Flags;
    ULONG ByteOffsetForSectorAlignment;
    ULONG ByteOffsetForPartitionAlignment;
  } FILE_STORAGE_INFO,*PFILE_STORAGE_INFO;

  typedef struct _FILE_ID_INFO {
    ULONGLONG VolumeSerialNumber;
    FILE_ID_128 FileId;
  } FILE_ID_INFO,*PFILE_ID_INFO;

  typedef struct _FILE_ID_EXTD_DIR_INFO {
    ULONG NextEntryOffset;
    ULONG FileIndex;
    LARGE_INTEGER CreationTime;
    LARGE_INTEGER LastAccessTime;
    LARGE_INTEGER LastWriteTime;
    LARGE_INTEGER ChangeTime;
    LARGE_INTEGER EndOfFile;
    LARGE_INTEGER AllocationSize;
    ULONG FileAttributes;
    ULONG FileNameLength;
    ULONG EaSize;
    ULONG ReparsePointTag;
    FILE_ID_128 FileId;
    WCHAR FileName[1];
  } FILE_ID_EXTD_DIR_INFO,*PFILE_ID_EXTD_DIR_INFO;
#endif

#define REMOTE_PROTOCOL_INFO_FLAG_LOOPBACK 0x00000001
#define REMOTE_PROTOCOL_INFO_FLAG_OFFLINE 0x00000002

#if _WIN32_WINNT >= 0x0602
#define REMOTE_PROTOCOL_INFO_FLAG_PERSISTENT_HANDLE 0x00000004

#define RPI_FLAG_SMB2_SHARECAP_TIMEWARP 0x00000002
#define RPI_FLAG_SMB2_SHARECAP_DFS 0x00000008
#define RPI_FLAG_SMB2_SHARECAP_CONTINUOUS_AVAILABILITY 0x00000010
#define RPI_FLAG_SMB2_SHARECAP_SCALEOUT 0x00000020
#define RPI_FLAG_SMB2_SHARECAP_CLUSTER 0x00000040

#define RPI_SMB2_FLAG_SERVERCAP_DFS 0x00000001
#define RPI_SMB2_FLAG_SERVERCAP_LEASING 0x00000002
#define RPI_SMB2_FLAG_SERVERCAP_LARGEMTU 0x00000004
#define RPI_SMB2_FLAG_SERVERCAP_MULTICHANNEL 0x00000008
#define RPI_SMB2_FLAG_SERVERCAP_PERSISTENT_HANDLES 0x00000010
#define RPI_SMB2_FLAG_SERVERCAP_DIRECTORY_LEASING 0x00000020
#endif

  typedef struct _FILE_REMOTE_PROTOCOL_INFO {
    USHORT StructureVersion;
    USHORT StructureSize;
    ULONG Protocol;
    USHORT ProtocolMajorVersion;
    USHORT ProtocolMinorVersion;
    USHORT ProtocolRevision;
    USHORT Reserved;
    ULONG Flags;
    struct {
      ULONG Reserved[8];
    } GenericReserved;
#if _WIN32_WINNT < 0x0602
    struct {
      ULONG Reserved[16];
    } ProtocolSpecificReserved;
#else
    union {
      struct {
    struct {
      ULONG Capabilities;
    } Server;
    struct {
      ULONG Capabilities;
      ULONG CachingFlags;
    } Share;
      } Smb2;
      ULONG Reserved[16];
    } ProtocolSpecific;
#endif
  } FILE_REMOTE_PROTOCOL_INFO,*PFILE_REMOTE_PROTOCOL_INFO;

  WINBASEAPI WINBOOL WINAPI GetFileInformationByHandleEx (HANDLE hFile, FILE_INFO_BY_HANDLE_CLASS FileInformationClass, LPVOID lpFileInformation, DWORD dwBufferSize);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  typedef enum _FILE_ID_TYPE {
    FileIdType,
    ObjectIdType,
    ExtendedFileIdType,
    MaximumFileIdType
  } FILE_ID_TYPE,*PFILE_ID_TYPE;

  typedef struct FILE_ID_DESCRIPTOR {
    DWORD dwSize;
    FILE_ID_TYPE Type;
    __C89_NAMELESS union {
      LARGE_INTEGER FileId;
      GUID ObjectId;
#if _WIN32_WINNT >= 0x0602
      FILE_ID_128 ExtendedFileId;
#endif
    } DUMMYUNIONNAME;
  } FILE_ID_DESCRIPTOR,*LPFILE_ID_DESCRIPTOR;

  WINBASEAPI HANDLE WINAPI OpenFileById (HANDLE hVolumeHint, LPFILE_ID_DESCRIPTOR lpFileId, DWORD dwDesiredAccess, DWORD dwShareMode, LPSECURITY_ATTRIBUTES lpSecurityAttributes, DWORD dwFlagsAndAttributes);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if _WIN32_WINNT >= 0x0600

#define SYMBOLIC_LINK_FLAG_DIRECTORY (0x1)
#define SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE (0x2)

#define VALID_SYMBOLIC_LINK_FLAGS SYMBOLIC_LINK_FLAG_DIRECTORY

  WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkA (LPCSTR lpSymlinkFileName, LPCSTR lpTargetFileName, DWORD dwFlags);
  WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkW (LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName, DWORD dwFlags);
  WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkTransactedA (LPCSTR lpSymlinkFileName, LPCSTR lpTargetFileName, DWORD dwFlags, HANDLE hTransaction);
  WINBASEAPI BOOLEAN APIENTRY CreateSymbolicLinkTransactedW (LPCWSTR lpSymlinkFileName, LPCWSTR lpTargetFileName, DWORD dwFlags, HANDLE hTransaction);
  WINBASEAPI WINBOOL WINAPI QueryActCtxSettingsW (DWORD dwFlags, HANDLE hActCtx, PCWSTR settingsNameSpace, PCWSTR settingName, PWSTR pvBuffer, SIZE_T dwBuffer, SIZE_T *pdwWrittenOrRequired);
  WINBASEAPI WINBOOL WINAPI ReplacePartitionUnit (PWSTR TargetPartition, PWSTR SparePartition, ULONG Flags);
  WINBASEAPI WINBOOL WINAPI AddSecureMemoryCacheCallback (PSECURE_MEMORY_CACHE_CALLBACK pfnCallBack);
  WINBASEAPI WINBOOL WINAPI RemoveSecureMemoryCacheCallback (PSECURE_MEMORY_CACHE_CALLBACK pfnCallBack);

#define CreateSymbolicLink __MINGW_NAME_AW(CreateSymbolicLink)
#define CreateSymbolicLinkTransacted __MINGW_NAME_AW(CreateSymbolicLinkTransacted)

#endif
#endif

#if NTDDI_VERSION >= NTDDI_WIN7SP1
#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
  WINBASEAPI WINBOOL WINAPI CopyContext (PCONTEXT Destination, DWORD ContextFlags, PCONTEXT Source);
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_APP)
  WINBASEAPI WINBOOL WINAPI InitializeContext (PVOID Buffer, DWORD ContextFlags, PCONTEXT *Context, PDWORD ContextLength);
#if defined (__x86_64__) || defined (__i386__)
  WINBASEAPI DWORD64 WINAPI GetEnabledXStateFeatures (VOID);
  WINBASEAPI WINBOOL WINAPI GetXStateFeaturesMask (PCONTEXT Context, PDWORD64 FeatureMask);
  WINBASEAPI PVOID WINAPI LocateXStateFeature (PCONTEXT Context, DWORD FeatureId, PDWORD Length);
#endif
#endif

#if WINAPI_FAMILY_PARTITION (WINAPI_PARTITION_DESKTOP)
#if defined (__x86_64__) || defined (__i386__)
  WINBASEAPI WINBOOL WINAPI SetXStateFeaturesMask (PCONTEXT Context, DWORD64 FeatureMask);
#endif
#if _WIN32_WINNT >= 0x0601
  WINBASEAPI DWORD APIENTRY EnableThreadProfiling (HANDLE ThreadHandle, DWORD Flags, DWORD64 HardwareCounters, HANDLE *PerformanceDataHandle);
  WINBASEAPI DWORD APIENTRY DisableThreadProfiling (HANDLE PerformanceDataHandle);
  WINBASEAPI DWORD APIENTRY QueryThreadProfiling (HANDLE ThreadHandle, PBOOLEAN Enabled);
  WINBASEAPI DWORD APIENTRY ReadThreadProfilingData (HANDLE PerformanceDataHandle, DWORD Flags, PPERFORMANCE_DATA PerformanceData);
#endif
#endif
#endif

#ifdef __cplusplus
}
#endif
#endif

#if !defined (RC_INVOKED) && !defined (NOWINBASEINTERLOCK) && !defined (_NTOS_) && !defined (MICROSOFT_WINDOWS_WINBASE_INTERLOCKED_CPLUSPLUS_H_INCLUDED)
#define MICROSOFT_WINDOWS_WINBASE_INTERLOCKED_CPLUSPLUS_H_INCLUDED
#if !defined (__WIDL__)
#if !defined (MICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS)
#if (_WIN32_WINNT >= 0x0502 || !defined (_WINBASE_))
#define MICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS 1
#else
#define MICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS 0
#endif
#endif
#if MICROSOFT_WINDOWS_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS && defined (__cplusplus)
extern "C++" {
#if defined(__x86_64__) && defined(__CYGWIN__)
#define __MINGW_USE_INT64_INTERLOCKED_LONG
#endif
  FORCEINLINE unsigned InterlockedIncrement (unsigned volatile *Addend) {
    return (unsigned) InterlockedIncrement ((volatile __LONG32 *) Addend);
  }

  FORCEINLINE unsigned long InterlockedIncrement (unsigned long volatile *Addend) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedIncrement ((volatile __LONG32 *) Addend);
#else
    return (unsigned long) InterlockedIncrement64 ((volatile __int64 *) Addend);
#endif
  }

#if defined (_WIN64) || ((_WIN32_WINNT >= 0x0502) && defined (_WINBASE_))
  FORCEINLINE unsigned __int64 InterlockedIncrement (unsigned __int64 volatile *Addend) {
    return (unsigned __int64) InterlockedIncrement64 ((volatile __int64 *) Addend);
  }
#endif

  FORCEINLINE unsigned InterlockedDecrement (unsigned volatile *Addend) {
    return (unsigned) InterlockedDecrement ((volatile __LONG32 *) Addend);
  }

  FORCEINLINE unsigned long InterlockedDecrement (unsigned long volatile *Addend) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedDecrement ((volatile __LONG32 *) Addend);
#else
    return (unsigned long) InterlockedDecrement64 ((volatile __int64 *) Addend);
#endif
  }

#if defined (_WIN64) || ((_WIN32_WINNT >= 0x0502) && defined (_WINBASE_))
  FORCEINLINE unsigned __int64 InterlockedDecrement (unsigned __int64 volatile *Addend) {
    return (unsigned __int64) InterlockedDecrement64 ((volatile __int64 *) Addend);
  }
#endif

  FORCEINLINE unsigned InterlockedExchange (unsigned volatile *Target, unsigned Value) {
    return (unsigned) InterlockedExchange ((volatile __LONG32 *) Target,(__LONG32) Value);
  }

  FORCEINLINE unsigned long InterlockedExchange (unsigned long volatile *Target, unsigned long Value) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedExchange ((volatile __LONG32 *) Target,(__LONG32) Value);
#else
    return (unsigned long) InterlockedExchange64 ((volatile __int64 *) Target,(__int64) Value);
#endif
  }

#if defined (_WIN64) || ((_WIN32_WINNT >= 0x0502) && defined (_WINBASE_))
  FORCEINLINE unsigned __int64 InterlockedExchange (unsigned __int64 volatile *Target, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedExchange64 ((volatile __int64 *) Target,(__int64) Value);
  }
#endif

  FORCEINLINE unsigned InterlockedExchangeAdd (unsigned volatile *Addend, unsigned Value) {
    return (unsigned) InterlockedExchangeAdd ((volatile __LONG32 *) Addend,(__LONG32) Value);
  }

  FORCEINLINE unsigned InterlockedExchangeSubtract (unsigned volatile *Addend, unsigned Value) {
    return (unsigned) InterlockedExchangeAdd ((volatile __LONG32 *) Addend,- (__LONG32) Value);
  }

  FORCEINLINE unsigned long InterlockedExchangeAdd (unsigned long volatile *Addend, unsigned long Value) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedExchangeAdd ((volatile __LONG32 *) Addend,(__LONG32) Value);
#else
    return (unsigned __int64) InterlockedExchangeAdd64 ((volatile __int64 *) Addend,(__int64) Value);
#endif
  }

  FORCEINLINE unsigned long InterlockedExchangeSubtract (unsigned long volatile *Addend, unsigned long Value) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedExchangeAdd ((volatile __LONG32 *) Addend,- (__LONG32) Value);
#else
    return (unsigned long) InterlockedExchangeAdd64 ((volatile __int64 *) Addend,- (__int64) Value);
#endif
  }

#if defined (_WIN64) || ((_WIN32_WINNT >= 0x0502) && defined (_WINBASE_))
  FORCEINLINE unsigned __int64 InterlockedExchangeAdd (unsigned __int64 volatile *Addend, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedExchangeAdd64 ((volatile __int64 *) Addend,(__int64) Value);
  }

  FORCEINLINE unsigned __int64 InterlockedExchangeSubtract (unsigned __int64 volatile *Addend, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedExchangeAdd64 ((volatile __int64 *) Addend,- (__int64) Value);
  }
#endif

  FORCEINLINE unsigned InterlockedCompareExchange (unsigned volatile *Destination, unsigned Exchange, unsigned Comperand) {
    return (unsigned) InterlockedCompareExchange ((volatile __LONG32 *) Destination,(__LONG32) Exchange,(__LONG32) Comperand);
  }

  FORCEINLINE unsigned long InterlockedCompareExchange (unsigned long volatile *Destination, unsigned long Exchange, unsigned long Comperand) {
#ifndef __MINGW_USE_INT64_INTERLOCKED_LONG
    return (unsigned __LONG32) InterlockedCompareExchange ((volatile __LONG32 *) Destination,(__LONG32) Exchange,(__LONG32) Comperand);
#else
    return (unsigned long) InterlockedCompareExchange64 ((volatile __int64 *) Destination,(__int64) Exchange,(__int64) Comperand);
#endif
  }

#if defined (_WIN64) || ((_WIN32_WINNT >= 0x0502) && defined (_WINBASE_))
  FORCEINLINE unsigned __int64 InterlockedCompareExchange (unsigned __int64 volatile *Destination, unsigned __int64 Exchange, unsigned __int64 Comperand) {
    return (unsigned __int64) InterlockedCompareExchange64 ((volatile __int64 *) Destination,(__int64) Exchange,(__int64) Comperand);
  }

  FORCEINLINE unsigned __int64 InterlockedAnd (unsigned __int64 volatile *Destination, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedAnd64 ((volatile __int64 *) Destination,(__int64) Value);
  }

  FORCEINLINE unsigned __int64 InterlockedOr (unsigned __int64 volatile *Destination, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedOr64 ((volatile __int64 *) Destination,(__int64) Value);
  }

  FORCEINLINE unsigned __int64 InterlockedXor (unsigned __int64 volatile *Destination, unsigned __int64 Value) {
    return (unsigned __int64) InterlockedXor64 ((volatile __int64 *) Destination,(__int64) Value);
  }
#endif
}
#endif

#undef MICROSOFT_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS
#define MICROSOFT_WINBASE_H_DEFINE_INTERLOCKED_CPLUSPLUS_OVERLOADS 0
#endif
#endif
