const std = @import("std");
const testing = std.testing;
const builtin = @import("builtin");

var x: u8 = 1;

// This excludes builtin functions that return void or noreturn that cannot be tested.
test {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv) return error.SkipZigTest;

    var val: u8 = undefined;
    try testing.expect({} == @atomicStore(u8, &val, 0, .unordered));
    try testing.expect(void == @TypeOf(@breakpoint()));
    try testing.expect({} == @export(&x, .{ .name = "x" }));
    try testing.expect({} == @memcpy(@as([*]u8, @ptrFromInt(1))[0..0], @as([*]u8, @ptrFromInt(1))[0..0]));
    try testing.expect({} == @memmove(@as([*]u8, @ptrFromInt(1))[0..0], @as([*]u8, @ptrFromInt(1))[0..0]));
    try testing.expect({} == @memset(@as([*]u8, @ptrFromInt(1))[0..0], undefined));
    try testing.expect(noreturn == @TypeOf(if (true) @panic("") else {}));
    try testing.expect({} == @prefetch(&val, .{}));
    try testing.expect({} == @setEvalBranchQuota(0));
    try testing.expect({} == @setFloatMode(.optimized));
    try testing.expect({} == @setRuntimeSafety(true));
}
