const std = @import("std");
const io = std.io;
const fs = std.fs;
const json = std.json;
const StringifyOptions = json.StringifyOptions;
const Allocator = std.mem.Allocator;
const introspect = @import("introspect.zig");

pub const CompilerInfo = struct {
    /// Compiler id hash
    id: []const u8,

    /// Compiler version
    version: []const u8,

    /// Path to lib/
    lib_dir: []const u8,

    /// Path to lib/zig/std
    std_dir: []const u8,

    /// Path to the global cache dir
    global_cache_dir: []const u8,

    pub fn init(allocator: *Allocator) !CompilerInfo {
        const zig_lib_dir = try introspect.resolveZigLibDir(allocator);
        const zig_std_dir = try fs.path.join(allocator, &[_][]const u8{zig_lib_dir, "std"});
        return CompilerInfo{
            .id = "test",
            .version = "0.7.0",
            .lib_dir = zig_lib_dir,
            .std_dir = zig_std_dir,
            .global_cache_dir = "/global/"
        };
    }

    pub fn deinit(self: *CompilerInfo, allocator: *Allocator) void {
        allocator.free(self.lib_dir);
        allocator.free(self.std_dir);
    }
};

pub fn cmdInfo(allocator: *Allocator, stdout: var) !void {
    var info = try CompilerInfo.init(allocator);
    defer info.deinit(allocator);

    var bos = io.bufferedOutStream(stdout);
    const bos_stream = bos.outStream();

    const stringifyOptions = StringifyOptions{
        .whitespace = StringifyOptions.Whitespace{
            // Match indentation of zig targets
            .indent = .{ .Space = 2 }
        },
    };
    try json.stringify(info, stringifyOptions, bos_stream);

    try bos_stream.writeByte('\n');
    try bos.flush();
}
