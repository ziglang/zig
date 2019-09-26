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
    AllocationSize: *LARGE_INTEGER,
    FileAttributes: ULONG,
    ShareAccess: ULONG,
    CreateDisposition: ULONG,
    CreateOptions: ULONG,
    EaBuffer: *c_void,
    EaLength: ULONG,
) NTSTATUS;
pub extern "NtDll" stdcallcc fn NtClose(Handle: HANDLE) NTSTATUS;
