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
                    const global_dir = unicode.utf16leToUtf8(allocator, utf16lePtrSlice(dir_path_ptr)) catch |err| switch (err) {
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
        // TODO for macos it should be "~/Library/Application Support/<APPNAME>"
        else => {
            const home_dir = os.getEnvVarOwned(allocator, "HOME") catch |err| switch (err) {
                error.OutOfMemory => return error.OutOfMemory,
                error.EnvironmentVariableNotFound => return error.AppDataDirUnavailable, // TODO look in /etc/passwd
            };
            defer allocator.free(home_dir);
            return os.path.join(allocator, home_dir, ".local", "share", appname);
        },
    }
}

fn utf16lePtrSlice(ptr: [*]const u16) []const u16 {
    var index: usize = 0;
    while (ptr[index] != 0) : (index += 1) {}
    return ptr[0..index];
}

test "getAppDataDir" {
    const result = try getAppDataDir(std.debug.global_allocator, "zig");
    std.debug.warn("{}...", result);
}

