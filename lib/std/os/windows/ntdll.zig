usingnamespace @import("bits.zig");

pub extern "NtDll" stdcallcc fn RtlCaptureStackBackTrace(FramesToSkip: DWORD, FramesToCapture: DWORD, BackTrace: **c_void, BackTraceHash: ?*DWORD) WORD;
pub extern "NtDll" stdcallcc fn NtQueryInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *c_void,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtCreateFile(
    FileHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: *OBJECT_ATTRIBUTES,
    IoStatusBlock: *IO_STATUS_BLOCK,
    AllocationSize: ?*LARGE_INTEGER,
    FileAttributes: ULONG,
    ShareAccess: ULONG,
    CreateDisposition: ULONG,
    CreateOptions: ULONG,
    EaBuffer: ?*c_void,
    EaLength: ULONG,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtDeviceIoControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*c_void,
    IoStatusBlock: *IO_STATUS_BLOCK,
    IoControlCode: ULONG,
    InputBuffer: ?*const c_void,
    InputBufferLength: ULONG,
    OutputBuffer: ?PVOID,
    OutputBufferLength: ULONG,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtClose(Handle: HANDLE) NTSTATUS;
pub extern "NtDll" stdcallcc fn RtlDosPathNameToNtPathName_U(
    DosPathName: [*]const u16,
    NtPathName: *UNICODE_STRING,
    NtFileNamePart: ?*?[*]const u16,
    DirectoryInfo: ?*CURDIR,
) BOOL;
pub extern "NtDll" stdcallcc fn RtlFreeUnicodeString(UnicodeString: *UNICODE_STRING) void;

pub extern "NtDll" stdcallcc fn NtQueryDirectoryFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*c_void,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *c_void,
    Length: ULONG,
    FileInformationClass: FILE_INFORMATION_CLASS,
    ReturnSingleEntry: BOOLEAN,
    FileName: ?*UNICODE_STRING,
    RestartScan: BOOLEAN,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtCreateKeyedEvent(
    KeyedEventHandle: *HANDLE,
    DesiredAccess: ACCESS_MASK,
    ObjectAttributes: ?PVOID,
    Flags: ULONG,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtReleaseKeyedEvent(
    EventHandle: HANDLE,
    Key: *const c_void,
    Alertable: BOOLEAN,
    Timeout: ?*LARGE_INTEGER,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtWaitForKeyedEvent(
    EventHandle: HANDLE,
    Key: *const c_void,
    Alertable: BOOLEAN,
    Timeout: ?*LARGE_INTEGER,
) NTSTATUS;
