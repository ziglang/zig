const std = @import("../../std.zig");
const windows = std.os.windows;

const BOOL = windows.BOOL;
const DWORD = windows.DWORD;
const ULONG = windows.ULONG;
const WINAPI = windows.WINAPI;
const NTSTATUS = windows.NTSTATUS;
const WORD = windows.WORD;
const HANDLE = windows.HANDLE;
const ACCESS_MASK = windows.ACCESS_MASK;
const IO_APC_ROUTINE = windows.IO_APC_ROUTINE;
const BOOLEAN = windows.BOOLEAN;
const OBJECT_ATTRIBUTES = windows.OBJECT_ATTRIBUTES;
const PVOID = windows.PVOID;
const IO_STATUS_BLOCK = windows.IO_STATUS_BLOCK;
const LARGE_INTEGER = windows.LARGE_INTEGER;
const OBJECT_INFORMATION_CLASS = windows.OBJECT_INFORMATION_CLASS;
const FILE_INFORMATION_CLASS = windows.FILE_INFORMATION_CLASS;
const UNICODE_STRING = windows.UNICODE_STRING;
const RTL_OSVERSIONINFOW = windows.RTL_OSVERSIONINFOW;
const FILE_BASIC_INFORMATION = windows.FILE_BASIC_INFORMATION;
const SIZE_T = windows.SIZE_T;
const CURDIR = windows.CURDIR;

pub extern "NtDll" fn RtlGetVersion(
    lpVersionInformation: *RTL_OSVERSIONINFOW,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn RtlCaptureStackBackTrace(
    FramesToSkip: DWORD,
    FramesToCapture: DWORD,
    BackTrace: **anyopaque,
    BackTraceHash: ?*DWORD,
) callconv(WINAPI) WORD;
pub extern "NtDll" fn NtQueryInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *anyopaque,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtSetInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: PVOID,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtQueryAttributesFile(
    ObjectAttributes: *OBJECT_ATTRIBUTES,
    FileAttributes: *FILE_BASIC_INFORMATION,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtCreateFile(
    FileHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: *OBJECT_ATTRIBUTES,
    IoStatusBlock: *IO_STATUS_BLOCK,
    AllocationSize: ?*LARGE_INTEGER,
    FileAttributes: ULONG,
    ShareAccess: ULONG,
    CreateDisposition: ULONG,
    CreateOptions: ULONG,
    EaBuffer: ?*anyopaque,
    EaLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtDeviceIoControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    IoControlCode: ULONG,
    InputBuffer: ?*const anyopaque,
    InputBufferLength: ULONG,
    OutputBuffer: ?PVOID,
    OutputBufferLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtFsControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FsControlCode: ULONG,
    InputBuffer: ?*const anyopaque,
    InputBufferLength: ULONG,
    OutputBuffer: ?PVOID,
    OutputBufferLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtClose(Handle: HANDLE) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn RtlDosPathNameToNtPathName_U(
    DosPathName: [*:0]const u16,
    NtPathName: *UNICODE_STRING,
    NtFileNamePart: ?*?[*:0]const u16,
    DirectoryInfo: ?*CURDIR,
) callconv(WINAPI) BOOL;
pub extern "NtDll" fn RtlFreeUnicodeString(UnicodeString: *UNICODE_STRING) callconv(WINAPI) void;

pub extern "NtDll" fn NtQueryDirectoryFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *anyopaque,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
    ReturnSingleEntry: BOOLEAN,
    FileName: ?*UNICODE_STRING,
    RestartScan: BOOLEAN,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtCreateKeyedEvent(
    KeyedEventHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: ?PVOID,
    Flags: ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtReleaseKeyedEvent(
    EventHandle: ?HANDLE,
    Key: ?*const anyopaque,
    Alertable: BOOLEAN,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtWaitForKeyedEvent(
    EventHandle: ?HANDLE,
    Key: ?*const anyopaque,
    Alertable: BOOLEAN,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn RtlSetCurrentDirectory_U(PathName: *UNICODE_STRING) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtQueryObject(
    Handle: HANDLE,
    ObjectInformationClass: OBJECT_INFORMATION_CLASS,
    ObjectInformation: PVOID,
    ObjectInformationLength: ULONG,
    ReturnLength: ?*ULONG,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn RtlWakeAddressAll(
    Address: ?*const anyopaque,
) callconv(WINAPI) void;

pub extern "NtDll" fn RtlWakeAddressSingle(
    Address: ?*const anyopaque,
) callconv(WINAPI) void;

pub extern "NtDll" fn RtlWaitOnAddress(
    Address: ?*const anyopaque,
    CompareAddress: ?*const anyopaque,
    AddressSize: SIZE_T,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtLockFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?*IO_APC_ROUTINE,
    ApcContext: ?*anyopaque,
    IoStatusBlock: *IO_STATUS_BLOCK,
    ByteOffset: *const LARGE_INTEGER,
    Length: *const LARGE_INTEGER,
    Key: ?*ULONG,
    FailImmediately: BOOLEAN,
    ExclusiveLock: BOOLEAN,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtUnlockFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    ByteOffset: *const LARGE_INTEGER,
    Length: *const LARGE_INTEGER,
    Key: ?*ULONG,
) callconv(WINAPI) NTSTATUS;
