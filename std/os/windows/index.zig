pub const ERROR = @import("error.zig");

pub extern fn CryptAcquireContext(phProv: &HCRYPTPROV, pszContainer: LPCTSTR,
    pszProvider: LPCTSTR, dwProvType: DWORD, dwFlags: DWORD) -> bool;

pub extern fn CryptReleaseContext(hProv: HCRYPTPROV, dwFlags: DWORD) -> bool;

pub extern fn CryptGenRandom(hProv: HCRYPTPROV, dwLen: DWORD, pbBuffer: &BYTE) -> bool;

pub extern fn ExitProcess(exit_code: UINT) -> noreturn;

pub extern fn GetConsoleMode(in_hConsoleHandle: HANDLE, out_lpMode: &DWORD) -> bool;

/// Retrieves the calling thread's last-error code value. The last-error code is maintained on a per-thread basis.
/// Multiple threads do not overwrite each other's last-error code.
pub extern fn GetLastError() -> DWORD;

/// Retrieves file information for the specified file.
pub extern fn GetFileInformationByHandleEx(in_hFile: HANDLE, in_FileInformationClass: FILE_INFO_BY_HANDLE_CLASS,
    out_lpFileInformation: &c_void, in_dwBufferSize: DWORD) -> bool;

/// Retrieves a handle to the specified standard device (standard input, standard output, or standard error).
pub extern fn GetStdHandle(in_nStdHandle: DWORD) -> ?HANDLE;

/// Reads data from the specified file or input/output (I/O) device. Reads occur at the position specified by the file pointer if supported by the device.
/// This function is designed for both synchronous and asynchronous operations. For a similar function designed solely for asynchronous operation, see ReadFileEx.
pub extern fn ReadFile(in_hFile: HANDLE, out_lpBuffer: LPVOID, in_nNumberOfBytesToRead: DWORD,
    out_lpNumberOfBytesRead: &DWORD, in_out_lpOverlapped: ?&OVERLAPPED) -> BOOL;

/// Writes data to the specified file or input/output (I/O) device.
/// This function is designed for both synchronous and asynchronous operation. For a similar function designed solely for asynchronous operation, see WriteFileEx.
pub extern fn WriteFile(in_hFile: HANDLE, in_lpBuffer: &const c_void, in_nNumberOfBytesToWrite: DWORD,
    out_lpNumberOfBytesWritten: ?&DWORD, in_out_lpOverlapped: ?&OVERLAPPED) -> BOOL;

pub const PROV_RSA_FULL = 1;


pub const BOOL = bool;
pub const BYTE = u8;
pub const DWORD = u32;
pub const FLOAT = f32;
pub const HANDLE = &c_void;
pub const HCRYPTPROV = ULONG_PTR;
pub const LPCTSTR = &const TCHAR;
pub const LPDWORD = &DWORD;
pub const LPVOID = &c_void;
pub const PVOID = &c_void;
pub const TCHAR = u8; // TODO something about unicode WCHAR vs char
pub const UINT = c_uint;
pub const ULONG_PTR = usize;
pub const WCHAR = u16;
pub const LPCVOID = &const c_void;

/// The standard input device. Initially, this is the console input buffer, CONIN$.
pub const STD_INPUT_HANDLE = @maxValue(DWORD) - 10 + 1;

/// The standard output device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_OUTPUT_HANDLE = @maxValue(DWORD) - 11 + 1;

/// The standard error device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_ERROR_HANDLE = @maxValue(DWORD) - 12 + 1;

pub const INVALID_HANDLE_VALUE = @intToPtr(HANDLE, 0xFFFFFFFFFFFFFFFF);

pub const OVERLAPPED = extern struct {
    Internal: ULONG_PTR,
    InternalHigh: ULONG_PTR,
    Pointer: PVOID,
    hEvent: HANDLE,
};
pub const LPOVERLAPPED = &OVERLAPPED;

pub const MAX_PATH = 260;

// TODO issue #305
pub const FILE_INFO_BY_HANDLE_CLASS = u32;
pub const FileBasicInfo                   = 0;
pub const FileStandardInfo                = 1;
pub const FileNameInfo                    = 2;
pub const FileRenameInfo                  = 3;
pub const FileDispositionInfo             = 4;
pub const FileAllocationInfo              = 5;
pub const FileEndOfFileInfo               = 6;
pub const FileStreamInfo                  = 7;
pub const FileCompressionInfo             = 8;
pub const FileAttributeTagInfo            = 9;
pub const FileIdBothDirectoryInfo         = 10;
pub const FileIdBothDirectoryRestartInfo  = 11;
pub const FileIoPriorityHintInfo          = 12;
pub const FileRemoteProtocolInfo          = 13;
pub const FileFullDirectoryInfo           = 14;
pub const FileFullDirectoryRestartInfo    = 15;
pub const FileStorageInfo                 = 16;
pub const FileAlignmentInfo               = 17;
pub const FileIdInfo                      = 18;
pub const FileIdExtdDirectoryInfo         = 19;
pub const FileIdExtdDirectoryRestartInfo  = 20;

pub const FILE_NAME_INFO = extern struct {
    FileNameLength: DWORD,
    FileName: [1]WCHAR,
};
