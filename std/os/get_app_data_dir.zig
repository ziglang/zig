const std = @import("../index.zig");
const builtin = @import("builtin");
const unicode = std.unicode;
const mem = std.mem;
const os = std.os;

pub const GetAppDataDirError = error{
    OutOfMemory,
    AppDataDirUnavailable,
};

/// Caller owns returned memory.
/// TODO determine if we can remove the allocator requirement
pub fn getAppDataDir(allocator: *mem.Allocator, appname: []const u8) GetAppDataDirError![]u8 {
    switch (builtin.os) {
        builtin.Os.windows => {
            var dir_path_ptr: [*]u16 = undefined;
            switch (os.windows.SHGetKnownFolderPath(
                &os.windows.FOLDERID_LocalAppData,
                os.windows.KF_FLAG_CREATE,
                null,
                &dir_path_ptr,
            )) {
                os.windows.S_OK => {
                    defer os.windows.CoTaskMemFree(@ptrCast(*c_void, dir_path_ptr));
                    const global_dir = unicode.utf16leToUtf8Alloc(allocator, utf16lePtrSlice(dir_path_ptr)) catch |err| switch (err) {
                        error.UnexpectedSecondSurrogateHalf => return error.AppDataDirUnavailable,
                        error.ExpectedSecondSurrogateHalf => return error.AppDataDirUnavailable,
                        error.DanglingSurrogateHalf => return error.AppDataDirUnavailable,
                        error.OutOfMemory => return error.OutOfMemory,
                    };
                    defer allocator.free(global_dir);
                    return os.path.join(allocator, global_dir, appname);
                },
                os.windows.E_OUTOFMEMORY => return error.OutOfMemory,
                else => return error.AppDataDirUnavailable,
            }
        },
        builtin.Os.macosx => {
            const home_dir = os.getEnvPosix("HOME") orelse {
                // TODO look in /etc/passwd
                return error.AppDataDirUnavailable;
            };
            return os.path.join(allocator, home_dir, "Library", "Application Support", appname);
        },
        builtin.Os.linux => {
            const home_dir = os.getEnvPosix("HOME") orelse {
                // TODO look in /etc/passwd
                return error.AppDataDirUnavailable;
            };
            return os.path.join(allocator, home_dir, ".local", "share", appname);
        },
        else => @compileError("Unsupported OS"),
    }
}

fn utf16lePtrSlice(ptr: [*]const u16) []const u16 {
    var index: usize = 0;
    while (ptr[index] != 0) : (index += 1) {}
    return ptr[0..index];
}

test "std.os.getAppDataDir" {
    var buf: [512]u8 = undefined;
    const allocator = &std.heap.FixedBufferAllocator.init(buf[0..]).allocator;

    // We can't actually validate the result
    _ = getAppDataDir(allocator, "zig") catch return;
}

