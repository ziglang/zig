const builtin = @import("builtin");
const std = @import("std");
const debug = std.debug;
const testing = std.testing;
const expect = testing.expect;

var argv: [*]const [*]const u8 = undefined;

test "const slice child" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const strs = [_][*]const u8{ "one", "two", "three" };
    argv = &strs;
    try bar(strs.len);
}

fn foo(args: [][]const u8) !void {
    try expect(args.len == 3);
    try expect(streql(args[0], "one"));
    try expect(streql(args[1], "two"));
    try expect(streql(args[2], "three"));
}

fn bar(argc: usize) !void {
    var args_buffer: [10][]const u8 = undefined;
    const args = args_buffer[0..argc];
    for (args, 0..) |_, i| {
        const ptr = argv[i];
        args[i] = ptr[0..strlen(ptr)];
    }
    try foo(args);
}

fn strlen(ptr: [*]const u8) usize {
    var count: usize = 0;
    while (ptr[count] != 0) : (count += 1) {}
    return count;
}

fn streql(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, 0..) |item, index| {
        if (b[index] != item) return false;
    }
    return true;
}
