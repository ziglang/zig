const builtin = @import("builtin");
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    unreachable;
}

// This file exists to create a libdl.so file so that LLD has something to look at
// and emit linker errors if an attempt to link against a non-existent C symbol happens.

export fn __libdl_freeres() void {}
export fn _dlfcn_hook() void {}
export fn dladdr() void {}
export fn dladdr1() void {}
export fn dlclose() void {}
export fn dlerror() void {}
export fn dlinfo() void {}
export fn dlmopen() void {}
export fn dlopen() void {}
export fn dlsym() void {}
export fn dlvsym() void {}
