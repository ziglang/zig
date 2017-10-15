const std = @import("../../index.zig");
const os = std.os;
const windows = std.os.windows;
const assert = std.debug.assert;
const mem = std.mem;
const BufMap = std.BufMap;

error WaitAbandoned;
error WaitTimeOut;

pub fn windowsWaitSingle(handle: windows.HANDLE, milliseconds: windows.DWORD) -> %void {
    const result = windows.WaitForSingleObject(handle, milliseconds);
    return switch (result) {
        windows.WAIT_ABANDONED => error.WaitAbandoned,
        windows.WAIT_OBJECT_0 => {},
        windows.WAIT_TIMEOUT => error.WaitTimeOut,
        windows.WAIT_FAILED => switch (windows.GetLastError()) {
            else => error.Unexpected,
        },
        else => error.Unexpected,
    };
}

pub fn windowsClose(handle: windows.HANDLE) {
    assert(windows.CloseHandle(handle) != 0);
}

error SystemResources;
error OperationAborted;
error IoPending;
error BrokenPipe;

pub fn windowsWrite(handle: windows.HANDLE, bytes: []const u8) -> %void {
    if (windows.WriteFile(handle, @ptrCast(&const c_void, bytes.ptr), u32(bytes.len), null, null) == 0) {
        return switch (windows.GetLastError()) {
            windows.ERROR.INVALID_USER_BUFFER => error.SystemResources,
            windows.ERROR.NOT_ENOUGH_MEMORY => error.SystemResources,
            windows.ERROR.OPERATION_ABORTED => error.OperationAborted,
            windows.ERROR.NOT_ENOUGH_QUOTA => error.SystemResources,
            windows.ERROR.IO_PENDING => error.IoPending,
            windows.ERROR.BROKEN_PIPE => error.BrokenPipe,
            else => error.Unexpected,
        };
    }
}

pub fn windowsIsTty(handle: windows.HANDLE) -> bool {
    if (windowsIsCygwinPty(handle))
        return true;

    var out: windows.DWORD = undefined;
    return windows.GetConsoleMode(handle, &out) != 0;
}

pub fn windowsIsCygwinPty(handle: windows.HANDLE) -> bool {
    const size = @sizeOf(windows.FILE_NAME_INFO);
    var name_info_bytes align(@alignOf(windows.FILE_NAME_INFO)) = []u8{0} ** (size + windows.MAX_PATH);

    if (windows.GetFileInformationByHandleEx(handle, windows.FileNameInfo,
        @ptrCast(&c_void, &name_info_bytes[0]), u32(name_info_bytes.len)) == 0)
    {
        return true;
    }

    const name_info = @ptrCast(&const windows.FILE_NAME_INFO, &name_info_bytes[0]);
    const name_bytes = name_info_bytes[size..size + usize(name_info.FileNameLength)];
    const name_wide  = ([]u16)(name_bytes);
    return mem.indexOf(u16, name_wide, []u16{'m','s','y','s','-'}) != null or
           mem.indexOf(u16, name_wide, []u16{'-','p','t','y'}) != null;
}

error SharingViolation;
error PipeBusy;

/// `file_path` may need to be copied in memory to add a null terminating byte. In this case
/// a fixed size buffer of size ::max_noalloc_path_len is an attempted solution. If the fixed
/// size buffer is too small, and the provided allocator is null, ::error.NameTooLong is returned.
/// otherwise if the fixed size buffer is too small, allocator is used to obtain the needed memory.
pub fn windowsOpen(file_path: []const u8, desired_access: windows.DWORD, share_mode: windows.DWORD,
    creation_disposition: windows.DWORD, flags_and_attrs: windows.DWORD, allocator: ?&mem.Allocator) -> %windows.HANDLE
{
    var stack_buf: [os.max_noalloc_path_len]u8 = undefined;
    var path0: []u8 = undefined;
    var need_free = false;
    defer if (need_free) (??allocator).free(path0);

    if (file_path.len < stack_buf.len) {
        path0 = stack_buf[0..file_path.len + 1];
    } else if (allocator) |a| {
        path0 = %return a.alloc(u8, file_path.len + 1);
        need_free = true;
    } else {
        return error.NameTooLong;
    }
    mem.copy(u8, path0, file_path);
    path0[file_path.len] = 0;

    const result = windows.CreateFileA(path0.ptr, desired_access, share_mode, null, creation_disposition,
        flags_and_attrs, null);

    if (result == windows.INVALID_HANDLE_VALUE) {
        const err = windows.GetLastError();
        return switch (err) {
            windows.ERROR.SHARING_VIOLATION => error.SharingViolation,
            windows.ERROR.ALREADY_EXISTS, windows.ERROR.FILE_EXISTS => error.PathAlreadyExists,
            windows.ERROR.FILE_NOT_FOUND => error.FileNotFound,
            windows.ERROR.ACCESS_DENIED => error.AccessDenied,
            windows.ERROR.PIPE_BUSY => error.PipeBusy,
            else => error.Unexpected,
        };
    }

    return result;
}

/// Caller must free result.
pub fn createWindowsEnvBlock(allocator: &mem.Allocator, env_map: &const BufMap) -> %[]u8 {
    // count bytes needed
    const bytes_needed = {
        var bytes_needed: usize = 1; // 1 for the final null byte
        var it = env_map.iterator();
        while (it.next()) |pair| {
            // +1 for '='
            // +1 for null byte
            bytes_needed += pair.key.len + pair.value.len + 2;
        }
        bytes_needed
    };
    const result = %return allocator.alloc(u8, bytes_needed);
    %defer allocator.free(result);

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
