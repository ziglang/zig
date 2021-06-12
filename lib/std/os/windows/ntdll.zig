// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
usingnamespace @import("bits.zig");

pub extern "NtDll" fn RtlGetVersion(
    lpVersionInformation: PRTL_OSVERSIONINFOW,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn RtlCaptureStackBackTrace(
    FramesToSkip: DWORD,
    FramesToCapture: DWORD,
    BackTrace: **c_void,
    BackTraceHash: ?*DWORD,
) callconv(WINAPI) WORD;
pub extern "NtDll" fn NtQueryInformationFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *c_void,
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
    EaBuffer: ?*c_void,
    EaLength: ULONG,
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtDeviceIoControlFile(
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
) callconv(WINAPI) NTSTATUS;
pub extern "NtDll" fn NtFsControlFile(
    FileHandle: HANDLE,
    Event: ?HANDLE,
    ApcRoutine: ?IO_APC_ROUTINE,
    ApcContext: ?*c_void,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FsControlCode: ULONG,
    InputBuffer: ?*const c_void,
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
    ApcContext: ?*c_void,
    IoStatusBlock: *IO_STATUS_BLOCK,
    FileInformation: *c_void,
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
    Key: ?*const c_void,
    Alertable: BOOLEAN,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;

pub extern "NtDll" fn NtWaitForKeyedEvent(
    EventHandle: ?HANDLE,
    Key: ?*const c_void,
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
    Address: ?*const c_void,
) callconv(WINAPI) void;

pub extern "NtDll" fn RtlWakeAddressSingle(
    Address: ?*const c_void,
) callconv(WINAPI) void;

pub extern "NtDll" fn RtlWaitOnAddress(
    Address: ?*const c_void,
    CompareAddress: ?*const c_void,
    AddressSize: SIZE_T,
    Timeout: ?*const LARGE_INTEGER,
) callconv(WINAPI) NTSTATUS;
