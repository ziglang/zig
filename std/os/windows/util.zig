const std = @import("../../index.zig");
const builtin = @import("builtin");
const os = std.os;
const unicode = std.unicode;
const windows = std.os.windows;
const assert = std.debug.assert;
const mem = std.mem;
const BufMap = std.BufMap;
const cstr = std.cstr;

// > The maximum path of 32,767 characters is approximate, because the "\\?\"
// > prefix may be expanded to a longer string by the system at run time, and
// > this expansion applies to the total length.
// from https://docs.microsoft.com/en-us/windows/desktop/FileIO/naming-a-file#maximum-path-length-limitation
pub const PATH_MAX_WIDE = 32767;

pub const WaitError = error.{
    WaitAbandoned,
    WaitTimeOut,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub fn windowsWaitSingle(handle: windows.HANDLE, milliseconds: windows.DWORD) WaitError!void {
    const result = windows.WaitForSingleObject(handle, milliseconds);
    return switch (result) {
        windows.WAIT_ABANDONED => error.WaitAbandoned,
        windows.WAIT_OBJECT_0 => {},
        windows.WAIT_TIMEOUT => error.WaitTimeOut,
        windows.WAIT_FAILED => x: {
            const err = windows.GetLastError();
            break :x switch (err) {
                else => os.unexpectedErrorWindows(err),
            };
        },
        else => error.Unexpected,
    };
}

pub fn windowsClose(handle: windows.HANDLE) void {
    assert(windows.CloseHandle(handle) != 0);
}

pub const ReadError = error.{
    OperationAborted,
    BrokenPipe,
    Unexpected,
};

pub const WriteError = error.{
    SystemResources,
    OperationAborted,
    BrokenPipe,

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub fn windowsWrite(handle: windows.HANDLE, bytes: []const u8) WriteError!void {
    var bytes_written: windows.DWORD = undefined;
    if (windows.WriteFile(handle, bytes.ptr, @intCast(u32, bytes.len), &bytes_written, null) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.INVALID_USER_BUFFER => WriteError.SystemResources,
            windows.ERROR.NOT_ENOUGH_MEMORY => WriteError.SystemResources,
            windows.ERROR.OPERATION_ABORTED => WriteError.OperationAborted,
            windows.ERROR.NOT_ENOUGH_QUOTA => WriteError.SystemResources,
            windows.ERROR.IO_PENDING => unreachable,
            windows.ERROR.BROKEN_PIPE => WriteError.BrokenPipe,
            else => os.unexpectedErrorWindows(err),
        };
    }
}

pub fn windowsIsTty(handle: windows.HANDLE) bool {
    if (windowsIsCygwinPty(handle))
        return true;

    var out: windows.DWORD = undefined;
    return windows.GetConsoleMode(handle, &out) != 0;
}

pub fn windowsIsCygwinPty(handle: windows.HANDLE) bool {
    const size = @sizeOf(windows.FILE_NAME_INFO);
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = []u8.{0} ** (size + windows.MAX_PATH);

    if (windows.GetFileInformationByHandleEx(
        handle,
        windows.FileNameInfo,
        @ptrCast(*c_void, &name_info_bytes[0]),
        @intCast(u32, name_info_bytes.len),
    ) == 0) {
        return false;
    }

    const name_info = @ptrCast(*const windows.FILE_NAME_INFO, &name_info_bytes[0]);
    const name_bytes = name_info_bytes[size .. size + usize(name_info.FileNameLength)];
    const name_wide = @bytesToSlice(u16, name_bytes);
    return mem.indexOf(u16, name_wide, []u16.{ 'm', 's', 'y', 's', '-' }) != null or
        mem.indexOf(u16, name_wide, []u16.{ '-', 'p', 't', 'y' }) != null;
}

pub const OpenError = error.{
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

    /// See https://github.com/ziglang/zig/issues/1396
    Unexpected,
};

pub fn windowsOpenW(
    file_path_w: [*]const u16,
    desired_access: windows.DWORD,
    share_mode: windows.DWORD,
    creation_disposition: windows.DWORD,
    flags_and_attrs: windows.DWORD,
) OpenError!windows.HANDLE {
    const result = windows.CreateFileW(file_path_w, desired_access, share_mode, null, creation_disposition, flags_and_attrs, null);

    if (result == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.SHARING_VIOLATION => return OpenError.SharingViolation,
            windows.ERROR.ALREADY_EXISTS => return OpenError.PathAlreadyExists,
            windows.ERROR.FILE_EXISTS => return OpenError.PathAlreadyExists,
            windows.ERROR.FILE_NOT_FOUND => return OpenError.FileNotFound,
            windows.ERROR.PATH_NOT_FOUND => return OpenError.FileNotFound,
            windows.ERROR.ACCESS_DENIED => return OpenError.AccessDenied,
            windows.ERROR.PIPE_BUSY => return OpenError.PipeBusy,
            else => return os.unexpectedErrorWindows(err),
        }
    }

    return result;
}

pub fn windowsOpen(
    file_path: []const u8,
    desired_access: windows.DWORD,
    share_mode: windows.DWORD,
    creation_disposition: windows.DWORD,
    flags_and_attrs: windows.DWORD,
) OpenError!windows.HANDLE {
    const file_path_w = try sliceToPrefixedFileW(file_path);
    return windowsOpenW(&file_path_w, desired_access, share_mode, creation_disposition, flags_and_attrs);
}

/// Caller must free result.
pub fn createWindowsEnvBlock(allocator: *mem.Allocator, env_map: *const BufMap) ![]u16 {
    // count bytes needed
    const max_chars_needed = x: {
        var max_chars_needed: usize = 1; // 1 for the final null byte
        var it = env_map.iterator();
        while (it.next()) |pair| {
            // +1 for '='
            // +1 for null byte
            max_chars_needed += pair.key.len + pair.value.len + 2;
        }
        break :x max_chars_needed;
    };
    const result = try allocator.alloc(u16, max_chars_needed);
    errdefer allocator.free(result);

    var it = env_map.iterator();
    var i: usize = 0;
    while (it.next()) |pair| {
        i += try unicode.utf8ToUtf16Le(result[i..], pair.key);
        result[i] = '=';
        i += 1;
        i += try unicode.utf8ToUtf16Le(result[i..], pair.value);
        result[i] = 0;
        i += 1;
    }
    result[i] = 0;
    i += 1;
    return allocator.shrink(u16, result, i);
}

pub fn windowsFindFirstFile(
    dir_path: []const u8,
    find_file_data: *windows.WIN32_FIND_DATAW,
) !windows.HANDLE {
    const dir_path_w = try sliceToPrefixedSuffixedFileW(dir_path, []u16.{ '\\', '*', 0 });
    const handle = windows.FindFirstFileW(&dir_path_w, find_file_data);

    if (handle == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.FILE_NOT_FOUND => return error.FileNotFound,
            windows.ERROR.PATH_NOT_FOUND => return error.FileNotFound,
            else => return os.unexpectedErrorWindows(err),
        }
    }

    return handle;
}

/// Returns `true` if there was another file, `false` otherwise.
pub fn windowsFindNextFile(handle: windows.HANDLE, find_file_data: *windows.WIN32_FIND_DATAW) !bool {
    if (windows.FindNextFileW(handle, find_file_data) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.NO_MORE_FILES => false,
            else => os.unexpectedErrorWindows(err),
        };
    }
    return true;
}

pub const WindowsCreateIoCompletionPortError = error.{Unexpected};

pub fn windowsCreateIoCompletionPort(file_handle: windows.HANDLE, existing_completion_port: ?windows.HANDLE, completion_key: usize, concurrent_thread_count: windows.DWORD) !windows.HANDLE {
    const handle = windows.CreateIoCompletionPort(file_handle, existing_completion_port, completion_key, concurrent_thread_count) orelse {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.INVALID_PARAMETER => unreachable,
            else => return os.unexpectedErrorWindows(err),
        }
    };
    return handle;
}

pub const WindowsPostQueuedCompletionStatusError = error.{Unexpected};

pub fn windowsPostQueuedCompletionStatus(completion_port: windows.HANDLE, bytes_transferred_count: windows.DWORD, completion_key: usize, lpOverlapped: ?*windows.OVERLAPPED) WindowsPostQueuedCompletionStatusError!void {
    if (windows.PostQueuedCompletionStatus(completion_port, bytes_transferred_count, completion_key, lpOverlapped) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return os.unexpectedErrorWindows(err),
        }
    }
}

pub const WindowsWaitResult = enum.{
    Normal,
    Aborted,
    Cancelled,
    EOF,
};

pub fn windowsGetQueuedCompletionStatus(completion_port: windows.HANDLE, bytes_transferred_count: *windows.DWORD, lpCompletionKey: *usize, lpOverlapped: *?*windows.OVERLAPPED, dwMilliseconds: windows.DWORD) WindowsWaitResult {
    if (windows.GetQueuedCompletionStatus(completion_port, bytes_transferred_count, lpCompletionKey, lpOverlapped, dwMilliseconds) == windows.FALSE) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.ABANDONED_WAIT_0 => return WindowsWaitResult.Aborted,
            windows.ERROR.OPERATION_ABORTED => return WindowsWaitResult.Cancelled,
            windows.ERROR.HANDLE_EOF => return WindowsWaitResult.EOF,
            else => {
                if (std.debug.runtime_safety) {
                    std.debug.panic("unexpected error: {}\n", err);
                }
            },
        }
    }
    return WindowsWaitResult.Normal;
}

pub fn cStrToPrefixedFileW(s: [*]const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedFileW(mem.toSliceConst(u8, s));
}

pub fn sliceToPrefixedFileW(s: []const u8) ![PATH_MAX_WIDE + 1]u16 {
    return sliceToPrefixedSuffixedFileW(s, []u16.{0});
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
        const prefix = []u16.{ '\\', '\\', '?', '\\' };
        mem.copy(u16, result[0..], prefix);
        break :blk prefix.len;
    };
    const end_index = start_index + try std.unicode.utf8ToUtf16Le(result[start_index..], s);
    assert(end_index <= result.len);
    if (end_index + suffix.len > result.len) return error.NameTooLong;
    mem.copy(u16, result[end_index..], suffix);
    return result;
}
