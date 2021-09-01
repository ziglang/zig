// C API bindings for src/windows_sdk.h

pub const ZigWindowsSDK = extern struct {
    path10_ptr: ?[*]const u8,
    path10_len: usize,
    version10_ptr: ?[*]const u8,
    version10_len: usize,
    path81_ptr: ?[*]const u8,
    path81_len: usize,
    version81_ptr: ?[*]const u8,
    version81_len: usize,
    msvc_lib_dir_ptr: ?[*]const u8,
    msvc_lib_dir_len: usize,

    pub const find = zig_find_windows_sdk;
    pub const free = zig_free_windows_sdk;

    pub const FindError = enum(c_int) {
        None,
        OutOfMemory,
        NotFound,
        PathTooLong,
    };

    extern fn zig_find_windows_sdk(out_sdk: **ZigWindowsSDK) FindError;
    extern fn zig_free_windows_sdk(sdk: *ZigWindowsSDK) void;
};
