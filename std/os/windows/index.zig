test "import" {
    _ = @import("util.zig");
}

pub const ERROR = @import("error.zig");

pub extern "advapi32" stdcallcc fn CryptAcquireContextA(
    phProv: *HCRYPTPROV,
    pszContainer: ?LPCSTR,
    pszProvider: ?LPCSTR,
    dwProvType: DWORD,
    dwFlags: DWORD,
) BOOL;

pub extern "advapi32" stdcallcc fn CryptReleaseContext(hProv: HCRYPTPROV, dwFlags: DWORD) BOOL;

pub extern "advapi32" stdcallcc fn CryptGenRandom(hProv: HCRYPTPROV, dwLen: DWORD, pbBuffer: [*]BYTE) BOOL;

pub extern "kernel32" stdcallcc fn CloseHandle(hObject: HANDLE) BOOL;

pub extern "kernel32" stdcallcc fn CreateDirectoryA(
    lpPathName: LPCSTR,
    lpSecurityAttributes: ?*SECURITY_ATTRIBUTES,
) BOOL;

pub extern "kernel32" stdcallcc fn CreateFileA(
    lpFileName: LPCSTR,
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

pub extern "kernel32" stdcallcc fn CreateProcessA(
    lpApplicationName: ?LPCSTR,
    lpCommandLine: LPSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?*c_void,
    lpCurrentDirectory: ?LPCSTR,
    lpStartupInfo: *STARTUPINFOA,
    lpProcessInformation: *PROCESS_INFORMATION,
) BOOL;

pub extern "kernel32" stdcallcc fn CreateSymbolicLinkA(
    lpSymlinkFileName: LPCSTR,
    lpTargetFileName: LPCSTR,
    dwFlags: DWORD,
) BOOLEAN;

pub extern "kernel32" stdcallcc fn CreateThread(lpThreadAttributes: ?LPSECURITY_ATTRIBUTES, dwStackSize: SIZE_T, lpStartAddress: LPTHREAD_START_ROUTINE, lpParameter: ?LPVOID, dwCreationFlags: DWORD, lpThreadId: ?LPDWORD) ?HANDLE;

pub extern "kernel32" stdcallcc fn DeleteFileA(lpFileName: LPCSTR) BOOL;

pub extern "kernel32" stdcallcc fn ExitProcess(exit_code: UINT) noreturn;

pub extern "kernel32" stdcallcc fn FindFirstFileA(lpFileName: LPCSTR, lpFindFileData: *WIN32_FIND_DATAA) HANDLE;
pub extern "kernel32" stdcallcc fn FindClose(hFindFile: HANDLE) BOOL;
pub extern "kernel32" stdcallcc fn FindNextFileA(hFindFile: HANDLE, lpFindFileData: *WIN32_FIND_DATAA) BOOL;

pub extern "kernel32" stdcallcc fn FreeEnvironmentStringsA(penv: [*]u8) BOOL;

pub extern "kernel32" stdcallcc fn GetCommandLineA() LPSTR;

pub extern "kernel32" stdcallcc fn GetConsoleMode(in_hConsoleHandle: HANDLE, out_lpMode: *DWORD) BOOL;

pub extern "kernel32" stdcallcc fn GetCurrentDirectoryA(nBufferLength: WORD, lpBuffer: ?LPSTR) DWORD;

pub extern "kernel32" stdcallcc fn GetEnvironmentStringsA() ?[*]u8;

pub extern "kernel32" stdcallcc fn GetEnvironmentVariableA(lpName: LPCSTR, lpBuffer: LPSTR, nSize: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn GetExitCodeProcess(hProcess: HANDLE, lpExitCode: *DWORD) BOOL;

pub extern "kernel32" stdcallcc fn GetFileSizeEx(hFile: HANDLE, lpFileSize: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn GetFileAttributesA(lpFileName: LPCSTR) DWORD;

pub extern "kernel32" stdcallcc fn GetModuleFileNameA(hModule: ?HMODULE, lpFilename: LPSTR, nSize: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn GetLastError() DWORD;

pub extern "kernel32" stdcallcc fn GetFileInformationByHandleEx(
    in_hFile: HANDLE,
    in_FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
    out_lpFileInformation: *c_void,
    in_dwBufferSize: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn GetFinalPathNameByHandleA(
    hFile: HANDLE,
    lpszFilePath: LPSTR,
    cchFilePath: DWORD,
    dwFlags: DWORD,
) DWORD;

pub extern "kernel32" stdcallcc fn GetProcessHeap() ?HANDLE;

pub extern "kernel32" stdcallcc fn GetSystemTimeAsFileTime(*FILETIME) void;

pub extern "kernel32" stdcallcc fn HeapCreate(flOptions: DWORD, dwInitialSize: SIZE_T, dwMaximumSize: SIZE_T) ?HANDLE;
pub extern "kernel32" stdcallcc fn HeapDestroy(hHeap: HANDLE) BOOL;
pub extern "kernel32" stdcallcc fn HeapReAlloc(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void, dwBytes: SIZE_T) ?*c_void;
pub extern "kernel32" stdcallcc fn HeapSize(hHeap: HANDLE, dwFlags: DWORD, lpMem: *const c_void) SIZE_T;
pub extern "kernel32" stdcallcc fn HeapValidate(hHeap: HANDLE, dwFlags: DWORD, lpMem: *const c_void) BOOL;
pub extern "kernel32" stdcallcc fn HeapCompact(hHeap: HANDLE, dwFlags: DWORD) SIZE_T;
pub extern "kernel32" stdcallcc fn HeapSummary(hHeap: HANDLE, dwFlags: DWORD, lpSummary: LPHEAP_SUMMARY) BOOL;

pub extern "kernel32" stdcallcc fn GetStdHandle(in_nStdHandle: DWORD) ?HANDLE;

pub extern "kernel32" stdcallcc fn HeapAlloc(hHeap: HANDLE, dwFlags: DWORD, dwBytes: SIZE_T) ?*c_void;

pub extern "kernel32" stdcallcc fn HeapFree(hHeap: HANDLE, dwFlags: DWORD, lpMem: *c_void) BOOL;

pub extern "kernel32" stdcallcc fn MoveFileExA(
    lpExistingFileName: LPCSTR,
    lpNewFileName: LPCSTR,
    dwFlags: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn QueryPerformanceCounter(lpPerformanceCount: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn QueryPerformanceFrequency(lpFrequency: *LARGE_INTEGER) BOOL;

pub extern "kernel32" stdcallcc fn ReadFile(
    in_hFile: HANDLE,
    out_lpBuffer: *c_void,
    in_nNumberOfBytesToRead: DWORD,
    out_lpNumberOfBytesRead: *DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) BOOL;

pub extern "kernel32" stdcallcc fn RemoveDirectoryA(lpPathName: LPCSTR) BOOL;

pub extern "kernel32" stdcallcc fn SetFilePointerEx(
    in_fFile: HANDLE,
    in_liDistanceToMove: LARGE_INTEGER,
    out_opt_ldNewFilePointer: ?*LARGE_INTEGER,
    in_dwMoveMethod: DWORD,
) BOOL;

pub extern "kernel32" stdcallcc fn SetHandleInformation(hObject: HANDLE, dwMask: DWORD, dwFlags: DWORD) BOOL;

pub extern "kernel32" stdcallcc fn Sleep(dwMilliseconds: DWORD) void;

pub extern "kernel32" stdcallcc fn TerminateProcess(hProcess: HANDLE, uExitCode: UINT) BOOL;

pub extern "kernel32" stdcallcc fn WaitForSingleObject(hHandle: HANDLE, dwMilliseconds: DWORD) DWORD;

pub extern "kernel32" stdcallcc fn WriteFile(
    in_hFile: HANDLE,
    in_lpBuffer: *const c_void,
    in_nNumberOfBytesToWrite: DWORD,
    out_lpNumberOfBytesWritten: ?*DWORD,
    in_out_lpOverlapped: ?*OVERLAPPED,
) BOOL;

//TODO: call unicode versions instead of relying on ANSI code page
pub extern "kernel32" stdcallcc fn LoadLibraryA(lpLibFileName: LPCSTR) ?HMODULE;

pub extern "kernel32" stdcallcc fn FreeLibrary(hModule: HMODULE) BOOL;

pub extern "user32" stdcallcc fn MessageBoxA(hWnd: ?HANDLE, lpText: ?LPCTSTR, lpCaption: ?LPCTSTR, uType: UINT) c_int;

pub extern "shlwapi" stdcallcc fn PathFileExistsA(pszPath: ?LPCTSTR) BOOL;

pub const PROV_RSA_FULL = 1;

pub const BOOL = c_int;
pub const BOOLEAN = BYTE;
pub const BYTE = u8;
pub const CHAR = u8;
pub const DWORD = u32;
pub const FLOAT = f32;
pub const HANDLE = *c_void;
pub const HCRYPTPROV = ULONG_PTR;
pub const HINSTANCE = *@OpaqueType();
pub const HMODULE = *@OpaqueType();
pub const INT = c_int;
pub const LPBYTE = *BYTE;
pub const LPCH = *CHAR;
pub const LPCSTR = [*]const CHAR;
pub const LPCTSTR = [*]const TCHAR;
pub const LPCVOID = *const c_void;
pub const LPDWORD = *DWORD;
pub const LPSTR = [*]CHAR;
pub const LPTSTR = if (UNICODE) LPWSTR else LPSTR;
pub const LPVOID = *c_void;
pub const LPWSTR = [*]WCHAR;
pub const PVOID = *c_void;
pub const PWSTR = [*]WCHAR;
pub const SIZE_T = usize;
pub const TCHAR = if (UNICODE) WCHAR else u8;
pub const UINT = c_uint;
pub const ULONG_PTR = usize;
pub const UNICODE = false;
pub const WCHAR = u16;
pub const WORD = u16;
pub const LARGE_INTEGER = i64;

pub const TRUE = 1;
pub const FALSE = 0;

/// The standard input device. Initially, this is the console input buffer, CONIN$.
pub const STD_INPUT_HANDLE = @maxValue(DWORD) - 10 + 1;

/// The standard output device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_OUTPUT_HANDLE = @maxValue(DWORD) - 11 + 1;

/// The standard error device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_ERROR_HANDLE = @maxValue(DWORD) - 12 + 1;

pub const INVALID_HANDLE_VALUE = @intToPtr(HANDLE, @maxValue(usize));

pub const INVALID_FILE_ATTRIBUTES = DWORD(@maxValue(DWORD));

pub const OVERLAPPED = extern struct {
    Internal: ULONG_PTR,
    InternalHigh: ULONG_PTR,
    Pointer: PVOID,
    hEvent: HANDLE,
};
pub const LPOVERLAPPED = *OVERLAPPED;

pub const MAX_PATH = 260;

// TODO issue #305
pub const FILE_INFO_BY_HANDLE_CLASS = u32;
pub const FileBasicInfo = 0;
pub const FileStandardInfo = 1;
pub const FileNameInfo = 2;
pub const FileRenameInfo = 3;
pub const FileDispositionInfo = 4;
pub const FileAllocationInfo = 5;
pub const FileEndOfFileInfo = 6;
pub const FileStreamInfo = 7;
pub const FileCompressionInfo = 8;
pub const FileAttributeTagInfo = 9;
pub const FileIdBothDirectoryInfo = 10;
pub const FileIdBothDirectoryRestartInfo = 11;
pub const FileIoPriorityHintInfo = 12;
pub const FileRemoteProtocolInfo = 13;
pub const FileFullDirectoryInfo = 14;
pub const FileFullDirectoryRestartInfo = 15;
pub const FileStorageInfo = 16;
pub const FileAlignmentInfo = 17;
pub const FileIdInfo = 18;
pub const FileIdExtdDirectoryInfo = 19;
pub const FileIdExtdDirectoryRestartInfo = 20;

pub const FILE_NAME_INFO = extern struct {
    FileNameLength: DWORD,
    FileName: [1]WCHAR,
};

/// Return the normalized drive name. This is the default.
pub const FILE_NAME_NORMALIZED = 0x0;

/// Return the opened file name (not normalized).
pub const FILE_NAME_OPENED = 0x8;

/// Return the path with the drive letter. This is the default.
pub const VOLUME_NAME_DOS = 0x0;

/// Return the path with a volume GUID path instead of the drive name.
pub const VOLUME_NAME_GUID = 0x1;

/// Return the path with no drive information.
pub const VOLUME_NAME_NONE = 0x4;

/// Return the path with the volume device path.
pub const VOLUME_NAME_NT = 0x2;

pub const SECURITY_ATTRIBUTES = extern struct {
    nLength: DWORD,
    lpSecurityDescriptor: ?*c_void,
    bInheritHandle: BOOL,
};
pub const PSECURITY_ATTRIBUTES = *SECURITY_ATTRIBUTES;
pub const LPSECURITY_ATTRIBUTES = *SECURITY_ATTRIBUTES;

pub const GENERIC_READ = 0x80000000;
pub const GENERIC_WRITE = 0x40000000;
pub const GENERIC_EXECUTE = 0x20000000;
pub const GENERIC_ALL = 0x10000000;

pub const FILE_SHARE_DELETE = 0x00000004;
pub const FILE_SHARE_READ = 0x00000001;
pub const FILE_SHARE_WRITE = 0x00000002;

pub const CREATE_ALWAYS = 2;
pub const CREATE_NEW = 1;
pub const OPEN_ALWAYS = 4;
pub const OPEN_EXISTING = 3;
pub const TRUNCATE_EXISTING = 5;

pub const FILE_ATTRIBUTE_ARCHIVE = 0x20;
pub const FILE_ATTRIBUTE_COMPRESSED = 0x800;
pub const FILE_ATTRIBUTE_DEVICE = 0x40;
pub const FILE_ATTRIBUTE_DIRECTORY = 0x10;
pub const FILE_ATTRIBUTE_ENCRYPTED = 0x4000;
pub const FILE_ATTRIBUTE_HIDDEN = 0x2;
pub const FILE_ATTRIBUTE_INTEGRITY_STREAM = 0x8000;
pub const FILE_ATTRIBUTE_NORMAL = 0x80;
pub const FILE_ATTRIBUTE_NOT_CONTENT_INDEXED = 0x2000;
pub const FILE_ATTRIBUTE_NO_SCRUB_DATA = 0x20000;
pub const FILE_ATTRIBUTE_OFFLINE = 0x1000;
pub const FILE_ATTRIBUTE_READONLY = 0x1;
pub const FILE_ATTRIBUTE_RECALL_ON_DATA_ACCESS = 0x400000;
pub const FILE_ATTRIBUTE_RECALL_ON_OPEN = 0x40000;
pub const FILE_ATTRIBUTE_REPARSE_POINT = 0x400;
pub const FILE_ATTRIBUTE_SPARSE_FILE = 0x200;
pub const FILE_ATTRIBUTE_SYSTEM = 0x4;
pub const FILE_ATTRIBUTE_TEMPORARY = 0x100;
pub const FILE_ATTRIBUTE_VIRTUAL = 0x10000;

pub const PROCESS_INFORMATION = extern struct {
    hProcess: HANDLE,
    hThread: HANDLE,
    dwProcessId: DWORD,
    dwThreadId: DWORD,
};

pub const STARTUPINFOA = extern struct {
    cb: DWORD,
    lpReserved: ?LPSTR,
    lpDesktop: ?LPSTR,
    lpTitle: ?LPSTR,
    dwX: DWORD,
    dwY: DWORD,
    dwXSize: DWORD,
    dwYSize: DWORD,
    dwXCountChars: DWORD,
    dwYCountChars: DWORD,
    dwFillAttribute: DWORD,
    dwFlags: DWORD,
    wShowWindow: WORD,
    cbReserved2: WORD,
    lpReserved2: ?LPBYTE,
    hStdInput: ?HANDLE,
    hStdOutput: ?HANDLE,
    hStdError: ?HANDLE,
};

pub const STARTF_FORCEONFEEDBACK = 0x00000040;
pub const STARTF_FORCEOFFFEEDBACK = 0x00000080;
pub const STARTF_PREVENTPINNING = 0x00002000;
pub const STARTF_RUNFULLSCREEN = 0x00000020;
pub const STARTF_TITLEISAPPID = 0x00001000;
pub const STARTF_TITLEISLINKNAME = 0x00000800;
pub const STARTF_UNTRUSTEDSOURCE = 0x00008000;
pub const STARTF_USECOUNTCHARS = 0x00000008;
pub const STARTF_USEFILLATTRIBUTE = 0x00000010;
pub const STARTF_USEHOTKEY = 0x00000200;
pub const STARTF_USEPOSITION = 0x00000004;
pub const STARTF_USESHOWWINDOW = 0x00000001;
pub const STARTF_USESIZE = 0x00000002;
pub const STARTF_USESTDHANDLES = 0x00000100;

pub const INFINITE = 4294967295;

pub const WAIT_ABANDONED = 0x00000080;
pub const WAIT_OBJECT_0 = 0x00000000;
pub const WAIT_TIMEOUT = 0x00000102;
pub const WAIT_FAILED = 0xFFFFFFFF;

pub const HANDLE_FLAG_INHERIT = 0x00000001;
pub const HANDLE_FLAG_PROTECT_FROM_CLOSE = 0x00000002;

pub const MOVEFILE_COPY_ALLOWED = 2;
pub const MOVEFILE_CREATE_HARDLINK = 16;
pub const MOVEFILE_DELAY_UNTIL_REBOOT = 4;
pub const MOVEFILE_FAIL_IF_NOT_TRACKABLE = 32;
pub const MOVEFILE_REPLACE_EXISTING = 1;
pub const MOVEFILE_WRITE_THROUGH = 8;

pub const FILE_BEGIN = 0;
pub const FILE_CURRENT = 1;
pub const FILE_END = 2;

pub const HEAP_CREATE_ENABLE_EXECUTE = 0x00040000;
pub const HEAP_GENERATE_EXCEPTIONS = 0x00000004;
pub const HEAP_NO_SERIALIZE = 0x00000001;

pub const PTHREAD_START_ROUTINE = extern fn (LPVOID) DWORD;
pub const LPTHREAD_START_ROUTINE = PTHREAD_START_ROUTINE;

pub const WIN32_FIND_DATAA = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    dwReserved0: DWORD,
    dwReserved1: DWORD,
    cFileName: [260]CHAR,
    cAlternateFileName: [14]CHAR,
};

pub const FILETIME = extern struct {
    dwLowDateTime: DWORD,
    dwHighDateTime: DWORD,
};
