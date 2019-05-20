const std = @import("../../std.zig");
const builtin = @import("builtin");
const os = std.os;
const unicode = std.unicode;
const windows = std.os.windows;
const assert = std.debug.assert;
const mem = std.mem;
const BufMap = std.BufMap;
const cstr = std.cstr;

pub const WaitError = error{
    WaitAbandoned,
    WaitTimeOut,
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

/// Caller must free result.
pub fn createWindowsEnvBlock(allocator: *mem.Allocator, env_map: *const BufMap) ![]u16 {
    // count bytes needed
    const max_chars_needed = x: {
        var max_chars_needed: usize = 4; // 4 for the final 4 null bytes
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
    result[i] = 0;
    i += 1;
    result[i] = 0;
    i += 1;
    result[i] = 0;
    i += 1;
    return allocator.shrink(result, i);
}

pub fn windowsFindFirstFile(
    dir_path: []const u8,
    find_file_data: *windows.WIN32_FIND_DATAW,
) !windows.HANDLE {
    const dir_path_w = try sliceToPrefixedSuffixedFileW(dir_path, []u16{ '\\', '*', 0 });
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

pub const WindowsCreateIoCompletionPortError = error{Unexpected};

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

pub const WindowsPostQueuedCompletionStatusError = error{Unexpected};

pub fn windowsPostQueuedCompletionStatus(completion_port: windows.HANDLE, bytes_transferred_count: windows.DWORD, completion_key: usize, lpOverlapped: ?*windows.OVERLAPPED) WindowsPostQueuedCompletionStatusError!void {
    if (windows.PostQueuedCompletionStatus(completion_port, bytes_transferred_count, completion_key, lpOverlapped) == 0) {
        const err = windows.GetLastError();
        switch (err) {
            else => return os.unexpectedErrorWindows(err),
        }
    }
}

pub const WindowsWaitResult = enum {
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
