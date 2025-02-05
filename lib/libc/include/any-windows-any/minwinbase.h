#ifndef _MINWINBASE_
#define _MINWINBASE_

#ifdef __cplusplus
extern "C" {
#endif

#define MoveMemory RtlMoveMemory
#define CopyMemory RtlCopyMemory
#define FillMemory RtlFillMemory
#define ZeroMemory RtlZeroMemory

  typedef struct _SECURITY_ATTRIBUTES {
    DWORD nLength;
    LPVOID lpSecurityDescriptor;
    WINBOOL bInheritHandle;
  } SECURITY_ATTRIBUTES, *PSECURITY_ATTRIBUTES, *LPSECURITY_ATTRIBUTES;

  typedef struct _OVERLAPPED {
    ULONG_PTR Internal;
    ULONG_PTR InternalHigh;
    __C89_NAMELESS union {
        struct {
            DWORD Offset;
            DWORD OffsetHigh;
        } DUMMYSTRUCTNAME;
        PVOID Pointer;
    } DUMMYUNIONNAME;
    HANDLE hEvent;
  } OVERLAPPED, *LPOVERLAPPED;

  typedef struct _OVERLAPPED_ENTRY {
    ULONG_PTR lpCompletionKey;
    LPOVERLAPPED lpOverlapped;
    ULONG_PTR Internal;
    DWORD dwNumberOfBytesTransferred;
  } OVERLAPPED_ENTRY, *LPOVERLAPPED_ENTRY;

#ifndef _FILETIME_
#define _FILETIME_
  typedef struct _FILETIME {
    DWORD dwLowDateTime;
    DWORD dwHighDateTime;
  } FILETIME,*PFILETIME,*LPFILETIME;
#endif

#ifndef _SYSTEMTIME_
#define _SYSTEMTIME_
  typedef struct _SYSTEMTIME {
    WORD wYear;
    WORD wMonth;
    WORD wDayOfWeek;
    WORD wDay;
    WORD wHour;
    WORD wMinute;
    WORD wSecond;
    WORD wMilliseconds;
  } SYSTEMTIME, *PSYSTEMTIME, *LPSYSTEMTIME;
#endif

  typedef struct _WIN32_FIND_DATAA {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    CHAR cFileName[MAX_PATH];
    CHAR cAlternateFileName[14];
#ifdef _MAC
    DWORD dwFileType;
    DWORD dwCreatorType;
    WORD  wFinderFlags;
#endif
  } WIN32_FIND_DATAA, *PWIN32_FIND_DATAA, *LPWIN32_FIND_DATAA;

  typedef struct _WIN32_FIND_DATAW {
    DWORD dwFileAttributes;
    FILETIME ftCreationTime;
    FILETIME ftLastAccessTime;
    FILETIME ftLastWriteTime;
    DWORD nFileSizeHigh;
    DWORD nFileSizeLow;
    DWORD dwReserved0;
    DWORD dwReserved1;
    WCHAR cFileName[MAX_PATH];
    WCHAR cAlternateFileName[14];
#ifdef _MAC
    DWORD dwFileType;
    DWORD dwCreatorType;
    WORD  wFinderFlags;
#endif
  } WIN32_FIND_DATAW, *PWIN32_FIND_DATAW, *LPWIN32_FIND_DATAW;

  __MINGW_TYPEDEF_AW(WIN32_FIND_DATA)
  __MINGW_TYPEDEF_AW(PWIN32_FIND_DATA)
  __MINGW_TYPEDEF_AW(LPWIN32_FIND_DATA)

#if _WIN32_WINNT >= 0x0400
  typedef enum _FINDEX_INFO_LEVELS {
    FindExInfoStandard,
    FindExInfoBasic,
    FindExInfoMaxInfoLevel
  } FINDEX_INFO_LEVELS;

#define FIND_FIRST_EX_CASE_SENSITIVE 0x00000001
#define FIND_FIRST_EX_LARGE_FETCH 0x00000002
#if NTDDI_VERSION >= 0x0A000005
#define FIND_FIRST_EX_ON_DISK_ENTRIES_ONLY  0x00000004
#endif

  typedef enum _FINDEX_SEARCH_OPS {
    FindExSearchNameMatch,
    FindExSearchLimitToDirectories,
    FindExSearchLimitToDevices,
    FindExSearchMaxSearchOp
  } FINDEX_SEARCH_OPS;
#endif

#if _WIN32_WINNT >= 0x0400
#if NTDDI_VERSION >= NTDDI_WIN10_RS3
  typedef enum _READ_DIRECTORY_NOTIFY_INFORMATION_CLASS {
    ReadDirectoryNotifyInformation = 1,
    ReadDirectoryNotifyExtendedInformation = 2
#if NTDDI_VERSION >= NTDDI_WIN10_NI
    ,ReadDirectoryNotifyFullInformation
#endif
    ,ReadDirectoryNotifyMaximumInformation
  } READ_DIRECTORY_NOTIFY_INFORMATION_CLASS, *PREAD_DIRECTORY_NOTIFY_INFORMATION_CLASS;
#endif
#endif /* _WIN32_WINNT >= 0x0400 */

  typedef enum _GET_FILEEX_INFO_LEVELS {
    GetFileExInfoStandard,
    GetFileExMaxInfoLevel
  } GET_FILEEX_INFO_LEVELS;

#if _WIN32_WINNT >= 0x0600
  typedef enum _FILE_INFO_BY_HANDLE_CLASS {
    FileBasicInfo /* is zero? */,
    FileStandardInfo,
    FileNameInfo,
    FileRenameInfo,
    FileDispositionInfo,
    FileAllocationInfo,
    FileEndOfFileInfo,
    FileStreamInfo,
    FileCompressionInfo,
    FileAttributeTagInfo,
    FileIdBothDirectoryInfo,
    FileIdBothDirectoryRestartInfo,
    FileIoPriorityHintInfo,
    FileRemoteProtocolInfo,
    FileFullDirectoryInfo,
    FileFullDirectoryRestartInfo,
#if _WIN32_WINNT >= 0x0602
    FileStorageInfo,
    FileAlignmentInfo,
    FileIdInfo,
    FileIdExtdDirectoryInfo,
    FileIdExtdDirectoryRestartInfo,
#endif
#if NTDDI_VERSION >= 0x0A000002
    FileDispositionInfoEx,
    FileRenameInfoEx,
#endif
#if NTDDI_VERSION >= 0x0A000007
    FileCaseSensitiveInfo,
    FileNormalizedNameInfo,
#endif
    MaximumFileInfoByHandleClass
  } FILE_INFO_BY_HANDLE_CLASS, *PFILE_INFO_BY_HANDLE_CLASS;
#endif

#if NTDDI_VERSION >= NTDDI_WIN11_ZN
  typedef enum _FILE_INFO_BY_NAME_CLASS {
    FileStatByNameInfo,
    FileStatLxByNameInfo,
    FileCaseSensitiveByNameInfo,
    FileStatBasicByNameInfo,
    MaximumFileInfoByNameClass
  } FILE_INFO_BY_NAME_CLASS, *PFILE_INFO_BY_NAME_CLASS;
#endif

  typedef RTL_CRITICAL_SECTION CRITICAL_SECTION;
  typedef PRTL_CRITICAL_SECTION PCRITICAL_SECTION;
  typedef PRTL_CRITICAL_SECTION LPCRITICAL_SECTION;
  typedef RTL_CRITICAL_SECTION_DEBUG CRITICAL_SECTION_DEBUG;
  typedef PRTL_CRITICAL_SECTION_DEBUG PCRITICAL_SECTION_DEBUG;
  typedef PRTL_CRITICAL_SECTION_DEBUG LPCRITICAL_SECTION_DEBUG;

  typedef VOID (WINAPI *LPOVERLAPPED_COMPLETION_ROUTINE) (DWORD dwErrorCode, DWORD dwNumberOfBytesTransfered, LPOVERLAPPED lpOverlapped);

#define LOCKFILE_FAIL_IMMEDIATELY 0x1
#define LOCKFILE_EXCLUSIVE_LOCK 0x2

  typedef struct _PROCESS_HEAP_ENTRY {
    PVOID lpData;
    DWORD cbData;
    BYTE cbOverhead;
    BYTE iRegionIndex;
    WORD wFlags;
    __C89_NAMELESS union {
        struct {
            HANDLE hMem;
            DWORD dwReserved[3];
        } Block;
        struct {
            DWORD dwCommittedSize;
            DWORD dwUnCommittedSize;
            LPVOID lpFirstBlock;
            LPVOID lpLastBlock;
        } Region;
    } DUMMYUNIONNAME;
  } PROCESS_HEAP_ENTRY,*LPPROCESS_HEAP_ENTRY,*PPROCESS_HEAP_ENTRY;

#define PROCESS_HEAP_REGION 0x1
#define PROCESS_HEAP_UNCOMMITTED_RANGE 0x2
#define PROCESS_HEAP_ENTRY_BUSY 0x4
#define PROCESS_HEAP_SEG_ALLOC 0x8
#define PROCESS_HEAP_ENTRY_MOVEABLE 0x10
#define PROCESS_HEAP_ENTRY_DDESHARE 0x20

  typedef struct _REASON_CONTEXT {
    ULONG Version;
    DWORD Flags;
    union {
        struct {
            HMODULE LocalizedReasonModule;
            ULONG LocalizedReasonId;
            ULONG ReasonStringCount;
            LPWSTR *ReasonStrings;
        } Detailed;
        LPWSTR SimpleReasonString;
    } Reason;
  } REASON_CONTEXT, *PREASON_CONTEXT;

#define EXCEPTION_DEBUG_EVENT 1
#define CREATE_THREAD_DEBUG_EVENT 2
#define CREATE_PROCESS_DEBUG_EVENT 3
#define EXIT_THREAD_DEBUG_EVENT 4
#define EXIT_PROCESS_DEBUG_EVENT 5
#define LOAD_DLL_DEBUG_EVENT 6
#define UNLOAD_DLL_DEBUG_EVENT 7
#define OUTPUT_DEBUG_STRING_EVENT 8
#define RIP_EVENT 9

  typedef DWORD (WINAPI *PTHREAD_START_ROUTINE) (LPVOID lpThreadParameter);
  typedef PTHREAD_START_ROUTINE LPTHREAD_START_ROUTINE;

  typedef LPVOID (WINAPI *PENCLAVE_ROUTINE) (LPVOID lpThreadParameter);
  typedef PENCLAVE_ROUTINE LPENCLAVE_ROUTINE;

  typedef struct _EXCEPTION_DEBUG_INFO {
    EXCEPTION_RECORD ExceptionRecord;
    DWORD dwFirstChance;
  } EXCEPTION_DEBUG_INFO, *LPEXCEPTION_DEBUG_INFO;

  typedef struct _CREATE_THREAD_DEBUG_INFO {
    HANDLE hThread;
    LPVOID lpThreadLocalBase;
    LPTHREAD_START_ROUTINE lpStartAddress;
  } CREATE_THREAD_DEBUG_INFO, *LPCREATE_THREAD_DEBUG_INFO;

  typedef struct _CREATE_PROCESS_DEBUG_INFO {
    HANDLE hFile;
    HANDLE hProcess;
    HANDLE hThread;
    LPVOID lpBaseOfImage;
    DWORD dwDebugInfoFileOffset;
    DWORD nDebugInfoSize;
    LPVOID lpThreadLocalBase;
    LPTHREAD_START_ROUTINE lpStartAddress;
    LPVOID lpImageName;
    WORD fUnicode;
  } CREATE_PROCESS_DEBUG_INFO, *LPCREATE_PROCESS_DEBUG_INFO;

  typedef struct _EXIT_THREAD_DEBUG_INFO {
    DWORD dwExitCode;
  } EXIT_THREAD_DEBUG_INFO, *LPEXIT_THREAD_DEBUG_INFO;

  typedef struct _EXIT_PROCESS_DEBUG_INFO {
    DWORD dwExitCode;
  } EXIT_PROCESS_DEBUG_INFO, *LPEXIT_PROCESS_DEBUG_INFO;

  typedef struct _LOAD_DLL_DEBUG_INFO {
    HANDLE hFile;
    LPVOID lpBaseOfDll;
    DWORD dwDebugInfoFileOffset;
    DWORD nDebugInfoSize;
    LPVOID lpImageName;
    WORD fUnicode;
  } LOAD_DLL_DEBUG_INFO, *LPLOAD_DLL_DEBUG_INFO;

  typedef struct _UNLOAD_DLL_DEBUG_INFO {
    LPVOID lpBaseOfDll;
  } UNLOAD_DLL_DEBUG_INFO, *LPUNLOAD_DLL_DEBUG_INFO;

  typedef struct _OUTPUT_DEBUG_STRING_INFO {
    LPSTR lpDebugStringData;
    WORD fUnicode;
    WORD nDebugStringLength;
  } OUTPUT_DEBUG_STRING_INFO, *LPOUTPUT_DEBUG_STRING_INFO;

  typedef struct _RIP_INFO {
    DWORD dwError;
    DWORD dwType;
  } RIP_INFO, *LPRIP_INFO;

  typedef struct _DEBUG_EVENT {
    DWORD dwDebugEventCode;
    DWORD dwProcessId;
    DWORD dwThreadId;
    union {
      EXCEPTION_DEBUG_INFO Exception;
      CREATE_THREAD_DEBUG_INFO CreateThread;
      CREATE_PROCESS_DEBUG_INFO CreateProcessInfo;
      EXIT_THREAD_DEBUG_INFO ExitThread;
      EXIT_PROCESS_DEBUG_INFO ExitProcess;
      LOAD_DLL_DEBUG_INFO LoadDll;
      UNLOAD_DLL_DEBUG_INFO UnloadDll;
      OUTPUT_DEBUG_STRING_INFO DebugString;
      RIP_INFO RipInfo;
    } u;
  } DEBUG_EVENT, *LPDEBUG_EVENT;

#ifndef __WIDL__
  typedef PCONTEXT LPCONTEXT;
#endif

#define STILL_ACTIVE STATUS_PENDING
#define EXCEPTION_ACCESS_VIOLATION STATUS_ACCESS_VIOLATION
#define EXCEPTION_DATATYPE_MISALIGNMENT STATUS_DATATYPE_MISALIGNMENT
#define EXCEPTION_BREAKPOINT STATUS_BREAKPOINT
#define EXCEPTION_SINGLE_STEP STATUS_SINGLE_STEP
#define EXCEPTION_ARRAY_BOUNDS_EXCEEDED STATUS_ARRAY_BOUNDS_EXCEEDED
#define EXCEPTION_FLT_DENORMAL_OPERAND STATUS_FLOAT_DENORMAL_OPERAND
#define EXCEPTION_FLT_DIVIDE_BY_ZERO STATUS_FLOAT_DIVIDE_BY_ZERO
#define EXCEPTION_FLT_INEXACT_RESULT STATUS_FLOAT_INEXACT_RESULT
#define EXCEPTION_FLT_INVALID_OPERATION STATUS_FLOAT_INVALID_OPERATION
#define EXCEPTION_FLT_OVERFLOW STATUS_FLOAT_OVERFLOW
#define EXCEPTION_FLT_STACK_CHECK STATUS_FLOAT_STACK_CHECK
#define EXCEPTION_FLT_UNDERFLOW STATUS_FLOAT_UNDERFLOW
#define EXCEPTION_INT_DIVIDE_BY_ZERO STATUS_INTEGER_DIVIDE_BY_ZERO
#define EXCEPTION_INT_OVERFLOW STATUS_INTEGER_OVERFLOW
#define EXCEPTION_PRIV_INSTRUCTION STATUS_PRIVILEGED_INSTRUCTION
#define EXCEPTION_IN_PAGE_ERROR STATUS_IN_PAGE_ERROR
#define EXCEPTION_ILLEGAL_INSTRUCTION STATUS_ILLEGAL_INSTRUCTION
#define EXCEPTION_NONCONTINUABLE_EXCEPTION STATUS_NONCONTINUABLE_EXCEPTION
#define EXCEPTION_STACK_OVERFLOW STATUS_STACK_OVERFLOW
#define EXCEPTION_INVALID_DISPOSITION STATUS_INVALID_DISPOSITION
#define EXCEPTION_GUARD_PAGE STATUS_GUARD_PAGE_VIOLATION
#define EXCEPTION_INVALID_HANDLE STATUS_INVALID_HANDLE
#define EXCEPTION_POSSIBLE_DEADLOCK STATUS_POSSIBLE_DEADLOCK
#define CONTROL_C_EXIT STATUS_CONTROL_C_EXIT

#define LMEM_FIXED 0x0
#define LMEM_MOVEABLE 0x2
#define LMEM_NOCOMPACT 0x10
#define LMEM_NODISCARD 0x20
#define LMEM_ZEROINIT 0x40
#define LMEM_MODIFY 0x80
#define LMEM_DISCARDABLE 0xf00
#define LMEM_VALID_FLAGS 0xf72
#define LMEM_INVALID_HANDLE 0x8000

#define LHND (LMEM_MOVEABLE | LMEM_ZEROINIT)
#define LPTR (LMEM_FIXED | LMEM_ZEROINIT)

#define NONZEROLHND (LMEM_MOVEABLE)
#define NONZEROLPTR (LMEM_FIXED)

#define LocalDiscard(h) LocalReAlloc ((h), 0, LMEM_MOVEABLE)

#define LMEM_DISCARDED 0x4000
#define LMEM_LOCKCOUNT 0xff

#define NUMA_NO_PREFERRED_NODE ((DWORD) -1)

#ifdef __cplusplus
}
#endif
#endif
