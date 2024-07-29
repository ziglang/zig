const std = @import("../../std.zig");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const BOOLEAN = windows.BOOLEAN;
const CONDITION_VARIABLE = windows.CONDITION_VARIABLE;
const CONSOLE_SCREEN_BUFFER_INFO = windows.CONSOLE_SCREEN_BUFFER_INFO;
const COORD = windows.COORD;
const CRITICAL_SECTION = windows.CRITICAL_SECTION;
const DWORD = windows.DWORD;
const FARPROC = windows.FARPROC;
const FILETIME = windows.FILETIME;
const HANDLE = windows.HANDLE;
const HANDLER_ROUTINE = windows.HANDLER_ROUTINE;
const HLOCAL = windows.HLOCAL;
const HMODULE = windows.HMODULE;
const INIT_ONCE = windows.INIT_ONCE;
const INIT_ONCE_FN = windows.INIT_ONCE_FN;
const LARGE_INTEGER = windows.LARGE_INTEGER;
const LPCSTR = windows.LPCSTR;
const LPCVOID = windows.LPCVOID;
const LPCWSTR = windows.LPCWSTR;
const LPTHREAD_START_ROUTINE = windows.LPTHREAD_START_ROUTINE;
const LPVOID = windows.LPVOID;
const LPWSTR = windows.LPWSTR;
const MODULEENTRY32 = windows.MODULEENTRY32;
const OVERLAPPED = windows.OVERLAPPED;
const OVERLAPPED_ENTRY = windows.OVERLAPPED_ENTRY;
const PMEMORY_BASIC_INFORMATION = windows.PMEMORY_BASIC_INFORMATION;
const PROCESS_INFORMATION = windows.PROCESS_INFORMATION;
const SECURITY_ATTRIBUTES = windows.SECURITY_ATTRIBUTES;
const SIZE_T = windows.SIZE_T;
const SRWLOCK = windows.SRWLOCK;
const STARTUPINFOW = windows.STARTUPINFOW;
const UCHAR = windows.UCHAR;
const UINT = windows.UINT;
const ULONG = windows.ULONG;
const ULONG_PTR = windows.ULONG_PTR;
const va_list = windows.va_list;
const VECTORED_EXCEPTION_HANDLER = windows.VECTORED_EXCEPTION_HANDLER;
const WCHAR = windows.WCHAR;
const WIN32_FIND_DATAW = windows.WIN32_FIND_DATAW;
const Win32Error = windows.Win32Error;
const WINAPI = windows.WINAPI;
const WORD = windows.WORD;

// I/O - Filesystem

pub extern "kernel32" fn ReadDirectoryChangesW(
    hDirectory: windows.HANDLE,
    lpBuffer: [*]align(@alignOf(windows.FILE_NOTIFY_INFORMATION)) u8,
    nBufferLength: windows.DWORD,
    bWatchSubtree: windows.BOOL,
    dwNotifyFilter: windows.FileNotifyChangeFilter,
    lpBytesReturned: ?*windows.DWORD,
    lpOverlapped: ?*windows.OVERLAPPED,
    lpCompletionRoutine: windows.LPOVERLAPPED_COMPLETION_ROUTINE,
) callconv(windows.WINAPI) windows.BOOL;

// TODO: Wrapper around NtCancelIoFile.
pub extern "kernel32" fn CancelIo(
    hFile: HANDLE,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtCancelIoFileEx.
pub extern "kernel32" fn CancelIoEx(
    hFile: HANDLE,
    lpOverlapped: ?*OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn CreateFileW(
    lpFileName: LPCWSTR,
    dwDesiredAccess: DWORD,
    dwShareMode: DWORD,
    lpSecurityAttributes: ?*SECURITY_ATTRIBUTES,
    dwCreationDisposition: DWORD,
    dwFlagsAndAttributes: DWORD,
    hTemplateFile: ?HANDLE,
) callconv(WINAPI) HANDLE;

// TODO A bunch of logic around NtCreateNamedPipe
pub extern "kernel32" fn CreateNamedPipeW(
    lpName: LPCWSTR,
    dwOpenMode: DWORD,
    dwPipeMode: DWORD,
    nMaxInstances: DWORD,
    nOutBufferSize: DWORD,
    nInBufferSize: DWORD,
    nDefaultTimeOut: DWORD,
    lpSecurityAttributes: ?*const SECURITY_ATTRIBUTES,
) callconv(WINAPI) HANDLE;

pub extern "kernel32" fn FindFirstFileW(
    lpFileName: LPCWSTR,
    lpFindFileData: *WIN32_FIND_DATAW,
) callconv(WINAPI) HANDLE;

pub extern "kernel32" fn FindClose(
    hFindFile: HANDLE,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around RtlGetFullPathName_UEx
pub extern "kernel32" fn GetFullPathNameW(
    lpFileName: LPCWSTR,
    nBufferLength: DWORD,
    lpBuffer: LPWSTR,
    lpFilePart: ?*?LPWSTR,
) callconv(WINAPI) DWORD;

// TODO: Matches `STD_*_HANDLE` to peb().ProcessParameters.Standard*
pub extern "kernel32" fn GetStdHandle(
    nStdHandle: DWORD,
) callconv(WINAPI) ?HANDLE;

pub extern "kernel32" fn MoveFileExW(
    lpExistingFileName: LPCWSTR,
    lpNewFileName: LPCWSTR,
    dwFlags: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtSetInformationFile + `FILE_POSITION_INFORMATION`.
//  `FILE_STANDARD_INFORMATION` is also used if dwMoveMethod is `FILE_END`
pub extern "kernel32" fn SetFilePointerEx(
    hFile: HANDLE,
    liDistanceToMove: LARGE_INTEGER,
    lpNewFilePointer: ?*LARGE_INTEGER,
    dwMoveMethod: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtSetInformationFile + `FILE_BASIC_INFORMATION`
pub extern "kernel32" fn SetFileTime(
    hFile: HANDLE,
    lpCreationTime: ?*const FILETIME,
    lpLastAccessTime: ?*const FILETIME,
    lpLastWriteTime: ?*const FILETIME,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn WriteFile(
    in_hFile: HANDLE,
    in_lpBuffer: [*]const u8,
    in_nNumberOfBytesToWrite: DWORD,
    out_lpNumberOfBytesWritten: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) callconv(WINAPI) BOOL;

// TODO: wrapper for NtQueryInformationFile + `FILE_STANDARD_INFORMATION`
pub extern "kernel32" fn GetFileSizeEx(
    hFile: HANDLE,
    lpFileSize: *LARGE_INTEGER,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around GetStdHandle + NtFlushBuffersFile.
pub extern "kernel32" fn FlushFileBuffers(
    hFile: HANDLE,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtSetInformationFile + `FILE_IO_COMPLETION_NOTIFICATION_INFORMATION`.
pub extern "kernel32" fn SetFileCompletionNotificationModes(
    FileHandle: HANDLE,
    Flags: UCHAR,
) callconv(WINAPI) BOOL;

// TODO: `RtlGetCurrentDirectory_U(nBufferLength * 2, lpBuffer)`
pub extern "kernel32" fn GetCurrentDirectoryW(
    nBufferLength: DWORD,
    lpBuffer: ?[*]WCHAR,
) callconv(WINAPI) DWORD;

// TODO: RtlDosPathNameToNtPathNameU_WithStatus + NtQueryAttributesFile.
pub extern "kernel32" fn GetFileAttributesW(
    lpFileName: LPCWSTR,
) callconv(WINAPI) DWORD;

pub extern "kernel32" fn ReadFile(
    hFile: HANDLE,
    lpBuffer: LPVOID,
    nNumberOfBytesToRead: DWORD,
    lpNumberOfBytesRead: ?*DWORD,
    lpOverlapped: ?*OVERLAPPED,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn GetSystemDirectoryW(
    lpBuffer: LPWSTR,
    uSize: UINT,
) callconv(WINAPI) UINT;

// I/O - Kernel Objects

// TODO: Wrapper around NtCreateEvent.
pub extern "kernel32" fn CreateEventExW(
    lpEventAttributes: ?*SECURITY_ATTRIBUTES,
    lpName: ?LPCWSTR,
    dwFlags: DWORD,
    dwDesiredAccess: DWORD,
) callconv(WINAPI) ?HANDLE;

// TODO: Wrapper around GetStdHandle + NtDuplicateObject.
pub extern "kernel32" fn DuplicateHandle(
    hSourceProcessHandle: HANDLE,
    hSourceHandle: HANDLE,
    hTargetProcessHandle: HANDLE,
    lpTargetHandle: *HANDLE,
    dwDesiredAccess: DWORD,
    bInheritHandle: BOOL,
    dwOptions: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around GetStdHandle + NtQueryObject + NtSetInformationObject with .ObjectHandleFlagInformation.
pub extern "kernel32" fn SetHandleInformation(
    hObject: HANDLE,
    dwMask: DWORD,
    dwFlags: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtRemoveIoCompletion.
pub extern "kernel32" fn GetQueuedCompletionStatus(
    CompletionPort: HANDLE,
    lpNumberOfBytesTransferred: *DWORD,
    lpCompletionKey: *ULONG_PTR,
    lpOverlapped: *?*OVERLAPPED,
    dwMilliseconds: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtRemoveIoCompletionEx.
pub extern "kernel32" fn GetQueuedCompletionStatusEx(
    CompletionPort: HANDLE,
    lpCompletionPortEntries: [*]OVERLAPPED_ENTRY,
    ulCount: ULONG,
    ulNumEntriesRemoved: *ULONG,
    dwMilliseconds: DWORD,
    fAlertable: BOOL,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtSetIoCompletion with `IoStatus = .SUCCESS`.
pub extern "kernel32" fn PostQueuedCompletionStatus(
    CompletionPort: HANDLE,
    dwNumberOfBytesTransferred: DWORD,
    dwCompletionKey: ULONG_PTR,
    lpOverlapped: ?*OVERLAPPED,
) callconv(WINAPI) BOOL;

// TODO:
// GetOverlappedResultEx with bAlertable=false, which calls: GetStdHandle + WaitForSingleObjectEx.
// Uses the SwitchBack system to run implementations for older programs; Do we care about this?
pub extern "kernel32" fn GetOverlappedResult(
    hFile: HANDLE,
    lpOverlapped: *OVERLAPPED,
    lpNumberOfBytesTransferred: *DWORD,
    bWait: BOOL,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtCreateIoCompletion + NtSetInformationFile with FILE_COMPLETION_INFORMATION.
// This would be better splitting into two functions.
pub extern "kernel32" fn CreateIoCompletionPort(
    FileHandle: HANDLE,
    ExistingCompletionPort: ?HANDLE,
    CompletionKey: ULONG_PTR,
    NumberOfConcurrentThreads: DWORD,
) callconv(WINAPI) ?HANDLE;

// TODO: Forwarder to NtAddVectoredExceptionHandler.
pub extern "kernel32" fn AddVectoredExceptionHandler(
    First: ULONG,
    Handler: ?VECTORED_EXCEPTION_HANDLER,
) callconv(WINAPI) ?LPVOID;

// TODO: Forwarder to NtRemoveVectoredExceptionHandler.
pub extern "kernel32" fn RemoveVectoredExceptionHandler(
    Handle: HANDLE,
) callconv(WINAPI) ULONG;

// TODO: Wrapper around RtlReportSilentProcessExit + NtTerminateProcess.
pub extern "kernel32" fn TerminateProcess(
    hProcess: HANDLE,
    uExitCode: UINT,
) callconv(WINAPI) BOOL;

// TODO: WaitForSingleObjectEx with bAlertable=false.
pub extern "kernel32" fn WaitForSingleObject(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
) callconv(WINAPI) DWORD;

// TODO: Wrapper for GetStdHandle + NtWaitForSingleObject.
// Sets up an activation context before calling NtWaitForSingleObject.
pub extern "kernel32" fn WaitForSingleObjectEx(
    hHandle: HANDLE,
    dwMilliseconds: DWORD,
    bAlertable: BOOL,
) callconv(WINAPI) DWORD;

// TODO: WaitForMultipleObjectsEx with alertable=false
pub extern "kernel32" fn WaitForMultipleObjects(
    nCount: DWORD,
    lpHandle: [*]const HANDLE,
    bWaitAll: BOOL,
    dwMilliseconds: DWORD,
) callconv(WINAPI) DWORD;

// TODO: Wrapper around NtWaitForMultipleObjects.
pub extern "kernel32" fn WaitForMultipleObjectsEx(
    nCount: DWORD,
    lpHandle: [*]const HANDLE,
    bWaitAll: BOOL,
    dwMilliseconds: DWORD,
    bAlertable: BOOL,
) callconv(WINAPI) DWORD;

// Process Management

pub extern "kernel32" fn CreateProcessW(
    lpApplicationName: ?LPCWSTR,
    lpCommandLine: ?LPWSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?LPVOID,
    lpCurrentDirectory: ?LPCWSTR,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) callconv(WINAPI) BOOL;

// TODO: Fowarder to RtlExitUserProcess.
pub extern "kernel32" fn ExitProcess(
    exit_code: UINT,
) callconv(WINAPI) noreturn;

// TODO: SleepEx with bAlertable=false.
pub extern "kernel32" fn Sleep(
    dwMilliseconds: DWORD,
) callconv(WINAPI) void;

// TODO: Wrapper around NtQueryInformationProcess with `PROCESS_BASIC_INFORMATION`.
pub extern "kernel32" fn GetExitCodeProcess(
    hProcess: HANDLE,
    lpExitCode: *DWORD,
) callconv(WINAPI) BOOL;

// TODO: Already a wrapper for this, see `windows.GetCurrentProcess`.
pub extern "kernel32" fn GetCurrentProcess() callconv(WINAPI) HANDLE;

// TODO: memcpy peb().ProcessParameters.Environment, mem.span(0). Requires locking the PEB.
pub extern "kernel32" fn GetEnvironmentStringsW() callconv(WINAPI) ?LPWSTR;

// TODO: RtlFreeHeap on the output of GetEnvironmentStringsW.
pub extern "kernel32" fn FreeEnvironmentStringsW(
    penv: LPWSTR,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around RtlQueryEnvironmentVariable.
pub extern "kernel32" fn GetEnvironmentVariableW(
    lpName: ?LPCWSTR,
    lpBuffer: ?[*]WCHAR,
    nSize: DWORD,
) callconv(WINAPI) DWORD;

// TODO: Wrapper around RtlSetEnvironmentVar.
pub extern "kernel32" fn SetEnvironmentVariableW(
    lpName: LPCWSTR,
    lpValue: ?LPCWSTR,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn CreateToolhelp32Snapshot(
    dwFlags: DWORD,
    th32ProcessID: DWORD,
) callconv(WINAPI) HANDLE;

// Threading

// TODO: Already a wrapper for this, see `windows.GetCurrentThreadId`.
pub extern "kernel32" fn GetCurrentThreadId() callconv(WINAPI) DWORD;

// TODO: CreateRemoteThread with hProcess=NtCurrentProcess().
pub extern "kernel32" fn CreateThread(
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    dwStackSize: SIZE_T,
    lpStartAddress: LPTHREAD_START_ROUTINE,
    lpParameter: ?LPVOID,
    dwCreationFlags: DWORD,
    lpThreadId: ?*DWORD,
) callconv(WINAPI) ?HANDLE;

// TODO: Wrapper around RtlDelayExecution.
pub extern "kernel32" fn SwitchToThread() callconv(WINAPI) BOOL;

// Locks, critical sections, initializers

// TODO: Forwarder to RtlInitializeCriticalSection
pub extern "kernel32" fn InitializeCriticalSection(
    lpCriticalSection: *CRITICAL_SECTION,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlEnterCriticalSection
pub extern "kernel32" fn EnterCriticalSection(
    lpCriticalSection: *CRITICAL_SECTION,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlLeaveCriticalSection
pub extern "kernel32" fn LeaveCriticalSection(
    lpCriticalSection: *CRITICAL_SECTION,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlDeleteCriticalSection
pub extern "kernel32" fn DeleteCriticalSection(
    lpCriticalSection: *CRITICAL_SECTION,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlTryAcquireSRWLockExclusive
pub extern "kernel32" fn TryAcquireSRWLockExclusive(
    SRWLock: *SRWLOCK,
) callconv(WINAPI) BOOLEAN;

// TODO: Forwarder to RtlAcquireSRWLockExclusive
pub extern "kernel32" fn AcquireSRWLockExclusive(
    SRWLock: *SRWLOCK,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlReleaseSRWLockExclusive
pub extern "kernel32" fn ReleaseSRWLockExclusive(
    SRWLock: *SRWLOCK,
) callconv(WINAPI) void;

pub extern "kernel32" fn InitOnceExecuteOnce(
    InitOnce: *INIT_ONCE,
    InitFn: INIT_ONCE_FN,
    Parameter: ?*anyopaque,
    Context: ?*anyopaque,
) callconv(WINAPI) BOOL;

// TODO: Forwarder to RtlWakeConditionVariable
pub extern "kernel32" fn WakeConditionVariable(
    ConditionVariable: *CONDITION_VARIABLE,
) callconv(WINAPI) void;

// TODO: Forwarder to RtlWakeAllConditionVariable
pub extern "kernel32" fn WakeAllConditionVariable(
    ConditionVariable: *CONDITION_VARIABLE,
) callconv(WINAPI) void;

// TODO:
//  - dwMilliseconds -> LARGE_INTEGER.
//  - RtlSleepConditionVariableSRW
//  - return rc != .TIMEOUT
pub extern "kernel32" fn SleepConditionVariableSRW(
    ConditionVariable: *CONDITION_VARIABLE,
    SRWLock: *SRWLOCK,
    dwMilliseconds: DWORD,
    Flags: ULONG,
) callconv(WINAPI) BOOL;

// Console management

pub extern "kernel32" fn GetConsoleMode(
    hConsoleHandle: HANDLE,
    lpMode: *DWORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn SetConsoleMode(
    hConsoleHandle: HANDLE,
    dwMode: DWORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn GetConsoleScreenBufferInfo(
    hConsoleOutput: HANDLE,
    lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn SetConsoleTextAttribute(
    hConsoleOutput: HANDLE,
    wAttributes: WORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn SetConsoleCtrlHandler(
    HandlerRoutine: ?HANDLER_ROUTINE,
    Add: BOOL,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn SetConsoleOutputCP(
    wCodePageID: UINT,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn GetConsoleOutputCP() callconv(WINAPI) UINT;

pub extern "kernel32" fn FillConsoleOutputAttribute(
    hConsoleOutput: HANDLE,
    wAttribute: WORD,
    nLength: DWORD,
    dwWriteCoord: COORD,
    lpNumberOfAttrsWritten: *DWORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn FillConsoleOutputCharacterW(
    hConsoleOutput: HANDLE,
    cCharacter: WCHAR,
    nLength: DWORD,
    dwWriteCoord: COORD,
    lpNumberOfCharsWritten: *DWORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn SetConsoleCursorPosition(
    hConsoleOutput: HANDLE,
    dwCursorPosition: COORD,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn WriteConsoleW(
    hConsoleOutput: HANDLE,
    lpBuffer: [*]const u16,
    nNumberOfCharsToWrite: DWORD,
    lpNumberOfCharsWritten: ?*DWORD,
    lpReserved: ?LPVOID,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn ReadConsoleOutputCharacterW(
    hConsoleOutput: HANDLE,
    lpCharacter: [*]u16,
    nLength: DWORD,
    dwReadCoord: COORD,
    lpNumberOfCharsRead: *DWORD,
) callconv(windows.WINAPI) BOOL;

// Memory Mapping/Allocation

// TODO: Wrapper around RtlCreateHeap.
pub extern "kernel32" fn HeapCreate(
    flOptions: DWORD,
    dwInitialSize: SIZE_T,
    dwMaximumSize: SIZE_T,
) callconv(WINAPI) ?HANDLE;

// TODO: Wrapper around RtlDestroyHeap (BOOLEAN -> BOOL).
pub extern "kernel32" fn HeapDestroy(
    hHeap: HANDLE,
) callconv(WINAPI) BOOL;

// TODO: Forwarder to RtlReAllocateHeap.
pub extern "kernel32" fn HeapReAlloc(
    hHeap: HANDLE,
    dwFlags: DWORD,
    lpMem: *anyopaque,
    dwBytes: SIZE_T,
) callconv(WINAPI) ?*anyopaque;

// TODO: Fowrarder to RtlAllocateHeap.
pub extern "kernel32" fn HeapAlloc(
    hHeap: HANDLE,
    dwFlags: DWORD,
    dwBytes: SIZE_T,
) callconv(WINAPI) ?*anyopaque;

// TODO: Fowrarder to RtlFreeHeap.
pub extern "kernel32" fn HeapFree(
    hHeap: HANDLE,
    dwFlags: DWORD,
    lpMem: LPVOID,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around RtlValidateHeap (BOOLEAN -> BOOL)
pub extern "kernel32" fn HeapValidate(
    hHeap: HANDLE,
    dwFlags: DWORD,
    lpMem: ?*const anyopaque,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtAllocateVirtualMemory.
pub extern "kernel32" fn VirtualAlloc(
    lpAddress: ?LPVOID,
    dwSize: SIZE_T,
    flAllocationType: DWORD,
    flProtect: DWORD,
) callconv(WINAPI) ?LPVOID;

// TODO: Wrapper around NtFreeVirtualMemory.
// If the return value is .INVALID_PAGE_PROTECTION, calls RtlFlushSecureMemoryCache and try again.
pub extern "kernel32" fn VirtualFree(
    lpAddress: ?LPVOID,
    dwSize: SIZE_T,
    dwFreeType: DWORD,
) callconv(WINAPI) BOOL;

// TODO: Wrapper around NtQueryVirtualMemory.
pub extern "kernel32" fn VirtualQuery(
    lpAddress: ?LPVOID,
    lpBuffer: PMEMORY_BASIC_INFORMATION,
    dwLength: SIZE_T,
) callconv(WINAPI) SIZE_T;

pub extern "kernel32" fn LocalFree(
    hMem: HLOCAL,
) callconv(WINAPI) ?HLOCAL;

// TODO: Getter for peb.ProcessHeap
pub extern "kernel32" fn GetProcessHeap() callconv(WINAPI) ?HANDLE;

// Code Libraries/Modules

// TODO: Wrapper around LdrGetDllFullName.
pub extern "kernel32" fn GetModuleFileNameW(
    hModule: ?HMODULE,
    lpFilename: [*]WCHAR,
    nSize: DWORD,
) callconv(WINAPI) DWORD;

extern "kernel32" fn K32GetModuleFileNameExW(
    hProcess: HANDLE,
    hModule: ?HMODULE,
    lpFilename: LPWSTR,
    nSize: DWORD,
) callconv(WINAPI) DWORD;
pub const GetModuleFileNameExW = K32GetModuleFileNameExW;

// TODO: Wrapper around ntdll.LdrGetDllHandle, which is a wrapper around LdrGetDllHandleEx
pub extern "kernel32" fn GetModuleHandleW(
    lpModuleName: ?LPCWSTR,
) callconv(WINAPI) ?HMODULE;

pub extern "kernel32" fn Module32First(
    hSnapshot: HANDLE,
    lpme: *MODULEENTRY32,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn Module32Next(
    hSnapshot: HANDLE,
    lpme: *MODULEENTRY32,
) callconv(WINAPI) BOOL;

pub extern "kernel32" fn LoadLibraryW(
    lpLibFileName: LPCWSTR,
) callconv(WINAPI) ?HMODULE;

pub extern "kernel32" fn LoadLibraryExW(
    lpLibFileName: LPCWSTR,
    hFile: ?HANDLE,
    dwFlags: DWORD,
) callconv(WINAPI) ?HMODULE;

pub extern "kernel32" fn GetProcAddress(
    hModule: HMODULE,
    lpProcName: LPCSTR,
) callconv(WINAPI) ?FARPROC;

pub extern "kernel32" fn FreeLibrary(
    hModule: HMODULE,
) callconv(WINAPI) BOOL;

// Error Management

pub extern "kernel32" fn FormatMessageW(
    dwFlags: DWORD,
    lpSource: ?LPCVOID,
    dwMessageId: Win32Error,
    dwLanguageId: DWORD,
    lpBuffer: LPWSTR,
    nSize: DWORD,
    Arguments: ?*va_list,
) callconv(WINAPI) DWORD;

// TODO: Getter for teb().LastErrorValue.
pub extern "kernel32" fn GetLastError() callconv(WINAPI) Win32Error;

// TODO: Wrapper around RtlSetLastWin32Error.
pub extern "kernel32" fn SetLastError(
    dwErrCode: Win32Error,
) callconv(WINAPI) void;

// Everything Else

// TODO:
//  Wrapper around KUSER_SHARED_DATA.SystemTime.
//  Much better to use NtQuerySystemTime or NtQuerySystemTimePrecise for guaranteed 0.1ns precision.
pub extern "kernel32" fn GetSystemTimeAsFileTime(
    lpSystemTimeAsFileTime: *FILETIME,
) callconv(WINAPI) void;
