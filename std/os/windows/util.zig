const std = @import("../../index.zig");
const builtin = @import("builtin");
const os = std.os;
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

pub fn windowsClose(handle: windows.HANDLE) void {
    assert(windows.CloseHandle(handle) != 0);
}

pub const WriteError = error{
    SystemResources,
    OperationAborted,
    IoPending,
    BrokenPipe,
    Unexpected,
};

pub fn windowsWrite(handle: windows.HANDLE, bytes: []const u8) WriteError!void {
    if (windows.WriteFile(handle, @ptrCast(*const c_void, bytes.ptr), @intCast(u32, bytes.len), null, null) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.INVALID_USER_BUFFER => WriteError.SystemResources,
            windows.ERROR.NOT_ENOUGH_MEMORY => WriteError.SystemResources,
            windows.ERROR.OPERATION_ABORTED => WriteError.OperationAborted,
            windows.ERROR.NOT_ENOUGH_QUOTA => WriteError.SystemResources,
            windows.ERROR.IO_PENDING => WriteError.IoPending,
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
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = []u8{0} ** (size + windows.MAX_PATH);

    if (windows.GetFileInformationByHandleEx(
        handle,
        windows.FileNameInfo,
        @ptrCast(*c_void, &name_info_bytes[0]),
        @intCast(u32, name_info_bytes.len),
    ) == 0) {
        return true;
    }

    const name_info = @ptrCast(*const windows.FILE_NAME_INFO, &name_info_bytes[0]);
    const name_bytes = name_info_bytes[size .. size + usize(name_info.FileNameLength)];
    const name_wide = @bytesToSlice(u16, name_bytes);
    return mem.indexOf(u16, name_wide, []u16{ 'm', 's', 'y', 's', '-' }) != null or
        mem.indexOf(u16, name_wide, []u16{ '-', 'p', 't', 'y' }) != null;
}

pub const OpenError = error{
    SharingViolation,
    PathAlreadyExists,
    FileNotFound,
    AccessDenied,
    PipeBusy,
    Unexpected,
    OutOfMemory,
};

/// `file_path` needs to be copied in memory to add a null terminating byte, hence the allocator.
pub fn windowsOpen(
    allocator: *mem.Allocator,
    file_path: []const u8,
    desired_access: windows.DWORD,
    share_mode: windows.DWORD,
    creation_disposition: windows.DWORD,
    flags_and_attrs: windows.DWORD,
) OpenError!windows.HANDLE {
    const path_with_null = try cstr.addNullByte(allocator, file_path);
    defer allocator.free(path_with_null);

    const result = windows.CreateFileA(path_with_null.ptr, desired_access, share_mode, null, creation_disposition, flags_and_attrs, null);

    if (result == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.SHARING_VIOLATION => OpenError.SharingViolation,
            windows.ERROR.ALREADY_EXISTS, windows.ERROR.FILE_EXISTS => OpenError.PathAlreadyExists,
            windows.ERROR.FILE_NOT_FOUND => OpenError.FileNotFound,
            windows.ERROR.ACCESS_DENIED => OpenError.AccessDenied,
            windows.ERROR.PIPE_BUSY => OpenError.PipeBusy,
            else => os.unexpectedErrorWindows(err),
        };
    }

    return result;
}

/// Caller must free result.
pub fn createWindowsEnvBlock(allocator: *mem.Allocator, env_map: *const BufMap) ![]u8 {
    // count bytes needed
    const bytes_needed = x: {
        var bytes_needed: usize = 1; // 1 for the final null byte
        var it = env_map.iterator();
        while (it.next()) |pair| {
            // +1 for '='
            // +1 for null byte
            bytes_needed += pair.key.len + pair.value.len + 2;
        }
        break :x bytes_needed;
    };
    const result = try allocator.alloc(u8, bytes_needed);
    errdefer allocator.free(result);

    var it = env_map.iterator();
    var i: usize = 0;
    while (it.next()) |pair| {
        mem.copy(u8, result[i..], pair.key);
        i += pair.key.len;
        result[i] = '=';
        i += 1;
        mem.copy(u8, result[i..], pair.value);
        i += pair.value.len;
        result[i] = 0;
        i += 1;
    }
    result[i] = 0;
    return result;
}

pub fn windowsLoadDll(allocator: *mem.Allocator, dll_path: []const u8) !windows.HMODULE {
    const padded_buff = try cstr.addNullByte(allocator, dll_path);
    defer allocator.free(padded_buff);
    return windows.LoadLibraryA(padded_buff.ptr) orelse error.DllNotFound;
}

pub fn windowsUnloadDll(hModule: windows.HMODULE) void {
    assert(windows.FreeLibrary(hModule) != 0);
}

test "InvalidDll" {
    if (builtin.os != builtin.Os.windows) return;

    const DllName = "asdf.dll";
    const allocator = std.debug.global_allocator;
    const handle = os.windowsLoadDll(allocator, DllName) catch |err| {
        assert(err == error.DllNotFound);
        return;
    };
}

pub fn windowsFindFirstFile(
    allocator: *mem.Allocator,
    dir_path: []const u8,
    find_file_data: *windows.WIN32_FIND_DATAA,
) !windows.HANDLE {
    const wild_and_null = []u8{ '\\', '*', 0 };
    const path_with_wild_and_null = try allocator.alloc(u8, dir_path.len + wild_and_null.len);
    defer allocator.free(path_with_wild_and_null);

    mem.copy(u8, path_with_wild_and_null, dir_path);
    mem.copy(u8, path_with_wild_and_null[dir_path.len..], wild_and_null);

    const handle = windows.FindFirstFileA(path_with_wild_and_null.ptr, find_file_data);

    if (handle == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        switch (err) {
            windows.ERROR.FILE_NOT_FOUND,
            windows.ERROR.PATH_NOT_FOUND,
            => return error.PathNotFound,
            else => return os.unexpectedErrorWindows(err),
        }
    }

    return handle;
}

/// Returns `true` if there was another file, `false` otherwise.
pub fn windowsFindNextFile(handle: windows.HANDLE, find_file_data: *windows.WIN32_FIND_DATAA) !bool {
    if (windows.FindNextFileA(handle, find_file_data) == 0) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.NO_MORE_FILES => false,
            else => os.unexpectedErrorWindows(err),
        };
    }
    return true;
}
