usingnamespace @import("bits.zig");

pub extern "kernel32" stdcallcc fn AddVectoredExceptionHandler(First: c_ulong, Handler: ?VECTORED_EXCEPTION_HANDLER) ?*c_void;
pub extern "kernel32" stdcallcc fn RemoveVectoredExceptionHandler(Handle: HANDLE) c_ulong;

pub extern "kernel32" stdcallcc fn CancelIoEx(hFile: HANDLE, lpOverlapped: LPOVERLAPPED) BOOL;

pub extern "kernel32" stdcallcc fn CloseHandle(hObject: HANDLE) BOOL;

pub extern "kernel32" stdcallcc fn CreateDirectoryW(lpPathName: [*]const u16, lpSecurityAttributes: ?*SECURITY_ATTRIBUTES) BOOL;

pub extern "kernel32" stdcallcc fn CreateFileW(
    lpFileName: [*]const u16, // TODO null terminated pointer type
    dwDesiredAccess: DWORD,
    dwShareMode: DWORD,
    lpSecurityAttributes: ?LPSECURITY_ATTRIBUTES,
    dwCreationDisposition: DWORD,
    dwFlagsAndAttributes: DWORD,
    hTemplateFile: ?HANDLE,
) HANDLE;

pub extern "kernel32" stdcallcc fn CreatePipe(
    hReadPipe: *HANDLE,
    hWritePipe: *HANDLE,
    lpPipeAttributes: *const SECURITY_ATTRIBUTES,
    nSize: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn CreateProcessW(
    lpApplicationName: ?LPWSTR,
    lpCommandLine: LPWSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?*c_void,
    lpCurrentDirectory: ?LPWSTR,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) BOOL;

pub extern "kernel32" stdcallcc fn CreateSymbolicLinkW(lpSymlinkFileName: [*]const u16, lpTargetFileName: [*]const u16, dwFlags: DWORD) BOOLEAN;

pub extern "kernel32" stdcallcc fn CreateIoCompletionPort(FileHandle: HANDLE, ExistingCompletionPort: ?HANDLE, CompletionKey: ULONG_PTR, NumberOfConcurrentThreads: DWORD) ?HANDLE;

pub extern "kernel32" stdcallcc fn CreateThread(lpThreadAttributes: ?LPSECURITY_ATTRIBUTES, dwStackSize: SIZE_T, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: ?LPVOID, dwCreationFlags: DWORD, lpThreadId: ?LPDWORD) ?HANDLE;

pub extern "kernel32" stdcallcc fn DeviceIoControl(
    h: HANDLE,
    dwIoControlCode: DWORD,
    lpInBuffer: ?*const c_void,
    nInBufferSize: DWORD,
    lpOutBuffer: ?LPVOID,
    nOutBufferSize: DWORD,
    lpBytesReturned: LPDWORD,
    lpOverlapped: ?*OVERLAPPED,
) BOOL;

pub extern "kernel32" stdcallcc fn DeleteFileW(lpFileName: [*]const u16) BOOL;

pub extern "kernel32" stdcallcc fn DuplicateHandle(hSourceProcessHandle: HANDLE, hSourceHandle: HANDLE, hTargetProcessHandle: HANDLE, lpTargetHandle: *HANDLE, dwDesiredAccess: DWORD, bInheritHandle: BOOL, dwOptions: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn ExitProcess(exit_code: UINT) noreturn;

pub extern "kernel32" stdcallcc fn FindFirstFileW(lpFileName: [*]const u16, lpFindFileData: *WIN32_FIND_DATAW) HANDLE;
pub extern "kernel32" stdcallcc fn FindClose(hFindFile: HANDLE) BOOL;
pub extern "kernel32" stdcallcc fn FindNextFileW(hFindFile: HANDLE, lpFindFileData: *WIN32_FIND_DATAW) BOOL;

pub extern "kernel32" stdcallcc fn FormatMessageW(dwFlags: DWORD, lpSource: ?LPVOID, dwMessageId: DWORD, dwLanguageId: DWORD, lpBuffer: LPWSTR, nSize: DWORD, Arguments: ?*va_list) DWORD;

pub extern "kernel32" stdcallcc fn FreeEnvironmentStringsW(penv: [*]u16) BOOL;

pub extern "kernel32" stdcallcc fn GetCommandLineA() LPSTR;

pub extern "kernel32" stdcallcc fn GetConsoleMode(in_hConsoleHandle: HANDLE, out_lpMode: *DWORD) BOOL;

pub extern "kernel32" stdcallcc fn GetConsoleScreenBufferInfo(hConsoleOutput: HANDLE, lpConsoleScreenBufferInfo: *CONSOLE_SCREEN_BUFFER_INFO) BOOL;

pub extern "kernel32" stdcallcc fn GetCurrentDirectoryW(nBufferLength: DWORD, lpBuffer: ?[*]WCHAR) DWORD;

pub extern "kernel32" stdcallcc fn GetCurrentThread() HANDLE;
pub extern "kernel32" stdcallcc fn GetCurrentThreadId() DWORD;

pub extern "kernel32" stdcallcc fn GetEnvironmentStringsW() ?[*]u16;

pub extern "kernel32" stdcallcc fn GetEnvironmentVariableW(lpName: LPWSTR, lpBuffer: LPWSTR, nSize: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn GetExitCodeProcess(hProcess: HANDLE, lpExitCode: *DWORD) BOOL;

pub extern "kernel32" stdcallcc fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn GetFileAttributesW(lpFileName: [*]const WCHAR) DWORD;

pub extern "kernel32" stdcallcc fn GetModuleFileNameW(hModule: ?HMODULE, lpFilename: [*]u16, nSize: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn GetModuleHandleW(lpModuleName: ?[*]const WCHAR) HMODULE;

pub extern "kernel32" stdcallcc fn GetLastError() DWORD;

pub extern "kernel32" stdcallcc fn GetFileInformationByHandle(
    hFile: HANDLE,
    lpFileInformation: *BY_HANDLE_FILE_INFORMATION,
) BOOL;

pub extern "kernel32" stdcallcc fn GetFileInformationByHandleEx(
    in_hFile: HANDLE,
    in_FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
    out_lpFileInformation: *c_void,
    in_dwBufferSize: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn GetFinalPathNameByHandleW(
    hFile: HANDLE,
    lpszFilePath: [*]u16,
    cchFilePath: DWORD,
    dwFlags: DWORD,
) DWORD;

pub extern "kernel32" stdcallcc fn GetOverlappedResult(hFile: HANDLE, lpOverlapped: *OVERLAPPED, lpNumberOfBytesTransferred: *DWORD, bWait: BOOL) BOOL;

pub extern "kernel32" stdcallcc fn GetProcessHeap() ?HANDLE;
pub extern "kernel32" stdcallcc fn GetQueuedCompletionStatus(CompletionPort: HANDLE, lpNumberOfBytesTransferred: LPDWORD, lpCompletionKey: *ULONG_PTR, lpOverlapped: *?*OVERLAPPED, dwMilliseconds: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn GetSystemInfo(lpSystemInfo: *SYSTEM_INFO) void;
pub extern "kernel32" stdcallcc fn GetSystemTimeAsFileTime(*FILETIME) void;

pub extern "kernel32" stdcallcc fn HeapCreate(flOptions: DWORD, dwInitialSize: SIZE_T, dwMaximumSize: SIZE_T) ?HANDLE;
pub extern "kernel32" stdcallcc fn HeapDestroy(hHeap: HANDLE) BOOL;
pub extern "kernel32" stdcallcc fn HeapReAlloc(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void, dwBytes: SIZE_T) ?*c_void;
pub extern "kernel32" stdcallcc fn HeapSize(hHeap: HANDLE, dwFlags: DWORD, lpMem: *const c_void) SIZE_T;
pub extern "kernel32" stdcallcc fn HeapCompact(hHeap: HANDLE, dwFlags: DWORD) SIZE_T;
pub extern "kernel32" stdcallcc fn HeapSummary(hHeap: HANDLE, dwFlags: DWORD, lpSummary: LPHEAP_SUMMARY) BOOL;

pub extern "kernel32" stdcallcc fn GetStdHandle(in_nStdHandle: DWORD) ?HANDLE;

pub extern "kernel32" stdcallcc fn HeapAlloc(hHeap: HANDLE, dwFlags: DWORD, dwBytes: SIZE_T) ?*c_void;

pub extern "kernel32" stdcallcc fn HeapFree(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void) BOOL;

pub extern "kernel32" stdcallcc fn HeapValidate(hHeap: HANDLE, dwFlags: DWORD, lpMem: ?*const c_void) BOOL;

pub extern "kernel32" stdcallcc fn VirtualAlloc(lpAddress: ?LPVOID, dwSize: SIZE_T, flAllocationType: DWORD, flProtect: DWORD) ?LPVOID;
pub extern "kernel32" stdcallcc fn VirtualFree(lpAddress: ?LPVOID, dwSize: SIZE_T, dwFreeType: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn MoveFileExW(
    lpExistingFileName: [*]const u16,
    lpNewFileName: [*]const u16,
    dwFlags: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn PostQueuedCompletionStatus(CompletionPort: HANDLE, dwNumberOfBytesTransferred: DWORD, dwCompletionKey: ULONG_PTR, lpOverlapped: ?*OVERLAPPED) BOOL;

pub extern "kernel32" stdcallcc fn QueryPerformanceCounter(lpPerformanceCount: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn QueryPerformanceFrequency(lpFrequency: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn ReadDirectoryChangesW(
    hDirectory: HANDLE,
    lpBuffer: [*]align(@alignOf(FILE_NOTIFY_INFORMATION)) u8,
    nBufferLength: DWORD,
    bWatchSubtree: BOOL,
    dwNotifyFilter: DWORD,
    lpBytesReturned: ?*DWORD,
    lpOverlapped: ?*OVERLAPPED,
    lpCompletionRoutine: LPOVERLAPPED_COMPLETION_ROUTINE,
) BOOL;

pub extern "kernel32" stdcallcc fn ReadFile(
    in_hFile: HANDLE,
    out_lpBuffer: [*]u8,
    in_nNumberOfBytesToRead: DWORD,
    out_lpNumberOfBytesRead: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) BOOL;

pub extern "kernel32" stdcallcc fn RemoveDirectoryW(lpPathName: [*]const u16) BOOL;

pub extern "kernel32" stdcallcc fn SetConsoleTextAttribute(hConsoleOutput: HANDLE, wAttributes: WORD) BOOL;

pub extern "kernel32" stdcallcc fn SetFilePointerEx(
    in_fFile: HANDLE,
    in_liDistanceToMove: LARGE_INTEGER,
    out_opt_ldNewFilePointer: ?*LARGE_INTEGER,
    in_dwMoveMethod: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn SetFileTime(
    hFile: HANDLE,
    lpCreationTime: ?*const FILETIME,
    lpLastAccessTime: ?*const FILETIME,
    lpLastWriteTime: ?*const FILETIME,
) BOOL;

pub extern "kernel32" stdcallcc fn SetHandleInformation(hObject: HANDLE, dwMask: DWORD, dwFlags: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn Sleep(dwMilliseconds: DWORD) void;

pub extern "kernel32" stdcallcc fn SwitchToThread() BOOL;

pub extern "kernel32" stdcallcc fn TerminateProcess(hProcess: HANDLE, uExitCode: UINT) BOOL;

pub extern "kernel32" stdcallcc fn TlsAlloc() DWORD;

pub extern "kernel32" stdcallcc fn TlsFree(dwTlsIndex: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn WaitForSingleObjectEx(hHandle: HANDLE, dwMilliseconds: DWORD, bAlertable: BOOL) DWORD;

pub extern "kernel32" stdcallcc fn WriteFile(
    in_hFile: HANDLE,
    in_lpBuffer: [*]const u8,
    in_nNumberOfBytesToWrite: DWORD,
    out_lpNumberOfBytesWritten: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) BOOL;

pub extern "kernel32" stdcallcc fn WriteFileEx(hFile: HANDLE, lpBuffer: [*]const u8, nNumberOfBytesToWrite: DWORD, lpOverlapped: LPOVERLAPPED, lpCompletionRoutine: LPOVERLAPPED_COMPLETION_ROUTINE) BOOL;

pub extern "kernel32" stdcallcc fn LoadLibraryW(lpLibFileName: [*]const u16) ?HMODULE;

pub extern "kernel32" stdcallcc fn GetProcAddress(hModule: HMODULE, lpProcName: [*]const u8) ?FARPROC;

pub extern "kernel32" stdcallcc fn FreeLibrary(hModule: HMODULE) BOOL;

pub extern "kernel32" stdcallcc fn InitializeCriticalSection(lpCriticalSection: *CRITICAL_SECTION) void;
pub extern "kernel32" stdcallcc fn EnterCriticalSection(lpCriticalSection: *CRITICAL_SECTION) void;
pub extern "kernel32" stdcallcc fn LeaveCriticalSection(lpCriticalSection: *CRITICAL_SECTION) void;
pub extern "kernel32" stdcallcc fn DeleteCriticalSection(lpCriticalSection: *CRITICAL_SECTION) void;

pub extern "kernel32" stdcallcc fn InitOnceExecuteOnce(InitOnce: *INIT_ONCE, InitFn: INIT_ONCE_FN, Parameter: ?*c_void, Context: ?*c_void) BOOL;
