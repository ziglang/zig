const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const native_endian = builtin.target.cpu.arch.endian();

test "reinterpret bytes as integer with nonzero offset" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    try testReinterpretBytesAsInteger();
    comptime try testReinterpretBytesAsInteger();
}

fn testReinterpretBytesAsInteger() !void {
    const bytes = "\x12\x34\x56\x78\xab";
    const expected = switch (native_endian) {
        .Little => 0xab785634,
        .Big => 0x345678ab,
    };
    try expect(@ptrCast(*align(1) const u32, bytes[1..5]).* == expected);
}

test "reinterpret bytes of an array into an extern struct" {
    if (builtin.zig_backend != .stage1) return error.SkipZigTest; // TODO

    try testReinterpretBytesAsExternStruct();
    comptime try testReinterpretBytesAsExternStruct();
}

fn testReinterpretBytesAsExternStruct() !void {
    var bytes align(2) = [_]u8{ 1, 2, 3, 4, 5, 6 };

    const S = extern struct {
        a: u8,
        b: u16,
        c: u8,
    };

    var ptr = @ptrCast(*const S, &bytes);
    var val = ptr.c;
    try expect(val == 5);
}

test "reinterpret struct field at comptime" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    const numNative = comptime Bytes.init(0x12345678);
    if (native_endian != .Little) {
        try expect(std.mem.eql(u8, &[_]u8{ 0x12, 0x34, 0x56, 0x78 }, &numNative.bytes));
    } else {
        try expect(std.mem.eql(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, &numNative.bytes));
    }
}

const Bytes = struct {
    bytes: [4]u8,

    pub fn init(v: u32) Bytes {
        var res: Bytes = undefined;
        @ptrCast(*align(1) u32, &res.bytes).* = v;

        return res;
    }
};

test "comptime ptrcast keeps larger alignment" {
    comptime {
        const a: u32 = 1234;
        const p = @ptrCast([*]const u8, &a);
        try expect(@TypeOf(p) == [*]align(@alignOf(u32)) const u8);
    }
}

test "implicit optional pointer to optional anyopaque pointer" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var buf: [4]u8 = "aoeu".*;
    var x: ?[*]u8 = &buf;
    var y: ?*anyopaque = x;
    var z = @ptrCast(*[4]u8, y);
    try expect(std.mem.eql(u8, z, "aoeu"));
}
