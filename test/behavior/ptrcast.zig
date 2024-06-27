const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const assert = std.debug.assert;
const native_endian = builtin.target.cpu.arch.endian();

test "reinterpret bytes as integer with nonzero offset" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretBytesAsInteger();
    try comptime testReinterpretBytesAsInteger();
}

fn testReinterpretBytesAsInteger() !void {
    const bytes = "\x12\x34\x56\x78\xab";
    const expected = switch (native_endian) {
        .little => 0xab785634,
        .big => 0x345678ab,
    };
    try expect(@as(*align(1) const u32, @ptrCast(bytes[1..5])).* == expected);
}

test "reinterpret an array over multiple elements, with no well-defined layout" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    try testReinterpretWithOffsetAndNoWellDefinedLayout();
    try comptime testReinterpretWithOffsetAndNoWellDefinedLayout();
}

fn testReinterpretWithOffsetAndNoWellDefinedLayout() !void {
    const bytes: ?[5]?u8 = [5]?u8{ 0x12, 0x34, 0x56, 0x78, 0x9a };
    const ptr = &bytes.?[1];
    const copy: [4]?u8 = @as(*const [4]?u8, @ptrCast(ptr)).*;
    _ = copy;
    //try expect(@ptrCast(*align(1)?u8, bytes[1..5]).* == );
}

test "reinterpret bytes inside auto-layout struct as integer with nonzero offset" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretStructWrappedBytesAsInteger();
    try comptime testReinterpretStructWrappedBytesAsInteger();
}

fn testReinterpretStructWrappedBytesAsInteger() !void {
    const S = struct { bytes: [5:0]u8 };
    const obj = S{ .bytes = "\x12\x34\x56\x78\xab".* };
    const expected = switch (native_endian) {
        .little => 0xab785634,
        .big => 0x345678ab,
    };
    try expect(@as(*align(1) const u32, @ptrCast(obj.bytes[1..5])).* == expected);
}

test "reinterpret bytes of an array into an extern struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretBytesAsExternStruct();
    try comptime testReinterpretBytesAsExternStruct();
}

fn testReinterpretBytesAsExternStruct() !void {
    var bytes align(2) = [_]u8{ 1, 2, 3, 4, 5, 6 };

    const S = extern struct {
        a: u8,
        b: u16,
        c: u8,
    };

    const ptr: *const S = @ptrCast(&bytes);
    const val = ptr.c;
    try expect(val == 5);
}

test "reinterpret bytes of an extern struct (with under-aligned fields) into another" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretExternStructAsExternStruct();
    try comptime testReinterpretExternStructAsExternStruct();
}

fn testReinterpretExternStructAsExternStruct() !void {
    const S1 = extern struct {
        a: u8,
        b: u16,
        c: u8,
    };
    comptime var bytes align(2) = S1{ .a = 0, .b = 0, .c = 5 };

    const S2 = extern struct {
        a: u32 align(2),
        c: u8,
    };
    const ptr: *const S2 = @ptrCast(&bytes);
    const val = ptr.c;
    try expect(val == 5);
}

test "reinterpret bytes of an extern struct into another" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretOverAlignedExternStructAsExternStruct();
    try comptime testReinterpretOverAlignedExternStructAsExternStruct();
}

fn testReinterpretOverAlignedExternStructAsExternStruct() !void {
    const S1 = extern struct {
        a: u32,
        b: u32,
        c: u8,
    };
    comptime var bytes: S1 = .{ .a = 0, .b = 0, .c = 5 };

    const S2 = extern struct {
        a0: u32,
        a1: u16,
        a2: u16,
        c: u8,
    };
    const ptr: *const S2 = @ptrCast(&bytes);
    const val = ptr.c;
    try expect(val == 5);
}

test "lower reinterpreted comptime field ptr (with under-aligned fields)" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // Test lowering a field ptr
    comptime var bytes align(2) = [_]u8{ 1, 2, 3, 4, 5, 6 };
    const S = extern struct {
        a: u32 align(2),
        c: u8,
    };
    comptime var ptr = @as(*const S, @ptrCast(&bytes));
    const val = &ptr.c;
    try expect(val.* == 5);

    // Test lowering an elem ptr
    comptime var src_value = S{ .a = 15, .c = 5 };
    comptime var ptr2 = @as(*[@sizeOf(S)]u8, @ptrCast(&src_value));
    const val2 = &ptr2[4];
    try expect(val2.* == 5);
}

test "lower reinterpreted comptime field ptr" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // Test lowering a field ptr
    comptime var bytes align(4) = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const S = extern struct {
        a: u32,
        c: u8,
    };
    comptime var ptr = @as(*const S, @ptrCast(&bytes));
    const val = &ptr.c;
    try expect(val.* == 5);

    // Test lowering an elem ptr
    comptime var src_value = S{ .a = 15, .c = 5 };
    comptime var ptr2 = @as(*[@sizeOf(S)]u8, @ptrCast(&src_value));
    const val2 = &ptr2[4];
    try expect(val2.* == 5);
}

test "reinterpret struct field at comptime" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const numNative = comptime Bytes.init(0x12345678);
    if (native_endian != .little) {
        try expect(std.mem.eql(u8, &[_]u8{ 0x12, 0x34, 0x56, 0x78 }, &numNative.bytes));
    } else {
        try expect(std.mem.eql(u8, &[_]u8{ 0x78, 0x56, 0x34, 0x12 }, &numNative.bytes));
    }
}

const Bytes = struct {
    bytes: [4]u8,

    pub fn init(v: u32) Bytes {
        var res: Bytes = undefined;
        @as(*align(1) u32, @ptrCast(&res.bytes)).* = v;

        return res;
    }
};

test "ptrcast of const integer has the correct object size" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const is_value = ~@as(isize, @intCast(std.math.minInt(isize)));
    const is_bytes = @as([*]const u8, @ptrCast(&is_value))[0..@sizeOf(isize)];
    if (@sizeOf(isize) == 8) {
        switch (native_endian) {
            .little => {
                try expect(is_bytes[0] == 0xff);
                try expect(is_bytes[1] == 0xff);
                try expect(is_bytes[2] == 0xff);
                try expect(is_bytes[3] == 0xff);

                try expect(is_bytes[4] == 0xff);
                try expect(is_bytes[5] == 0xff);
                try expect(is_bytes[6] == 0xff);
                try expect(is_bytes[7] == 0x7f);
            },
            .big => {
                try expect(is_bytes[0] == 0x7f);
                try expect(is_bytes[1] == 0xff);
                try expect(is_bytes[2] == 0xff);
                try expect(is_bytes[3] == 0xff);

                try expect(is_bytes[4] == 0xff);
                try expect(is_bytes[5] == 0xff);
                try expect(is_bytes[6] == 0xff);
                try expect(is_bytes[7] == 0xff);
            },
        }
    }
}

test "implicit optional pointer to optional anyopaque pointer" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    var buf: [4]u8 = "aoeu".*;
    const x: ?[*]u8 = &buf;
    const y: ?*anyopaque = x;
    const z: *[4]u8 = @ptrCast(y);
    try expect(std.mem.eql(u8, z, "aoeu"));
}

test "@ptrCast slice to slice" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(slice: []u32) []i32 {
            return @as([]i32, @ptrCast(slice));
        }
    };
    var buf: [4]u32 = .{ 0, 0, 0, 0 };
    const alias = S.foo(&buf);
    alias[1] = 42;
    try expect(buf[1] == 42);
    try expect(alias.len == 4);
}

test "comptime @ptrCast a subset of an array, then write through it" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    comptime {
        var buff: [16]u8 align(4) = undefined;
        const len_bytes = @as(*u32, @ptrCast(&buff));
        len_bytes.* = 16;
        const source = "abcdef";
        @memcpy(buff[4 .. 4 + source.len], source);
    }
}

test "@ptrCast undefined value at comptime" {
    const S = struct {
        fn transmute(comptime T: type, comptime U: type, value: T) U {
            return @as(*const U, @ptrCast(&value)).*;
        }
    };
    comptime {
        const x = S.transmute(u64, i32, undefined);
        _ = x;
    }
}

test "comptime @ptrCast with packed struct leaves value unmodified" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;

    const S = packed struct { three: u3 };
    const st: S = .{ .three = 6 };
    try expect(st.three == 6);
    const p: *const [1]u3 = @ptrCast(&st);
    try expect(p.*[0] == 6);
    try expect(st.three == 6);
}

test "@ptrCast restructures comptime-only array" {
    {
        const a3a2: [3][2]comptime_int = .{
            .{ 1, 2 },
            .{ 3, 4 },
            .{ 5, 6 },
        };
        const a2a3: *const [2][3]comptime_int = @ptrCast(&a3a2);
        comptime assert(a2a3[0][0] == 1);
        comptime assert(a2a3[0][1] == 2);
        comptime assert(a2a3[0][2] == 3);
        comptime assert(a2a3[1][0] == 4);
        comptime assert(a2a3[1][1] == 5);
        comptime assert(a2a3[1][2] == 6);
    }

    {
        const a6a1: [6][1]comptime_int = .{
            .{1}, .{2}, .{3}, .{4}, .{5}, .{6},
        };
        const a1a2a3: *const [1][2][3]comptime_int = @ptrCast(&a6a1);
        comptime assert(a1a2a3[0][0][0] == 1);
        comptime assert(a1a2a3[0][0][1] == 2);
        comptime assert(a1a2a3[0][0][2] == 3);
        comptime assert(a1a2a3[0][1][0] == 4);
        comptime assert(a1a2a3[0][1][1] == 5);
        comptime assert(a1a2a3[0][1][2] == 6);
    }

    {
        const a1: [1]comptime_int = .{123};
        const raw: *const comptime_int = @ptrCast(&a1);
        comptime assert(raw.* == 123);
    }

    {
        const raw: comptime_int = 123;
        const a1: *const [1]comptime_int = @ptrCast(&raw);
        comptime assert(a1[0] == 123);
    }
}

test "@ptrCast restructures sliced comptime-only array" {
    const a3a2: [4][2]comptime_int = .{
        .{ 1, 2 },
        .{ 3, 4 },
        .{ 5, 6 },
        .{ 7, 8 },
    };

    const sub: *const [4]comptime_int = @ptrCast(a3a2[1..]);
    comptime assert(sub[0] == 3);
    comptime assert(sub[1] == 4);
    comptime assert(sub[2] == 5);
    comptime assert(sub[3] == 6);
}
