// This file contains the types and constants of the Windows API,
// as well as the Windows-equivalent of "Zig-flavored POSIX" API layer.
const std = @import("../std.zig");
const assert = std.debug.assert;
const maxInt = std.math.maxInt;

pub const is_the_target = builtin.os == .windows;
pub const posix = if (builtin.link_libc) struct {} else @import("windows/posix.zig");
pub use posix;

pub const advapi32 = @import("windows/advapi32.zig");
pub const kernel32 = @import("windows/kernel32.zig");
pub const ntdll = @import("windows/ntdll.zig");
pub const ole32 = @import("windows/ole32.zig");
pub const shell32 = @import("windows/shell32.zig");

pub const ERROR = @import("windows/error.zig");

/// The standard input device. Initially, this is the console input buffer, CONIN$.
pub const STD_INPUT_HANDLE = maxInt(DWORD) - 10 + 1;

/// The standard output device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_OUTPUT_HANDLE = maxInt(DWORD) - 11 + 1;

/// The standard error device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_ERROR_HANDLE = maxInt(DWORD) - 12 + 1;

pub const SHORT = c_short;
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
pub const FARPROC = *@OpaqueType();
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
pub const LPCWSTR = [*]const WCHAR;
pub const PVOID = *c_void;
pub const PWSTR = [*]WCHAR;
pub const SIZE_T = usize;
pub const TCHAR = if (UNICODE) WCHAR else u8;
pub const UINT = c_uint;
pub const ULONG_PTR = usize;
pub const DWORD_PTR = ULONG_PTR;
pub const UNICODE = false;
pub const WCHAR = u16;
pub const WORD = u16;
pub const LARGE_INTEGER = i64;
pub const ULONG = u32;
pub const LONG = i32;
pub const ULONGLONG = u64;
pub const LONGLONG = i64;

pub const TRUE = 1;
pub const FALSE = 0;

pub const INVALID_HANDLE_VALUE = @intToPtr(HANDLE, maxInt(usize));

pub const INVALID_FILE_ATTRIBUTES = DWORD(maxInt(DWORD));

pub const OVERLAPPED = extern struct {
    Internal: ULONG_PTR,
    InternalHigh: ULONG_PTR,
    Offset: DWORD,
    OffsetHigh: DWORD,
    hEvent: ?HANDLE,
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

pub const STARTUPINFOW = extern struct {
    cb: DWORD,
    lpReserved: ?LPWSTR,
    lpDesktop: ?LPWSTR,
    lpTitle: ?LPWSTR,
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

// AllocationType values
pub const MEM_COMMIT = 0x1000;
pub const MEM_RESERVE = 0x2000;
pub const MEM_RESET = 0x80000;
pub const MEM_RESET_UNDO = 0x1000000;
pub const MEM_LARGE_PAGES = 0x20000000;
pub const MEM_PHYSICAL = 0x400000;
pub const MEM_TOP_DOWN = 0x100000;
pub const MEM_WRITE_WATCH = 0x200000;

// Protect values
pub const PAGE_EXECUTE = 0x10;
pub const PAGE_EXECUTE_READ = 0x20;
pub const PAGE_EXECUTE_READWRITE = 0x40;
pub const PAGE_EXECUTE_WRITECOPY = 0x80;
pub const PAGE_NOACCESS = 0x01;
pub const PAGE_READONLY = 0x02;
pub const PAGE_READWRITE = 0x04;
pub const PAGE_WRITECOPY = 0x08;
pub const PAGE_TARGETS_INVALID = 0x40000000;
pub const PAGE_TARGETS_NO_UPDATE = 0x40000000; // Same as PAGE_TARGETS_INVALID
pub const PAGE_GUARD = 0x100;
pub const PAGE_NOCACHE = 0x200;
pub const PAGE_WRITECOMBINE = 0x400;

// FreeType values
pub const MEM_COALESCE_PLACEHOLDERS = 0x1;
pub const MEM_RESERVE_PLACEHOLDERS = 0x2;
pub const MEM_DECOMMIT = 0x4000;
pub const MEM_RELEASE = 0x8000;

pub const PTHREAD_START_ROUTINE = extern fn (LPVOID) DWORD;
pub const LPTHREAD_START_ROUTINE = PTHREAD_START_ROUTINE;

pub const WIN32_FIND_DATAW = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    dwReserved0: DWORD,
    dwReserved1: DWORD,
    cFileName: [260]u16,
    cAlternateFileName: [14]u16,
};

pub const FILETIME = extern struct {
    dwLowDateTime: DWORD,
    dwHighDateTime: DWORD,
};

pub const SYSTEM_INFO = extern struct {
    anon1: extern union {
        dwOemId: DWORD,
        anon2: extern struct {
            wProcessorArchitecture: WORD,
            wReserved: WORD,
        },
    },
    dwPageSize: DWORD,
    lpMinimumApplicationAddress: LPVOID,
    lpMaximumApplicationAddress: LPVOID,
    dwActiveProcessorMask: DWORD_PTR,
    dwNumberOfProcessors: DWORD,
    dwProcessorType: DWORD,
    dwAllocationGranularity: DWORD,
    wProcessorLevel: WORD,
    wProcessorRevision: WORD,
};

pub const HRESULT = c_long;

pub const KNOWNFOLDERID = GUID;
pub const GUID = extern struct {
    Data1: c_ulong,
    Data2: c_ushort,
    Data3: c_ushort,
    Data4: [8]u8,

    pub fn parse(str: []const u8) GUID {
        var guid: GUID = undefined;
        var index: usize = 0;
        assert(str[index] == '{');
        index += 1;

        guid.Data1 = std.fmt.parseUnsigned(c_ulong, str[index .. index + 8], 16) catch unreachable;
        index += 8;

        assert(str[index] == '-');
        index += 1;

        guid.Data2 = std.fmt.parseUnsigned(c_ushort, str[index .. index + 4], 16) catch unreachable;
        index += 4;

        assert(str[index] == '-');
        index += 1;

        guid.Data3 = std.fmt.parseUnsigned(c_ushort, str[index .. index + 4], 16) catch unreachable;
        index += 4;

        assert(str[index] == '-');
        index += 1;

        guid.Data4[0] = std.fmt.parseUnsigned(u8, str[index .. index + 2], 16) catch unreachable;
        index += 2;
        guid.Data4[1] = std.fmt.parseUnsigned(u8, str[index .. index + 2], 16) catch unreachable;
        index += 2;

        assert(str[index] == '-');
        index += 1;

        var i: usize = 2;
        while (i < guid.Data4.len) : (i += 1) {
            guid.Data4[i] = std.fmt.parseUnsigned(u8, str[index .. index + 2], 16) catch unreachable;
            index += 2;
        }

        assert(str[index] == '}');
        index += 1;
        return guid;
    }
};

pub const FOLDERID_LocalAppData = GUID.parse("{F1B32785-6FBA-4FCF-9D55-7B8E7F157091}");

pub const KF_FLAG_DEFAULT = 0;
pub const KF_FLAG_NO_APPCONTAINER_REDIRECTION = 65536;
pub const KF_FLAG_CREATE = 32768;
pub const KF_FLAG_DONT_VERIFY = 16384;
pub const KF_FLAG_DONT_UNEXPAND = 8192;
pub const KF_FLAG_NO_ALIAS = 4096;
pub const KF_FLAG_INIT = 2048;
pub const KF_FLAG_DEFAULT_PATH = 1024;
pub const KF_FLAG_NOT_PARENT_RELATIVE = 512;
pub const KF_FLAG_SIMPLE_IDLIST = 256;
pub const KF_FLAG_ALIAS_ONLY = -2147483648;

pub const S_OK = 0;
pub const E_NOTIMPL = @bitCast(c_long, c_ulong(0x80004001));
pub const E_NOINTERFACE = @bitCast(c_long, c_ulong(0x80004002));
pub const E_POINTER = @bitCast(c_long, c_ulong(0x80004003));
pub const E_ABORT = @bitCast(c_long, c_ulong(0x80004004));
pub const E_FAIL = @bitCast(c_long, c_ulong(0x80004005));
pub const E_UNEXPECTED = @bitCast(c_long, c_ulong(0x8000FFFF));
pub const E_ACCESSDENIED = @bitCast(c_long, c_ulong(0x80070005));
pub const E_HANDLE = @bitCast(c_long, c_ulong(0x80070006));
pub const E_OUTOFMEMORY = @bitCast(c_long, c_ulong(0x8007000E));
pub const E_INVALIDARG = @bitCast(c_long, c_ulong(0x80070057));

pub const FILE_FLAG_BACKUP_SEMANTICS = 0x02000000;
pub const FILE_FLAG_DELETE_ON_CLOSE = 0x04000000;
pub const FILE_FLAG_NO_BUFFERING = 0x20000000;
pub const FILE_FLAG_OPEN_NO_RECALL = 0x00100000;
pub const FILE_FLAG_OPEN_REPARSE_POINT = 0x00200000;
pub const FILE_FLAG_OVERLAPPED = 0x40000000;
pub const FILE_FLAG_POSIX_SEMANTICS = 0x0100000;
pub const FILE_FLAG_RANDOM_ACCESS = 0x10000000;
pub const FILE_FLAG_SESSION_AWARE = 0x00800000;
pub const FILE_FLAG_SEQUENTIAL_SCAN = 0x08000000;
pub const FILE_FLAG_WRITE_THROUGH = 0x80000000;

pub const SMALL_RECT = extern struct {
    Left: SHORT,
    Top: SHORT,
    Right: SHORT,
    Bottom: SHORT,
};

pub const COORD = extern struct {
    X: SHORT,
    Y: SHORT,
};

pub const CREATE_UNICODE_ENVIRONMENT = 1024;

pub const TLS_OUT_OF_INDEXES = 4294967295;
pub const IMAGE_TLS_DIRECTORY = extern struct {
    StartAddressOfRawData: usize,
    EndAddressOfRawData: usize,
    AddressOfIndex: usize,
    AddressOfCallBacks: usize,
    SizeOfZeroFill: u32,
    Characteristics: u32,
};
pub const IMAGE_TLS_DIRECTORY64 = IMAGE_TLS_DIRECTORY;
pub const IMAGE_TLS_DIRECTORY32 = IMAGE_TLS_DIRECTORY;

pub const PIMAGE_TLS_CALLBACK = ?extern fn (PVOID, DWORD, PVOID) void;

pub const PROV_RSA_FULL = 1;

pub const REGSAM = ACCESS_MASK;
pub const ACCESS_MASK = DWORD;
pub const PHKEY = *HKEY;
pub const HKEY = *HKEY__;
pub const HKEY__ = extern struct {
    unused: c_int,
};
pub const LSTATUS = LONG;

pub const FILE_NOTIFY_INFORMATION = extern struct {
    NextEntryOffset: DWORD,
    Action: DWORD,
    FileNameLength: DWORD,
    FileName: [1]WCHAR,
};

pub const FILE_ACTION_ADDED = 0x00000001;
pub const FILE_ACTION_REMOVED = 0x00000002;
pub const FILE_ACTION_MODIFIED = 0x00000003;
pub const FILE_ACTION_RENAMED_OLD_NAME = 0x00000004;
pub const FILE_ACTION_RENAMED_NEW_NAME = 0x00000005;

pub const LPOVERLAPPED_COMPLETION_ROUTINE = ?extern fn (DWORD, DWORD, *OVERLAPPED) void;

pub const FILE_LIST_DIRECTORY = 1;

pub const FILE_NOTIFY_CHANGE_CREATION = 64;
pub const FILE_NOTIFY_CHANGE_SIZE = 8;
pub const FILE_NOTIFY_CHANGE_SECURITY = 256;
pub const FILE_NOTIFY_CHANGE_LAST_ACCESS = 32;
pub const FILE_NOTIFY_CHANGE_LAST_WRITE = 16;
pub const FILE_NOTIFY_CHANGE_DIR_NAME = 2;
pub const FILE_NOTIFY_CHANGE_FILE_NAME = 1;
pub const FILE_NOTIFY_CHANGE_ATTRIBUTES = 4;

pub const CONSOLE_SCREEN_BUFFER_INFO = extern struct {
    dwSize: COORD,
    dwCursorPosition: COORD,
    wAttributes: WORD,
    srWindow: SMALL_RECT,
    dwMaximumWindowSize: COORD,
};

pub const FOREGROUND_BLUE = 1;
pub const FOREGROUND_GREEN = 2;
pub const FOREGROUND_RED = 4;
pub const FOREGROUND_INTENSITY = 8;

pub const LIST_ENTRY = extern struct {
    Flink: *LIST_ENTRY,
    Blink: *LIST_ENTRY,
};

pub const RTL_CRITICAL_SECTION_DEBUG = extern struct {
    Type: WORD,
    CreatorBackTraceIndex: WORD,
    CriticalSection: *RTL_CRITICAL_SECTION,
    ProcessLocksList: LIST_ENTRY,
    EntryCount: DWORD,
    ContentionCount: DWORD,
    Flags: DWORD,
    CreatorBackTraceIndexHigh: WORD,
    SpareWORD: WORD,
};

pub const RTL_CRITICAL_SECTION = extern struct {
    DebugInfo: *RTL_CRITICAL_SECTION_DEBUG,
    LockCount: LONG,
    RecursionCount: LONG,
    OwningThread: HANDLE,
    LockSemaphore: HANDLE,
    SpinCount: ULONG_PTR,
};

pub const CRITICAL_SECTION = RTL_CRITICAL_SECTION;
pub const INIT_ONCE = RTL_RUN_ONCE;
pub const INIT_ONCE_STATIC_INIT = RTL_RUN_ONCE_INIT;
pub const INIT_ONCE_FN = extern fn (InitOnce: *INIT_ONCE, Parameter: ?*c_void, Context: ?*c_void) BOOL;

pub const RTL_RUN_ONCE = extern struct {
    Ptr: ?*c_void,
};

pub const RTL_RUN_ONCE_INIT = RTL_RUN_ONCE{ .Ptr = null };

pub const COINIT_APARTMENTTHREADED = COINIT.COINIT_APARTMENTTHREADED;
pub const COINIT_MULTITHREADED = COINIT.COINIT_MULTITHREADED;
pub const COINIT_DISABLE_OLE1DDE = COINIT.COINIT_DISABLE_OLE1DDE;
pub const COINIT_SPEED_OVER_MEMORY = COINIT.COINIT_SPEED_OVER_MEMORY;
pub const COINIT = extern enum {
    COINIT_APARTMENTTHREADED = 2,
    COINIT_MULTITHREADED = 0,
    COINIT_DISABLE_OLE1DDE = 4,
    COINIT_SPEED_OVER_MEMORY = 8,
};

/// > The maximum path of 32,767 characters is approximate, because the "\\?\"
/// > prefix may be expanded to a longer string by the system at run time, and
/// > this expansion applies to the total length.
/// from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
pub const PATH_MAX_WIDE = 32767;

pub const CreateFileError = error{
    SharingViolation,
    PathAlreadyExists,

    /// When any of the path components can not be found or the file component can not
    /// be found. Some operating systems distinguish between path components not found and
    /// file components not found, but they are collapsed into FileNotFound to gain
    /// consistency across operating systems.
    FileNotFound,

    AccessDenied,
    PipeBusy,
    NameTooLong,

    /// On Windows, file paths must be valid Unicode.
    InvalidUtf8,

    /// On Windows, file paths cannot contain these characters:
    /// '/', '*', '?', '"', '<', '>', '|'
    BadPathName,

    Unexpected,
};

pub fn CreateFile(
    file_path: []const u8,
    desired_access: DWORD,
    share_mode: DWORD,
    creation_disposition: DWORD,
    flags_and_attrs: DWORD,
) CreateFileError!fd_t {
    const file_path_w = try sliceToPrefixedFileW(file_path);
    return CreateFileW(&file_path_w, desired_access, share_mode, creation_disposition, flags_and_attrs);
}

pub fn CreateFileW(
    file_path_w: [*]const u16,
    desired_access: DWORD,
    share_mode: DWORD,
    creation_disposition: DWORD,
    flags_and_attrs: DWORD,
) CreateFileError!HANDLE {
    const result = kernel32.CreateFileW(file_path_w, desired_access, share_mode, null, creation_disposition, flags_and_attrs, null);

    if (result == INVALID_HANDLE_VALUE) {
        switch (kernel32.GetLastError()) {
            ERROR.SHARING_VIOLATION => return error.SharingViolation,
            ERROR.ALREADY_EXISTS => return error.PathAlreadyExists,
            ERROR.FILE_EXISTS => return error.PathAlreadyExists,
            ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            ERROR.ACCESS_DENIED => return error.AccessDenied,
            ERROR.PIPE_BUSY => return error.PipeBusy,
            ERROR.FILENAME_EXCED_RANGE => return error.NameTooLong,
            else => |err| return unexpectedErrorWindows(err),
        }
    }

    return result;
}

pub const CreatePipeError = error{Unexpected};

fn CreatePipe(rd: *HANDLE, wr: *HANDLE, sattr: *const SECURITY_ATTRIBUTES) CreatePipeError!void {
    if (kernel32.CreatePipe(rd, wr, sattr, 0) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const SetHandleInformationError = error{Unexpected};

fn SetHandleInformation(h: HANDLE, mask: DWORD, flags: DWORD) SetHandleInformationError!void {
    if (SetHandleInformation(h, mask, flags) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const RtlGenRandomError = error{Unexpected};

/// Call RtlGenRandom() instead of CryptGetRandom() on Windows
/// https://github.com/rust-lang-nursery/rand/issues/111
/// https://bugzilla.mozilla.org/show_bug.cgi?id=504270
pub fn RtlGenRandom(output: []u8) RtlGenRandomError!void {
    if (advapi32.RtlGenRandom(output.ptr, output.len) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const WaitForSingleObjectError = error{
    WaitAbandoned,
    WaitTimeOut,
    Unexpected,
};

pub fn WaitForSingleObject(handle: HANDLE, milliseconds: DWORD) WaitForSingleObjectError!void {
    switch (kernel32.WaitForSingleObject(handle, milliseconds)) {
        WAIT_ABANDONED => return error.WaitAbandoned,
        WAIT_OBJECT_0 => return,
        WAIT_TIMEOUT => return error.WaitTimeOut,
        WAIT_FAILED => switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        },
        else => return error.Unexpected,
    }
}

pub const FindFirstFileError = error{
    FileNotFound,
    Unexpected,
};

pub fn FindFirstFile(dir_path: []const u8, find_file_data: *WIN32_FIND_DATAW) FindFirstFileError!HANDLE {
    const dir_path_w = try sliceToPrefixedSuffixedFileW(dir_path, []u16{ '\\', '*', 0 });
    const handle = kernel32.FindFirstFileW(&dir_path_w, find_file_data);

    if (handle == INVALID_HANDLE_VALUE) {
        switch (kernel32.GetLastError()) {
            ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            else => |err| return unexpectedError(err),
        }
    }

    return handle;
}

pub const FindNextFileError = error{Unexpected};

/// Returns `true` if there was another file, `false` otherwise.
pub fn FindNextFile(handle: HANDLE, find_file_data: *WIN32_FIND_DATAW) FindNextFileError!bool {
    if (kernel32.FindNextFileW(handle, find_file_data) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.NO_MORE_FILES => return false,
            else => |err| return unexpectedError(err),
        }
    }
    return true;
}

pub const CreateIoCompletionPortError = error{Unexpected};

pub fn CreateIoCompletionPort(
    file_handle: HANDLE,
    existing_completion_port: ?HANDLE,
    completion_key: usize,
    concurrent_thread_count: DWORD,
) CreateIoCompletionPortError!HANDLE {
    const handle = kernel32.CreateIoCompletionPort(file_handle, existing_completion_port, completion_key, concurrent_thread_count) orelse {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_PARAMETER => unreachable,
            else => |err| return unexpectedError(err),
        }
    };
    return handle;
}

pub const PostQueuedCompletionStatusError = error{Unexpected};

pub fn PostQueuedCompletionStatus(
    completion_port: HANDLE,
    bytes_transferred_count: DWORD,
    completion_key: usize,
    lpOverlapped: ?*OVERLAPPED,
) PostQueuedCompletionStatusError!void {
    if (kernel32.PostQueuedCompletionStatus(completion_port, bytes_transferred_count, completion_key, lpOverlapped) == 0) {
        switch (kernel32.GetLastError()) {
            else => return unexpectedError(err),
        }
    }
}

pub const GetQueuedCompletionStatusResult = enum {
    Normal,
    Aborted,
    Cancelled,
    EOF,
};

pub fn GetQueuedCompletionStatus(
    completion_port: HANDLE,
    bytes_transferred_count: *DWORD,
    lpCompletionKey: *usize,
    lpOverlapped: *?*OVERLAPPED,
    dwMilliseconds: DWORD,
) GetQueuedCompletionStatusResult {
    if (kernel32.GetQueuedCompletionStatus(
        completion_port,
        bytes_transferred_count,
        lpCompletionKey,
        lpOverlapped,
        dwMilliseconds,
    ) == FALSE) {
        switch (kernel32.GetLastError()) {
            ERROR.ABANDONED_WAIT_0 => return GetQueuedCompletionStatusResult.Aborted,
            ERROR.OPERATION_ABORTED => return GetQueuedCompletionStatusResult.Cancelled,
            ERROR.HANDLE_EOF => return GetQueuedCompletionStatusResult.EOF,
            else => |err| {
                if (std.debug.runtime_safety) {
                    std.debug.panic("unexpected error: {}\n", err);
                }
            },
        }
    }
    return GetQueuedCompletionStatusResult.Normal;
}

pub fn CloseHandle(hObject: HANDLE) void {
    assert(kernel32.CloseHandle(hObject) != 0);
}

pub const ReadFileError = error{Unexpected};

pub fn ReadFile(in_hFile: HANDLE, buffer: []u8) ReadFileError!usize {
    var index: usize = 0;
    while (index < buffer.len) {
        const want_read_count = @intCast(DWORD, math.min(DWORD(maxInt(DWORD)), buffer.len - index));
        var amt_read: DWORD = undefined;
        if (kernel32.ReadFile(fd, buffer.ptr + index, want_read_count, &amt_read, null) == 0) {
            switch (kernel32.GetLastError()) {
                ERROR.OPERATION_ABORTED => continue,
                ERROR.BROKEN_PIPE => return index,
                else => |err| return unexpectedError(err),
            }
        }
        if (amt_read == 0) return index;
        index += amt_read;
    }
    return index;
}

pub const WriteFileError = error{
    SystemResources,
    OperationAborted,
    BrokenPipe,
    Unexpected,
};

/// This function is for blocking file descriptors only. For non-blocking, see
/// `WriteFileAsync`.
pub fn WriteFile(in_hFile: HANDLE, bytes: []const u8) WriteFileError!void {
    var bytes_written: DWORD = undefined;
    // TODO replace this @intCast with a loop that writes all the bytes
    if (kernel32.WriteFile(handle, bytes.ptr, @intCast(u32, bytes.len), &bytes_written, null) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_USER_BUFFER => return error.SystemResources,
            ERROR.NOT_ENOUGH_MEMORY => return error.SystemResources,
            ERROR.OPERATION_ABORTED => return error.OperationAborted,
            ERROR.NOT_ENOUGH_QUOTA => return error.SystemResources,
            ERROR.IO_PENDING => unreachable, // this function is for blocking files only
            ERROR.BROKEN_PIPE => return error.BrokenPipe,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const GetCurrentDirectoryError = error{
    NameTooLong,
    Unexpected,
};

/// The result is a slice of out_buffer, indexed from 0.
pub fn GetCurrentDirectory(buffer: []u8) GetCurrentDirectoryError![]u8 {
    var utf16le_buf: [PATH_MAX_WIDE]u16 = undefined;
    const result = kernel32.GetCurrentDirectoryW(utf16le_buf.len, &utf16le_buf);
    if (result == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    assert(result <= utf16le_buf.len);
    const utf16le_slice = utf16le_buf[0..result];
    // Trust that Windows gives us valid UTF-16LE.
    var end_index: usize = 0;
    var it = std.unicode.Utf16LeIterator.init(utf16le);
    while (it.nextCodepoint() catch unreachable) |codepoint| {
        if (end_index + std.unicode.utf8CodepointSequenceLength(codepoint) >= out_buffer.len)
            return error.NameTooLong;
        end_index += utf8Encode(codepoint, out_buffer[end_index..]) catch unreachable;
    }
    return out_buffer[0..end_index];
}

pub const CreateSymbolicLinkError = error{Unexpected};

pub fn CreateSymbolicLink(
    sym_link_path: []const u8,
    target_path: []const u8,
    flags: DWORD,
) CreateSymbolicLinkError!void {
    const sym_link_path_w = try sliceToPrefixedFileW(sym_link_path);
    const target_path_w = try sliceToPrefixedFileW(target_path);
    return CreateSymbolicLinkW(&sym_link_path_w, &target_path_w, flags);
}

pub fn CreateSymbolicLinkW(
    sym_link_path: [*]const u16,
    target_path: [*]const u16,
    flags: DWORD,
) CreateSymbolicLinkError!void {
    if (kernel32.CreateSymbolicLinkW(sym_link_path, target_path, flags) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return kernel32.unexpectedError(err),
        }
    }
}

pub const DeleteFileError = error{
    FileNotFound,
    AccessDenied,
    NameTooLong,
    Unexpected,
};

pub fn DeleteFile(filename: []const u8) DeleteFileError!void {
    const filename_w = try sliceToPrefixedFileW(filename);
    return DeleteFileW(&filename_w);
}

pub fn DeleteFileW(filename: [*]const u16) DeleteFileError!void {
    if (kernel32.DeleteFileW(file_path) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            ERROR.ACCESS_DENIED => return error.AccessDenied,
            ERROR.FILENAME_EXCED_RANGE => return error.NameTooLong,
            ERROR.INVALID_PARAMETER => return error.NameTooLong,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const MoveFileError = error{Unexpected};

pub fn MoveFileEx(old_path: []const u8, new_path: []const u8, flags: DWORD) MoveFileError!void {
    const old_path_w = try sliceToPrefixedFileW(old_path);
    const new_path_w = try sliceToPrefixedFileW(new_path);
    return MoveFileExW(&old_path_w, &new_path_w, flags);
}

pub fn MoveFileExW(old_path: [*]const u16, new_path: [*]const u16, flags: DWORD) MoveFileError!void {
    if (kernel32.MoveFileExW(old_path, new_path, flags) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const CreateDirectoryError = error{
    PathAlreadyExists,
    FileNotFound,
    Unexpected,
};

pub fn CreateDirectory(pathname: []const u8, attrs: ?*SECURITY_ATTRIBUTES) CreateDirectoryError!void {
    const pathname_w = try sliceToPrefixedFileW(pathname);
    return CreateDirectoryW(&pathname_w, attrs);
}

pub fn CreateDirectoryW(pathname: [*]const u16, attrs: ?*SECURITY_ATTRIBUTES) CreateDirectoryError!void {
    if (kernel32.CreateDirectoryW(pathname, attrs) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.ALREADY_EXISTS => return error.PathAlreadyExists,
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const RemoveDirectoryError = error{
    FileNotFound,
    DirNotEmpty,
    Unexpected,
};

pub fn RemoveDirectory(dir_path: []const u8) RemoveDirectoryError!void {
    const dir_path_w = try sliceToPrefixedFileW(dir_path);
    return RemoveDirectoryW(&dir_path_w);
}

pub fn RemoveDirectoryW(dir_path_w: [*]const u16) RemoveDirectoryError!void {
    if (kernel32.RemoveDirectoryW(dir_path_w) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            ERROR.DIR_NOT_EMPTY => return error.DirNotEmpty,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const GetStdHandleError = error{
    NoStandardHandleAttached,
    Unexpected,
};

pub fn GetStdHandle(handle_id: DWORD) GetStdHandleError!fd_t {
    const handle = kernel32.GetStdHandle(handle_id) orelse return error.NoStandardHandleAttached;
    if (handle == INVALID_HANDLE_VALUE) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    return handle;
}

pub const SetFilePointerError = error{Unexpected};

/// The SetFilePointerEx function with the `dwMoveMethod` parameter set to `FILE_BEGIN`.
pub fn SetFilePointerEx_BEGIN(handle: HANDLE, offset: u64) SetFilePointerError!void {
    // "The starting point is zero or the beginning of the file. If [FILE_BEGIN]
    // is specified, then the liDistanceToMove parameter is interpreted as an unsigned value."
    // https://docs.microsoft.com/en-us/windows/desktop/api/fileapi/nf-fileapi-setfilepointerex
    const ipos = @bitCast(LARGE_INTEGER, offset);
    if (kernel32.SetFilePointerEx(handle, ipos, null, FILE_BEGIN) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_PARAMETER => unreachable,
            ERROR.INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with the `dwMoveMethod` parameter set to `FILE_CURRENT`.
pub fn SetFilePointerEx_CURRENT(handle: HANDLE, offset: i64) SetFilePointerError!void {
    if (kernel32.SetFilePointerEx(handle, offset, null, FILE_CURRENT) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_PARAMETER => unreachable,
            ERROR.INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with the `dwMoveMethod` parameter set to `FILE_END`.
pub fn SetFilePointerEx_END(handle: HANDLE, offset: i64) SetFilePointerError!void {
    if (kernel32.SetFilePointerEx(handle, offset, null, FILE_END) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_PARAMETER => unreachable,
            ERROR.INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with parameters to get the current offset.
pub fn SetFilePointerEx_CURRENT_get(handle: HANDLE) SetFilePointerError!u64 {
    var result: LARGE_INTEGER = undefined;
    if (kernel32.SetFilePointerEx(handle, 0, &result, FILE_CURRENT) == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.INVALID_PARAMETER => unreachable,
            ERROR.INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
    // Based on the docs for FILE_BEGIN, it seems that the returned signed integer
    // should be interpreted as an unsigned integer.
    return @bitCast(u64, result);
}

pub const GetFinalPathNameByHandleError = error{
    FileNotFound,
    SystemResources,
    NameTooLong,
    Unexpected,
};

pub fn GetFinalPathNameByHandleW(
    hFile: HANDLE,
    buf_ptr: [*]u16,
    buf_len: DWORD,
    flags: DWORD,
) GetFinalPathNameByHandleError!DWORD {
    const rc = kernel32.GetFinalPathNameByHandleW(h_file, buf_ptr, buf.len, flags);
    if (rc == 0) {
        switch (kernel32.GetLastError()) {
            ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            ERROR.NOT_ENOUGH_MEMORY => return error.SystemResources,
            ERROR.FILENAME_EXCED_RANGE => return error.NameTooLong,
            ERROR.INVALID_PARAMETER => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
    return rc;
}

pub const GetFileSizeError = error{Unexpected};

pub fn GetFileSizeEx(hFile: HANDLE) GetFileSizeError!u64 {
    var file_size: LARGE_INTEGER = undefined;
    if (kernel32.GetFileSizeEx(hFile, &file_size) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    return @bitCast(u64, file_size);
}

pub const GetFileAttributesError = error{
    FileNotFound,
    PermissionDenied,
    Unexpected,
};

pub fn GetFileAttributes(filename: []const u8) GetFileAttributesError!DWORD {
    const filename_w = try sliceToPrefixedFileW(filename);
    return GetFileAttributesW(&filename_w);
}

pub fn GetFileAttributesW(lpFileName: [*]const u16) GetFileAttributesError!DWORD {
    const rc = kernel32.GetFileAttributesW(path);
    if (rc == INVALID_FILE_ATTRIBUTES) {
        switch (kernel32.GetLastError()) {
            ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            ERROR.ACCESS_DENIED => return error.PermissionDenied,
            else => |err| return unexpectedError(err),
        }
    }
    return rc;
}

pub fn cStrToPrefixedFileW(s: [*]const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedFileW(mem.toSliceConst(u8, s));
}

pub fn sliceToPrefixedFileW(s: []const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedSuffixedFileW(s, []u16{0});
}

pub fn sliceToPrefixedSuffixedFileW(s: []const u8, comptime suffix: []const u16) ![PATH_MAX_WIDE + suffix.len]u16 {
    // TODO well defined copy elision
    var result: [PATH_MAX_WIDE + suffix.len]u16 = undefined;

    // > File I/O functions in the Windows API convert "/" to "\" as part of
    // > converting the name to an NT-style name, except when using the "\\?\"
    // > prefix as detailed in the following sections.
    // from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
    // Because we want the larger maximum path length for absolute paths, we
    // disallow forward slashes in zig std lib file functions on Windows.
    for (s) |byte| {
        switch (byte) {
            '/', '*', '?', '"', '<', '>', '|' => return error.BadPathName,
            else => {},
        }
    }
    const start_index = if (mem.startsWith(u8, s, "\\\\") or !os.path.isAbsolute(s)) 0 else blk: {
        const prefix = []u16{ '\\', '\\', '?', '\\' };
        mem.copy(u16, result[0..], prefix);
        break :blk prefix.len;
    };
    const end_index = start_index + try std.unicode.utf8ToUtf16Le(result[start_index..], s);
    assert(end_index <= result.len);
    if (end_index + suffix.len > result.len) return error.NameTooLong;
    mem.copy(u16, result[end_index..], suffix);
    return result;
}

/// Call this when you made a windows DLL call or something that does SetLastError
/// and you get an unexpected error.
pub fn unexpectedError(err: DWORD) std.os.UnexpectedError {
    if (std.os.unexpected_error_tracing) {
        std.debug.warn("unexpected GetLastError(): {}\n", err);
        std.debug.dumpCurrentStackTrace(null);
    }
    return error.Unexpected;
}
