//! This file contains thin wrappers around Windows-specific APIs, with these
//! specific goals in mind:
//! * Convert "errno"-style error codes into Zig errors.
//! * When null-terminated or UTF16LE byte buffers are required, provide APIs which accept
//!   slices as well as APIs which accept null-terminated UTF16LE byte buffers.

const builtin = @import("builtin");
const std = @import("../std.zig");
const mem = std.mem;
const assert = std.debug.assert;
const math = std.math;
const maxInt = std.math.maxInt;
const native_arch = builtin.cpu.arch;

test {
    if (builtin.os.tag == .windows) {
        _ = @import("windows/test.zig");
    }
}

pub const advapi32 = @import("windows/advapi32.zig");
pub const kernel32 = @import("windows/kernel32.zig");
pub const ntdll = @import("windows/ntdll.zig");
pub const ole32 = @import("windows/ole32.zig");
pub const psapi = @import("windows/psapi.zig");
pub const shell32 = @import("windows/shell32.zig");
pub const user32 = @import("windows/user32.zig");
pub const ws2_32 = @import("windows/ws2_32.zig");
pub const gdi32 = @import("windows/gdi32.zig");
pub const winmm = @import("windows/winmm.zig");
pub const crypt32 = @import("windows/crypt32.zig");
pub const nls = @import("windows/nls.zig");

pub const self_process_handle = @as(HANDLE, @ptrFromInt(maxInt(usize)));

const Self = @This();

pub const OpenError = error{
    IsDir,
    NotDir,
    FileNotFound,
    NoDevice,
    AccessDenied,
    PipeBusy,
    PathAlreadyExists,
    Unexpected,
    NameTooLong,
    WouldBlock,
    NetworkNotFound,
};

pub const OpenFileOptions = struct {
    access_mask: ACCESS_MASK,
    dir: ?HANDLE = null,
    sa: ?*SECURITY_ATTRIBUTES = null,
    share_access: ULONG = FILE_SHARE_WRITE | FILE_SHARE_READ | FILE_SHARE_DELETE,
    creation: ULONG,
    io_mode: std.io.ModeOverride,
    /// If true, tries to open path as a directory.
    /// Defaults to false.
    filter: Filter = .file_only,
    /// If false, tries to open path as a reparse point without dereferencing it.
    /// Defaults to true.
    follow_symlinks: bool = true,

    pub const Filter = enum {
        /// Causes `OpenFile` to return `error.IsDir` if the opened handle would be a directory.
        file_only,
        /// Causes `OpenFile` to return `error.NotDir` if the opened handle would be a file.
        dir_only,
        /// `OpenFile` does not discriminate between opening files and directories.
        any,
    };
};

pub fn OpenFile(sub_path_w: []const u16, options: OpenFileOptions) OpenError!HANDLE {
    if (mem.eql(u16, sub_path_w, &[_]u16{'.'}) and options.filter == .file_only) {
        return error.IsDir;
    }
    if (mem.eql(u16, sub_path_w, &[_]u16{ '.', '.' }) and options.filter == .file_only) {
        return error.IsDir;
    }

    var result: HANDLE = undefined;

    const path_len_bytes = math.cast(u16, sub_path_w.len * 2) orelse return error.NameTooLong;
    var nt_name = UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w.ptr),
    };
    var attr = OBJECT_ATTRIBUTES{
        .Length = @sizeOf(OBJECT_ATTRIBUTES),
        .RootDirectory = if (std.fs.path.isAbsoluteWindowsWTF16(sub_path_w)) null else options.dir,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = if (options.sa) |ptr| ptr.lpSecurityDescriptor else null,
        .SecurityQualityOfService = null,
    };
    var io: IO_STATUS_BLOCK = undefined;
    const blocking_flag: ULONG = if (options.io_mode == .blocking) FILE_SYNCHRONOUS_IO_NONALERT else 0;
    const file_or_dir_flag: ULONG = switch (options.filter) {
        .file_only => FILE_NON_DIRECTORY_FILE,
        .dir_only => FILE_DIRECTORY_FILE,
        .any => 0,
    };
    // If we're not following symlinks, we need to ensure we don't pass in any synchronization flags such as FILE_SYNCHRONOUS_IO_NONALERT.
    const flags: ULONG = if (options.follow_symlinks) file_or_dir_flag | blocking_flag else file_or_dir_flag | FILE_OPEN_REPARSE_POINT;

    while (true) {
        const rc = ntdll.NtCreateFile(
            &result,
            options.access_mask,
            &attr,
            &io,
            null,
            FILE_ATTRIBUTE_NORMAL,
            options.share_access,
            options.creation,
            flags,
            null,
            0,
        );
        switch (rc) {
            .SUCCESS => {
                if (std.io.is_async and options.io_mode == .evented) {
                    _ = CreateIoCompletionPort(result, std.event.Loop.instance.?.os_data.io_port, undefined, undefined) catch undefined;
                }
                return result;
            },
            .OBJECT_NAME_INVALID => unreachable,
            .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
            .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
            .BAD_NETWORK_PATH => return error.NetworkNotFound, // \\server was not found
            .BAD_NETWORK_NAME => return error.NetworkNotFound, // \\server was found but \\server\share wasn't
            .NO_MEDIA_IN_DEVICE => return error.NoDevice,
            .INVALID_PARAMETER => unreachable,
            .SHARING_VIOLATION => return error.AccessDenied,
            .ACCESS_DENIED => return error.AccessDenied,
            .PIPE_BUSY => return error.PipeBusy,
            .OBJECT_PATH_SYNTAX_BAD => unreachable,
            .OBJECT_NAME_COLLISION => return error.PathAlreadyExists,
            .FILE_IS_A_DIRECTORY => return error.IsDir,
            .NOT_A_DIRECTORY => return error.NotDir,
            .USER_MAPPED_FILE => return error.AccessDenied,
            .INVALID_HANDLE => unreachable,
            .DELETE_PENDING => {
                // This error means that there *was* a file in this location on
                // the file system, but it was deleted. However, the OS is not
                // finished with the deletion operation, and so this CreateFile
                // call has failed. There is not really a sane way to handle
                // this other than retrying the creation after the OS finishes
                // the deletion.
                std.time.sleep(std.time.ns_per_ms);
                continue;
            },
            else => return unexpectedStatus(rc),
        }
    }
}

pub const CreatePipeError = error{Unexpected};

pub fn CreatePipe(rd: *HANDLE, wr: *HANDLE, sattr: *const SECURITY_ATTRIBUTES) CreatePipeError!void {
    if (kernel32.CreatePipe(rd, wr, sattr, 0) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub fn CreateEventEx(attributes: ?*SECURITY_ATTRIBUTES, name: []const u8, flags: DWORD, desired_access: DWORD) !HANDLE {
    const nameW = try sliceToPrefixedFileW(name);
    return CreateEventExW(attributes, nameW.span().ptr, flags, desired_access);
}

pub fn CreateEventExW(attributes: ?*SECURITY_ATTRIBUTES, nameW: [*:0]const u16, flags: DWORD, desired_access: DWORD) !HANDLE {
    const handle = kernel32.CreateEventExW(attributes, nameW, flags, desired_access);
    if (handle) |h| {
        return h;
    } else {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const DeviceIoControlError = error{ AccessDenied, Unexpected };

/// A Zig wrapper around `NtDeviceIoControlFile` and `NtFsControlFile` syscalls.
/// It implements similar behavior to `DeviceIoControl` and is meant to serve
/// as a direct substitute for that call.
/// TODO work out if we need to expose other arguments to the underlying syscalls.
pub fn DeviceIoControl(
    h: HANDLE,
    ioControlCode: ULONG,
    in: ?[]const u8,
    out: ?[]u8,
) DeviceIoControlError!void {
    // Logic from: https://doxygen.reactos.org/d3/d74/deviceio_8c.html
    const is_fsctl = (ioControlCode >> 16) == FILE_DEVICE_FILE_SYSTEM;

    var io: IO_STATUS_BLOCK = undefined;
    const in_ptr = if (in) |i| i.ptr else null;
    const in_len = if (in) |i| @as(ULONG, @intCast(i.len)) else 0;
    const out_ptr = if (out) |o| o.ptr else null;
    const out_len = if (out) |o| @as(ULONG, @intCast(o.len)) else 0;

    const rc = blk: {
        if (is_fsctl) {
            break :blk ntdll.NtFsControlFile(
                h,
                null,
                null,
                null,
                &io,
                ioControlCode,
                in_ptr,
                in_len,
                out_ptr,
                out_len,
            );
        } else {
            break :blk ntdll.NtDeviceIoControlFile(
                h,
                null,
                null,
                null,
                &io,
                ioControlCode,
                in_ptr,
                in_len,
                out_ptr,
                out_len,
            );
        }
    };
    switch (rc) {
        .SUCCESS => {},
        .PRIVILEGE_NOT_HELD => return error.AccessDenied,
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_DEVICE_REQUEST => return error.AccessDenied, // Not supported by the underlying filesystem
        .INVALID_PARAMETER => unreachable,
        else => return unexpectedStatus(rc),
    }
}

pub fn GetOverlappedResult(h: HANDLE, overlapped: *OVERLAPPED, wait: bool) !DWORD {
    var bytes: DWORD = undefined;
    if (kernel32.GetOverlappedResult(h, overlapped, &bytes, @intFromBool(wait)) == 0) {
        switch (kernel32.GetLastError()) {
            .IO_INCOMPLETE => if (!wait) return error.WouldBlock else unreachable,
            else => |err| return unexpectedError(err),
        }
    }
    return bytes;
}

pub const SetHandleInformationError = error{Unexpected};

pub fn SetHandleInformation(h: HANDLE, mask: DWORD, flags: DWORD) SetHandleInformationError!void {
    if (kernel32.SetHandleInformation(h, mask, flags) == 0) {
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
    var total_read: usize = 0;
    var buff: []u8 = output[0..];
    const max_read_size: ULONG = maxInt(ULONG);

    while (total_read < output.len) {
        const to_read: ULONG = @min(buff.len, max_read_size);

        if (advapi32.RtlGenRandom(buff.ptr, to_read) == 0) {
            return unexpectedError(kernel32.GetLastError());
        }

        total_read += to_read;
        buff = buff[to_read..];
    }
}

pub const WaitForSingleObjectError = error{
    WaitAbandoned,
    WaitTimeOut,
    Unexpected,
};

pub fn WaitForSingleObject(handle: HANDLE, milliseconds: DWORD) WaitForSingleObjectError!void {
    return WaitForSingleObjectEx(handle, milliseconds, false);
}

pub fn WaitForSingleObjectEx(handle: HANDLE, milliseconds: DWORD, alertable: bool) WaitForSingleObjectError!void {
    switch (kernel32.WaitForSingleObjectEx(handle, milliseconds, @intFromBool(alertable))) {
        WAIT_ABANDONED => return error.WaitAbandoned,
        WAIT_OBJECT_0 => return,
        WAIT_TIMEOUT => return error.WaitTimeOut,
        WAIT_FAILED => switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        },
        else => return error.Unexpected,
    }
}

pub fn WaitForMultipleObjectsEx(handles: []const HANDLE, waitAll: bool, milliseconds: DWORD, alertable: bool) !u32 {
    assert(handles.len < MAXIMUM_WAIT_OBJECTS);
    const nCount: DWORD = @as(DWORD, @intCast(handles.len));
    switch (kernel32.WaitForMultipleObjectsEx(
        nCount,
        handles.ptr,
        @intFromBool(waitAll),
        milliseconds,
        @intFromBool(alertable),
    )) {
        WAIT_OBJECT_0...WAIT_OBJECT_0 + MAXIMUM_WAIT_OBJECTS => |n| {
            const handle_index = n - WAIT_OBJECT_0;
            assert(handle_index < nCount);
            return handle_index;
        },
        WAIT_ABANDONED_0...WAIT_ABANDONED_0 + MAXIMUM_WAIT_OBJECTS => |n| {
            const handle_index = n - WAIT_ABANDONED_0;
            assert(handle_index < nCount);
            return error.WaitAbandoned;
        },
        WAIT_TIMEOUT => return error.WaitTimeOut,
        WAIT_FAILED => switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        },
        else => return error.Unexpected,
    }
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
            .INVALID_PARAMETER => unreachable,
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
            else => |err| return unexpectedError(err),
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
            .ABANDONED_WAIT_0 => return GetQueuedCompletionStatusResult.Aborted,
            .OPERATION_ABORTED => return GetQueuedCompletionStatusResult.Cancelled,
            .HANDLE_EOF => return GetQueuedCompletionStatusResult.EOF,
            else => |err| {
                if (std.debug.runtime_safety) {
                    @setEvalBranchQuota(2500);
                    std.debug.panic("unexpected error: {}\n", .{err});
                }
            },
        }
    }
    return GetQueuedCompletionStatusResult.Normal;
}

pub const GetQueuedCompletionStatusError = error{
    Aborted,
    Cancelled,
    EOF,
    Timeout,
} || std.os.UnexpectedError;

pub fn GetQueuedCompletionStatusEx(
    completion_port: HANDLE,
    completion_port_entries: []OVERLAPPED_ENTRY,
    timeout_ms: ?DWORD,
    alertable: bool,
) GetQueuedCompletionStatusError!u32 {
    var num_entries_removed: u32 = 0;

    const success = kernel32.GetQueuedCompletionStatusEx(
        completion_port,
        completion_port_entries.ptr,
        @as(ULONG, @intCast(completion_port_entries.len)),
        &num_entries_removed,
        timeout_ms orelse INFINITE,
        @intFromBool(alertable),
    );

    if (success == FALSE) {
        return switch (kernel32.GetLastError()) {
            .ABANDONED_WAIT_0 => error.Aborted,
            .OPERATION_ABORTED => error.Cancelled,
            .HANDLE_EOF => error.EOF,
            .IMEOUT => error.Timeout,
            else => |err| unexpectedError(err),
        };
    }

    return num_entries_removed;
}

pub fn CloseHandle(hObject: HANDLE) void {
    assert(ntdll.NtClose(hObject) == .SUCCESS);
}

pub fn FindClose(hFindFile: HANDLE) void {
    assert(kernel32.FindClose(hFindFile) != 0);
}

pub const ReadFileError = error{
    BrokenPipe,
    NetNameDeleted,
    OperationAborted,
    Unexpected,
};

/// If buffer's length exceeds what a Windows DWORD integer can hold, it will be broken into
/// multiple non-atomic reads.
pub fn ReadFile(in_hFile: HANDLE, buffer: []u8, offset: ?u64, io_mode: std.io.ModeOverride) ReadFileError!usize {
    if (io_mode != .blocking) {
        const loop = std.event.Loop.instance.?;
        // TODO make getting the file position non-blocking
        const off = if (offset) |o| o else try SetFilePointerEx_CURRENT_get(in_hFile);
        var resume_node = std.event.Loop.ResumeNode.Basic{
            .base = .{
                .id = .Basic,
                .handle = @frame(),
                .overlapped = OVERLAPPED{
                    .Internal = 0,
                    .InternalHigh = 0,
                    .DUMMYUNIONNAME = .{
                        .DUMMYSTRUCTNAME = .{
                            .Offset = @as(u32, @truncate(off)),
                            .OffsetHigh = @as(u32, @truncate(off >> 32)),
                        },
                    },
                    .hEvent = null,
                },
            },
        };
        loop.beginOneEvent();
        suspend {
            // TODO handle buffer bigger than DWORD can hold
            _ = kernel32.ReadFile(in_hFile, buffer.ptr, @as(DWORD, @intCast(buffer.len)), null, &resume_node.base.overlapped);
        }
        var bytes_transferred: DWORD = undefined;
        if (kernel32.GetOverlappedResult(in_hFile, &resume_node.base.overlapped, &bytes_transferred, FALSE) == 0) {
            switch (kernel32.GetLastError()) {
                .IO_PENDING => unreachable,
                .OPERATION_ABORTED => return error.OperationAborted,
                .BROKEN_PIPE => return error.BrokenPipe,
                .NETNAME_DELETED => return error.NetNameDeleted,
                .HANDLE_EOF => return @as(usize, bytes_transferred),
                else => |err| return unexpectedError(err),
            }
        }
        if (offset == null) {
            // TODO make setting the file position non-blocking
            const new_off = off + bytes_transferred;
            try SetFilePointerEx_CURRENT(in_hFile, @as(i64, @bitCast(new_off)));
        }
        return @as(usize, bytes_transferred);
    } else {
        while (true) {
            const want_read_count: DWORD = @min(@as(DWORD, maxInt(DWORD)), buffer.len);
            var amt_read: DWORD = undefined;
            var overlapped_data: OVERLAPPED = undefined;
            const overlapped: ?*OVERLAPPED = if (offset) |off| blk: {
                overlapped_data = .{
                    .Internal = 0,
                    .InternalHigh = 0,
                    .DUMMYUNIONNAME = .{
                        .DUMMYSTRUCTNAME = .{
                            .Offset = @as(u32, @truncate(off)),
                            .OffsetHigh = @as(u32, @truncate(off >> 32)),
                        },
                    },
                    .hEvent = null,
                };
                break :blk &overlapped_data;
            } else null;
            if (kernel32.ReadFile(in_hFile, buffer.ptr, want_read_count, &amt_read, overlapped) == 0) {
                switch (kernel32.GetLastError()) {
                    .IO_PENDING => unreachable,
                    .OPERATION_ABORTED => continue,
                    .BROKEN_PIPE => return 0,
                    .HANDLE_EOF => return 0,
                    .NETNAME_DELETED => return error.NetNameDeleted,
                    else => |err| return unexpectedError(err),
                }
            }
            return amt_read;
        }
    }
}

pub const WriteFileError = error{
    SystemResources,
    OperationAborted,
    BrokenPipe,
    NotOpenForWriting,
    /// The process cannot access the file because another process has locked
    /// a portion of the file.
    LockViolation,
    Unexpected,
};

pub fn WriteFile(
    handle: HANDLE,
    bytes: []const u8,
    offset: ?u64,
    io_mode: std.io.ModeOverride,
) WriteFileError!usize {
    if (std.event.Loop.instance != null and io_mode != .blocking) {
        const loop = std.event.Loop.instance.?;
        // TODO make getting the file position non-blocking
        const off = if (offset) |o| o else try SetFilePointerEx_CURRENT_get(handle);
        var resume_node = std.event.Loop.ResumeNode.Basic{
            .base = .{
                .id = .Basic,
                .handle = @frame(),
                .overlapped = OVERLAPPED{
                    .Internal = 0,
                    .InternalHigh = 0,
                    .DUMMYUNIONNAME = .{
                        .DUMMYSTRUCTNAME = .{
                            .Offset = @as(u32, @truncate(off)),
                            .OffsetHigh = @as(u32, @truncate(off >> 32)),
                        },
                    },
                    .hEvent = null,
                },
            },
        };
        loop.beginOneEvent();
        suspend {
            const adjusted_len = math.cast(DWORD, bytes.len) orelse maxInt(DWORD);
            _ = kernel32.WriteFile(handle, bytes.ptr, adjusted_len, null, &resume_node.base.overlapped);
        }
        var bytes_transferred: DWORD = undefined;
        if (kernel32.GetOverlappedResult(handle, &resume_node.base.overlapped, &bytes_transferred, FALSE) == 0) {
            switch (kernel32.GetLastError()) {
                .IO_PENDING => unreachable,
                .INVALID_USER_BUFFER => return error.SystemResources,
                .NOT_ENOUGH_MEMORY => return error.SystemResources,
                .OPERATION_ABORTED => return error.OperationAborted,
                .NOT_ENOUGH_QUOTA => return error.SystemResources,
                .BROKEN_PIPE => return error.BrokenPipe,
                else => |err| return unexpectedError(err),
            }
        }
        if (offset == null) {
            // TODO make setting the file position non-blocking
            const new_off = off + bytes_transferred;
            try SetFilePointerEx_CURRENT(handle, @as(i64, @bitCast(new_off)));
        }
        return bytes_transferred;
    } else {
        var bytes_written: DWORD = undefined;
        var overlapped_data: OVERLAPPED = undefined;
        const overlapped: ?*OVERLAPPED = if (offset) |off| blk: {
            overlapped_data = .{
                .Internal = 0,
                .InternalHigh = 0,
                .DUMMYUNIONNAME = .{
                    .DUMMYSTRUCTNAME = .{
                        .Offset = @as(u32, @truncate(off)),
                        .OffsetHigh = @as(u32, @truncate(off >> 32)),
                    },
                },
                .hEvent = null,
            };
            break :blk &overlapped_data;
        } else null;
        const adjusted_len = math.cast(u32, bytes.len) orelse maxInt(u32);
        if (kernel32.WriteFile(handle, bytes.ptr, adjusted_len, &bytes_written, overlapped) == 0) {
            switch (kernel32.GetLastError()) {
                .INVALID_USER_BUFFER => return error.SystemResources,
                .NOT_ENOUGH_MEMORY => return error.SystemResources,
                .OPERATION_ABORTED => return error.OperationAborted,
                .NOT_ENOUGH_QUOTA => return error.SystemResources,
                .IO_PENDING => unreachable,
                .BROKEN_PIPE => return error.BrokenPipe,
                .INVALID_HANDLE => return error.NotOpenForWriting,
                .LOCK_VIOLATION => return error.LockViolation,
                else => |err| return unexpectedError(err),
            }
        }
        return bytes_written;
    }
}

pub const SetCurrentDirectoryError = error{
    NameTooLong,
    InvalidUtf8,
    FileNotFound,
    NotDir,
    AccessDenied,
    NoDevice,
    BadPathName,
    Unexpected,
};

pub fn SetCurrentDirectory(path_name: []const u16) SetCurrentDirectoryError!void {
    const path_len_bytes = math.cast(u16, path_name.len * 2) orelse return error.NameTooLong;

    var nt_name = UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(path_name.ptr),
    };

    const rc = ntdll.RtlSetCurrentDirectory_U(&nt_name);
    switch (rc) {
        .SUCCESS => {},
        .OBJECT_NAME_INVALID => return error.BadPathName,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .NO_MEDIA_IN_DEVICE => return error.NoDevice,
        .INVALID_PARAMETER => unreachable,
        .ACCESS_DENIED => return error.AccessDenied,
        .OBJECT_PATH_SYNTAX_BAD => unreachable,
        .NOT_A_DIRECTORY => return error.NotDir,
        else => return unexpectedStatus(rc),
    }
}

pub const GetCurrentDirectoryError = error{
    NameTooLong,
    Unexpected,
};

/// The result is a slice of `buffer`, indexed from 0.
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
    var it = std.unicode.Utf16LeIterator.init(utf16le_slice);
    while (it.nextCodepoint() catch unreachable) |codepoint| {
        const seq_len = std.unicode.utf8CodepointSequenceLength(codepoint) catch unreachable;
        if (end_index + seq_len >= buffer.len)
            return error.NameTooLong;
        end_index += std.unicode.utf8Encode(codepoint, buffer[end_index..]) catch unreachable;
    }
    return buffer[0..end_index];
}

pub const CreateSymbolicLinkError = error{
    AccessDenied,
    PathAlreadyExists,
    FileNotFound,
    NameTooLong,
    NoDevice,
    NetworkNotFound,
    Unexpected,
};

/// Needs either:
/// - `SeCreateSymbolicLinkPrivilege` privilege
/// or
/// - Developer mode on Windows 10
/// otherwise fails with `error.AccessDenied`. In which case `sym_link_path` may still
/// be created on the file system but will lack reparse processing data applied to it.
pub fn CreateSymbolicLink(
    dir: ?HANDLE,
    sym_link_path: []const u16,
    target_path: []const u16,
    is_directory: bool,
) CreateSymbolicLinkError!void {
    const SYMLINK_DATA = extern struct {
        ReparseTag: ULONG,
        ReparseDataLength: USHORT,
        Reserved: USHORT,
        SubstituteNameOffset: USHORT,
        SubstituteNameLength: USHORT,
        PrintNameOffset: USHORT,
        PrintNameLength: USHORT,
        Flags: ULONG,
    };

    const symlink_handle = OpenFile(sym_link_path, .{
        .access_mask = SYNCHRONIZE | GENERIC_READ | GENERIC_WRITE,
        .dir = dir,
        .creation = FILE_CREATE,
        .io_mode = .blocking,
        .filter = if (is_directory) .dir_only else .file_only,
    }) catch |err| switch (err) {
        error.IsDir => return error.PathAlreadyExists,
        error.NotDir => unreachable,
        error.WouldBlock => unreachable,
        error.PipeBusy => unreachable,
        else => |e| return e,
    };
    defer CloseHandle(symlink_handle);

    // prepare reparse data buffer
    var buffer: [MAXIMUM_REPARSE_DATA_BUFFER_SIZE]u8 = undefined;
    const buf_len = @sizeOf(SYMLINK_DATA) + target_path.len * 4;
    const header_len = @sizeOf(ULONG) + @sizeOf(USHORT) * 2;
    const symlink_data = SYMLINK_DATA{
        .ReparseTag = IO_REPARSE_TAG_SYMLINK,
        .ReparseDataLength = @as(u16, @intCast(buf_len - header_len)),
        .Reserved = 0,
        .SubstituteNameOffset = @as(u16, @intCast(target_path.len * 2)),
        .SubstituteNameLength = @as(u16, @intCast(target_path.len * 2)),
        .PrintNameOffset = 0,
        .PrintNameLength = @as(u16, @intCast(target_path.len * 2)),
        .Flags = if (dir) |_| SYMLINK_FLAG_RELATIVE else 0,
    };

    @memcpy(buffer[0..@sizeOf(SYMLINK_DATA)], std.mem.asBytes(&symlink_data));
    @memcpy(buffer[@sizeOf(SYMLINK_DATA)..][0 .. target_path.len * 2], @as([*]const u8, @ptrCast(target_path)));
    const paths_start = @sizeOf(SYMLINK_DATA) + target_path.len * 2;
    @memcpy(buffer[paths_start..][0 .. target_path.len * 2], @as([*]const u8, @ptrCast(target_path)));
    _ = try DeviceIoControl(symlink_handle, FSCTL_SET_REPARSE_POINT, buffer[0..buf_len], null);
}

pub const ReadLinkError = error{
    FileNotFound,
    AccessDenied,
    Unexpected,
    NameTooLong,
    UnsupportedReparsePointType,
};

pub fn ReadLink(dir: ?HANDLE, sub_path_w: []const u16, out_buffer: []u8) ReadLinkError![]u8 {
    // Here, we use `NtCreateFile` to shave off one syscall if we were to use `OpenFile` wrapper.
    // With the latter, we'd need to call `NtCreateFile` twice, once for file symlink, and if that
    // failed, again for dir symlink. Omitting any mention of file/dir flags makes it possible
    // to open the symlink there and then.
    const path_len_bytes = math.cast(u16, sub_path_w.len * 2) orelse return error.NameTooLong;
    var nt_name = UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        .Buffer = @constCast(sub_path_w.ptr),
    };
    var attr = OBJECT_ATTRIBUTES{
        .Length = @sizeOf(OBJECT_ATTRIBUTES),
        .RootDirectory = if (std.fs.path.isAbsoluteWindowsWTF16(sub_path_w)) null else dir,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var result_handle: HANDLE = undefined;
    var io: IO_STATUS_BLOCK = undefined;

    const rc = ntdll.NtCreateFile(
        &result_handle,
        FILE_READ_ATTRIBUTES,
        &attr,
        &io,
        null,
        FILE_ATTRIBUTE_NORMAL,
        FILE_SHARE_READ,
        FILE_OPEN,
        FILE_OPEN_REPARSE_POINT,
        null,
        0,
    );
    switch (rc) {
        .SUCCESS => {},
        .OBJECT_NAME_INVALID => unreachable,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .NO_MEDIA_IN_DEVICE => return error.FileNotFound,
        // TODO: Should BAD_NETWORK_* be translated to a different error?
        .BAD_NETWORK_PATH => return error.FileNotFound, // \\server was not found
        .BAD_NETWORK_NAME => return error.FileNotFound, // \\server was found but \\server\share wasn't
        .INVALID_PARAMETER => unreachable,
        .SHARING_VIOLATION => return error.AccessDenied,
        .ACCESS_DENIED => return error.AccessDenied,
        .PIPE_BUSY => return error.AccessDenied,
        .OBJECT_PATH_SYNTAX_BAD => unreachable,
        .OBJECT_NAME_COLLISION => unreachable,
        .FILE_IS_A_DIRECTORY => unreachable,
        else => return unexpectedStatus(rc),
    }
    defer CloseHandle(result_handle);

    var reparse_buf: [MAXIMUM_REPARSE_DATA_BUFFER_SIZE]u8 align(@alignOf(REPARSE_DATA_BUFFER)) = undefined;
    _ = DeviceIoControl(result_handle, FSCTL_GET_REPARSE_POINT, null, reparse_buf[0..]) catch |err| switch (err) {
        error.AccessDenied => unreachable,
        else => |e| return e,
    };

    const reparse_struct: *const REPARSE_DATA_BUFFER = @ptrCast(@alignCast(&reparse_buf[0]));
    switch (reparse_struct.ReparseTag) {
        IO_REPARSE_TAG_SYMLINK => {
            const buf: *const SYMBOLIC_LINK_REPARSE_BUFFER = @ptrCast(@alignCast(&reparse_struct.DataBuffer[0]));
            const offset = buf.SubstituteNameOffset >> 1;
            const len = buf.SubstituteNameLength >> 1;
            const path_buf = @as([*]const u16, &buf.PathBuffer);
            const is_relative = buf.Flags & SYMLINK_FLAG_RELATIVE != 0;
            return parseReadlinkPath(path_buf[offset..][0..len], is_relative, out_buffer);
        },
        IO_REPARSE_TAG_MOUNT_POINT => {
            const buf: *const MOUNT_POINT_REPARSE_BUFFER = @ptrCast(@alignCast(&reparse_struct.DataBuffer[0]));
            const offset = buf.SubstituteNameOffset >> 1;
            const len = buf.SubstituteNameLength >> 1;
            const path_buf = @as([*]const u16, &buf.PathBuffer);
            return parseReadlinkPath(path_buf[offset..][0..len], false, out_buffer);
        },
        else => |value| {
            std.debug.print("unsupported symlink type: {}", .{value});
            return error.UnsupportedReparsePointType;
        },
    }
}

fn parseReadlinkPath(path: []const u16, is_relative: bool, out_buffer: []u8) []u8 {
    const prefix = [_]u16{ '\\', '?', '?', '\\' };
    var start_index: usize = 0;
    if (!is_relative and std.mem.startsWith(u16, path, &prefix)) {
        start_index = prefix.len;
    }
    const out_len = std.unicode.utf16leToUtf8(out_buffer, path[start_index..]) catch unreachable;
    return out_buffer[0..out_len];
}

pub const DeleteFileError = error{
    FileNotFound,
    AccessDenied,
    NameTooLong,
    /// Also known as sharing violation.
    FileBusy,
    Unexpected,
    NotDir,
    IsDir,
    DirNotEmpty,
    NetworkNotFound,
};

pub const DeleteFileOptions = struct {
    dir: ?HANDLE,
    remove_dir: bool = false,
};

pub fn DeleteFile(sub_path_w: []const u16, options: DeleteFileOptions) DeleteFileError!void {
    const create_options_flags: ULONG = if (options.remove_dir)
        FILE_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT
    else
        FILE_NON_DIRECTORY_FILE | FILE_OPEN_REPARSE_POINT; // would we ever want to delete the target instead?

    const path_len_bytes = @as(u16, @intCast(sub_path_w.len * 2));
    var nt_name = UNICODE_STRING{
        .Length = path_len_bytes,
        .MaximumLength = path_len_bytes,
        // The Windows API makes this mutable, but it will not mutate here.
        .Buffer = @constCast(sub_path_w.ptr),
    };

    if (sub_path_w[0] == '.' and sub_path_w[1] == 0) {
        // Windows does not recognize this, but it does work with empty string.
        nt_name.Length = 0;
    }
    if (sub_path_w[0] == '.' and sub_path_w[1] == '.' and sub_path_w[2] == 0) {
        // Can't remove the parent directory with an open handle.
        return error.FileBusy;
    }

    var attr = OBJECT_ATTRIBUTES{
        .Length = @sizeOf(OBJECT_ATTRIBUTES),
        .RootDirectory = if (std.fs.path.isAbsoluteWindowsWTF16(sub_path_w)) null else options.dir,
        .Attributes = 0, // Note we do not use OBJ_CASE_INSENSITIVE here.
        .ObjectName = &nt_name,
        .SecurityDescriptor = null,
        .SecurityQualityOfService = null,
    };
    var io: IO_STATUS_BLOCK = undefined;
    var tmp_handle: HANDLE = undefined;
    var rc = ntdll.NtCreateFile(
        &tmp_handle,
        SYNCHRONIZE | DELETE,
        &attr,
        &io,
        null,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
        FILE_OPEN,
        create_options_flags,
        null,
        0,
    );
    switch (rc) {
        .SUCCESS => {},
        .OBJECT_NAME_INVALID => unreachable,
        .OBJECT_NAME_NOT_FOUND => return error.FileNotFound,
        .OBJECT_PATH_NOT_FOUND => return error.FileNotFound,
        .BAD_NETWORK_PATH => return error.NetworkNotFound, // \\server was not found
        .BAD_NETWORK_NAME => return error.NetworkNotFound, // \\server was found but \\server\share wasn't
        .INVALID_PARAMETER => unreachable,
        .FILE_IS_A_DIRECTORY => return error.IsDir,
        .NOT_A_DIRECTORY => return error.NotDir,
        .SHARING_VIOLATION => return error.FileBusy,
        .ACCESS_DENIED => return error.AccessDenied,
        .DELETE_PENDING => return,
        else => return unexpectedStatus(rc),
    }
    defer CloseHandle(tmp_handle);

    // FileDispositionInformationEx (and therefore FILE_DISPOSITION_POSIX_SEMANTICS and FILE_DISPOSITION_IGNORE_READONLY_ATTRIBUTE)
    // are only supported on NTFS filesystems, so the version check on its own is only a partial solution. To support non-NTFS filesystems
    // like FAT32, we need to fallback to FileDispositionInformation if the usage of FileDispositionInformationEx gives
    // us INVALID_PARAMETER.
    var need_fallback = true;
    if (comptime builtin.target.os.version_range.windows.min.isAtLeast(.win10_rs1)) {
        // Deletion with posix semantics if the filesystem supports it.
        var info = FILE_DISPOSITION_INFORMATION_EX{
            .Flags = FILE_DISPOSITION_DELETE |
                FILE_DISPOSITION_POSIX_SEMANTICS |
                FILE_DISPOSITION_IGNORE_READONLY_ATTRIBUTE,
        };

        rc = ntdll.NtSetInformationFile(
            tmp_handle,
            &io,
            &info,
            @sizeOf(FILE_DISPOSITION_INFORMATION_EX),
            .FileDispositionInformationEx,
        );
        switch (rc) {
            // INVALID_PARAMETER here means that the filesystem does not support FileDispositionInformationEx
            .INVALID_PARAMETER => {},
            // For all other statuses, fall down to the switch below to handle them.
            else => need_fallback = false,
        }
    }
    if (need_fallback) {
        // Deletion with file pending semantics, which requires waiting or moving
        // files to get them removed (from here).
        var file_dispo = FILE_DISPOSITION_INFORMATION{
            .DeleteFile = TRUE,
        };

        rc = ntdll.NtSetInformationFile(
            tmp_handle,
            &io,
            &file_dispo,
            @sizeOf(FILE_DISPOSITION_INFORMATION),
            .FileDispositionInformation,
        );
    }
    switch (rc) {
        .SUCCESS => {},
        .DIRECTORY_NOT_EMPTY => return error.DirNotEmpty,
        .INVALID_PARAMETER => unreachable,
        .CANNOT_DELETE => return error.AccessDenied,
        .MEDIA_WRITE_PROTECTED => return error.AccessDenied,
        .ACCESS_DENIED => return error.AccessDenied,
        else => return unexpectedStatus(rc),
    }
}

pub const MoveFileError = error{ FileNotFound, AccessDenied, Unexpected };

pub fn MoveFileEx(old_path: []const u8, new_path: []const u8, flags: DWORD) MoveFileError!void {
    const old_path_w = try sliceToPrefixedFileW(old_path);
    const new_path_w = try sliceToPrefixedFileW(new_path);
    return MoveFileExW(old_path_w.span().ptr, new_path_w.span().ptr, flags);
}

pub fn MoveFileExW(old_path: [*:0]const u16, new_path: [*:0]const u16, flags: DWORD) MoveFileError!void {
    if (kernel32.MoveFileExW(old_path, new_path, flags) == 0) {
        switch (kernel32.GetLastError()) {
            .FILE_NOT_FOUND => return error.FileNotFound,
            .ACCESS_DENIED => return error.AccessDenied,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const GetStdHandleError = error{
    NoStandardHandleAttached,
    Unexpected,
};

pub fn GetStdHandle(handle_id: DWORD) GetStdHandleError!HANDLE {
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
    const ipos = @as(LARGE_INTEGER, @bitCast(offset));
    if (kernel32.SetFilePointerEx(handle, ipos, null, FILE_BEGIN) == 0) {
        switch (kernel32.GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            .INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with the `dwMoveMethod` parameter set to `FILE_CURRENT`.
pub fn SetFilePointerEx_CURRENT(handle: HANDLE, offset: i64) SetFilePointerError!void {
    if (kernel32.SetFilePointerEx(handle, offset, null, FILE_CURRENT) == 0) {
        switch (kernel32.GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            .INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with the `dwMoveMethod` parameter set to `FILE_END`.
pub fn SetFilePointerEx_END(handle: HANDLE, offset: i64) SetFilePointerError!void {
    if (kernel32.SetFilePointerEx(handle, offset, null, FILE_END) == 0) {
        switch (kernel32.GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            .INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
}

/// The SetFilePointerEx function with parameters to get the current offset.
pub fn SetFilePointerEx_CURRENT_get(handle: HANDLE) SetFilePointerError!u64 {
    var result: LARGE_INTEGER = undefined;
    if (kernel32.SetFilePointerEx(handle, 0, &result, FILE_CURRENT) == 0) {
        switch (kernel32.GetLastError()) {
            .INVALID_PARAMETER => unreachable,
            .INVALID_HANDLE => unreachable,
            else => |err| return unexpectedError(err),
        }
    }
    // Based on the docs for FILE_BEGIN, it seems that the returned signed integer
    // should be interpreted as an unsigned integer.
    return @as(u64, @bitCast(result));
}

pub fn QueryObjectName(
    handle: HANDLE,
    out_buffer: []u16,
) ![]u16 {
    const out_buffer_aligned = mem.alignInSlice(out_buffer, @alignOf(OBJECT_NAME_INFORMATION)) orelse return error.NameTooLong;

    const info = @as(*OBJECT_NAME_INFORMATION, @ptrCast(out_buffer_aligned));
    //buffer size is specified in bytes
    const out_buffer_len = std.math.cast(ULONG, out_buffer_aligned.len * 2) orelse std.math.maxInt(ULONG);
    //last argument would return the length required for full_buffer, not exposed here
    const rc = ntdll.NtQueryObject(handle, .ObjectNameInformation, info, out_buffer_len, null);
    switch (rc) {
        .SUCCESS => {
            // info.Name.Buffer from ObQueryNameString is documented to be null (and MaximumLength == 0)
            // if the object was "unnamed", not sure if this can happen for file handles
            if (info.Name.MaximumLength == 0) return error.Unexpected;
            // resulting string length is specified in bytes
            const path_length_unterminated = @divExact(info.Name.Length, 2);
            return info.Name.Buffer[0..path_length_unterminated];
        },
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_HANDLE => return error.InvalidHandle,
        // triggered when the buffer is too small for the OBJECT_NAME_INFORMATION object (.INFO_LENGTH_MISMATCH),
        // or if the buffer is too small for the file path returned (.BUFFER_OVERFLOW, .BUFFER_TOO_SMALL)
        .INFO_LENGTH_MISMATCH, .BUFFER_OVERFLOW, .BUFFER_TOO_SMALL => return error.NameTooLong,
        else => |e| return unexpectedStatus(e),
    }
}
test "QueryObjectName" {
    if (builtin.os.tag != .windows)
        return;

    //any file will do; canonicalization works on NTFS junctions and symlinks, hardlinks remain separate paths.
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir.fd;
    var out_buffer: [PATH_MAX_WIDE]u16 = undefined;

    var result_path = try QueryObjectName(handle, &out_buffer);
    const required_len_in_u16 = result_path.len + @divExact(@intFromPtr(result_path.ptr) - @intFromPtr(&out_buffer), 2) + 1;
    //insufficient size
    try std.testing.expectError(error.NameTooLong, QueryObjectName(handle, out_buffer[0 .. required_len_in_u16 - 1]));
    //exactly-sufficient size
    _ = try QueryObjectName(handle, out_buffer[0..required_len_in_u16]);
}

pub const GetFinalPathNameByHandleError = error{
    AccessDenied,
    BadPathName,
    FileNotFound,
    NameTooLong,
    Unexpected,
};

/// Specifies how to format volume path in the result of `GetFinalPathNameByHandle`.
/// Defaults to DOS volume names.
pub const GetFinalPathNameByHandleFormat = struct {
    volume_name: enum {
        /// Format as DOS volume name
        Dos,
        /// Format as NT volume name
        Nt,
    } = .Dos,
};

/// Returns canonical (normalized) path of handle.
/// Use `GetFinalPathNameByHandleFormat` to specify whether the path is meant to include
/// NT or DOS volume name (e.g., `\Device\HarddiskVolume0\foo.txt` versus `C:\foo.txt`).
/// If DOS volume name format is selected, note that this function does *not* prepend
/// `\\?\` prefix to the resultant path.
pub fn GetFinalPathNameByHandle(
    hFile: HANDLE,
    fmt: GetFinalPathNameByHandleFormat,
    out_buffer: []u16,
) GetFinalPathNameByHandleError![]u16 {
    const final_path = QueryObjectName(hFile, out_buffer) catch |err| switch (err) {
        // we assume InvalidHandle is close enough to FileNotFound in semantics
        // to not further complicate the error set
        error.InvalidHandle => return error.FileNotFound,
        else => |e| return e,
    };

    switch (fmt.volume_name) {
        .Nt => {
            // the returned path is already in .Nt format
            return final_path;
        },
        .Dos => {
            // parse the string to separate volume path from file path
            const expected_prefix = std.unicode.utf8ToUtf16LeStringLiteral("\\Device\\");

            // TODO find out if a path can start with something besides `\Device\<volume name>`,
            // and if we need to handle it differently
            // (i.e. how to determine the start and end of the volume name in that case)
            if (!mem.eql(u16, expected_prefix, final_path[0..expected_prefix.len])) return error.Unexpected;

            const file_path_begin_index = mem.indexOfPos(u16, final_path, expected_prefix.len, &[_]u16{'\\'}) orelse unreachable;
            const volume_name_u16 = final_path[0..file_path_begin_index];
            const file_name_u16 = final_path[file_path_begin_index..];

            // Get DOS volume name. DOS volume names are actually symbolic link objects to the
            // actual NT volume. For example:
            // (NT) \Device\HarddiskVolume4 => (DOS) \DosDevices\C: == (DOS) C:
            const MIN_SIZE = @sizeOf(MOUNTMGR_MOUNT_POINT) + MAX_PATH;
            // We initialize the input buffer to all zeros for convenience since
            // `DeviceIoControl` with `IOCTL_MOUNTMGR_QUERY_POINTS` expects this.
            var input_buf: [MIN_SIZE]u8 align(@alignOf(MOUNTMGR_MOUNT_POINT)) = [_]u8{0} ** MIN_SIZE;
            var output_buf: [MIN_SIZE * 4]u8 align(@alignOf(MOUNTMGR_MOUNT_POINTS)) = undefined;

            // This surprising path is a filesystem path to the mount manager on Windows.
            // Source: https://stackoverflow.com/questions/3012828/using-ioctl-mountmgr-query-points
            // This is the NT namespaced version of \\.\MountPointManager
            const mgmt_path_u16 = std.unicode.utf8ToUtf16LeStringLiteral("\\??\\MountPointManager");
            const mgmt_handle = OpenFile(mgmt_path_u16, .{
                .access_mask = SYNCHRONIZE,
                .share_access = FILE_SHARE_READ | FILE_SHARE_WRITE,
                .creation = FILE_OPEN,
                .io_mode = .blocking,
            }) catch |err| switch (err) {
                error.IsDir => unreachable,
                error.NotDir => unreachable,
                error.NoDevice => unreachable,
                error.AccessDenied => unreachable,
                error.PipeBusy => unreachable,
                error.PathAlreadyExists => unreachable,
                error.WouldBlock => unreachable,
                error.NetworkNotFound => unreachable,
                else => |e| return e,
            };
            defer CloseHandle(mgmt_handle);

            var input_struct = @as(*MOUNTMGR_MOUNT_POINT, @ptrCast(&input_buf[0]));
            input_struct.DeviceNameOffset = @sizeOf(MOUNTMGR_MOUNT_POINT);
            input_struct.DeviceNameLength = @as(USHORT, @intCast(volume_name_u16.len * 2));
            @memcpy(input_buf[@sizeOf(MOUNTMGR_MOUNT_POINT)..][0 .. volume_name_u16.len * 2], @as([*]const u8, @ptrCast(volume_name_u16.ptr)));

            DeviceIoControl(mgmt_handle, IOCTL_MOUNTMGR_QUERY_POINTS, &input_buf, &output_buf) catch |err| switch (err) {
                error.AccessDenied => unreachable,
                else => |e| return e,
            };
            const mount_points_struct = @as(*const MOUNTMGR_MOUNT_POINTS, @ptrCast(&output_buf[0]));

            const mount_points = @as(
                [*]const MOUNTMGR_MOUNT_POINT,
                @ptrCast(&mount_points_struct.MountPoints[0]),
            )[0..mount_points_struct.NumberOfMountPoints];

            for (mount_points) |mount_point| {
                const symlink = @as(
                    [*]const u16,
                    @ptrCast(@alignCast(&output_buf[mount_point.SymbolicLinkNameOffset])),
                )[0 .. mount_point.SymbolicLinkNameLength / 2];

                // Look for `\DosDevices\` prefix. We don't really care if there are more than one symlinks
                // with traditional DOS drive letters, so pick the first one available.
                var prefix_buf = std.unicode.utf8ToUtf16LeStringLiteral("\\DosDevices\\");
                const prefix = prefix_buf[0..prefix_buf.len];

                if (mem.startsWith(u16, symlink, prefix)) {
                    const drive_letter = symlink[prefix.len..];

                    if (out_buffer.len < drive_letter.len + file_name_u16.len) return error.NameTooLong;

                    @memcpy(out_buffer[0..drive_letter.len], drive_letter);
                    mem.copyForwards(u16, out_buffer[drive_letter.len..][0..file_name_u16.len], file_name_u16);
                    const total_len = drive_letter.len + file_name_u16.len;

                    // Validate that DOS does not contain any spurious nul bytes.
                    if (mem.indexOfScalar(u16, out_buffer[0..total_len], 0)) |_| {
                        return error.BadPathName;
                    }

                    return out_buffer[0..total_len];
                }
            }

            // If we've ended up here, then something went wrong/is corrupted in the OS,
            // so error out!
            return error.FileNotFound;
        },
    }
}

test "GetFinalPathNameByHandle" {
    if (builtin.os.tag != .windows)
        return;

    //any file will do
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const handle = tmp.dir.fd;
    var buffer: [PATH_MAX_WIDE]u16 = undefined;

    //check with sufficient size
    const nt_path = try GetFinalPathNameByHandle(handle, .{ .volume_name = .Nt }, &buffer);
    _ = try GetFinalPathNameByHandle(handle, .{ .volume_name = .Dos }, &buffer);

    const required_len_in_u16 = nt_path.len + @divExact(@intFromPtr(nt_path.ptr) - @intFromPtr(&buffer), 2) + 1;
    //check with insufficient size
    try std.testing.expectError(error.NameTooLong, GetFinalPathNameByHandle(handle, .{ .volume_name = .Nt }, buffer[0 .. required_len_in_u16 - 1]));
    try std.testing.expectError(error.NameTooLong, GetFinalPathNameByHandle(handle, .{ .volume_name = .Dos }, buffer[0 .. required_len_in_u16 - 1]));

    //check with exactly-sufficient size
    _ = try GetFinalPathNameByHandle(handle, .{ .volume_name = .Nt }, buffer[0..required_len_in_u16]);
    _ = try GetFinalPathNameByHandle(handle, .{ .volume_name = .Dos }, buffer[0..required_len_in_u16]);
}

pub const GetFileSizeError = error{Unexpected};

pub fn GetFileSizeEx(hFile: HANDLE) GetFileSizeError!u64 {
    var file_size: LARGE_INTEGER = undefined;
    if (kernel32.GetFileSizeEx(hFile, &file_size) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    return @as(u64, @bitCast(file_size));
}

pub const GetFileAttributesError = error{
    FileNotFound,
    PermissionDenied,
    Unexpected,
};

pub fn GetFileAttributes(filename: []const u8) GetFileAttributesError!DWORD {
    const filename_w = try sliceToPrefixedFileW(filename);
    return GetFileAttributesW(filename_w.span().ptr);
}

pub fn GetFileAttributesW(lpFileName: [*:0]const u16) GetFileAttributesError!DWORD {
    const rc = kernel32.GetFileAttributesW(lpFileName);
    if (rc == INVALID_FILE_ATTRIBUTES) {
        switch (kernel32.GetLastError()) {
            .FILE_NOT_FOUND => return error.FileNotFound,
            .PATH_NOT_FOUND => return error.FileNotFound,
            .ACCESS_DENIED => return error.PermissionDenied,
            else => |err| return unexpectedError(err),
        }
    }
    return rc;
}

pub fn WSAStartup(majorVersion: u8, minorVersion: u8) !ws2_32.WSADATA {
    var wsadata: ws2_32.WSADATA = undefined;
    return switch (ws2_32.WSAStartup((@as(WORD, minorVersion) << 8) | majorVersion, &wsadata)) {
        0 => wsadata,
        else => |err_int| switch (@as(ws2_32.WinsockError, @enumFromInt(@as(u16, @intCast(err_int))))) {
            .WSASYSNOTREADY => return error.SystemNotAvailable,
            .WSAVERNOTSUPPORTED => return error.VersionNotSupported,
            .WSAEINPROGRESS => return error.BlockingOperationInProgress,
            .WSAEPROCLIM => return error.ProcessFdQuotaExceeded,
            else => |err| return unexpectedWSAError(err),
        },
    };
}

pub fn WSACleanup() !void {
    return switch (ws2_32.WSACleanup()) {
        0 => {},
        ws2_32.SOCKET_ERROR => switch (ws2_32.WSAGetLastError()) {
            .WSANOTINITIALISED => return error.NotInitialized,
            .WSAENETDOWN => return error.NetworkNotAvailable,
            .WSAEINPROGRESS => return error.BlockingOperationInProgress,
            else => |err| return unexpectedWSAError(err),
        },
        else => unreachable,
    };
}

var wsa_startup_mutex: std.Thread.Mutex = .{};

pub fn callWSAStartup() !void {
    wsa_startup_mutex.lock();
    defer wsa_startup_mutex.unlock();

    // Here we could use a flag to prevent multiple threads to prevent
    // multiple calls to WSAStartup, but it doesn't matter. We're globally
    // leaking the resource intentionally, and the mutex already prevents
    // data races within the WSAStartup function.
    _ = WSAStartup(2, 2) catch |err| switch (err) {
        error.SystemNotAvailable => return error.SystemResources,
        error.VersionNotSupported => return error.Unexpected,
        error.BlockingOperationInProgress => return error.Unexpected,
        error.ProcessFdQuotaExceeded => return error.ProcessFdQuotaExceeded,
        error.Unexpected => return error.Unexpected,
    };
}

/// Microsoft requires WSAStartup to be called to initialize, or else
/// WSASocketW will return WSANOTINITIALISED.
/// Since this is a standard library, we do not have the luxury of
/// putting initialization code anywhere, because we would not want
/// to pay the cost of calling WSAStartup if there ended up being no
/// networking. Also, if Zig code is used as a library, Zig is not in
/// charge of the start code, and we couldn't put in any initialization
/// code even if we wanted to.
/// The documentation for WSAStartup mentions that there must be a
/// matching WSACleanup call. It is not possible for the Zig Standard
/// Library to honor this for the same reason - there is nowhere to put
/// deinitialization code.
/// So, API users of the zig std lib have two options:
///  * (recommended) The simple, cross-platform way: just call `WSASocketW`
///    and don't worry about it. Zig will call WSAStartup() in a thread-safe
///    manner and never deinitialize networking. This is ideal for an
///    application which has the capability to do networking.
///  * The getting-your-hands-dirty way: call `WSAStartup()` before doing
///    networking, so that the error handling code for WSANOTINITIALISED never
///    gets run, which then allows the application or library to call `WSACleanup()`.
///    This could make sense for a library, which has init and deinit
///    functions for the whole library's lifetime.
pub fn WSASocketW(
    af: i32,
    socket_type: i32,
    protocol: i32,
    protocolInfo: ?*ws2_32.WSAPROTOCOL_INFOW,
    g: ws2_32.GROUP,
    dwFlags: DWORD,
) !ws2_32.SOCKET {
    var first = true;
    while (true) {
        const rc = ws2_32.WSASocketW(af, socket_type, protocol, protocolInfo, g, dwFlags);
        if (rc == ws2_32.INVALID_SOCKET) {
            switch (ws2_32.WSAGetLastError()) {
                .WSAEAFNOSUPPORT => return error.AddressFamilyNotSupported,
                .WSAEMFILE => return error.ProcessFdQuotaExceeded,
                .WSAENOBUFS => return error.SystemResources,
                .WSAEPROTONOSUPPORT => return error.ProtocolNotSupported,
                .WSANOTINITIALISED => {
                    if (!first) return error.Unexpected;
                    first = false;
                    try callWSAStartup();
                    continue;
                },
                else => |err| return unexpectedWSAError(err),
            }
        }
        return rc;
    }
}

pub fn bind(s: ws2_32.SOCKET, name: *const ws2_32.sockaddr, namelen: ws2_32.socklen_t) i32 {
    return ws2_32.bind(s, name, @as(i32, @intCast(namelen)));
}

pub fn listen(s: ws2_32.SOCKET, backlog: u31) i32 {
    return ws2_32.listen(s, backlog);
}

pub fn closesocket(s: ws2_32.SOCKET) !void {
    switch (ws2_32.closesocket(s)) {
        0 => {},
        ws2_32.SOCKET_ERROR => switch (ws2_32.WSAGetLastError()) {
            else => |err| return unexpectedWSAError(err),
        },
        else => unreachable,
    }
}

pub fn accept(s: ws2_32.SOCKET, name: ?*ws2_32.sockaddr, namelen: ?*ws2_32.socklen_t) ws2_32.SOCKET {
    assert((name == null) == (namelen == null));
    return ws2_32.accept(s, name, @as(?*i32, @ptrCast(namelen)));
}

pub fn getsockname(s: ws2_32.SOCKET, name: *ws2_32.sockaddr, namelen: *ws2_32.socklen_t) i32 {
    return ws2_32.getsockname(s, name, @as(*i32, @ptrCast(namelen)));
}

pub fn getpeername(s: ws2_32.SOCKET, name: *ws2_32.sockaddr, namelen: *ws2_32.socklen_t) i32 {
    return ws2_32.getpeername(s, name, @as(*i32, @ptrCast(namelen)));
}

pub fn sendmsg(
    s: ws2_32.SOCKET,
    msg: *const ws2_32.WSAMSG,
    flags: u32,
) i32 {
    var bytes_send: DWORD = undefined;
    if (ws2_32.WSASendMsg(s, msg, flags, &bytes_send, null, null) == ws2_32.SOCKET_ERROR) {
        return ws2_32.SOCKET_ERROR;
    } else {
        return @as(i32, @as(u31, @intCast(bytes_send)));
    }
}

pub fn sendto(s: ws2_32.SOCKET, buf: [*]const u8, len: usize, flags: u32, to: ?*const ws2_32.sockaddr, to_len: ws2_32.socklen_t) i32 {
    var buffer = ws2_32.WSABUF{ .len = @as(u31, @truncate(len)), .buf = @constCast(buf) };
    var bytes_send: DWORD = undefined;
    if (ws2_32.WSASendTo(s, @as([*]ws2_32.WSABUF, @ptrCast(&buffer)), 1, &bytes_send, flags, to, @as(i32, @intCast(to_len)), null, null) == ws2_32.SOCKET_ERROR) {
        return ws2_32.SOCKET_ERROR;
    } else {
        return @as(i32, @as(u31, @intCast(bytes_send)));
    }
}

pub fn recvfrom(s: ws2_32.SOCKET, buf: [*]u8, len: usize, flags: u32, from: ?*ws2_32.sockaddr, from_len: ?*ws2_32.socklen_t) i32 {
    var buffer = ws2_32.WSABUF{ .len = @as(u31, @truncate(len)), .buf = buf };
    var bytes_received: DWORD = undefined;
    var flags_inout = flags;
    if (ws2_32.WSARecvFrom(s, @as([*]ws2_32.WSABUF, @ptrCast(&buffer)), 1, &bytes_received, &flags_inout, from, @as(?*i32, @ptrCast(from_len)), null, null) == ws2_32.SOCKET_ERROR) {
        return ws2_32.SOCKET_ERROR;
    } else {
        return @as(i32, @as(u31, @intCast(bytes_received)));
    }
}

pub fn poll(fds: [*]ws2_32.pollfd, n: c_ulong, timeout: i32) i32 {
    return ws2_32.WSAPoll(fds, n, timeout);
}

pub fn WSAIoctl(
    s: ws2_32.SOCKET,
    dwIoControlCode: DWORD,
    inBuffer: ?[]const u8,
    outBuffer: []u8,
    overlapped: ?*OVERLAPPED,
    completionRoutine: ?ws2_32.LPWSAOVERLAPPED_COMPLETION_ROUTINE,
) !DWORD {
    var bytes: DWORD = undefined;
    switch (ws2_32.WSAIoctl(
        s,
        dwIoControlCode,
        if (inBuffer) |i| i.ptr else null,
        if (inBuffer) |i| @as(DWORD, @intCast(i.len)) else 0,
        outBuffer.ptr,
        @as(DWORD, @intCast(outBuffer.len)),
        &bytes,
        overlapped,
        completionRoutine,
    )) {
        0 => {},
        ws2_32.SOCKET_ERROR => switch (ws2_32.WSAGetLastError()) {
            else => |err| return unexpectedWSAError(err),
        },
        else => unreachable,
    }
    return bytes;
}

const GetModuleFileNameError = error{Unexpected};

pub fn GetModuleFileNameW(hModule: ?HMODULE, buf_ptr: [*]u16, buf_len: DWORD) GetModuleFileNameError![:0]u16 {
    const rc = kernel32.GetModuleFileNameW(hModule, buf_ptr, buf_len);
    if (rc == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    return buf_ptr[0..rc :0];
}

pub const TerminateProcessError = error{Unexpected};

pub fn TerminateProcess(hProcess: HANDLE, uExitCode: UINT) TerminateProcessError!void {
    if (kernel32.TerminateProcess(hProcess, uExitCode) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const VirtualAllocError = error{Unexpected};

pub fn VirtualAlloc(addr: ?LPVOID, size: usize, alloc_type: DWORD, flProtect: DWORD) VirtualAllocError!LPVOID {
    return kernel32.VirtualAlloc(addr, size, alloc_type, flProtect) orelse {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    };
}

pub fn VirtualFree(lpAddress: ?LPVOID, dwSize: usize, dwFreeType: DWORD) void {
    assert(kernel32.VirtualFree(lpAddress, dwSize, dwFreeType) != 0);
}

pub const VirtualProtectError = error{
    InvalidAddress,
    Unexpected,
};

pub fn VirtualProtect(lpAddress: ?LPVOID, dwSize: SIZE_T, flNewProtect: DWORD, lpflOldProtect: *DWORD) VirtualProtectError!void {
    // ntdll takes an extra level of indirection here
    var addr = lpAddress;
    var size = dwSize;
    switch (ntdll.NtProtectVirtualMemory(self_process_handle, &addr, &size, flNewProtect, lpflOldProtect)) {
        .SUCCESS => {},
        .INVALID_ADDRESS => return error.InvalidAddress,
        else => |st| return unexpectedStatus(st),
    }
}

pub fn VirtualProtectEx(handle: HANDLE, addr: ?LPVOID, size: SIZE_T, new_prot: DWORD) VirtualProtectError!DWORD {
    var old_prot: DWORD = undefined;
    var out_addr = addr;
    var out_size = size;
    switch (ntdll.NtProtectVirtualMemory(
        handle,
        &out_addr,
        &out_size,
        new_prot,
        &old_prot,
    )) {
        .SUCCESS => return old_prot,
        .INVALID_ADDRESS => return error.InvalidAddress,
        // TODO: map errors
        else => |rc| return std.os.windows.unexpectedStatus(rc),
    }
}

pub const VirtualQueryError = error{Unexpected};

pub fn VirtualQuery(lpAddress: ?LPVOID, lpBuffer: PMEMORY_BASIC_INFORMATION, dwLength: SIZE_T) VirtualQueryError!SIZE_T {
    const rc = kernel32.VirtualQuery(lpAddress, lpBuffer, dwLength);
    if (rc == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }

    return rc;
}

pub const SetConsoleTextAttributeError = error{Unexpected};

pub fn SetConsoleTextAttribute(hConsoleOutput: HANDLE, wAttributes: WORD) SetConsoleTextAttributeError!void {
    if (kernel32.SetConsoleTextAttribute(hConsoleOutput, wAttributes) == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub fn SetConsoleCtrlHandler(handler_routine: ?HANDLER_ROUTINE, add: bool) !void {
    const success = kernel32.SetConsoleCtrlHandler(
        handler_routine,
        if (add) TRUE else FALSE,
    );

    if (success == FALSE) {
        return switch (kernel32.GetLastError()) {
            else => |err| unexpectedError(err),
        };
    }
}

pub fn SetFileCompletionNotificationModes(handle: HANDLE, flags: UCHAR) !void {
    const success = kernel32.SetFileCompletionNotificationModes(handle, flags);
    if (success == FALSE) {
        return switch (kernel32.GetLastError()) {
            else => |err| unexpectedError(err),
        };
    }
}

pub const GetEnvironmentStringsError = error{OutOfMemory};

pub fn GetEnvironmentStringsW() GetEnvironmentStringsError![*:0]u16 {
    return kernel32.GetEnvironmentStringsW() orelse return error.OutOfMemory;
}

pub fn FreeEnvironmentStringsW(penv: [*:0]u16) void {
    assert(kernel32.FreeEnvironmentStringsW(penv) != 0);
}

pub const GetEnvironmentVariableError = error{
    EnvironmentVariableNotFound,
    Unexpected,
};

pub fn GetEnvironmentVariableW(lpName: LPWSTR, lpBuffer: [*]u16, nSize: DWORD) GetEnvironmentVariableError!DWORD {
    const rc = kernel32.GetEnvironmentVariableW(lpName, lpBuffer, nSize);
    if (rc == 0) {
        switch (kernel32.GetLastError()) {
            .ENVVAR_NOT_FOUND => return error.EnvironmentVariableNotFound,
            else => |err| return unexpectedError(err),
        }
    }
    return rc;
}

pub const CreateProcessError = error{
    FileNotFound,
    AccessDenied,
    InvalidName,
    NameTooLong,
    InvalidExe,
    Unexpected,
};

pub fn CreateProcessW(
    lpApplicationName: ?LPWSTR,
    lpCommandLine: LPWSTR,
    lpProcessAttributes: ?*SECURITY_ATTRIBUTES,
    lpThreadAttributes: ?*SECURITY_ATTRIBUTES,
    bInheritHandles: BOOL,
    dwCreationFlags: DWORD,
    lpEnvironment: ?*anyopaque,
    lpCurrentDirectory: ?LPWSTR,
    lpStartupInfo: *STARTUPINFOW,
    lpProcessInformation: *PROCESS_INFORMATION,
) CreateProcessError!void {
    if (kernel32.CreateProcessW(
        lpApplicationName,
        lpCommandLine,
        lpProcessAttributes,
        lpThreadAttributes,
        bInheritHandles,
        dwCreationFlags,
        lpEnvironment,
        lpCurrentDirectory,
        lpStartupInfo,
        lpProcessInformation,
    ) == 0) {
        switch (kernel32.GetLastError()) {
            .FILE_NOT_FOUND => return error.FileNotFound,
            .PATH_NOT_FOUND => return error.FileNotFound,
            .ACCESS_DENIED => return error.AccessDenied,
            .INVALID_PARAMETER => unreachable,
            .INVALID_NAME => return error.InvalidName,
            .FILENAME_EXCED_RANGE => return error.NameTooLong,
            // These are all the system errors that are mapped to ENOEXEC by
            // the undocumented _dosmaperr (old CRT) or __acrt_errno_map_os_error
            // (newer CRT) functions. Their code can be found in crt/src/dosmap.c (old SDK)
            // or urt/misc/errno.cpp (newer SDK) in the Windows SDK.
            .BAD_FORMAT,
            .INVALID_STARTING_CODESEG, // MIN_EXEC_ERROR in errno.cpp
            .INVALID_STACKSEG,
            .INVALID_MODULETYPE,
            .INVALID_EXE_SIGNATURE,
            .EXE_MARKED_INVALID,
            .BAD_EXE_FORMAT,
            .ITERATED_DATA_EXCEEDS_64k,
            .INVALID_MINALLOCSIZE,
            .DYNLINK_FROM_INVALID_RING,
            .IOPL_NOT_ENABLED,
            .INVALID_SEGDPL,
            .AUTODATASEG_EXCEEDS_64k,
            .RING2SEG_MUST_BE_MOVABLE,
            .RELOC_CHAIN_XEEDS_SEGLIM,
            .INFLOOP_IN_RELOC_CHAIN, // MAX_EXEC_ERROR in errno.cpp
            // This one is not mapped to ENOEXEC but it is possible, for example
            // when calling CreateProcessW on a plain text file with a .exe extension
            .EXE_MACHINE_TYPE_MISMATCH,
            => return error.InvalidExe,
            else => |err| return unexpectedError(err),
        }
    }
}

pub const LoadLibraryError = error{
    FileNotFound,
    Unexpected,
};

pub fn LoadLibraryW(lpLibFileName: [*:0]const u16) LoadLibraryError!HMODULE {
    return kernel32.LoadLibraryW(lpLibFileName) orelse {
        switch (kernel32.GetLastError()) {
            .FILE_NOT_FOUND => return error.FileNotFound,
            .PATH_NOT_FOUND => return error.FileNotFound,
            .MOD_NOT_FOUND => return error.FileNotFound,
            else => |err| return unexpectedError(err),
        }
    };
}

pub fn FreeLibrary(hModule: HMODULE) void {
    assert(kernel32.FreeLibrary(hModule) != 0);
}

pub fn QueryPerformanceFrequency() u64 {
    // "On systems that run Windows XP or later, the function will always succeed"
    // https://docs.microsoft.com/en-us/windows/desktop/api/profileapi/nf-profileapi-queryperformancefrequency
    var result: LARGE_INTEGER = undefined;
    assert(kernel32.QueryPerformanceFrequency(&result) != 0);
    // The kernel treats this integer as unsigned.
    return @as(u64, @bitCast(result));
}

pub fn QueryPerformanceCounter() u64 {
    // "On systems that run Windows XP or later, the function will always succeed"
    // https://docs.microsoft.com/en-us/windows/desktop/api/profileapi/nf-profileapi-queryperformancecounter
    var result: LARGE_INTEGER = undefined;
    assert(kernel32.QueryPerformanceCounter(&result) != 0);
    // The kernel treats this integer as unsigned.
    return @as(u64, @bitCast(result));
}

pub fn InitOnceExecuteOnce(InitOnce: *INIT_ONCE, InitFn: INIT_ONCE_FN, Parameter: ?*anyopaque, Context: ?*anyopaque) void {
    assert(kernel32.InitOnceExecuteOnce(InitOnce, InitFn, Parameter, Context) != 0);
}

pub fn HeapFree(hHeap: HANDLE, dwFlags: DWORD, lpMem: *anyopaque) void {
    assert(kernel32.HeapFree(hHeap, dwFlags, lpMem) != 0);
}

pub fn HeapDestroy(hHeap: HANDLE) void {
    assert(kernel32.HeapDestroy(hHeap) != 0);
}

pub fn LocalFree(hMem: HLOCAL) void {
    assert(kernel32.LocalFree(hMem) == null);
}

pub const SetFileTimeError = error{Unexpected};

pub fn SetFileTime(
    hFile: HANDLE,
    lpCreationTime: ?*const FILETIME,
    lpLastAccessTime: ?*const FILETIME,
    lpLastWriteTime: ?*const FILETIME,
) SetFileTimeError!void {
    const rc = kernel32.SetFileTime(hFile, lpCreationTime, lpLastAccessTime, lpLastWriteTime);
    if (rc == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
}

pub const LockFileError = error{
    SystemResources,
    WouldBlock,
} || std.os.UnexpectedError;

pub fn LockFile(
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
) !void {
    const rc = ntdll.NtLockFile(
        FileHandle,
        Event,
        ApcRoutine,
        ApcContext,
        IoStatusBlock,
        ByteOffset,
        Length,
        Key,
        FailImmediately,
        ExclusiveLock,
    );
    switch (rc) {
        .SUCCESS => return,
        .INSUFFICIENT_RESOURCES => return error.SystemResources,
        .LOCK_NOT_GRANTED => return error.WouldBlock,
        .ACCESS_VIOLATION => unreachable, // bad io_status_block pointer
        else => return unexpectedStatus(rc),
    }
}

pub const UnlockFileError = error{
    RangeNotLocked,
} || std.os.UnexpectedError;

pub fn UnlockFile(
    FileHandle: HANDLE,
    IoStatusBlock: *IO_STATUS_BLOCK,
    ByteOffset: *const LARGE_INTEGER,
    Length: *const LARGE_INTEGER,
    Key: ?*ULONG,
) !void {
    const rc = ntdll.NtUnlockFile(FileHandle, IoStatusBlock, ByteOffset, Length, Key);
    switch (rc) {
        .SUCCESS => return,
        .RANGE_NOT_LOCKED => return error.RangeNotLocked,
        .ACCESS_VIOLATION => unreachable, // bad io_status_block pointer
        else => return unexpectedStatus(rc),
    }
}

/// This is a workaround for the C backend until zig has the ability to put
/// C code in inline assembly.
extern fn zig_x86_windows_teb() callconv(.C) *anyopaque;
extern fn zig_x86_64_windows_teb() callconv(.C) *anyopaque;

pub fn teb() *TEB {
    return switch (native_arch) {
        .x86 => blk: {
            if (builtin.zig_backend == .stage2_c) {
                break :blk @ptrCast(@alignCast(zig_x86_windows_teb()));
            } else {
                break :blk asm volatile (
                    \\ movl %%fs:0x18, %[ptr]
                    : [ptr] "=r" (-> *TEB),
                );
            }
        },
        .x86_64 => blk: {
            if (builtin.zig_backend == .stage2_c) {
                break :blk @ptrCast(@alignCast(zig_x86_64_windows_teb()));
            } else {
                break :blk asm volatile (
                    \\ movq %%gs:0x30, %[ptr]
                    : [ptr] "=r" (-> *TEB),
                );
            }
        },
        .aarch64 => asm volatile (
            \\ mov %[ptr], x18
            : [ptr] "=r" (-> *TEB),
        ),
        else => @compileError("unsupported arch"),
    };
}

pub fn peb() *PEB {
    return teb().ProcessEnvironmentBlock;
}

/// A file time is a 64-bit value that represents the number of 100-nanosecond
/// intervals that have elapsed since 12:00 A.M. January 1, 1601 Coordinated
/// Universal Time (UTC).
/// This function returns the number of nanoseconds since the canonical epoch,
/// which is the POSIX one (Jan 01, 1970 AD).
pub fn fromSysTime(hns: i64) i128 {
    const adjusted_epoch: i128 = hns + std.time.epoch.windows * (std.time.ns_per_s / 100);
    return adjusted_epoch * 100;
}

pub fn toSysTime(ns: i128) i64 {
    const hns = @divFloor(ns, 100);
    return @as(i64, @intCast(hns)) - std.time.epoch.windows * (std.time.ns_per_s / 100);
}

pub fn fileTimeToNanoSeconds(ft: FILETIME) i128 {
    const hns = (@as(i64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
    return fromSysTime(hns);
}

/// Converts a number of nanoseconds since the POSIX epoch to a Windows FILETIME.
pub fn nanoSecondsToFileTime(ns: i128) FILETIME {
    const adjusted: u64 = @bitCast(toSysTime(ns));
    return FILETIME{
        .dwHighDateTime = @as(u32, @truncate(adjusted >> 32)),
        .dwLowDateTime = @as(u32, @truncate(adjusted)),
    };
}

/// Compares two WTF16 strings using the equivalent functionality of
/// `RtlEqualUnicodeString` (with case insensitive comparison enabled).
/// This function can be called on any target.
pub fn eqlIgnoreCaseWTF16(a: []const u16, b: []const u16) bool {
    if (@inComptime() or builtin.os.tag != .windows) {
        // This function compares the strings code unit by code unit (aka u16-to-u16),
        // so any length difference implies inequality. In other words, there's no possible
        // conversion that changes the number of UTF-16 code units needed for the uppercase/lowercase
        // version in the conversion table since only codepoints <= max(u16) are eligible
        // for conversion at all.
        if (a.len != b.len) return false;

        for (a, b) |a_c, b_c| {
            // The slices are always UTF-16 LE, so need to convert the elements to native
            // endianness for the uppercasing
            const a_c_native = std.mem.littleToNative(u16, a_c);
            const b_c_native = std.mem.littleToNative(u16, b_c);
            if (a_c != b_c and nls.upcaseW(a_c_native) != nls.upcaseW(b_c_native)) {
                return false;
            }
        }
        return true;
    }
    // Use RtlEqualUnicodeString on Windows when not in comptime to avoid including a
    // redundant copy of the uppercase data.
    const a_bytes = @as(u16, @intCast(a.len * 2));
    const a_string = UNICODE_STRING{
        .Length = a_bytes,
        .MaximumLength = a_bytes,
        .Buffer = @constCast(a.ptr),
    };
    const b_bytes = @as(u16, @intCast(b.len * 2));
    const b_string = UNICODE_STRING{
        .Length = b_bytes,
        .MaximumLength = b_bytes,
        .Buffer = @constCast(b.ptr),
    };
    return ntdll.RtlEqualUnicodeString(&a_string, &b_string, TRUE) == TRUE;
}

/// Compares two UTF-8 strings using the equivalent functionality of
/// `RtlEqualUnicodeString` (with case insensitive comparison enabled).
/// This function can be called on any target.
/// Assumes `a` and `b` are valid UTF-8.
pub fn eqlIgnoreCaseUtf8(a: []const u8, b: []const u8) bool {
    // A length equality check is not possible here because there are
    // some codepoints that have a different length uppercase UTF-8 representations
    // than their lowercase counterparts, e.g. U+0250 (2 bytes) <-> U+2C6F (3 bytes).
    // There are 7 such codepoints in the uppercase data used by Windows.

    var a_utf8_it = std.unicode.Utf8View.initUnchecked(a).iterator();
    var b_utf8_it = std.unicode.Utf8View.initUnchecked(b).iterator();

    // Use RtlUpcaseUnicodeChar on Windows when not in comptime to avoid including a
    // redundant copy of the uppercase data.
    const upcaseImpl = switch (builtin.os.tag) {
        .windows => if (@inComptime()) nls.upcaseW else ntdll.RtlUpcaseUnicodeChar,
        else => nls.upcaseW,
    };

    while (true) {
        var a_cp = a_utf8_it.nextCodepoint() orelse break;
        var b_cp = b_utf8_it.nextCodepoint() orelse return false;

        if (a_cp <= std.math.maxInt(u16) and b_cp <= std.math.maxInt(u16)) {
            if (a_cp != b_cp and upcaseImpl(@intCast(a_cp)) != upcaseImpl(@intCast(b_cp))) {
                return false;
            }
        } else if (a_cp != b_cp) {
            return false;
        }
    }
    // Make sure there are no leftover codepoints in b
    if (b_utf8_it.nextCodepoint() != null) return false;

    return true;
}

fn testEqlIgnoreCase(comptime expect_eql: bool, comptime a: []const u8, comptime b: []const u8) !void {
    try std.testing.expectEqual(expect_eql, eqlIgnoreCaseUtf8(a, b));
    try std.testing.expectEqual(expect_eql, eqlIgnoreCaseWTF16(
        std.unicode.utf8ToUtf16LeStringLiteral(a),
        std.unicode.utf8ToUtf16LeStringLiteral(b),
    ));

    try comptime std.testing.expect(expect_eql == eqlIgnoreCaseUtf8(a, b));
    try comptime std.testing.expect(expect_eql == eqlIgnoreCaseWTF16(
        std.unicode.utf8ToUtf16LeStringLiteral(a),
        std.unicode.utf8ToUtf16LeStringLiteral(b),
    ));
}

test "eqlIgnoreCaseWTF16/Utf8" {
    try testEqlIgnoreCase(true, "\x01 a B Λ ɐ", "\x01 A b λ Ɐ");
    // does not do case-insensitive comparison for codepoints >= U+10000
    try testEqlIgnoreCase(false, "𐓏", "𐓷");
}

pub const PathSpace = struct {
    data: [PATH_MAX_WIDE:0]u16,
    len: usize,

    pub fn span(self: *const PathSpace) [:0]const u16 {
        return self.data[0..self.len :0];
    }
};

/// The error type for `removeDotDirsSanitized`
pub const RemoveDotDirsError = error{TooManyParentDirs};

/// Removes '.' and '..' path components from a "sanitized relative path".
/// A "sanitized path" is one where:
///    1) all forward slashes have been replaced with back slashes
///    2) all repeating back slashes have been collapsed
///    3) the path is a relative one (does not start with a back slash)
pub fn removeDotDirsSanitized(comptime T: type, path: []T) RemoveDotDirsError!usize {
    std.debug.assert(path.len == 0 or path[0] != '\\');

    var write_idx: usize = 0;
    var read_idx: usize = 0;
    while (read_idx < path.len) {
        if (path[read_idx] == '.') {
            if (read_idx + 1 == path.len)
                return write_idx;

            const after_dot = path[read_idx + 1];
            if (after_dot == '\\') {
                read_idx += 2;
                continue;
            }
            if (after_dot == '.' and (read_idx + 2 == path.len or path[read_idx + 2] == '\\')) {
                if (write_idx == 0) return error.TooManyParentDirs;
                std.debug.assert(write_idx >= 2);
                write_idx -= 1;
                while (true) {
                    write_idx -= 1;
                    if (write_idx == 0) break;
                    if (path[write_idx] == '\\') {
                        write_idx += 1;
                        break;
                    }
                }
                if (read_idx + 2 == path.len)
                    return write_idx;
                read_idx += 3;
                continue;
            }
        }

        // skip to the next path separator
        while (true) : (read_idx += 1) {
            if (read_idx == path.len)
                return write_idx;
            path[write_idx] = path[read_idx];
            write_idx += 1;
            if (path[read_idx] == '\\')
                break;
        }
        read_idx += 1;
    }
    return write_idx;
}

/// Normalizes a Windows path with the following steps:
///     1) convert all forward slashes to back slashes
///     2) collapse duplicate back slashes
///     3) remove '.' and '..' directory parts
/// Returns the length of the new path.
pub fn normalizePath(comptime T: type, path: []T) RemoveDotDirsError!usize {
    mem.replaceScalar(T, path, '/', '\\');
    const new_len = mem.collapseRepeatsLen(T, path, '\\');

    const prefix_len: usize = init: {
        if (new_len >= 1 and path[0] == '\\') break :init 1;
        if (new_len >= 2 and path[1] == ':')
            break :init if (new_len >= 3 and path[2] == '\\') @as(usize, 3) else @as(usize, 2);
        break :init 0;
    };

    return prefix_len + try removeDotDirsSanitized(T, path[prefix_len..new_len]);
}

/// Same as `sliceToPrefixedFileW` but accepts a pointer
/// to a null-terminated path.
pub fn cStrToPrefixedFileW(s: [*:0]const u8) !PathSpace {
    return sliceToPrefixedFileW(mem.sliceTo(s, 0));
}

/// Same as `wToPrefixedFileW` but accepts a UTF-8 encoded path.
pub fn sliceToPrefixedFileW(path: []const u8) !PathSpace {
    var temp_path: PathSpace = undefined;
    temp_path.len = try std.unicode.utf8ToUtf16Le(&temp_path.data, path);
    temp_path.data[temp_path.len] = 0;
    return wToPrefixedFileW(temp_path.span());
}

/// Converts the `path` to WTF16, null-terminated. If the path contains any
/// namespace prefix, or is anything but a relative path (rooted, drive relative,
/// etc) the result will have the NT-style prefix `\??\`.
///
/// Similar to RtlDosPathNameToNtPathName_U with a few differences:
/// - Does not allocate on the heap.
/// - Relative paths are kept as relative unless they contain too many ..
///   components, in which case they are treated as drive-relative and resolved
///   against the CWD.
/// - Special case device names like COM1, NUL, etc are not handled specially (TODO)
/// - . and space are not stripped from the end of relative paths (potential TODO)
pub fn wToPrefixedFileW(path: [:0]const u16) !PathSpace {
    const nt_prefix = [_]u16{ '\\', '?', '?', '\\' };
    switch (getNamespacePrefix(u16, path)) {
        // TODO: Figure out a way to design an API that can avoid the copy for .nt,
        //       since it is always returned fully unmodified.
        .nt, .verbatim => {
            var path_space: PathSpace = undefined;
            path_space.data[0..nt_prefix.len].* = nt_prefix;
            const len_after_prefix = path.len - nt_prefix.len;
            @memcpy(path_space.data[nt_prefix.len..][0..len_after_prefix], path[nt_prefix.len..]);
            path_space.len = path.len;
            path_space.data[path_space.len] = 0;
            return path_space;
        },
        .local_device, .fake_verbatim => {
            var path_space: PathSpace = undefined;
            const path_byte_len = ntdll.RtlGetFullPathName_U(
                path.ptr,
                path_space.data.len * 2,
                &path_space.data,
                null,
            );
            if (path_byte_len == 0) {
                // TODO: This may not be the right error
                return error.BadPathName;
            } else if (path_byte_len / 2 > path_space.data.len) {
                return error.NameTooLong;
            }
            path_space.len = path_byte_len / 2;
            // Both prefixes will be normalized but retained, so all
            // we need to do now is replace them with the NT prefix
            path_space.data[0..nt_prefix.len].* = nt_prefix;
            return path_space;
        },
        .none => {
            const path_type = getUnprefixedPathType(u16, path);
            var path_space: PathSpace = undefined;
            relative: {
                if (path_type == .relative) {
                    // TODO: Handle special case device names like COM1, AUX, NUL, CONIN$, CONOUT$, etc.
                    //       See https://googleprojectzero.blogspot.com/2016/02/the-definitive-guide-on-win32-to-nt.html

                    // TODO: Potentially strip all trailing . and space characters from the
                    //       end of the path. This is something that both RtlDosPathNameToNtPathName_U
                    //       and RtlGetFullPathName_U do. Technically, trailing . and spaces
                    //       are allowed, but such paths may not interact well with Windows (i.e.
                    //       files with these paths can't be deleted from explorer.exe, etc).
                    //       This could be something that normalizePath may want to do.

                    @memcpy(path_space.data[0..path.len], path);
                    // Try to normalize, but if we get too many parent directories,
                    // then this is effectively a 'drive relative' path, so we need to
                    // start over and use RtlGetFullPathName_U instead.
                    path_space.len = normalizePath(u16, path_space.data[0..path.len]) catch |err| switch (err) {
                        error.TooManyParentDirs => break :relative,
                    };
                    path_space.data[path_space.len] = 0;
                    return path_space;
                }
            }
            // We now know we are going to return an absolute NT path, so
            // we can unconditionally prefix it with the NT prefix.
            path_space.data[0..nt_prefix.len].* = nt_prefix;
            if (path_type == .root_local_device) {
                // `\\.` and `\\?` always get converted to `\??\` exactly, so
                // we can just stop here
                path_space.len = nt_prefix.len;
                path_space.data[path_space.len] = 0;
                return path_space;
            }
            const path_buf_offset = switch (path_type) {
                // UNC paths will always start with `\\`. However, we want to
                // end up with something like `\??\UNC\server\share`, so to get
                // RtlGetFullPathName to write into the spot we want the `server`
                // part to end up, we need to provide an offset such that
                // the `\\` part gets written where the `C\` of `UNC\` will be
                // in the final NT path.
                .unc_absolute => nt_prefix.len + 2,
                else => nt_prefix.len,
            };
            const buf_len = @as(u32, @intCast(path_space.data.len - path_buf_offset));
            const path_byte_len = ntdll.RtlGetFullPathName_U(
                path.ptr,
                buf_len * 2,
                path_space.data[path_buf_offset..].ptr,
                null,
            );
            if (path_byte_len == 0) {
                // TODO: This may not be the right error
                return error.BadPathName;
            } else if (path_byte_len / 2 > buf_len) {
                return error.NameTooLong;
            }
            path_space.len = path_buf_offset + (path_byte_len / 2);
            if (path_type == .unc_absolute) {
                // Now add in the UNC, the `C` should overwrite the first `\` of the
                // FullPathName, ultimately resulting in `\??\UNC\<the rest of the path>`
                std.debug.assert(path_space.data[path_buf_offset] == '\\');
                std.debug.assert(path_space.data[path_buf_offset + 1] == '\\');
                const unc = [_]u16{ 'U', 'N', 'C' };
                path_space.data[nt_prefix.len..][0..unc.len].* = unc;
            }
            return path_space;
        },
    }
}

pub const NamespacePrefix = enum {
    none,
    /// `\\.\` (path separators can be `\` or `/`)
    local_device,
    /// `\\?\`
    /// When converted to an NT path, everything past the prefix is left
    /// untouched and `\\?\` is replaced by `\??\`.
    verbatim,
    /// `\\?\` without all path separators being `\`.
    /// This seems to be recognized as a prefix, but the 'verbatim' aspect
    /// is not respected (i.e. if `//?/C:/foo` is converted to an NT path,
    /// it will become `\??\C:\foo` [it will be canonicalized and the //?/ won't
    /// be treated as part of the final path])
    fake_verbatim,
    /// `\??\`
    nt,
};

pub fn getNamespacePrefix(comptime T: type, path: []const T) NamespacePrefix {
    if (path.len < 4) return .none;
    var all_backslash = switch (path[0]) {
        '\\' => true,
        '/' => false,
        else => return .none,
    };
    all_backslash = all_backslash and switch (path[3]) {
        '\\' => true,
        '/' => false,
        else => return .none,
    };
    switch (path[1]) {
        '?' => if (path[2] == '?' and all_backslash) return .nt else return .none,
        '\\' => {},
        '/' => all_backslash = false,
        else => return .none,
    }
    return switch (path[2]) {
        '?' => if (all_backslash) .verbatim else .fake_verbatim,
        '.' => .local_device,
        else => .none,
    };
}

test getNamespacePrefix {
    try std.testing.expectEqual(NamespacePrefix.none, getNamespacePrefix(u8, ""));
    try std.testing.expectEqual(NamespacePrefix.nt, getNamespacePrefix(u8, "\\??\\"));
    try std.testing.expectEqual(NamespacePrefix.none, getNamespacePrefix(u8, "/??/"));
    try std.testing.expectEqual(NamespacePrefix.none, getNamespacePrefix(u8, "/??\\"));
    try std.testing.expectEqual(NamespacePrefix.none, getNamespacePrefix(u8, "\\?\\\\"));
    try std.testing.expectEqual(NamespacePrefix.local_device, getNamespacePrefix(u8, "\\\\.\\"));
    try std.testing.expectEqual(NamespacePrefix.local_device, getNamespacePrefix(u8, "\\\\./"));
    try std.testing.expectEqual(NamespacePrefix.local_device, getNamespacePrefix(u8, "/\\./"));
    try std.testing.expectEqual(NamespacePrefix.local_device, getNamespacePrefix(u8, "//./"));
    try std.testing.expectEqual(NamespacePrefix.none, getNamespacePrefix(u8, "/.//"));
    try std.testing.expectEqual(NamespacePrefix.verbatim, getNamespacePrefix(u8, "\\\\?\\"));
    try std.testing.expectEqual(NamespacePrefix.fake_verbatim, getNamespacePrefix(u8, "\\/?\\"));
    try std.testing.expectEqual(NamespacePrefix.fake_verbatim, getNamespacePrefix(u8, "\\/?/"));
    try std.testing.expectEqual(NamespacePrefix.fake_verbatim, getNamespacePrefix(u8, "//?/"));
}

pub const UnprefixedPathType = enum {
    unc_absolute,
    drive_absolute,
    drive_relative,
    rooted,
    relative,
    root_local_device,
};

/// Get the path type of a path that is known to not have any namespace prefixes
/// (`\\?\`, `\\.\`, `\??\`).
pub fn getUnprefixedPathType(comptime T: type, path: []const T) UnprefixedPathType {
    if (path.len < 1) return .relative;

    if (std.debug.runtime_safety) {
        std.debug.assert(getNamespacePrefix(T, path) == .none);
    }

    const windows_path = std.fs.path.PathType.windows;
    if (windows_path.isSep(T, path[0])) {
        // \x
        if (path.len < 2 or !windows_path.isSep(T, path[1])) return .rooted;
        // exactly \\. or \\? with nothing trailing
        if (path.len == 3 and (path[2] == '.' or path[2] == '?')) return .root_local_device;
        // \\x
        return .unc_absolute;
    } else {
        // x
        if (path.len < 2 or path[1] != ':') return .relative;
        // x:\
        if (path.len > 2 and windows_path.isSep(T, path[2])) return .drive_absolute;
        // x:
        return .drive_relative;
    }
}

test getUnprefixedPathType {
    try std.testing.expectEqual(UnprefixedPathType.relative, getUnprefixedPathType(u8, ""));
    try std.testing.expectEqual(UnprefixedPathType.relative, getUnprefixedPathType(u8, "x"));
    try std.testing.expectEqual(UnprefixedPathType.relative, getUnprefixedPathType(u8, "x\\"));
    try std.testing.expectEqual(UnprefixedPathType.root_local_device, getUnprefixedPathType(u8, "//."));
    try std.testing.expectEqual(UnprefixedPathType.root_local_device, getUnprefixedPathType(u8, "/\\?"));
    try std.testing.expectEqual(UnprefixedPathType.root_local_device, getUnprefixedPathType(u8, "\\\\?"));
    try std.testing.expectEqual(UnprefixedPathType.unc_absolute, getUnprefixedPathType(u8, "\\\\x"));
    try std.testing.expectEqual(UnprefixedPathType.unc_absolute, getUnprefixedPathType(u8, "//x"));
    try std.testing.expectEqual(UnprefixedPathType.rooted, getUnprefixedPathType(u8, "\\x"));
    try std.testing.expectEqual(UnprefixedPathType.rooted, getUnprefixedPathType(u8, "/"));
    try std.testing.expectEqual(UnprefixedPathType.drive_relative, getUnprefixedPathType(u8, "x:"));
    try std.testing.expectEqual(UnprefixedPathType.drive_relative, getUnprefixedPathType(u8, "x:abc"));
    try std.testing.expectEqual(UnprefixedPathType.drive_relative, getUnprefixedPathType(u8, "x:a/b/c"));
    try std.testing.expectEqual(UnprefixedPathType.drive_absolute, getUnprefixedPathType(u8, "x:\\"));
    try std.testing.expectEqual(UnprefixedPathType.drive_absolute, getUnprefixedPathType(u8, "x:\\abc"));
    try std.testing.expectEqual(UnprefixedPathType.drive_absolute, getUnprefixedPathType(u8, "x:/a/b/c"));
}

fn getFullPathNameW(path: [*:0]const u16, out: []u16) !usize {
    const result = kernel32.GetFullPathNameW(path, @as(u32, @intCast(out.len)), out.ptr, null);
    if (result == 0) {
        switch (kernel32.GetLastError()) {
            else => |err| return unexpectedError(err),
        }
    }
    return result;
}

inline fn MAKELANGID(p: c_ushort, s: c_ushort) LANGID {
    return (s << 10) | p;
}

/// Loads a Winsock extension function in runtime specified by a GUID.
pub fn loadWinsockExtensionFunction(comptime T: type, sock: ws2_32.SOCKET, guid: GUID) !T {
    var function: T = undefined;
    var num_bytes: DWORD = undefined;

    const rc = ws2_32.WSAIoctl(
        sock,
        ws2_32.SIO_GET_EXTENSION_FUNCTION_POINTER,
        @as(*const anyopaque, @ptrCast(&guid)),
        @sizeOf(GUID),
        @as(?*anyopaque, @ptrFromInt(@intFromPtr(&function))),
        @sizeOf(T),
        &num_bytes,
        null,
        null,
    );

    if (rc == ws2_32.SOCKET_ERROR) {
        return switch (ws2_32.WSAGetLastError()) {
            .WSAEOPNOTSUPP => error.OperationNotSupported,
            .WSAENOTSOCK => error.FileDescriptorNotASocket,
            else => |err| unexpectedWSAError(err),
        };
    }

    if (num_bytes != @sizeOf(T)) {
        return error.ShortRead;
    }

    return function;
}

/// Call this when you made a windows DLL call or something that does SetLastError
/// and you get an unexpected error.
pub fn unexpectedError(err: Win32Error) std.os.UnexpectedError {
    if (std.os.unexpected_error_tracing) {
        // 614 is the length of the longest windows error description
        var buf_wstr: [614]WCHAR = undefined;
        var buf_utf8: [614]u8 = undefined;
        const len = kernel32.FormatMessageW(
            FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
            null,
            err,
            MAKELANGID(LANG.NEUTRAL, SUBLANG.DEFAULT),
            &buf_wstr,
            buf_wstr.len,
            null,
        );
        _ = std.unicode.utf16leToUtf8(&buf_utf8, buf_wstr[0..len]) catch unreachable;
        std.debug.print("error.Unexpected: GetLastError({}): {s}\n", .{ @intFromEnum(err), buf_utf8[0..len] });
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}

pub fn unexpectedWSAError(err: ws2_32.WinsockError) std.os.UnexpectedError {
    return unexpectedError(@as(Win32Error, @enumFromInt(@intFromEnum(err))));
}

/// Call this when you made a windows NtDll call
/// and you get an unexpected status.
pub fn unexpectedStatus(status: NTSTATUS) std.os.UnexpectedError {
    if (std.os.unexpected_error_tracing) {
        std.debug.print("error.Unexpected NTSTATUS=0x{x}\n", .{@intFromEnum(status)});
        std.debug.dumpCurrentStackTrace(@returnAddress());
    }
    return error.Unexpected;
}

pub const Win32Error = @import("windows/win32error.zig").Win32Error;
pub const NTSTATUS = @import("windows/ntstatus.zig").NTSTATUS;
pub const LANG = @import("windows/lang.zig");
pub const SUBLANG = @import("windows/sublang.zig");

/// The standard input device. Initially, this is the console input buffer, CONIN$.
pub const STD_INPUT_HANDLE = maxInt(DWORD) - 10 + 1;

/// The standard output device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_OUTPUT_HANDLE = maxInt(DWORD) - 11 + 1;

/// The standard error device. Initially, this is the active console screen buffer, CONOUT$.
pub const STD_ERROR_HANDLE = maxInt(DWORD) - 12 + 1;

pub const WINAPI: std.builtin.CallingConvention = if (native_arch == .x86)
    .Stdcall
else
    .C;

pub const BOOL = c_int;
pub const BOOLEAN = BYTE;
pub const BYTE = u8;
pub const CHAR = u8;
pub const UCHAR = u8;
pub const FLOAT = f32;
pub const HANDLE = *anyopaque;
pub const HCRYPTPROV = ULONG_PTR;
pub const ATOM = u16;
pub const HBRUSH = *opaque {};
pub const HCURSOR = *opaque {};
pub const HICON = *opaque {};
pub const HINSTANCE = *opaque {};
pub const HMENU = *opaque {};
pub const HMODULE = *opaque {};
pub const HWND = *opaque {};
pub const HDC = *opaque {};
pub const HGLRC = *opaque {};
pub const FARPROC = *opaque {};
pub const INT = c_int;
pub const LPCSTR = [*:0]const CHAR;
pub const LPCVOID = *const anyopaque;
pub const LPSTR = [*:0]CHAR;
pub const LPVOID = *anyopaque;
pub const LPWSTR = [*:0]WCHAR;
pub const LPCWSTR = [*:0]const WCHAR;
pub const PVOID = *anyopaque;
pub const PWSTR = [*:0]WCHAR;
pub const PCWSTR = [*:0]const WCHAR;
/// Allocated by SysAllocString, freed by SysFreeString
pub const BSTR = [*:0]WCHAR;
pub const SIZE_T = usize;
pub const UINT = c_uint;
pub const ULONG_PTR = usize;
pub const LONG_PTR = isize;
pub const DWORD_PTR = ULONG_PTR;
pub const WCHAR = u16;
pub const WORD = u16;
pub const DWORD = u32;
pub const DWORD64 = u64;
pub const LARGE_INTEGER = i64;
pub const ULARGE_INTEGER = u64;
pub const USHORT = u16;
pub const SHORT = i16;
pub const ULONG = u32;
pub const LONG = i32;
pub const ULONG64 = u64;
pub const ULONGLONG = u64;
pub const LONGLONG = i64;
pub const HLOCAL = HANDLE;
pub const LANGID = c_ushort;

pub const WPARAM = usize;
pub const LPARAM = LONG_PTR;
pub const LRESULT = LONG_PTR;

pub const va_list = *opaque {};

pub const TRUE = 1;
pub const FALSE = 0;

pub const DEVICE_TYPE = ULONG;
pub const FILE_DEVICE_BEEP: DEVICE_TYPE = 0x0001;
pub const FILE_DEVICE_CD_ROM: DEVICE_TYPE = 0x0002;
pub const FILE_DEVICE_CD_ROM_FILE_SYSTEM: DEVICE_TYPE = 0x0003;
pub const FILE_DEVICE_CONTROLLER: DEVICE_TYPE = 0x0004;
pub const FILE_DEVICE_DATALINK: DEVICE_TYPE = 0x0005;
pub const FILE_DEVICE_DFS: DEVICE_TYPE = 0x0006;
pub const FILE_DEVICE_DISK: DEVICE_TYPE = 0x0007;
pub const FILE_DEVICE_DISK_FILE_SYSTEM: DEVICE_TYPE = 0x0008;
pub const FILE_DEVICE_FILE_SYSTEM: DEVICE_TYPE = 0x0009;
pub const FILE_DEVICE_INPORT_PORT: DEVICE_TYPE = 0x000a;
pub const FILE_DEVICE_KEYBOARD: DEVICE_TYPE = 0x000b;
pub const FILE_DEVICE_MAILSLOT: DEVICE_TYPE = 0x000c;
pub const FILE_DEVICE_MIDI_IN: DEVICE_TYPE = 0x000d;
pub const FILE_DEVICE_MIDI_OUT: DEVICE_TYPE = 0x000e;
pub const FILE_DEVICE_MOUSE: DEVICE_TYPE = 0x000f;
pub const FILE_DEVICE_MULTI_UNC_PROVIDER: DEVICE_TYPE = 0x0010;
pub const FILE_DEVICE_NAMED_PIPE: DEVICE_TYPE = 0x0011;
pub const FILE_DEVICE_NETWORK: DEVICE_TYPE = 0x0012;
pub const FILE_DEVICE_NETWORK_BROWSER: DEVICE_TYPE = 0x0013;
pub const FILE_DEVICE_NETWORK_FILE_SYSTEM: DEVICE_TYPE = 0x0014;
pub const FILE_DEVICE_NULL: DEVICE_TYPE = 0x0015;
pub const FILE_DEVICE_PARALLEL_PORT: DEVICE_TYPE = 0x0016;
pub const FILE_DEVICE_PHYSICAL_NETCARD: DEVICE_TYPE = 0x0017;
pub const FILE_DEVICE_PRINTER: DEVICE_TYPE = 0x0018;
pub const FILE_DEVICE_SCANNER: DEVICE_TYPE = 0x0019;
pub const FILE_DEVICE_SERIAL_MOUSE_PORT: DEVICE_TYPE = 0x001a;
pub const FILE_DEVICE_SERIAL_PORT: DEVICE_TYPE = 0x001b;
pub const FILE_DEVICE_SCREEN: DEVICE_TYPE = 0x001c;
pub const FILE_DEVICE_SOUND: DEVICE_TYPE = 0x001d;
pub const FILE_DEVICE_STREAMS: DEVICE_TYPE = 0x001e;
pub const FILE_DEVICE_TAPE: DEVICE_TYPE = 0x001f;
pub const FILE_DEVICE_TAPE_FILE_SYSTEM: DEVICE_TYPE = 0x0020;
pub const FILE_DEVICE_TRANSPORT: DEVICE_TYPE = 0x0021;
pub const FILE_DEVICE_UNKNOWN: DEVICE_TYPE = 0x0022;
pub const FILE_DEVICE_VIDEO: DEVICE_TYPE = 0x0023;
pub const FILE_DEVICE_VIRTUAL_DISK: DEVICE_TYPE = 0x0024;
pub const FILE_DEVICE_WAVE_IN: DEVICE_TYPE = 0x0025;
pub const FILE_DEVICE_WAVE_OUT: DEVICE_TYPE = 0x0026;
pub const FILE_DEVICE_8042_PORT: DEVICE_TYPE = 0x0027;
pub const FILE_DEVICE_NETWORK_REDIRECTOR: DEVICE_TYPE = 0x0028;
pub const FILE_DEVICE_BATTERY: DEVICE_TYPE = 0x0029;
pub const FILE_DEVICE_BUS_EXTENDER: DEVICE_TYPE = 0x002a;
pub const FILE_DEVICE_MODEM: DEVICE_TYPE = 0x002b;
pub const FILE_DEVICE_VDM: DEVICE_TYPE = 0x002c;
pub const FILE_DEVICE_MASS_STORAGE: DEVICE_TYPE = 0x002d;
pub const FILE_DEVICE_SMB: DEVICE_TYPE = 0x002e;
pub const FILE_DEVICE_KS: DEVICE_TYPE = 0x002f;
pub const FILE_DEVICE_CHANGER: DEVICE_TYPE = 0x0030;
pub const FILE_DEVICE_SMARTCARD: DEVICE_TYPE = 0x0031;
pub const FILE_DEVICE_ACPI: DEVICE_TYPE = 0x0032;
pub const FILE_DEVICE_DVD: DEVICE_TYPE = 0x0033;
pub const FILE_DEVICE_FULLSCREEN_VIDEO: DEVICE_TYPE = 0x0034;
pub const FILE_DEVICE_DFS_FILE_SYSTEM: DEVICE_TYPE = 0x0035;
pub const FILE_DEVICE_DFS_VOLUME: DEVICE_TYPE = 0x0036;
pub const FILE_DEVICE_SERENUM: DEVICE_TYPE = 0x0037;
pub const FILE_DEVICE_TERMSRV: DEVICE_TYPE = 0x0038;
pub const FILE_DEVICE_KSEC: DEVICE_TYPE = 0x0039;
pub const FILE_DEVICE_FIPS: DEVICE_TYPE = 0x003a;
pub const FILE_DEVICE_INFINIBAND: DEVICE_TYPE = 0x003b;
// TODO: missing values?
pub const FILE_DEVICE_VMBUS: DEVICE_TYPE = 0x003e;
pub const FILE_DEVICE_CRYPT_PROVIDER: DEVICE_TYPE = 0x003f;
pub const FILE_DEVICE_WPD: DEVICE_TYPE = 0x0040;
pub const FILE_DEVICE_BLUETOOTH: DEVICE_TYPE = 0x0041;
pub const FILE_DEVICE_MT_COMPOSITE: DEVICE_TYPE = 0x0042;
pub const FILE_DEVICE_MT_TRANSPORT: DEVICE_TYPE = 0x0043;
pub const FILE_DEVICE_BIOMETRIC: DEVICE_TYPE = 0x0044;
pub const FILE_DEVICE_PMI: DEVICE_TYPE = 0x0045;
pub const FILE_DEVICE_EHSTOR: DEVICE_TYPE = 0x0046;
pub const FILE_DEVICE_DEVAPI: DEVICE_TYPE = 0x0047;
pub const FILE_DEVICE_GPIO: DEVICE_TYPE = 0x0048;
pub const FILE_DEVICE_USBEX: DEVICE_TYPE = 0x0049;
pub const FILE_DEVICE_CONSOLE: DEVICE_TYPE = 0x0050;
pub const FILE_DEVICE_NFP: DEVICE_TYPE = 0x0051;
pub const FILE_DEVICE_SYSENV: DEVICE_TYPE = 0x0052;
pub const FILE_DEVICE_VIRTUAL_BLOCK: DEVICE_TYPE = 0x0053;
pub const FILE_DEVICE_POINT_OF_SERVICE: DEVICE_TYPE = 0x0054;
pub const FILE_DEVICE_STORAGE_REPLICATION: DEVICE_TYPE = 0x0055;
pub const FILE_DEVICE_TRUST_ENV: DEVICE_TYPE = 0x0056;
pub const FILE_DEVICE_UCM: DEVICE_TYPE = 0x0057;
pub const FILE_DEVICE_UCMTCPCI: DEVICE_TYPE = 0x0058;
pub const FILE_DEVICE_PERSISTENT_MEMORY: DEVICE_TYPE = 0x0059;
pub const FILE_DEVICE_NVDIMM: DEVICE_TYPE = 0x005a;
pub const FILE_DEVICE_HOLOGRAPHIC: DEVICE_TYPE = 0x005b;
pub const FILE_DEVICE_SDFXHCI: DEVICE_TYPE = 0x005c;

/// https://docs.microsoft.com/en-us/windows-hardware/drivers/kernel/buffer-descriptions-for-i-o-control-codes
pub const TransferType = enum(u2) {
    METHOD_BUFFERED = 0,
    METHOD_IN_DIRECT = 1,
    METHOD_OUT_DIRECT = 2,
    METHOD_NEITHER = 3,
};

pub const FILE_ANY_ACCESS = 0;
pub const FILE_READ_ACCESS = 1;
pub const FILE_WRITE_ACCESS = 2;

/// https://docs.microsoft.com/en-us/windows-hardware/drivers/kernel/defining-i-o-control-codes
pub fn CTL_CODE(deviceType: u16, function: u12, method: TransferType, access: u2) DWORD {
    return (@as(DWORD, deviceType) << 16) |
        (@as(DWORD, access) << 14) |
        (@as(DWORD, function) << 2) |
        @intFromEnum(method);
}

pub const INVALID_HANDLE_VALUE = @as(HANDLE, @ptrFromInt(maxInt(usize)));

pub const INVALID_FILE_ATTRIBUTES = @as(DWORD, maxInt(DWORD));

pub const FILE_ALL_INFORMATION = extern struct {
    BasicInformation: FILE_BASIC_INFORMATION,
    StandardInformation: FILE_STANDARD_INFORMATION,
    InternalInformation: FILE_INTERNAL_INFORMATION,
    EaInformation: FILE_EA_INFORMATION,
    AccessInformation: FILE_ACCESS_INFORMATION,
    PositionInformation: FILE_POSITION_INFORMATION,
    ModeInformation: FILE_MODE_INFORMATION,
    AlignmentInformation: FILE_ALIGNMENT_INFORMATION,
    NameInformation: FILE_NAME_INFORMATION,
};

pub const FILE_BASIC_INFORMATION = extern struct {
    CreationTime: LARGE_INTEGER,
    LastAccessTime: LARGE_INTEGER,
    LastWriteTime: LARGE_INTEGER,
    ChangeTime: LARGE_INTEGER,
    FileAttributes: ULONG,
};

pub const FILE_STANDARD_INFORMATION = extern struct {
    AllocationSize: LARGE_INTEGER,
    EndOfFile: LARGE_INTEGER,
    NumberOfLinks: ULONG,
    DeletePending: BOOLEAN,
    Directory: BOOLEAN,
};

pub const FILE_INTERNAL_INFORMATION = extern struct {
    IndexNumber: LARGE_INTEGER,
};

pub const FILE_EA_INFORMATION = extern struct {
    EaSize: ULONG,
};

pub const FILE_ACCESS_INFORMATION = extern struct {
    AccessFlags: ACCESS_MASK,
};

pub const FILE_POSITION_INFORMATION = extern struct {
    CurrentByteOffset: LARGE_INTEGER,
};

pub const FILE_END_OF_FILE_INFORMATION = extern struct {
    EndOfFile: LARGE_INTEGER,
};

pub const FILE_MODE_INFORMATION = extern struct {
    Mode: ULONG,
};

pub const FILE_ALIGNMENT_INFORMATION = extern struct {
    AlignmentRequirement: ULONG,
};

pub const FILE_NAME_INFORMATION = extern struct {
    FileNameLength: ULONG,
    FileName: [1]WCHAR,
};

pub const FILE_DISPOSITION_INFORMATION_EX = extern struct {
    /// combination of FILE_DISPOSITION_* flags
    Flags: ULONG,
};

const FILE_DISPOSITION_DO_NOT_DELETE: ULONG = 0x00000000;
const FILE_DISPOSITION_DELETE: ULONG = 0x00000001;
const FILE_DISPOSITION_POSIX_SEMANTICS: ULONG = 0x00000002;
const FILE_DISPOSITION_FORCE_IMAGE_SECTION_CHECK: ULONG = 0x00000004;
const FILE_DISPOSITION_ON_CLOSE: ULONG = 0x00000008;
const FILE_DISPOSITION_IGNORE_READONLY_ATTRIBUTE: ULONG = 0x00000010;

pub const FILE_RENAME_INFORMATION = extern struct {
    ReplaceIfExists: BOOLEAN,
    RootDirectory: ?HANDLE,
    FileNameLength: ULONG,
    FileName: [1]WCHAR,
};

pub const IO_STATUS_BLOCK = extern struct {
    // "DUMMYUNIONNAME" expands to "u"
    u: extern union {
        Status: NTSTATUS,
        Pointer: ?*anyopaque,
    },
    Information: ULONG_PTR,
};

pub const FILE_INFORMATION_CLASS = enum(c_int) {
    FileDirectoryInformation = 1,
    FileFullDirectoryInformation,
    FileBothDirectoryInformation,
    FileBasicInformation,
    FileStandardInformation,
    FileInternalInformation,
    FileEaInformation,
    FileAccessInformation,
    FileNameInformation,
    FileRenameInformation,
    FileLinkInformation,
    FileNamesInformation,
    FileDispositionInformation,
    FilePositionInformation,
    FileFullEaInformation,
    FileModeInformation,
    FileAlignmentInformation,
    FileAllInformation,
    FileAllocationInformation,
    FileEndOfFileInformation,
    FileAlternateNameInformation,
    FileStreamInformation,
    FilePipeInformation,
    FilePipeLocalInformation,
    FilePipeRemoteInformation,
    FileMailslotQueryInformation,
    FileMailslotSetInformation,
    FileCompressionInformation,
    FileObjectIdInformation,
    FileCompletionInformation,
    FileMoveClusterInformation,
    FileQuotaInformation,
    FileReparsePointInformation,
    FileNetworkOpenInformation,
    FileAttributeTagInformation,
    FileTrackingInformation,
    FileIdBothDirectoryInformation,
    FileIdFullDirectoryInformation,
    FileValidDataLengthInformation,
    FileShortNameInformation,
    FileIoCompletionNotificationInformation,
    FileIoStatusBlockRangeInformation,
    FileIoPriorityHintInformation,
    FileSfioReserveInformation,
    FileSfioVolumeInformation,
    FileHardLinkInformation,
    FileProcessIdsUsingFileInformation,
    FileNormalizedNameInformation,
    FileNetworkPhysicalNameInformation,
    FileIdGlobalTxDirectoryInformation,
    FileIsRemoteDeviceInformation,
    FileUnusedInformation,
    FileNumaNodeInformation,
    FileStandardLinkInformation,
    FileRemoteProtocolInformation,
    FileRenameInformationBypassAccessCheck,
    FileLinkInformationBypassAccessCheck,
    FileVolumeNameInformation,
    FileIdInformation,
    FileIdExtdDirectoryInformation,
    FileReplaceCompletionInformation,
    FileHardLinkFullIdInformation,
    FileIdExtdBothDirectoryInformation,
    FileDispositionInformationEx,
    FileRenameInformationEx,
    FileRenameInformationExBypassAccessCheck,
    FileDesiredStorageClassInformation,
    FileStatInformation,
    FileMemoryPartitionInformation,
    FileStatLxInformation,
    FileCaseSensitiveInformation,
    FileLinkInformationEx,
    FileLinkInformationExBypassAccessCheck,
    FileStorageReserveIdInformation,
    FileCaseSensitiveInformationForceAccessCheck,
    FileMaximumInformation,
};

pub const FILE_DISPOSITION_INFORMATION = extern struct {
    DeleteFile: BOOLEAN,
};

pub const FILE_FS_DEVICE_INFORMATION = extern struct {
    DeviceType: DEVICE_TYPE,
    Characteristics: ULONG,
};

pub const FS_INFORMATION_CLASS = enum(c_int) {
    FileFsVolumeInformation = 1,
    FileFsLabelInformation,
    FileFsSizeInformation,
    FileFsDeviceInformation,
    FileFsAttributeInformation,
    FileFsControlInformation,
    FileFsFullSizeInformation,
    FileFsObjectIdInformation,
    FileFsDriverPathInformation,
    FileFsVolumeFlagsInformation,
    FileFsSectorSizeInformation,
    FileFsDataCopyInformation,
    FileFsMetadataSizeInformation,
    FileFsFullSizeInformationEx,
    FileFsMaximumInformation,
};

pub const OVERLAPPED = extern struct {
    Internal: ULONG_PTR,
    InternalHigh: ULONG_PTR,
    DUMMYUNIONNAME: extern union {
        DUMMYSTRUCTNAME: extern struct {
            Offset: DWORD,
            OffsetHigh: DWORD,
        },
        Pointer: ?PVOID,
    },
    hEvent: ?HANDLE,
};

pub const OVERLAPPED_ENTRY = extern struct {
    lpCompletionKey: ULONG_PTR,
    lpOverlapped: *OVERLAPPED,
    Internal: ULONG_PTR,
    dwNumberOfBytesTransferred: DWORD,
};

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

pub const BY_HANDLE_FILE_INFORMATION = extern struct {
    dwFileAttributes: DWORD,
    ftCreationTime: FILETIME,
    ftLastAccessTime: FILETIME,
    ftLastWriteTime: FILETIME,
    dwVolumeSerialNumber: DWORD,
    nFileSizeHigh: DWORD,
    nFileSizeLow: DWORD,
    nNumberOfLinks: DWORD,
    nFileIndexHigh: DWORD,
    nFileIndexLow: DWORD,
};

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
    lpSecurityDescriptor: ?*anyopaque,
    bInheritHandle: BOOL,
};

pub const PIPE_ACCESS_INBOUND = 0x00000001;
pub const PIPE_ACCESS_OUTBOUND = 0x00000002;
pub const PIPE_ACCESS_DUPLEX = 0x00000003;

pub const PIPE_TYPE_BYTE = 0x00000000;
pub const PIPE_TYPE_MESSAGE = 0x00000004;

pub const PIPE_READMODE_BYTE = 0x00000000;
pub const PIPE_READMODE_MESSAGE = 0x00000002;

pub const PIPE_WAIT = 0x00000000;
pub const PIPE_NOWAIT = 0x00000001;

pub const GENERIC_READ = 0x80000000;
pub const GENERIC_WRITE = 0x40000000;
pub const GENERIC_EXECUTE = 0x20000000;
pub const GENERIC_ALL = 0x10000000;

pub const FILE_SHARE_DELETE = 0x00000004;
pub const FILE_SHARE_READ = 0x00000001;
pub const FILE_SHARE_WRITE = 0x00000002;

pub const DELETE = 0x00010000;
pub const READ_CONTROL = 0x00020000;
pub const WRITE_DAC = 0x00040000;
pub const WRITE_OWNER = 0x00080000;
pub const SYNCHRONIZE = 0x00100000;
pub const STANDARD_RIGHTS_READ = READ_CONTROL;
pub const STANDARD_RIGHTS_WRITE = READ_CONTROL;
pub const STANDARD_RIGHTS_EXECUTE = READ_CONTROL;
pub const STANDARD_RIGHTS_REQUIRED = DELETE | READ_CONTROL | WRITE_DAC | WRITE_OWNER;
pub const MAXIMUM_ALLOWED = 0x02000000;

// disposition for NtCreateFile
pub const FILE_SUPERSEDE = 0;
pub const FILE_OPEN = 1;
pub const FILE_CREATE = 2;
pub const FILE_OPEN_IF = 3;
pub const FILE_OVERWRITE = 4;
pub const FILE_OVERWRITE_IF = 5;
pub const FILE_MAXIMUM_DISPOSITION = 5;

// flags for NtCreateFile and NtOpenFile
pub const FILE_READ_DATA = 0x00000001;
pub const FILE_LIST_DIRECTORY = 0x00000001;
pub const FILE_WRITE_DATA = 0x00000002;
pub const FILE_ADD_FILE = 0x00000002;
pub const FILE_APPEND_DATA = 0x00000004;
pub const FILE_ADD_SUBDIRECTORY = 0x00000004;
pub const FILE_CREATE_PIPE_INSTANCE = 0x00000004;
pub const FILE_READ_EA = 0x00000008;
pub const FILE_WRITE_EA = 0x00000010;
pub const FILE_EXECUTE = 0x00000020;
pub const FILE_TRAVERSE = 0x00000020;
pub const FILE_DELETE_CHILD = 0x00000040;
pub const FILE_READ_ATTRIBUTES = 0x00000080;
pub const FILE_WRITE_ATTRIBUTES = 0x00000100;

pub const FILE_DIRECTORY_FILE = 0x00000001;
pub const FILE_WRITE_THROUGH = 0x00000002;
pub const FILE_SEQUENTIAL_ONLY = 0x00000004;
pub const FILE_NO_INTERMEDIATE_BUFFERING = 0x00000008;
pub const FILE_SYNCHRONOUS_IO_ALERT = 0x00000010;
pub const FILE_SYNCHRONOUS_IO_NONALERT = 0x00000020;
pub const FILE_NON_DIRECTORY_FILE = 0x00000040;
pub const FILE_CREATE_TREE_CONNECTION = 0x00000080;
pub const FILE_COMPLETE_IF_OPLOCKED = 0x00000100;
pub const FILE_NO_EA_KNOWLEDGE = 0x00000200;
pub const FILE_OPEN_FOR_RECOVERY = 0x00000400;
pub const FILE_RANDOM_ACCESS = 0x00000800;
pub const FILE_DELETE_ON_CLOSE = 0x00001000;
pub const FILE_OPEN_BY_FILE_ID = 0x00002000;
pub const FILE_OPEN_FOR_BACKUP_INTENT = 0x00004000;
pub const FILE_NO_COMPRESSION = 0x00008000;
pub const FILE_RESERVE_OPFILTER = 0x00100000;
pub const FILE_OPEN_REPARSE_POINT = 0x00200000;
pub const FILE_OPEN_OFFLINE_FILE = 0x00400000;
pub const FILE_OPEN_FOR_FREE_SPACE_QUERY = 0x00800000;

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

// flags for CreateEvent
pub const CREATE_EVENT_INITIAL_SET = 0x00000002;
pub const CREATE_EVENT_MANUAL_RESET = 0x00000001;

pub const EVENT_ALL_ACCESS = 0x1F0003;
pub const EVENT_MODIFY_STATE = 0x0002;

// MEMORY_BASIC_INFORMATION.Type flags for VirtualQuery
pub const MEM_IMAGE = 0x1000000;
pub const MEM_MAPPED = 0x40000;
pub const MEM_PRIVATE = 0x20000;

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
    lpReserved2: ?*BYTE,
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

pub const MAXIMUM_WAIT_OBJECTS = 64;

pub const WAIT_ABANDONED = 0x00000080;
pub const WAIT_ABANDONED_0 = WAIT_ABANDONED + 0;
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
pub const HEAP_REALLOC_IN_PLACE_ONLY = 0x00000010;
pub const HEAP_GENERATE_EXCEPTIONS = 0x00000004;
pub const HEAP_NO_SERIALIZE = 0x00000001;

// AllocationType values
pub const MEM_COMMIT = 0x1000;
pub const MEM_RESERVE = 0x2000;
pub const MEM_FREE = 0x10000;
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

pub const PTHREAD_START_ROUTINE = *const fn (LPVOID) callconv(.C) DWORD;
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
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,

    const hex_offsets = switch (builtin.target.cpu.arch.endian()) {
        .Big => [16]u6{
            0,  2,  4,  6,
            9,  11, 14, 16,
            19, 21, 24, 26,
            28, 30, 32, 34,
        },
        .Little => [16]u6{
            6,  4,  2,  0,
            11, 9,  16, 14,
            19, 21, 24, 26,
            28, 30, 32, 34,
        },
    };

    pub fn parse(s: []const u8) GUID {
        assert(s[0] == '{');
        assert(s[37] == '}');
        return parseNoBraces(s[1 .. s.len - 1]) catch @panic("invalid GUID string");
    }

    pub fn parseNoBraces(s: []const u8) !GUID {
        assert(s.len == 36);
        assert(s[8] == '-');
        assert(s[13] == '-');
        assert(s[18] == '-');
        assert(s[23] == '-');
        var bytes: [16]u8 = undefined;
        for (hex_offsets, 0..) |hex_offset, i| {
            bytes[i] = (try std.fmt.charToDigit(s[hex_offset], 16)) << 4 |
                try std.fmt.charToDigit(s[hex_offset + 1], 16);
        }
        return @as(GUID, @bitCast(bytes));
    }
};

test "GUID" {
    try std.testing.expectEqual(
        GUID{
            .Data1 = 0x01234567,
            .Data2 = 0x89ab,
            .Data3 = 0xef10,
            .Data4 = "\x32\x54\x76\x98\xba\xdc\xfe\x91".*,
        },
        GUID.parse("{01234567-89AB-EF10-3254-7698badcfe91}"),
    );
}

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
pub const S_FALSE = 0x00000001;
pub const E_NOTIMPL = @as(c_long, @bitCast(@as(c_ulong, 0x80004001)));
pub const E_NOINTERFACE = @as(c_long, @bitCast(@as(c_ulong, 0x80004002)));
pub const E_POINTER = @as(c_long, @bitCast(@as(c_ulong, 0x80004003)));
pub const E_ABORT = @as(c_long, @bitCast(@as(c_ulong, 0x80004004)));
pub const E_FAIL = @as(c_long, @bitCast(@as(c_ulong, 0x80004005)));
pub const E_UNEXPECTED = @as(c_long, @bitCast(@as(c_ulong, 0x8000FFFF)));
pub const E_ACCESSDENIED = @as(c_long, @bitCast(@as(c_ulong, 0x80070005)));
pub const E_HANDLE = @as(c_long, @bitCast(@as(c_ulong, 0x80070006)));
pub const E_OUTOFMEMORY = @as(c_long, @bitCast(@as(c_ulong, 0x8007000E)));
pub const E_INVALIDARG = @as(c_long, @bitCast(@as(c_ulong, 0x80070057)));

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

pub const RECT = extern struct {
    left: LONG,
    top: LONG,
    right: LONG,
    bottom: LONG,
};

pub const SMALL_RECT = extern struct {
    Left: SHORT,
    Top: SHORT,
    Right: SHORT,
    Bottom: SHORT,
};

pub const POINT = extern struct {
    x: LONG,
    y: LONG,
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

pub const PIMAGE_TLS_CALLBACK = ?*const fn (PVOID, DWORD, PVOID) callconv(.C) void;

pub const PROV_RSA_FULL = 1;

pub const REGSAM = ACCESS_MASK;
pub const ACCESS_MASK = DWORD;
pub const LSTATUS = LONG;

pub const SECTION_INHERIT = enum(c_int) {
    ViewShare = 0,
    ViewUnmap = 1,
};

pub const SECTION_QUERY = 0x0001;
pub const SECTION_MAP_WRITE = 0x0002;
pub const SECTION_MAP_READ = 0x0004;
pub const SECTION_MAP_EXECUTE = 0x0008;
pub const SECTION_EXTEND_SIZE = 0x0010;
pub const SECTION_ALL_ACCESS =
    STANDARD_RIGHTS_REQUIRED |
    SECTION_QUERY |
    SECTION_MAP_WRITE |
    SECTION_MAP_READ |
    SECTION_MAP_EXECUTE |
    SECTION_EXTEND_SIZE;

pub const SEC_64K_PAGES = 0x80000;
pub const SEC_FILE = 0x800000;
pub const SEC_IMAGE = 0x1000000;
pub const SEC_PROTECTED_IMAGE = 0x2000000;
pub const SEC_RESERVE = 0x4000000;
pub const SEC_COMMIT = 0x8000000;
pub const SEC_IMAGE_NO_EXECUTE = SEC_IMAGE | SEC_NOCACHE;
pub const SEC_NOCACHE = 0x10000000;
pub const SEC_WRITECOMBINE = 0x40000000;
pub const SEC_LARGE_PAGES = 0x80000000;

pub const HKEY = *opaque {};

pub const HKEY_LOCAL_MACHINE: HKEY = @as(HKEY, @ptrFromInt(0x80000002));

/// Combines the STANDARD_RIGHTS_REQUIRED, KEY_QUERY_VALUE, KEY_SET_VALUE, KEY_CREATE_SUB_KEY,
/// KEY_ENUMERATE_SUB_KEYS, KEY_NOTIFY, and KEY_CREATE_LINK access rights.
pub const KEY_ALL_ACCESS = 0xF003F;
/// Reserved for system use.
pub const KEY_CREATE_LINK = 0x0020;
/// Required to create a subkey of a registry key.
pub const KEY_CREATE_SUB_KEY = 0x0004;
/// Required to enumerate the subkeys of a registry key.
pub const KEY_ENUMERATE_SUB_KEYS = 0x0008;
/// Equivalent to KEY_READ.
pub const KEY_EXECUTE = 0x20019;
/// Required to request change notifications for a registry key or for subkeys of a registry key.
pub const KEY_NOTIFY = 0x0010;
/// Required to query the values of a registry key.
pub const KEY_QUERY_VALUE = 0x0001;
/// Combines the STANDARD_RIGHTS_READ, KEY_QUERY_VALUE, KEY_ENUMERATE_SUB_KEYS, and KEY_NOTIFY values.
pub const KEY_READ = 0x20019;
/// Required to create, delete, or set a registry value.
pub const KEY_SET_VALUE = 0x0002;
/// Indicates that an application on 64-bit Windows should operate on the 32-bit registry view.
/// This flag is ignored by 32-bit Windows.
pub const KEY_WOW64_32KEY = 0x0200;
/// Indicates that an application on 64-bit Windows should operate on the 64-bit registry view.
/// This flag is ignored by 32-bit Windows.
pub const KEY_WOW64_64KEY = 0x0100;
/// Combines the STANDARD_RIGHTS_WRITE, KEY_SET_VALUE, and KEY_CREATE_SUB_KEY access rights.
pub const KEY_WRITE = 0x20006;

/// Open symbolic link.
pub const REG_OPTION_OPEN_LINK: DWORD = 0x8;

pub const RTL_QUERY_REGISTRY_TABLE = extern struct {
    QueryRoutine: RTL_QUERY_REGISTRY_ROUTINE,
    Flags: ULONG,
    Name: ?PWSTR,
    EntryContext: ?*anyopaque,
    DefaultType: ULONG,
    DefaultData: ?*anyopaque,
    DefaultLength: ULONG,
};

pub const RTL_QUERY_REGISTRY_ROUTINE = ?*const fn (
    PWSTR,
    ULONG,
    ?*anyopaque,
    ULONG,
    ?*anyopaque,
    ?*anyopaque,
) callconv(WINAPI) NTSTATUS;

/// Path is a full path
pub const RTL_REGISTRY_ABSOLUTE = 0;
/// \Registry\Machine\System\CurrentControlSet\Services
pub const RTL_REGISTRY_SERVICES = 1;
/// \Registry\Machine\System\CurrentControlSet\Control
pub const RTL_REGISTRY_CONTROL = 2;
/// \Registry\Machine\Software\Microsoft\Windows NT\CurrentVersion
pub const RTL_REGISTRY_WINDOWS_NT = 3;
/// \Registry\Machine\Hardware\DeviceMap
pub const RTL_REGISTRY_DEVICEMAP = 4;
/// \Registry\User\CurrentUser
pub const RTL_REGISTRY_USER = 5;
pub const RTL_REGISTRY_MAXIMUM = 6;

/// Low order bits are registry handle
pub const RTL_REGISTRY_HANDLE = 0x40000000;
/// Indicates the key node is optional
pub const RTL_REGISTRY_OPTIONAL = 0x80000000;

/// Name is a subkey and remainder of table or until next subkey are value
/// names for that subkey to look at.
pub const RTL_QUERY_REGISTRY_SUBKEY = 0x00000001;

/// Reset current key to original key for this and all following table entries.
pub const RTL_QUERY_REGISTRY_TOPKEY = 0x00000002;

/// Fail if no match found for this table entry.
pub const RTL_QUERY_REGISTRY_REQUIRED = 0x00000004;

/// Used to mark a table entry that has no value name, just wants a call out, not
/// an enumeration of all values.
pub const RTL_QUERY_REGISTRY_NOVALUE = 0x00000008;

/// Used to suppress the expansion of REG_MULTI_SZ into multiple callouts or
/// to prevent the expansion of environment variable values in REG_EXPAND_SZ.
pub const RTL_QUERY_REGISTRY_NOEXPAND = 0x00000010;

/// QueryRoutine field ignored.  EntryContext field points to location to store value.
/// For null terminated strings, EntryContext points to UNICODE_STRING structure that
/// that describes maximum size of buffer. If .Buffer field is NULL then a buffer is
/// allocated.
pub const RTL_QUERY_REGISTRY_DIRECT = 0x00000020;

/// Used to delete value keys after they are queried.
pub const RTL_QUERY_REGISTRY_DELETE = 0x00000040;

/// Use this flag with the RTL_QUERY_REGISTRY_DIRECT flag to verify that the REG_XXX type
/// of the stored registry value matches the type expected by the caller.
/// If the types do not match, the call fails.
pub const RTL_QUERY_REGISTRY_TYPECHECK = 0x00000100;

pub const REG = struct {
    /// No value type
    pub const NONE: ULONG = 0;
    /// Unicode nul terminated string
    pub const SZ: ULONG = 1;
    /// Unicode nul terminated string (with environment variable references)
    pub const EXPAND_SZ: ULONG = 2;
    /// Free form binary
    pub const BINARY: ULONG = 3;
    /// 32-bit number
    pub const DWORD: ULONG = 4;
    /// 32-bit number (same as REG_DWORD)
    pub const DWORD_LITTLE_ENDIAN: ULONG = 4;
    /// 32-bit number
    pub const DWORD_BIG_ENDIAN: ULONG = 5;
    /// Symbolic Link (unicode)
    pub const LINK: ULONG = 6;
    /// Multiple Unicode strings
    pub const MULTI_SZ: ULONG = 7;
    /// Resource list in the resource map
    pub const RESOURCE_LIST: ULONG = 8;
    /// Resource list in the hardware description
    pub const FULL_RESOURCE_DESCRIPTOR: ULONG = 9;
    pub const RESOURCE_REQUIREMENTS_LIST: ULONG = 10;
    /// 64-bit number
    pub const QWORD: ULONG = 11;
    /// 64-bit number (same as REG_QWORD)
    pub const QWORD_LITTLE_ENDIAN: ULONG = 11;
};

pub const FILE_NOTIFY_INFORMATION = extern struct {
    NextEntryOffset: DWORD,
    Action: DWORD,
    FileNameLength: DWORD,
    // Flexible array member
    // FileName: [1]WCHAR,
};

pub const FILE_ACTION_ADDED = 0x00000001;
pub const FILE_ACTION_REMOVED = 0x00000002;
pub const FILE_ACTION_MODIFIED = 0x00000003;
pub const FILE_ACTION_RENAMED_OLD_NAME = 0x00000004;
pub const FILE_ACTION_RENAMED_NEW_NAME = 0x00000005;

pub const LPOVERLAPPED_COMPLETION_ROUTINE = ?*const fn (DWORD, DWORD, *OVERLAPPED) callconv(.C) void;

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

pub const ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x4;

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
pub const INIT_ONCE_FN = *const fn (InitOnce: *INIT_ONCE, Parameter: ?*anyopaque, Context: ?*anyopaque) callconv(.C) BOOL;

pub const RTL_RUN_ONCE = extern struct {
    Ptr: ?*anyopaque,
};

pub const RTL_RUN_ONCE_INIT = RTL_RUN_ONCE{ .Ptr = null };

pub const COINIT = struct {
    pub const APARTMENTTHREADED = 2;
    pub const MULTITHREADED = 0;
    pub const DISABLE_OLE1DDE = 4;
    pub const SPEED_OVER_MEMORY = 8;
};

pub const MEMORY_BASIC_INFORMATION = extern struct {
    BaseAddress: PVOID,
    AllocationBase: PVOID,
    AllocationProtect: DWORD,
    PartitionId: WORD,
    RegionSize: SIZE_T,
    State: DWORD,
    Protect: DWORD,
    Type: DWORD,
};

pub const PMEMORY_BASIC_INFORMATION = *MEMORY_BASIC_INFORMATION;

/// > The maximum path of 32,767 characters is approximate, because the "\\?\"
/// > prefix may be expanded to a longer string by the system at run time, and
/// > this expansion applies to the total length.
/// from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
pub const PATH_MAX_WIDE = 32767;

/// > [Each file name component can be] up to the value returned in the
/// > lpMaximumComponentLength parameter of the GetVolumeInformation function
/// > (this value is commonly 255 characters)
/// from https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation
///
/// > The value that is stored in the variable that *lpMaximumComponentLength points to is
/// > used to indicate that a specified file system supports long names. For example, for
/// > a FAT file system that supports long names, the function stores the value 255, rather
/// > than the previous 8.3 indicator. Long names can also be supported on systems that use
/// > the NTFS file system.
/// from https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-getvolumeinformationw
///
/// The assumption being made here is that while lpMaximumComponentLength may vary, it will never
/// be larger than 255.
///
/// TODO: More verification of this assumption.
pub const NAME_MAX = 255;

pub const FORMAT_MESSAGE_ALLOCATE_BUFFER = 0x00000100;
pub const FORMAT_MESSAGE_ARGUMENT_ARRAY = 0x00002000;
pub const FORMAT_MESSAGE_FROM_HMODULE = 0x00000800;
pub const FORMAT_MESSAGE_FROM_STRING = 0x00000400;
pub const FORMAT_MESSAGE_FROM_SYSTEM = 0x00001000;
pub const FORMAT_MESSAGE_IGNORE_INSERTS = 0x00000200;
pub const FORMAT_MESSAGE_MAX_WIDTH_MASK = 0x000000FF;

pub const EXCEPTION_DATATYPE_MISALIGNMENT = 0x80000002;
pub const EXCEPTION_ACCESS_VIOLATION = 0xc0000005;
pub const EXCEPTION_ILLEGAL_INSTRUCTION = 0xc000001d;
pub const EXCEPTION_STACK_OVERFLOW = 0xc00000fd;
pub const EXCEPTION_CONTINUE_SEARCH = 0;

pub const EXCEPTION_RECORD = extern struct {
    ExceptionCode: u32,
    ExceptionFlags: u32,
    ExceptionRecord: *EXCEPTION_RECORD,
    ExceptionAddress: *anyopaque,
    NumberParameters: u32,
    ExceptionInformation: [15]usize,
};

pub usingnamespace switch (native_arch) {
    .x86 => struct {
        pub const FLOATING_SAVE_AREA = extern struct {
            ControlWord: DWORD,
            StatusWord: DWORD,
            TagWord: DWORD,
            ErrorOffset: DWORD,
            ErrorSelector: DWORD,
            DataOffset: DWORD,
            DataSelector: DWORD,
            RegisterArea: [80]BYTE,
            Cr0NpxState: DWORD,
        };

        pub const CONTEXT = extern struct {
            ContextFlags: DWORD,
            Dr0: DWORD,
            Dr1: DWORD,
            Dr2: DWORD,
            Dr3: DWORD,
            Dr6: DWORD,
            Dr7: DWORD,
            FloatSave: FLOATING_SAVE_AREA,
            SegGs: DWORD,
            SegFs: DWORD,
            SegEs: DWORD,
            SegDs: DWORD,
            Edi: DWORD,
            Esi: DWORD,
            Ebx: DWORD,
            Edx: DWORD,
            Ecx: DWORD,
            Eax: DWORD,
            Ebp: DWORD,
            Eip: DWORD,
            SegCs: DWORD,
            EFlags: DWORD,
            Esp: DWORD,
            SegSs: DWORD,
            ExtendedRegisters: [512]BYTE,

            pub fn getRegs(ctx: *const CONTEXT) struct { bp: usize, ip: usize } {
                return .{ .bp = ctx.Ebp, .ip = ctx.Eip };
            }
        };
    },
    .x86_64 => struct {
        pub const M128A = extern struct {
            Low: ULONGLONG,
            High: LONGLONG,
        };

        pub const XMM_SAVE_AREA32 = extern struct {
            ControlWord: WORD,
            StatusWord: WORD,
            TagWord: BYTE,
            Reserved1: BYTE,
            ErrorOpcode: WORD,
            ErrorOffset: DWORD,
            ErrorSelector: WORD,
            Reserved2: WORD,
            DataOffset: DWORD,
            DataSelector: WORD,
            Reserved3: WORD,
            MxCsr: DWORD,
            MxCsr_Mask: DWORD,
            FloatRegisters: [8]M128A,
            XmmRegisters: [16]M128A,
            Reserved4: [96]BYTE,
        };

        pub const CONTEXT = extern struct {
            P1Home: DWORD64 align(16),
            P2Home: DWORD64,
            P3Home: DWORD64,
            P4Home: DWORD64,
            P5Home: DWORD64,
            P6Home: DWORD64,
            ContextFlags: DWORD,
            MxCsr: DWORD,
            SegCs: WORD,
            SegDs: WORD,
            SegEs: WORD,
            SegFs: WORD,
            SegGs: WORD,
            SegSs: WORD,
            EFlags: DWORD,
            Dr0: DWORD64,
            Dr1: DWORD64,
            Dr2: DWORD64,
            Dr3: DWORD64,
            Dr6: DWORD64,
            Dr7: DWORD64,
            Rax: DWORD64,
            Rcx: DWORD64,
            Rdx: DWORD64,
            Rbx: DWORD64,
            Rsp: DWORD64,
            Rbp: DWORD64,
            Rsi: DWORD64,
            Rdi: DWORD64,
            R8: DWORD64,
            R9: DWORD64,
            R10: DWORD64,
            R11: DWORD64,
            R12: DWORD64,
            R13: DWORD64,
            R14: DWORD64,
            R15: DWORD64,
            Rip: DWORD64,
            DUMMYUNIONNAME: extern union {
                FltSave: XMM_SAVE_AREA32,
                FloatSave: XMM_SAVE_AREA32,
                DUMMYSTRUCTNAME: extern struct {
                    Header: [2]M128A,
                    Legacy: [8]M128A,
                    Xmm0: M128A,
                    Xmm1: M128A,
                    Xmm2: M128A,
                    Xmm3: M128A,
                    Xmm4: M128A,
                    Xmm5: M128A,
                    Xmm6: M128A,
                    Xmm7: M128A,
                    Xmm8: M128A,
                    Xmm9: M128A,
                    Xmm10: M128A,
                    Xmm11: M128A,
                    Xmm12: M128A,
                    Xmm13: M128A,
                    Xmm14: M128A,
                    Xmm15: M128A,
                },
            },
            VectorRegister: [26]M128A,
            VectorControl: DWORD64,
            DebugControl: DWORD64,
            LastBranchToRip: DWORD64,
            LastBranchFromRip: DWORD64,
            LastExceptionToRip: DWORD64,
            LastExceptionFromRip: DWORD64,

            pub fn getRegs(ctx: *const CONTEXT) struct { bp: usize, ip: usize, sp: usize } {
                return .{ .bp = ctx.Rbp, .ip = ctx.Rip, .sp = ctx.Rsp };
            }

            pub fn setIp(ctx: *CONTEXT, ip: usize) void {
                ctx.Rip = ip;
            }

            pub fn setSp(ctx: *CONTEXT, sp: usize) void {
                ctx.Rsp = sp;
            }
        };

        pub const RUNTIME_FUNCTION = extern struct {
            BeginAddress: DWORD,
            EndAddress: DWORD,
            UnwindData: DWORD,
        };

        pub const KNONVOLATILE_CONTEXT_POINTERS = extern struct {
            FloatingContext: [16]?*M128A,
            IntegerContext: [16]?*ULONG64,
        };
    },
    .aarch64 => struct {
        pub const NEON128 = extern union {
            DUMMYSTRUCTNAME: extern struct {
                Low: ULONGLONG,
                High: LONGLONG,
            },
            D: [2]f64,
            S: [4]f32,
            H: [8]WORD,
            B: [16]BYTE,
        };

        pub const CONTEXT = extern struct {
            ContextFlags: ULONG align(16),
            Cpsr: ULONG,
            DUMMYUNIONNAME: extern union {
                DUMMYSTRUCTNAME: extern struct {
                    X0: DWORD64,
                    X1: DWORD64,
                    X2: DWORD64,
                    X3: DWORD64,
                    X4: DWORD64,
                    X5: DWORD64,
                    X6: DWORD64,
                    X7: DWORD64,
                    X8: DWORD64,
                    X9: DWORD64,
                    X10: DWORD64,
                    X11: DWORD64,
                    X12: DWORD64,
                    X13: DWORD64,
                    X14: DWORD64,
                    X15: DWORD64,
                    X16: DWORD64,
                    X17: DWORD64,
                    X18: DWORD64,
                    X19: DWORD64,
                    X20: DWORD64,
                    X21: DWORD64,
                    X22: DWORD64,
                    X23: DWORD64,
                    X24: DWORD64,
                    X25: DWORD64,
                    X26: DWORD64,
                    X27: DWORD64,
                    X28: DWORD64,
                    Fp: DWORD64,
                    Lr: DWORD64,
                },
                X: [31]DWORD64,
            },
            Sp: DWORD64,
            Pc: DWORD64,
            V: [32]NEON128,
            Fpcr: DWORD,
            Fpsr: DWORD,
            Bcr: [8]DWORD,
            Bvr: [8]DWORD64,
            Wcr: [2]DWORD,
            Wvr: [2]DWORD64,

            pub fn getRegs(ctx: *const CONTEXT) struct { bp: usize, ip: usize, sp: usize } {
                return .{
                    .bp = ctx.DUMMYUNIONNAME.DUMMYSTRUCTNAME.Fp,
                    .ip = ctx.Pc,
                    .sp = ctx.Sp,
                };
            }

            pub fn setIp(ctx: *CONTEXT, ip: usize) void {
                ctx.Pc = ip;
            }

            pub fn setSp(ctx: *CONTEXT, sp: usize) void {
                ctx.Sp = sp;
            }
        };

        pub const RUNTIME_FUNCTION = extern struct {
            BeginAddress: DWORD,
            DUMMYUNIONNAME: extern union {
                UnwindData: DWORD,
                DUMMYSTRUCTNAME: packed struct {
                    Flag: u2,
                    FunctionLength: u11,
                    RegF: u3,
                    RegI: u4,
                    H: u1,
                    CR: u2,
                    FrameSize: u9,
                },
            },
        };

        pub const KNONVOLATILE_CONTEXT_POINTERS = extern struct {
            X19: ?*DWORD64,
            X20: ?*DWORD64,
            X21: ?*DWORD64,
            X22: ?*DWORD64,
            X23: ?*DWORD64,
            X24: ?*DWORD64,
            X25: ?*DWORD64,
            X26: ?*DWORD64,
            X27: ?*DWORD64,
            X28: ?*DWORD64,
            Fp: ?*DWORD64,
            Lr: ?*DWORD64,
            D8: ?*DWORD64,
            D9: ?*DWORD64,
            D10: ?*DWORD64,
            D11: ?*DWORD64,
            D12: ?*DWORD64,
            D13: ?*DWORD64,
            D14: ?*DWORD64,
            D15: ?*DWORD64,
        };
    },
    else => struct {},
};

pub const EXCEPTION_POINTERS = extern struct {
    ExceptionRecord: *EXCEPTION_RECORD,
    ContextRecord: *std.os.windows.CONTEXT,
};

pub const VECTORED_EXCEPTION_HANDLER = *const fn (ExceptionInfo: *EXCEPTION_POINTERS) callconv(WINAPI) c_long;

pub const EXCEPTION_DISPOSITION = i32;
pub const EXCEPTION_ROUTINE = *const fn (
    ExceptionRecord: ?*EXCEPTION_RECORD,
    EstablisherFrame: PVOID,
    ContextRecord: *(Self.CONTEXT),
    DispatcherContext: PVOID,
) callconv(WINAPI) EXCEPTION_DISPOSITION;

pub const UNWIND_HISTORY_TABLE_SIZE = 12;
pub const UNWIND_HISTORY_TABLE_ENTRY = extern struct {
    ImageBase: ULONG64,
    FunctionEntry: *Self.RUNTIME_FUNCTION,
};

pub const UNWIND_HISTORY_TABLE = extern struct {
    Count: ULONG,
    LocalHint: BYTE,
    GlobalHint: BYTE,
    Search: BYTE,
    Once: BYTE,
    LowAddress: ULONG64,
    HighAddress: ULONG64,
    Entry: [UNWIND_HISTORY_TABLE_SIZE]UNWIND_HISTORY_TABLE_ENTRY,
};

pub const UNW_FLAG_NHANDLER = 0x0;
pub const UNW_FLAG_EHANDLER = 0x1;
pub const UNW_FLAG_UHANDLER = 0x2;
pub const UNW_FLAG_CHAININFO = 0x4;

pub const OBJECT_ATTRIBUTES = extern struct {
    Length: ULONG,
    RootDirectory: ?HANDLE,
    ObjectName: *UNICODE_STRING,
    Attributes: ULONG,
    SecurityDescriptor: ?*anyopaque,
    SecurityQualityOfService: ?*anyopaque,
};

pub const OBJ_INHERIT = 0x00000002;
pub const OBJ_PERMANENT = 0x00000010;
pub const OBJ_EXCLUSIVE = 0x00000020;
pub const OBJ_CASE_INSENSITIVE = 0x00000040;
pub const OBJ_OPENIF = 0x00000080;
pub const OBJ_OPENLINK = 0x00000100;
pub const OBJ_KERNEL_HANDLE = 0x00000200;
pub const OBJ_VALID_ATTRIBUTES = 0x000003F2;

pub const UNICODE_STRING = extern struct {
    Length: c_ushort,
    MaximumLength: c_ushort,
    Buffer: [*]WCHAR,
};

pub const ACTIVATION_CONTEXT_DATA = opaque {};
pub const ASSEMBLY_STORAGE_MAP = opaque {};
pub const FLS_CALLBACK_INFO = opaque {};
pub const RTL_BITMAP = opaque {};
pub const KAFFINITY = usize;
pub const KPRIORITY = i32;

pub const CLIENT_ID = extern struct {
    UniqueProcess: HANDLE,
    UniqueThread: HANDLE,
};

pub const THREAD_BASIC_INFORMATION = extern struct {
    ExitStatus: NTSTATUS,
    TebBaseAddress: PVOID,
    ClientId: CLIENT_ID,
    AffinityMask: KAFFINITY,
    Priority: KPRIORITY,
    BasePriority: KPRIORITY,
};

pub const TEB = extern struct {
    Reserved1: [12]PVOID,
    ProcessEnvironmentBlock: *PEB,
    Reserved2: [399]PVOID,
    Reserved3: [1952]u8,
    TlsSlots: [64]PVOID,
    Reserved4: [8]u8,
    Reserved5: [26]PVOID,
    ReservedForOle: PVOID,
    Reserved6: [4]PVOID,
    TlsExpansionSlots: PVOID,
};

pub const EXCEPTION_REGISTRATION_RECORD = extern struct {
    Next: ?*EXCEPTION_REGISTRATION_RECORD,
    Handler: ?*EXCEPTION_DISPOSITION,
};

pub const NT_TIB = extern struct {
    ExceptionList: ?*EXCEPTION_REGISTRATION_RECORD,
    StackBase: PVOID,
    StackLimit: PVOID,
    SubSystemTib: PVOID,
    DUMMYUNIONNAME: extern union { FiberData: PVOID, Version: DWORD },
    ArbitraryUserPointer: PVOID,
    Self: ?*@This(),
};

/// Process Environment Block
/// Microsoft documentation of this is incomplete, the fields here are taken from various resources including:
///  - https://github.com/wine-mirror/wine/blob/1aff1e6a370ee8c0213a0fd4b220d121da8527aa/include/winternl.h#L269
///  - https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb/index.htm
pub const PEB = extern struct {
    // Versions: All
    InheritedAddressSpace: BOOLEAN,

    // Versions: 3.51+
    ReadImageFileExecOptions: BOOLEAN,
    BeingDebugged: BOOLEAN,

    // Versions: 5.2+ (previously was padding)
    BitField: UCHAR,

    // Versions: all
    Mutant: HANDLE,
    ImageBaseAddress: HMODULE,
    Ldr: *PEB_LDR_DATA,
    ProcessParameters: *RTL_USER_PROCESS_PARAMETERS,
    SubSystemData: PVOID,
    ProcessHeap: HANDLE,

    // Versions: 5.1+
    FastPebLock: *RTL_CRITICAL_SECTION,

    // Versions: 5.2+
    AtlThunkSListPtr: PVOID,
    IFEOKey: PVOID,

    // Versions: 6.0+

    /// https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb/crossprocessflags.htm
    CrossProcessFlags: ULONG,

    // Versions: 6.0+
    union1: extern union {
        KernelCallbackTable: PVOID,
        UserSharedInfoPtr: PVOID,
    },

    // Versions: 5.1+
    SystemReserved: ULONG,

    // Versions: 5.1, (not 5.2, not 6.0), 6.1+
    AtlThunkSListPtr32: ULONG,

    // Versions: 6.1+
    ApiSetMap: PVOID,

    // Versions: all
    TlsExpansionCounter: ULONG,
    // note: there is padding here on 64 bit
    TlsBitmap: *RTL_BITMAP,
    TlsBitmapBits: [2]ULONG,
    ReadOnlySharedMemoryBase: PVOID,

    // Versions: 1703+
    SharedData: PVOID,

    // Versions: all
    ReadOnlyStaticServerData: *PVOID,
    AnsiCodePageData: PVOID,
    OemCodePageData: PVOID,
    UnicodeCaseTableData: PVOID,

    // Versions: 3.51+
    NumberOfProcessors: ULONG,
    NtGlobalFlag: ULONG,

    // Versions: all
    CriticalSectionTimeout: LARGE_INTEGER,

    // End of Original PEB size

    // Fields appended in 3.51:
    HeapSegmentReserve: ULONG_PTR,
    HeapSegmentCommit: ULONG_PTR,
    HeapDeCommitTotalFreeThreshold: ULONG_PTR,
    HeapDeCommitFreeBlockThreshold: ULONG_PTR,
    NumberOfHeaps: ULONG,
    MaximumNumberOfHeaps: ULONG,
    ProcessHeaps: *PVOID,

    // Fields appended in 4.0:
    GdiSharedHandleTable: PVOID,
    ProcessStarterHelper: PVOID,
    GdiDCAttributeList: ULONG,
    // note: there is padding here on 64 bit
    LoaderLock: *RTL_CRITICAL_SECTION,
    OSMajorVersion: ULONG,
    OSMinorVersion: ULONG,
    OSBuildNumber: USHORT,
    OSCSDVersion: USHORT,
    OSPlatformId: ULONG,
    ImageSubSystem: ULONG,
    ImageSubSystemMajorVersion: ULONG,
    ImageSubSystemMinorVersion: ULONG,
    // note: there is padding here on 64 bit
    ActiveProcessAffinityMask: KAFFINITY,
    GdiHandleBuffer: [
        switch (@sizeOf(usize)) {
            4 => 0x22,
            8 => 0x3C,
            else => unreachable,
        }
    ]ULONG,

    // Fields appended in 5.0 (Windows 2000):
    PostProcessInitRoutine: PVOID,
    TlsExpansionBitmap: *RTL_BITMAP,
    TlsExpansionBitmapBits: [32]ULONG,
    SessionId: ULONG,
    // note: there is padding here on 64 bit
    // Versions: 5.1+
    AppCompatFlags: ULARGE_INTEGER,
    AppCompatFlagsUser: ULARGE_INTEGER,
    ShimData: PVOID,
    // Versions: 5.0+
    AppCompatInfo: PVOID,
    CSDVersion: UNICODE_STRING,

    // Fields appended in 5.1 (Windows XP):
    ActivationContextData: *const ACTIVATION_CONTEXT_DATA,
    ProcessAssemblyStorageMap: *ASSEMBLY_STORAGE_MAP,
    SystemDefaultActivationData: *const ACTIVATION_CONTEXT_DATA,
    SystemAssemblyStorageMap: *ASSEMBLY_STORAGE_MAP,
    MinimumStackCommit: ULONG_PTR,

    // Fields appended in 5.2 (Windows Server 2003):
    FlsCallback: *FLS_CALLBACK_INFO,
    FlsListHead: LIST_ENTRY,
    FlsBitmap: *RTL_BITMAP,
    FlsBitmapBits: [4]ULONG,
    FlsHighIndex: ULONG,

    // Fields appended in 6.0 (Windows Vista):
    WerRegistrationData: PVOID,
    WerShipAssertPtr: PVOID,

    // Fields appended in 6.1 (Windows 7):
    pUnused: PVOID, // previously pContextData
    pImageHeaderHash: PVOID,

    /// TODO: https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb/tracingflags.htm
    TracingFlags: ULONG,

    // Fields appended in 6.2 (Windows 8):
    CsrServerReadOnlySharedMemoryBase: ULONGLONG,

    // Fields appended in 1511:
    TppWorkerpListLock: ULONG,
    TppWorkerpList: LIST_ENTRY,
    WaitOnAddressHashTable: [0x80]PVOID,

    // Fields appended in 1709:
    TelemetryCoverageHeader: PVOID,
    CloudFileFlags: ULONG,
};

/// The `PEB_LDR_DATA` structure is the main record of what modules are loaded in a process.
/// It is essentially the head of three double-linked lists of `LDR_DATA_TABLE_ENTRY` structures which each represent one loaded module.
///
/// Microsoft documentation of this is incomplete, the fields here are taken from various resources including:
///  - https://www.geoffchappell.com/studies/windows/win32/ntdll/structs/peb_ldr_data.htm
pub const PEB_LDR_DATA = extern struct {
    // Versions: 3.51 and higher
    /// The size in bytes of the structure
    Length: ULONG,

    /// TRUE if the structure is prepared.
    Initialized: BOOLEAN,

    SsHandle: PVOID,
    InLoadOrderModuleList: LIST_ENTRY,
    InMemoryOrderModuleList: LIST_ENTRY,
    InInitializationOrderModuleList: LIST_ENTRY,

    // Versions: 5.1 and higher

    /// No known use of this field is known in Windows 8 and higher.
    EntryInProgress: PVOID,

    // Versions: 6.0 from Windows Vista SP1, and higher
    ShutdownInProgress: BOOLEAN,

    /// Though ShutdownThreadId is declared as a HANDLE,
    /// it is indeed the thread ID as suggested by its name.
    /// It is picked up from the UniqueThread member of the CLIENT_ID in the
    /// TEB of the thread that asks to terminate the process.
    ShutdownThreadId: HANDLE,
};

/// Microsoft documentation of this is incomplete, the fields here are taken from various resources including:
///  - https://docs.microsoft.com/en-us/windows/win32/api/winternl/ns-winternl-peb_ldr_data
///  - https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntldr/ldr_data_table_entry.htm
pub const LDR_DATA_TABLE_ENTRY = extern struct {
    Reserved1: [2]PVOID,
    InMemoryOrderLinks: LIST_ENTRY,
    Reserved2: [2]PVOID,
    DllBase: PVOID,
    EntryPoint: PVOID,
    SizeOfImage: ULONG,
    FullDllName: UNICODE_STRING,
    Reserved4: [8]BYTE,
    Reserved5: [3]PVOID,
    DUMMYUNIONNAME: extern union {
        CheckSum: ULONG,
        Reserved6: PVOID,
    },
    TimeDateStamp: ULONG,
};

pub const RTL_USER_PROCESS_PARAMETERS = extern struct {
    AllocationSize: ULONG,
    Size: ULONG,
    Flags: ULONG,
    DebugFlags: ULONG,
    ConsoleHandle: HANDLE,
    ConsoleFlags: ULONG,
    hStdInput: HANDLE,
    hStdOutput: HANDLE,
    hStdError: HANDLE,
    CurrentDirectory: CURDIR,
    DllPath: UNICODE_STRING,
    ImagePathName: UNICODE_STRING,
    CommandLine: UNICODE_STRING,
    Environment: [*:0]WCHAR,
    dwX: ULONG,
    dwY: ULONG,
    dwXSize: ULONG,
    dwYSize: ULONG,
    dwXCountChars: ULONG,
    dwYCountChars: ULONG,
    dwFillAttribute: ULONG,
    dwFlags: ULONG,
    dwShowWindow: ULONG,
    WindowTitle: UNICODE_STRING,
    Desktop: UNICODE_STRING,
    ShellInfo: UNICODE_STRING,
    RuntimeInfo: UNICODE_STRING,
    DLCurrentDirectory: [0x20]RTL_DRIVE_LETTER_CURDIR,
};

pub const RTL_DRIVE_LETTER_CURDIR = extern struct {
    Flags: c_ushort,
    Length: c_ushort,
    TimeStamp: ULONG,
    DosPath: UNICODE_STRING,
};

pub const PPS_POST_PROCESS_INIT_ROUTINE = ?*const fn () callconv(.C) void;

pub const FILE_DIRECTORY_INFORMATION = extern struct {
    NextEntryOffset: ULONG,
    FileIndex: ULONG,
    CreationTime: LARGE_INTEGER,
    LastAccessTime: LARGE_INTEGER,
    LastWriteTime: LARGE_INTEGER,
    ChangeTime: LARGE_INTEGER,
    EndOfFile: LARGE_INTEGER,
    AllocationSize: LARGE_INTEGER,
    FileAttributes: ULONG,
    FileNameLength: ULONG,
    FileName: [1]WCHAR,
};

pub const FILE_BOTH_DIR_INFORMATION = extern struct {
    NextEntryOffset: ULONG,
    FileIndex: ULONG,
    CreationTime: LARGE_INTEGER,
    LastAccessTime: LARGE_INTEGER,
    LastWriteTime: LARGE_INTEGER,
    ChangeTime: LARGE_INTEGER,
    EndOfFile: LARGE_INTEGER,
    AllocationSize: LARGE_INTEGER,
    FileAttributes: ULONG,
    FileNameLength: ULONG,
    EaSize: ULONG,
    ShortNameLength: CHAR,
    ShortName: [12]WCHAR,
    FileName: [1]WCHAR,
};
pub const FILE_BOTH_DIRECTORY_INFORMATION = FILE_BOTH_DIR_INFORMATION;

/// Helper for iterating a byte buffer of FILE_*_INFORMATION structures (from
/// things like NtQueryDirectoryFile calls).
pub fn FileInformationIterator(comptime FileInformationType: type) type {
    return struct {
        byte_offset: usize = 0,
        buf: []u8 align(@alignOf(FileInformationType)),

        pub fn next(self: *@This()) ?*FileInformationType {
            if (self.byte_offset >= self.buf.len) return null;
            const cur: *FileInformationType = @ptrCast(@alignCast(&self.buf[self.byte_offset]));
            if (cur.NextEntryOffset == 0) {
                self.byte_offset = self.buf.len;
            } else {
                self.byte_offset += cur.NextEntryOffset;
            }
            return cur;
        }
    };
}

pub const IO_APC_ROUTINE = *const fn (PVOID, *IO_STATUS_BLOCK, ULONG) callconv(.C) void;

pub const CURDIR = extern struct {
    DosPath: UNICODE_STRING,
    Handle: HANDLE,
};

pub const DUPLICATE_SAME_ACCESS = 2;

pub const MODULEINFO = extern struct {
    lpBaseOfDll: LPVOID,
    SizeOfImage: DWORD,
    EntryPoint: LPVOID,
};

pub const PSAPI_WS_WATCH_INFORMATION = extern struct {
    FaultingPc: LPVOID,
    FaultingVa: LPVOID,
};

pub const VM_COUNTERS = extern struct {
    PeakVirtualSize: SIZE_T,
    VirtualSize: SIZE_T,
    PageFaultCount: ULONG,
    PeakWorkingSetSize: SIZE_T,
    WorkingSetSize: SIZE_T,
    QuotaPeakPagedPoolUsage: SIZE_T,
    QuotaPagedPoolUsage: SIZE_T,
    QuotaPeakNonPagedPoolUsage: SIZE_T,
    QuotaNonPagedPoolUsage: SIZE_T,
    PagefileUsage: SIZE_T,
    PeakPagefileUsage: SIZE_T,
};

pub const PROCESS_MEMORY_COUNTERS = extern struct {
    cb: DWORD,
    PageFaultCount: DWORD,
    PeakWorkingSetSize: SIZE_T,
    WorkingSetSize: SIZE_T,
    QuotaPeakPagedPoolUsage: SIZE_T,
    QuotaPagedPoolUsage: SIZE_T,
    QuotaPeakNonPagedPoolUsage: SIZE_T,
    QuotaNonPagedPoolUsage: SIZE_T,
    PagefileUsage: SIZE_T,
    PeakPagefileUsage: SIZE_T,
};

pub const PROCESS_MEMORY_COUNTERS_EX = extern struct {
    cb: DWORD,
    PageFaultCount: DWORD,
    PeakWorkingSetSize: SIZE_T,
    WorkingSetSize: SIZE_T,
    QuotaPeakPagedPoolUsage: SIZE_T,
    QuotaPagedPoolUsage: SIZE_T,
    QuotaPeakNonPagedPoolUsage: SIZE_T,
    QuotaNonPagedPoolUsage: SIZE_T,
    PagefileUsage: SIZE_T,
    PeakPagefileUsage: SIZE_T,
    PrivateUsage: SIZE_T,
};

pub const GetProcessMemoryInfoError = error{
    AccessDenied,
    InvalidHandle,
    Unexpected,
};

pub fn GetProcessMemoryInfo(hProcess: HANDLE) GetProcessMemoryInfoError!VM_COUNTERS {
    var vmc: VM_COUNTERS = undefined;
    const rc = ntdll.NtQueryInformationProcess(hProcess, .ProcessVmCounters, &vmc, @sizeOf(VM_COUNTERS), null);
    switch (rc) {
        .SUCCESS => return vmc,
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_HANDLE => return error.InvalidHandle,
        .INVALID_PARAMETER => unreachable,
        else => return unexpectedStatus(rc),
    }
}

pub const PERFORMANCE_INFORMATION = extern struct {
    cb: DWORD,
    CommitTotal: SIZE_T,
    CommitLimit: SIZE_T,
    CommitPeak: SIZE_T,
    PhysicalTotal: SIZE_T,
    PhysicalAvailable: SIZE_T,
    SystemCache: SIZE_T,
    KernelTotal: SIZE_T,
    KernelPaged: SIZE_T,
    KernelNonpaged: SIZE_T,
    PageSize: SIZE_T,
    HandleCount: DWORD,
    ProcessCount: DWORD,
    ThreadCount: DWORD,
};

pub const ENUM_PAGE_FILE_INFORMATION = extern struct {
    cb: DWORD,
    Reserved: DWORD,
    TotalSize: SIZE_T,
    TotalInUse: SIZE_T,
    PeakUsage: SIZE_T,
};

pub const PENUM_PAGE_FILE_CALLBACKW = ?*const fn (?LPVOID, *ENUM_PAGE_FILE_INFORMATION, LPCWSTR) callconv(.C) BOOL;
pub const PENUM_PAGE_FILE_CALLBACKA = ?*const fn (?LPVOID, *ENUM_PAGE_FILE_INFORMATION, LPCSTR) callconv(.C) BOOL;

pub const PSAPI_WS_WATCH_INFORMATION_EX = extern struct {
    BasicInfo: PSAPI_WS_WATCH_INFORMATION,
    FaultingThreadId: ULONG_PTR,
    Flags: ULONG_PTR,
};

pub const OSVERSIONINFOW = extern struct {
    dwOSVersionInfoSize: ULONG,
    dwMajorVersion: ULONG,
    dwMinorVersion: ULONG,
    dwBuildNumber: ULONG,
    dwPlatformId: ULONG,
    szCSDVersion: [128]WCHAR,
};
pub const RTL_OSVERSIONINFOW = OSVERSIONINFOW;

pub const REPARSE_DATA_BUFFER = extern struct {
    ReparseTag: ULONG,
    ReparseDataLength: USHORT,
    Reserved: USHORT,
    DataBuffer: [1]UCHAR,
};
pub const SYMBOLIC_LINK_REPARSE_BUFFER = extern struct {
    SubstituteNameOffset: USHORT,
    SubstituteNameLength: USHORT,
    PrintNameOffset: USHORT,
    PrintNameLength: USHORT,
    Flags: ULONG,
    PathBuffer: [1]WCHAR,
};
pub const MOUNT_POINT_REPARSE_BUFFER = extern struct {
    SubstituteNameOffset: USHORT,
    SubstituteNameLength: USHORT,
    PrintNameOffset: USHORT,
    PrintNameLength: USHORT,
    PathBuffer: [1]WCHAR,
};
pub const MAXIMUM_REPARSE_DATA_BUFFER_SIZE: ULONG = 16 * 1024;
pub const FSCTL_SET_REPARSE_POINT: DWORD = 0x900a4;
pub const FSCTL_GET_REPARSE_POINT: DWORD = 0x900a8;
pub const IO_REPARSE_TAG_SYMLINK: ULONG = 0xa000000c;
pub const IO_REPARSE_TAG_MOUNT_POINT: ULONG = 0xa0000003;
pub const SYMLINK_FLAG_RELATIVE: ULONG = 0x1;

pub const SYMBOLIC_LINK_FLAG_DIRECTORY: DWORD = 0x1;
pub const SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE: DWORD = 0x2;

pub const MOUNTMGR_MOUNT_POINT = extern struct {
    SymbolicLinkNameOffset: ULONG,
    SymbolicLinkNameLength: USHORT,
    Reserved1: USHORT,
    UniqueIdOffset: ULONG,
    UniqueIdLength: USHORT,
    Reserved2: USHORT,
    DeviceNameOffset: ULONG,
    DeviceNameLength: USHORT,
    Reserved3: USHORT,
};
pub const MOUNTMGR_MOUNT_POINTS = extern struct {
    Size: ULONG,
    NumberOfMountPoints: ULONG,
    MountPoints: [1]MOUNTMGR_MOUNT_POINT,
};
pub const IOCTL_MOUNTMGR_QUERY_POINTS: ULONG = 0x6d0008;

pub const OBJECT_INFORMATION_CLASS = enum(c_int) {
    ObjectBasicInformation = 0,
    ObjectNameInformation = 1,
    ObjectTypeInformation = 2,
    ObjectTypesInformation = 3,
    ObjectHandleFlagInformation = 4,
    ObjectSessionInformation = 5,
    MaxObjectInfoClass,
};

pub const OBJECT_NAME_INFORMATION = extern struct {
    Name: UNICODE_STRING,
};

pub const SRWLOCK_INIT = SRWLOCK{};
pub const SRWLOCK = extern struct {
    Ptr: ?PVOID = null,
};

pub const CONDITION_VARIABLE_INIT = CONDITION_VARIABLE{};
pub const CONDITION_VARIABLE = extern struct {
    Ptr: ?PVOID = null,
};

pub const FILE_SKIP_COMPLETION_PORT_ON_SUCCESS = 0x1;
pub const FILE_SKIP_SET_EVENT_ON_HANDLE = 0x2;

pub const CTRL_C_EVENT: DWORD = 0;
pub const CTRL_BREAK_EVENT: DWORD = 1;
pub const CTRL_CLOSE_EVENT: DWORD = 2;
pub const CTRL_LOGOFF_EVENT: DWORD = 5;
pub const CTRL_SHUTDOWN_EVENT: DWORD = 6;

pub const HANDLER_ROUTINE = *const fn (dwCtrlType: DWORD) callconv(WINAPI) BOOL;

/// Processor feature enumeration.
pub const PF = enum(DWORD) {
    /// On a Pentium, a floating-point precision error can occur in rare circumstances.
    FLOATING_POINT_PRECISION_ERRATA = 0,

    /// Floating-point operations are emulated using software emulator.
    /// This function returns a nonzero value if floating-point operations are emulated; otherwise, it returns zero.
    FLOATING_POINT_EMULATED = 1,

    /// The atomic compare and exchange operation (cmpxchg) is available.
    COMPARE_EXCHANGE_DOUBLE = 2,

    /// The MMX instruction set is available.
    MMX_INSTRUCTIONS_AVAILABLE = 3,

    PPC_MOVEMEM_64BIT_OK = 4,
    ALPHA_BYTE_INSTRUCTIONS = 5,

    /// The SSE instruction set is available.
    XMMI_INSTRUCTIONS_AVAILABLE = 6,

    /// The 3D-Now instruction is available.
    @"3DNOW_INSTRUCTIONS_AVAILABLE" = 7,

    /// The RDTSC instruction is available.
    RDTSC_INSTRUCTION_AVAILABLE = 8,

    /// The processor is PAE-enabled.
    PAE_ENABLED = 9,

    /// The SSE2 instruction set is available.
    XMMI64_INSTRUCTIONS_AVAILABLE = 10,

    SSE_DAZ_MODE_AVAILABLE = 11,

    /// Data execution prevention is enabled.
    NX_ENABLED = 12,

    /// The SSE3 instruction set is available.
    SSE3_INSTRUCTIONS_AVAILABLE = 13,

    /// The atomic compare and exchange 128-bit operation (cmpxchg16b) is available.
    COMPARE_EXCHANGE128 = 14,

    /// The atomic compare 64 and exchange 128-bit operation (cmp8xchg16) is available.
    COMPARE64_EXCHANGE128 = 15,

    /// The processor channels are enabled.
    CHANNELS_ENABLED = 16,

    /// The processor implements the XSAVI and XRSTOR instructions.
    XSAVE_ENABLED = 17,

    /// The VFP/Neon: 32 x 64bit register bank is present.
    /// This flag has the same meaning as PF_ARM_VFP_EXTENDED_REGISTERS.
    ARM_VFP_32_REGISTERS_AVAILABLE = 18,

    /// This ARM processor implements the ARM v8 NEON instruction set.
    ARM_NEON_INSTRUCTIONS_AVAILABLE = 19,

    /// Second Level Address Translation is supported by the hardware.
    SECOND_LEVEL_ADDRESS_TRANSLATION = 20,

    /// Virtualization is enabled in the firmware and made available by the operating system.
    VIRT_FIRMWARE_ENABLED = 21,

    /// RDFSBASE, RDGSBASE, WRFSBASE, and WRGSBASE instructions are available.
    RDWRFSGBASE_AVAILABLE = 22,

    /// _fastfail() is available.
    FASTFAIL_AVAILABLE = 23,

    /// The divide instruction_available.
    ARM_DIVIDE_INSTRUCTION_AVAILABLE = 24,

    /// The 64-bit load/store atomic instructions are available.
    ARM_64BIT_LOADSTORE_ATOMIC = 25,

    /// The external cache is available.
    ARM_EXTERNAL_CACHE_AVAILABLE = 26,

    /// The floating-point multiply-accumulate instruction is available.
    ARM_FMAC_INSTRUCTIONS_AVAILABLE = 27,

    RDRAND_INSTRUCTION_AVAILABLE = 28,

    /// This ARM processor implements the ARM v8 instructions set.
    ARM_V8_INSTRUCTIONS_AVAILABLE = 29,

    /// This ARM processor implements the ARM v8 extra cryptographic instructions (i.e., AES, SHA1 and SHA2).
    ARM_V8_CRYPTO_INSTRUCTIONS_AVAILABLE = 30,

    /// This ARM processor implements the ARM v8 extra CRC32 instructions.
    ARM_V8_CRC32_INSTRUCTIONS_AVAILABLE = 31,

    RDTSCP_INSTRUCTION_AVAILABLE = 32,
    RDPID_INSTRUCTION_AVAILABLE = 33,

    /// This ARM processor implements the ARM v8.1 atomic instructions (e.g., CAS, SWP).
    ARM_V81_ATOMIC_INSTRUCTIONS_AVAILABLE = 34,

    MONITORX_INSTRUCTION_AVAILABLE = 35,

    /// The SSSE3 instruction set is available.
    SSSE3_INSTRUCTIONS_AVAILABLE = 36,

    /// The SSE4_1 instruction set is available.
    SSE4_1_INSTRUCTIONS_AVAILABLE = 37,

    /// The SSE4_2 instruction set is available.
    SSE4_2_INSTRUCTIONS_AVAILABLE = 38,

    /// The AVX instruction set is available.
    AVX_INSTRUCTIONS_AVAILABLE = 39,

    /// The AVX2 instruction set is available.
    AVX2_INSTRUCTIONS_AVAILABLE = 40,

    /// The AVX512F instruction set is available.
    AVX512F_INSTRUCTIONS_AVAILABLE = 41,

    ERMS_AVAILABLE = 42,

    /// This ARM processor implements the ARM v8.2 Dot Product (DP) instructions.
    ARM_V82_DP_INSTRUCTIONS_AVAILABLE = 43,

    /// This ARM processor implements the ARM v8.3 JavaScript conversion (JSCVT) instructions.
    ARM_V83_JSCVT_INSTRUCTIONS_AVAILABLE = 44,
};

pub const MAX_WOW64_SHARED_ENTRIES = 16;
pub const PROCESSOR_FEATURE_MAX = 64;
pub const MAXIMUM_XSTATE_FEATURES = 64;

pub const KSYSTEM_TIME = extern struct {
    LowPart: ULONG,
    High1Time: LONG,
    High2Time: LONG,
};

pub const NT_PRODUCT_TYPE = enum(INT) {
    NtProductWinNt = 1,
    NtProductLanManNt,
    NtProductServer,
};

pub const ALTERNATIVE_ARCHITECTURE_TYPE = enum(INT) {
    StandardDesign,
    NEC98x86,
    EndAlternatives,
};

pub const XSTATE_FEATURE = extern struct {
    Offset: ULONG,
    Size: ULONG,
};

pub const XSTATE_CONFIGURATION = extern struct {
    EnabledFeatures: ULONG64,
    Size: ULONG,
    OptimizedSave: ULONG,
    Features: [MAXIMUM_XSTATE_FEATURES]XSTATE_FEATURE,
};

/// Shared Kernel User Data
pub const KUSER_SHARED_DATA = extern struct {
    TickCountLowDeprecated: ULONG,
    TickCountMultiplier: ULONG,
    InterruptTime: KSYSTEM_TIME,
    SystemTime: KSYSTEM_TIME,
    TimeZoneBias: KSYSTEM_TIME,
    ImageNumberLow: USHORT,
    ImageNumberHigh: USHORT,
    NtSystemRoot: [260]WCHAR,
    MaxStackTraceDepth: ULONG,
    CryptoExponent: ULONG,
    TimeZoneId: ULONG,
    LargePageMinimum: ULONG,
    AitSamplingValue: ULONG,
    AppCompatFlag: ULONG,
    RNGSeedVersion: ULONGLONG,
    GlobalValidationRunlevel: ULONG,
    TimeZoneBiasStamp: LONG,
    NtBuildNumber: ULONG,
    NtProductType: NT_PRODUCT_TYPE,
    ProductTypeIsValid: BOOLEAN,
    Reserved0: [1]BOOLEAN,
    NativeProcessorArchitecture: USHORT,
    NtMajorVersion: ULONG,
    NtMinorVersion: ULONG,
    ProcessorFeatures: [PROCESSOR_FEATURE_MAX]BOOLEAN,
    Reserved1: ULONG,
    Reserved3: ULONG,
    TimeSlip: ULONG,
    AlternativeArchitecture: ALTERNATIVE_ARCHITECTURE_TYPE,
    BootId: ULONG,
    SystemExpirationDate: LARGE_INTEGER,
    SuiteMaskY: ULONG,
    KdDebuggerEnabled: BOOLEAN,
    DummyUnion1: extern union {
        MitigationPolicies: UCHAR,
        Alt: packed struct {
            NXSupportPolicy: u2,
            SEHValidationPolicy: u2,
            CurDirDevicesSkippedForDlls: u2,
            Reserved: u2,
        },
    },
    CyclesPerYield: USHORT,
    ActiveConsoleId: ULONG,
    DismountCount: ULONG,
    ComPlusPackage: ULONG,
    LastSystemRITEventTickCount: ULONG,
    NumberOfPhysicalPages: ULONG,
    SafeBootMode: BOOLEAN,
    DummyUnion2: extern union {
        VirtualizationFlags: UCHAR,
        Alt: packed struct {
            ArchStartedInEl2: u1,
            QcSlIsSupported: u1,
            SpareBits: u6,
        },
    },
    Reserved12: [2]UCHAR,
    DummyUnion3: extern union {
        SharedDataFlags: ULONG,
        Alt: packed struct {
            DbgErrorPortPresent: u1,
            DbgElevationEnabled: u1,
            DbgVirtEnabled: u1,
            DbgInstallerDetectEnabled: u1,
            DbgLkgEnabled: u1,
            DbgDynProcessorEnabled: u1,
            DbgConsoleBrokerEnabled: u1,
            DbgSecureBootEnabled: u1,
            DbgMultiSessionSku: u1,
            DbgMultiUsersInSessionSku: u1,
            DbgStateSeparationEnabled: u1,
            SpareBits: u21,
        },
    },
    DataFlagsPad: [1]ULONG,
    TestRetInstruction: ULONGLONG,
    QpcFrequency: LONGLONG,
    SystemCall: ULONG,
    Reserved2: ULONG,
    SystemCallPad: [2]ULONGLONG,
    DummyUnion4: extern union {
        TickCount: KSYSTEM_TIME,
        TickCountQuad: ULONG64,
        Alt: extern struct {
            ReservedTickCountOverlay: [3]ULONG,
            TickCountPad: [1]ULONG,
        },
    },
    Cookie: ULONG,
    CookiePad: [1]ULONG,
    ConsoleSessionForegroundProcessId: LONGLONG,
    TimeUpdateLock: ULONGLONG,
    BaselineSystemTimeQpc: ULONGLONG,
    BaselineInterruptTimeQpc: ULONGLONG,
    QpcSystemTimeIncrement: ULONGLONG,
    QpcInterruptTimeIncrement: ULONGLONG,
    QpcSystemTimeIncrementShift: UCHAR,
    QpcInterruptTimeIncrementShift: UCHAR,
    UnparkedProcessorCount: USHORT,
    EnclaveFeatureMask: [4]ULONG,
    TelemetryCoverageRound: ULONG,
    UserModeGlobalLogger: [16]USHORT,
    ImageFileExecutionOptions: ULONG,
    LangGenerationCount: ULONG,
    Reserved4: ULONGLONG,
    InterruptTimeBias: ULONGLONG,
    QpcBias: ULONGLONG,
    ActiveProcessorCount: ULONG,
    ActiveGroupCount: UCHAR,
    Reserved9: UCHAR,
    DummyUnion5: extern union {
        QpcData: USHORT,
        Alt: extern struct {
            QpcBypassEnabled: UCHAR,
            QpcShift: UCHAR,
        },
    },
    TimeZoneBiasEffectiveStart: LARGE_INTEGER,
    TimeZoneBiasEffectiveEnd: LARGE_INTEGER,
    XState: XSTATE_CONFIGURATION,
    FeatureConfigurationChangeStamp: KSYSTEM_TIME,
    Spare: ULONG,
    UserPointerAuthMask: ULONG64,
};

/// Read-only user-mode address for the shared data.
/// https://www.geoffchappell.com/studies/windows/km/ntoskrnl/inc/api/ntexapi_x/kuser_shared_data/index.htm
/// https://msrc-blog.microsoft.com/2022/04/05/randomizing-the-kuser_shared_data-structure-on-windows/
pub const SharedUserData: *const KUSER_SHARED_DATA = @as(*const KUSER_SHARED_DATA, @ptrFromInt(0x7FFE0000));

pub fn IsProcessorFeaturePresent(feature: PF) bool {
    if (@intFromEnum(feature) >= PROCESSOR_FEATURE_MAX) return false;
    return SharedUserData.ProcessorFeatures[@intFromEnum(feature)] == 1;
}

pub const TH32CS_SNAPHEAPLIST = 0x00000001;
pub const TH32CS_SNAPPROCESS = 0x00000002;
pub const TH32CS_SNAPTHREAD = 0x00000004;
pub const TH32CS_SNAPMODULE = 0x00000008;
pub const TH32CS_SNAPMODULE32 = 0x00000010;
pub const TH32CS_SNAPALL = TH32CS_SNAPHEAPLIST | TH32CS_SNAPPROCESS | TH32CS_SNAPTHREAD | TH32CS_SNAPMODULE;
pub const TH32CS_INHERIT = 0x80000000;

pub const MAX_MODULE_NAME32 = 255;
pub const MODULEENTRY32 = extern struct {
    dwSize: DWORD,
    th32ModuleID: DWORD,
    th32ProcessID: DWORD,
    GlblcntUsage: DWORD,
    ProccntUsage: DWORD,
    modBaseAddr: *BYTE,
    modBaseSize: DWORD,
    hModule: HMODULE,
    szModule: [MAX_MODULE_NAME32 + 1]CHAR,
    szExePath: [MAX_PATH]CHAR,
};

pub const SYSTEM_INFORMATION_CLASS = enum(c_int) {
    SystemBasicInformation = 0,
    SystemPerformanceInformation = 2,
    SystemTimeOfDayInformation = 3,
    SystemProcessInformation = 5,
    SystemProcessorPerformanceInformation = 8,
    SystemInterruptInformation = 23,
    SystemExceptionInformation = 33,
    SystemRegistryQuotaInformation = 37,
    SystemLookasideInformation = 45,
    SystemCodeIntegrityInformation = 103,
    SystemPolicyInformation = 134,
};

pub const SYSTEM_BASIC_INFORMATION = extern struct {
    Reserved: ULONG,
    TimerResolution: ULONG,
    PageSize: ULONG,
    NumberOfPhysicalPages: ULONG,
    LowestPhysicalPageNumber: ULONG,
    HighestPhysicalPageNumber: ULONG,
    AllocationGranularity: ULONG,
    MinimumUserModeAddress: ULONG_PTR,
    MaximumUserModeAddress: ULONG_PTR,
    ActiveProcessorsAffinityMask: KAFFINITY,
    NumberOfProcessors: UCHAR,
};

pub const THREADINFOCLASS = enum(c_int) {
    ThreadBasicInformation,
    ThreadTimes,
    ThreadPriority,
    ThreadBasePriority,
    ThreadAffinityMask,
    ThreadImpersonationToken,
    ThreadDescriptorTableEntry,
    ThreadEnableAlignmentFaultFixup,
    ThreadEventPair_Reusable,
    ThreadQuerySetWin32StartAddress,
    ThreadZeroTlsCell,
    ThreadPerformanceCount,
    ThreadAmILastThread,
    ThreadIdealProcessor,
    ThreadPriorityBoost,
    ThreadSetTlsArrayAddress,
    ThreadIsIoPending,
    // Windows 2000+ from here
    ThreadHideFromDebugger,
    // Windows XP+ from here
    ThreadBreakOnTermination,
    ThreadSwitchLegacyState,
    ThreadIsTerminated,
    // Windows Vista+ from here
    ThreadLastSystemCall,
    ThreadIoPriority,
    ThreadCycleTime,
    ThreadPagePriority,
    ThreadActualBasePriority,
    ThreadTebInformation,
    ThreadCSwitchMon,
    // Windows 7+ from here
    ThreadCSwitchPmu,
    ThreadWow64Context,
    ThreadGroupInformation,
    ThreadUmsInformation,
    ThreadCounterProfiling,
    ThreadIdealProcessorEx,
    // Windows 8+ from here
    ThreadCpuAccountingInformation,
    // Windows 8.1+ from here
    ThreadSuspendCount,
    // Windows 10+ from here
    ThreadHeterogeneousCpuPolicy,
    ThreadContainerId,
    ThreadNameInformation,
    ThreadSelectedCpuSets,
    ThreadSystemThreadInformation,
    ThreadActualGroupAffinity,
};

pub const PROCESSINFOCLASS = enum(c_int) {
    ProcessBasicInformation,
    ProcessQuotaLimits,
    ProcessIoCounters,
    ProcessVmCounters,
    ProcessTimes,
    ProcessBasePriority,
    ProcessRaisePriority,
    ProcessDebugPort,
    ProcessExceptionPort,
    ProcessAccessToken,
    ProcessLdtInformation,
    ProcessLdtSize,
    ProcessDefaultHardErrorMode,
    ProcessIoPortHandlers,
    ProcessPooledUsageAndLimits,
    ProcessWorkingSetWatch,
    ProcessUserModeIOPL,
    ProcessEnableAlignmentFaultFixup,
    ProcessPriorityClass,
    ProcessWx86Information,
    ProcessHandleCount,
    ProcessAffinityMask,
    ProcessPriorityBoost,
    ProcessDeviceMap,
    ProcessSessionInformation,
    ProcessForegroundInformation,
    ProcessWow64Information,
    ProcessImageFileName,
    ProcessLUIDDeviceMapsEnabled,
    ProcessBreakOnTermination,
    ProcessDebugObjectHandle,
    ProcessDebugFlags,
    ProcessHandleTracing,
    ProcessIoPriority,
    ProcessExecuteFlags,
    ProcessTlsInformation,
    ProcessCookie,
    ProcessImageInformation,
    ProcessCycleTime,
    ProcessPagePriority,
    ProcessInstrumentationCallback,
    ProcessThreadStackAllocation,
    ProcessWorkingSetWatchEx,
    ProcessImageFileNameWin32,
    ProcessImageFileMapping,
    ProcessAffinityUpdateMode,
    ProcessMemoryAllocationMode,
    ProcessGroupInformation,
    ProcessTokenVirtualizationEnabled,
    ProcessConsoleHostProcess,
    ProcessWindowInformation,
    MaxProcessInfoClass,
};

pub const PROCESS_BASIC_INFORMATION = extern struct {
    ExitStatus: NTSTATUS,
    PebBaseAddress: *PEB,
    AffinityMask: ULONG_PTR,
    BasePriority: KPRIORITY,
    UniqueProcessId: ULONG_PTR,
    InheritedFromUniqueProcessId: ULONG_PTR,
};

pub const ReadMemoryError = error{
    Unexpected,
};

pub fn ReadProcessMemory(handle: HANDLE, addr: ?LPVOID, buffer: []u8) ReadMemoryError![]u8 {
    var nread: usize = 0;
    switch (ntdll.NtReadVirtualMemory(
        handle,
        addr,
        buffer.ptr,
        buffer.len,
        &nread,
    )) {
        .SUCCESS => return buffer[0..nread],
        // TODO: map errors
        else => |rc| return unexpectedStatus(rc),
    }
}

pub const WriteMemoryError = error{
    Unexpected,
};

pub fn WriteProcessMemory(handle: HANDLE, addr: ?LPVOID, buffer: []const u8) WriteMemoryError!usize {
    var nwritten: usize = 0;
    switch (ntdll.NtWriteVirtualMemory(
        handle,
        addr,
        @as(*const anyopaque, @ptrCast(buffer.ptr)),
        buffer.len,
        &nwritten,
    )) {
        .SUCCESS => return nwritten,
        // TODO: map errors
        else => |rc| return unexpectedStatus(rc),
    }
}

pub const ProcessBaseAddressError = GetProcessMemoryInfoError || ReadMemoryError;

/// Returns the base address of the process loaded into memory.
pub fn ProcessBaseAddress(handle: HANDLE) ProcessBaseAddressError!HMODULE {
    var info: PROCESS_BASIC_INFORMATION = undefined;
    var nread: DWORD = 0;
    const rc = ntdll.NtQueryInformationProcess(
        handle,
        .ProcessBasicInformation,
        &info,
        @sizeOf(PROCESS_BASIC_INFORMATION),
        &nread,
    );
    switch (rc) {
        .SUCCESS => {},
        .ACCESS_DENIED => return error.AccessDenied,
        .INVALID_HANDLE => return error.InvalidHandle,
        .INVALID_PARAMETER => unreachable,
        else => return unexpectedStatus(rc),
    }

    var peb_buf: [@sizeOf(PEB)]u8 align(@alignOf(PEB)) = undefined;
    const peb_out = try ReadProcessMemory(handle, info.PebBaseAddress, &peb_buf);
    const ppeb: *const PEB = @ptrCast(@alignCast(peb_out.ptr));
    return ppeb.ImageBaseAddress;
}
