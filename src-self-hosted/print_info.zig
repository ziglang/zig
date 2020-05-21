const std = @import("std");
const io = std.io;
const json = std.json;
const StringifyOptions = json.StringifyOptions;
const Allocator = std.mem.Allocator;

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
};

fn resolveCompilerInfo(allocator: *Allocator) CompilerInfo {
    return CompilerInfo{
        .id = "test",
        .version = "0.7.0",
        .lib_dir = "/some/path",
        .std_dir = "/some/path/std",
        .global_cache_dir = "/global/"
    };
}

pub fn cmdInfo(allocator: *Allocator, stdout: var) !void {
    const info = resolveCompilerInfo(allocator);

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
