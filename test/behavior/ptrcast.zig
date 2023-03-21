const std = @import("std");
const builtin = @import("builtin");
const expect = std.testing.expect;
const native_endian = builtin.target.cpu.arch.endian();

test "reinterpret bytes as integer with nonzero offset" {
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

test "reinterpret an array over multiple elements, with no well-defined layout" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretWithOffsetAndNoWellDefinedLayout();
    comptime try testReinterpretWithOffsetAndNoWellDefinedLayout();
}

fn testReinterpretWithOffsetAndNoWellDefinedLayout() !void {
    const bytes: ?[5]?u8 = [5]?u8{ 0x12, 0x34, 0x56, 0x78, 0x9a };
    const ptr = &bytes.?[1];
    const copy: [4]?u8 = @ptrCast(*const [4]?u8, ptr).*;
    _ = copy;
    //try expect(@ptrCast(*align(1)?u8, bytes[1..5]).* == );
}

test "reinterpret bytes inside auto-layout struct as integer with nonzero offset" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    try testReinterpretStructWrappedBytesAsInteger();
    comptime try testReinterpretStructWrappedBytesAsInteger();
}

fn testReinterpretStructWrappedBytesAsInteger() !void {
    const S = struct { bytes: [5:0]u8 };
    const obj = S{ .bytes = "\x12\x34\x56\x78\xab".* };
    const expected = switch (native_endian) {
        .Little => 0xab785634,
        .Big => 0x345678ab,
    };
    try expect(@ptrCast(*align(1) const u32, obj.bytes[1..5]).* == expected);
}

test "reinterpret bytes of an array into an extern struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

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

test "reinterpret bytes of an extern struct (with under-aligned fields) into another" {
    try testReinterpretExternStructAsExternStruct();
    comptime try testReinterpretExternStructAsExternStruct();
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
    var ptr = @ptrCast(*const S2, &bytes);
    var val = ptr.c;
    try expect(val == 5);
}

test "reinterpret bytes of an extern struct into another" {
    try testReinterpretOverAlignedExternStructAsExternStruct();
    comptime try testReinterpretOverAlignedExternStructAsExternStruct();
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
    var ptr = @ptrCast(*const S2, &bytes);
    var val = ptr.c;
    try expect(val == 5);
}

test "lower reinterpreted comptime field ptr (with under-aligned fields)" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // Test lowering a field ptr
    comptime var bytes align(2) = [_]u8{ 1, 2, 3, 4, 5, 6 };
    const S = extern struct {
        a: u32 align(2),
        c: u8,
    };
    comptime var ptr = @ptrCast(*const S, &bytes);
    var val = &ptr.c;
    try expect(val.* == 5);

    // Test lowering an elem ptr
    comptime var src_value = S{ .a = 15, .c = 5 };
    comptime var ptr2 = @ptrCast(*[@sizeOf(S)]u8, &src_value);
    var val2 = &ptr2[4];
    try expect(val2.* == 5);
}

test "lower reinterpreted comptime field ptr" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    // Test lowering a field ptr
    comptime var bytes align(4) = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const S = extern struct {
        a: u32,
        c: u8,
    };
    comptime var ptr = @ptrCast(*const S, &bytes);
    var val = &ptr.c;
    try expect(val.* == 5);

    // Test lowering an elem ptr
    comptime var src_value = S{ .a = 15, .c = 5 };
    comptime var ptr2 = @ptrCast(*[@sizeOf(S)]u8, &src_value);
    var val2 = &ptr2[4];
    try expect(val2.* == 5);
}

test "reinterpret struct field at comptime" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
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

test "ptrcast of const integer has the correct object size" {
    const is_value = ~@intCast(isize, std.math.minInt(isize));
    const is_bytes = @ptrCast([*]const u8, &is_value)[0..@sizeOf(isize)];
    if (@sizeOf(isize) == 8) {
        switch (native_endian) {
            .Little => {
                try expect(is_bytes[0] == 0xff);
                try expect(is_bytes[1] == 0xff);
                try expect(is_bytes[2] == 0xff);
                try expect(is_bytes[3] == 0xff);

                try expect(is_bytes[4] == 0xff);
                try expect(is_bytes[5] == 0xff);
                try expect(is_bytes[6] == 0xff);
                try expect(is_bytes[7] == 0x7f);
            },
            .Big => {
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
    var x: ?[*]u8 = &buf;
    var y: ?*anyopaque = x;
    var z = @ptrCast(*[4]u8, y);
    try expect(std.mem.eql(u8, z, "aoeu"));
}

test "@ptrCast slice to slice" {
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        fn foo(slice: []u32) []i32 {
            return @ptrCast([]i32, slice);
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
        const len_bytes = @ptrCast(*u32, &buff);
        len_bytes.* = 16;
        std.mem.copy(u8, buff[4..], "abcdef");
    }
}

test "@ptrCast undefined value at comptime" {
    const S = struct {
        fn transmute(comptime T: type, comptime U: type, value: T) U {
            return @ptrCast(*const U, &value).*;
        }
    };
    comptime {
        var x = S.transmute([]u8, i32, undefined);
        _ = x;
    }
}
