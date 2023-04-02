const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const native_endian = builtin.cpu.arch.endian();

test "flags in packed structs" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Flags1 = packed struct {
        // first 8 bits
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // 7 more bits
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,

        // some padding to fill to 24 bits
        _: u9,
    };

    try expectEqual(@sizeOf(u24), @sizeOf(Flags1));
    try expectEqual(24, @bitSizeOf(Flags1));

    const Flags2 = packed struct {
        // byte 0
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // partial byte 1 (but not 8 bits)
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,

        // some padding that should yield @sizeOf(Flags2) == 4
        _: u10,
    };

    try expectEqual(@sizeOf(u25), @sizeOf(Flags2));
    try expectEqual(25, @bitSizeOf(Flags2));

    const Flags3 = packed struct {
        // byte 0
        b0_0: u1,
        b0_1: u1,
        b0_2: u1,
        b0_3: u1,
        b0_4: u1,
        b0_5: u1,
        b0_6: u1,
        b0_7: u1,

        // byte 1
        b1_0: u1,
        b1_1: u1,
        b1_2: u1,
        b1_3: u1,
        b1_4: u1,
        b1_5: u1,
        b1_6: u1,
        b1_7: u1,

        // some padding that should yield @sizeOf(Flags2) == 4
        _: u16, // it works, if the padding is 8-based
    };

    try expectEqual(@sizeOf(u32), @sizeOf(Flags3));
    try expectEqual(32, @bitSizeOf(Flags3));
}

test "consistent size of packed structs" {
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const TxData1 = packed struct { data: u8, _23: u23, full: bool = false };
    const TxData2 = packed struct { data: u9, _22: u22, full: bool = false };

    const register_size_bits = 32;
    const register_size_bytes = @sizeOf(u32);

    try expectEqual(register_size_bits, @bitSizeOf(TxData1));
    try expectEqual(register_size_bytes, @sizeOf(TxData1));

    try expectEqual(register_size_bits, @bitSizeOf(TxData2));
    try expectEqual(register_size_bytes, @sizeOf(TxData2));

    const TxData4 = packed struct { a: u32, b: u24 };
    const TxData6 = packed struct { a: u24, b: u32 };

    const expectedBitSize = 56;
    const expectedByteSize = @sizeOf(u56);

    try expectEqual(expectedBitSize, @bitSizeOf(TxData4));
    try expectEqual(expectedByteSize, @sizeOf(TxData4));

    try expectEqual(expectedBitSize, @bitSizeOf(TxData6));
    try expectEqual(expectedByteSize, @sizeOf(TxData6));
}

test "correct sizeOf and offsets in packed structs" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const PStruct = packed struct {
        bool_a: bool,
        bool_b: bool,
        bool_c: bool,
        bool_d: bool,
        bool_e: bool,
        bool_f: bool,
        u1_a: u1,
        bool_g: bool,
        u1_b: u1,
        u3_a: u3,
        u10_a: u10,
        u10_b: u10,
    };
    try expectEqual(0, @offsetOf(PStruct, "bool_a"));
    try expectEqual(0, @bitOffsetOf(PStruct, "bool_a"));
    try expectEqual(0, @offsetOf(PStruct, "bool_b"));
    try expectEqual(1, @bitOffsetOf(PStruct, "bool_b"));
    try expectEqual(0, @offsetOf(PStruct, "bool_c"));
    try expectEqual(2, @bitOffsetOf(PStruct, "bool_c"));
    try expectEqual(0, @offsetOf(PStruct, "bool_d"));
    try expectEqual(3, @bitOffsetOf(PStruct, "bool_d"));
    try expectEqual(0, @offsetOf(PStruct, "bool_e"));
    try expectEqual(4, @bitOffsetOf(PStruct, "bool_e"));
    try expectEqual(0, @offsetOf(PStruct, "bool_f"));
    try expectEqual(5, @bitOffsetOf(PStruct, "bool_f"));
    try expectEqual(0, @offsetOf(PStruct, "u1_a"));
    try expectEqual(6, @bitOffsetOf(PStruct, "u1_a"));
    try expectEqual(0, @offsetOf(PStruct, "bool_g"));
    try expectEqual(7, @bitOffsetOf(PStruct, "bool_g"));
    try expectEqual(1, @offsetOf(PStruct, "u1_b"));
    try expectEqual(8, @bitOffsetOf(PStruct, "u1_b"));
    try expectEqual(1, @offsetOf(PStruct, "u3_a"));
    try expectEqual(9, @bitOffsetOf(PStruct, "u3_a"));
    try expectEqual(1, @offsetOf(PStruct, "u10_a"));
    try expectEqual(12, @bitOffsetOf(PStruct, "u10_a"));
    try expectEqual(2, @offsetOf(PStruct, "u10_b"));
    try expectEqual(22, @bitOffsetOf(PStruct, "u10_b"));
    try expectEqual(4, @sizeOf(PStruct));

    if (native_endian == .Little) {
        const s1 = @bitCast(PStruct, @as(u32, 0x12345678));
        try expectEqual(false, s1.bool_a);
        try expectEqual(false, s1.bool_b);
        try expectEqual(false, s1.bool_c);
        try expectEqual(true, s1.bool_d);
        try expectEqual(true, s1.bool_e);
        try expectEqual(true, s1.bool_f);
        try expectEqual(@as(u1, 1), s1.u1_a);
        try expectEqual(false, s1.bool_g);
        try expectEqual(@as(u1, 0), s1.u1_b);
        try expectEqual(@as(u3, 3), s1.u3_a);
        try expectEqual(@as(u10, 0b1101000101), s1.u10_a);
        try expectEqual(@as(u10, 0b0001001000), s1.u10_b);

        const s2 = @bitCast(packed struct { x: u1, y: u7, z: u24 }, @as(u32, 0xd5c71ff4));
        try expectEqual(@as(u1, 0), s2.x);
        try expectEqual(@as(u7, 0b1111010), s2.y);
        try expectEqual(@as(u24, 0xd5c71f), s2.z);
    }
}

test "nested packed structs" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S1 = packed struct { a: u8, b: u8, c: u8 };

    const S2 = packed struct { d: u8, e: u8, f: u8 };

    const S3 = packed struct { x: S1, y: S2 };
    const S3Padded = packed struct { s3: S3, pad: u16 };

    try expectEqual(48, @bitSizeOf(S3));
    try expectEqual(@sizeOf(u48), @sizeOf(S3));

    try expectEqual(3, @offsetOf(S3, "y"));
    try expectEqual(24, @bitOffsetOf(S3, "y"));

    if (native_endian == .Little) {
        const s3 = @bitCast(S3Padded, @as(u64, 0xe952d5c71ff4)).s3;
        try expectEqual(@as(u8, 0xf4), s3.x.a);
        try expectEqual(@as(u8, 0x1f), s3.x.b);
        try expectEqual(@as(u8, 0xc7), s3.x.c);
        try expectEqual(@as(u8, 0xd5), s3.y.d);
        try expectEqual(@as(u8, 0x52), s3.y.e);
        try expectEqual(@as(u8, 0xe9), s3.y.f);
    }

    const S4 = packed struct { a: i32, b: i8 };
    const S5 = packed struct { a: i32, b: i8, c: S4 };
    const S6 = packed struct { a: i32, b: S4, c: i8 };

    const expectedBitSize = 80;
    const expectedByteSize = @sizeOf(u80);
    try expectEqual(expectedBitSize, @bitSizeOf(S5));
    try expectEqual(expectedByteSize, @sizeOf(S5));
    try expectEqual(expectedBitSize, @bitSizeOf(S6));
    try expectEqual(expectedByteSize, @sizeOf(S6));

    try expectEqual(5, @offsetOf(S5, "c"));
    try expectEqual(40, @bitOffsetOf(S5, "c"));
    try expectEqual(9, @offsetOf(S6, "c"));
    try expectEqual(72, @bitOffsetOf(S6, "c"));
}

test "regular in irregular packed struct" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const Irregular = packed struct {
        bar: Regular = Regular{},
        _: u24 = 0,
        pub const Regular = packed struct { a: u16 = 0, b: u8 = 0 };
    };

    var foo = Irregular{};
    foo.bar.a = 235;
    foo.bar.b = 42;

    try expectEqual(@as(u16, 235), foo.bar.a);
    try expectEqual(@as(u8, 42), foo.bar.b);
}

test "byte-aligned field pointer offsets" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const A = packed struct {
            a: u8,
            b: u8,
            c: u8,
            d: u8,
        };

        const B = packed struct {
            a: u16,
            b: u16,
        };

        fn doTheTest() !void {
            var a: A = .{
                .a = 1,
                .b = 2,
                .c = 3,
                .d = 4,
            };
            switch (comptime builtin.cpu.arch.endian()) {
                .Little => {
                    comptime assert(@TypeOf(&a.a) == *align(4) u8);
                    comptime assert(@TypeOf(&a.b) == *u8);
                    comptime assert(@TypeOf(&a.c) == *align(2) u8);
                    comptime assert(@TypeOf(&a.d) == *u8);
                },
                .Big => {
                    // TODO re-evaluate packed struct endianness
                    comptime assert(@TypeOf(&a.a) == *align(4:0:4) u8);
                    comptime assert(@TypeOf(&a.b) == *align(4:8:4) u8);
                    comptime assert(@TypeOf(&a.c) == *align(4:16:4) u8);
                    comptime assert(@TypeOf(&a.d) == *align(4:24:4) u8);
                },
            }
            try expect(a.a == 1);
            try expect(a.b == 2);
            try expect(a.c == 3);
            try expect(a.d == 4);

            a.a += 1;
            try expect(a.a == 2);
            try expect(a.b == 2);
            try expect(a.c == 3);
            try expect(a.d == 4);

            a.b += 1;
            try expect(a.a == 2);
            try expect(a.b == 3);
            try expect(a.c == 3);
            try expect(a.d == 4);

            a.c += 1;
            try expect(a.a == 2);
            try expect(a.b == 3);
            try expect(a.c == 4);
            try expect(a.d == 4);

            a.d += 1;
            try expect(a.a == 2);
            try expect(a.b == 3);
            try expect(a.c == 4);
            try expect(a.d == 5);

            var b: B = .{
                .a = 1,
                .b = 2,
            };
            switch (comptime builtin.cpu.arch.endian()) {
                .Little => {
                    comptime assert(@TypeOf(&b.a) == *align(4) u16);
                    comptime assert(@TypeOf(&b.b) == *u16);
                },
                .Big => {
                    comptime assert(@TypeOf(&b.a) == *align(4:0:4) u16);
                    comptime assert(@TypeOf(&b.b) == *align(4:16:4) u16);
                },
            }
            try expect(b.a == 1);
            try expect(b.b == 2);

            b.a += 1;
            try expect(b.a == 2);
            try expect(b.b == 2);

            b.b += 1;
            try expect(b.a == 2);
            try expect(b.b == 3);
        }
    };

    try S.doTheTest();
    comptime try S.doTheTest();
}

test "load pointer from packed struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const A = struct {
        index: u16,
    };
    const B = packed struct {
        x: *A,
        y: u32,
    };
    var a: A = .{ .index = 123 };
    var b_list: []const B = &.{.{ .x = &a, .y = 99 }};
    for (b_list) |b| {
        var i = b.x.index;
        try expect(i == 123);
    }
}

test "@ptrToInt on a packed struct field" {
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const P = packed struct {
            x: u8,
            y: u8,
            z: u32,
        };
        var p0: P = P{
            .x = 1,
            .y = 2,
            .z = 0,
        };
    };
    try expect(@ptrToInt(&S.p0.z) - @ptrToInt(&S.p0.x) == 2);
}

test "optional pointer in packed struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const T = packed struct { ptr: ?*const u8 };
    var n: u8 = 0;
    const x = T{ .ptr = &n };
    try expect(x.ptr.? == &n);
}

test "nested packed struct field access test" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO
    //
    const Vec2 = packed struct {
        x: f32,
        y: f32,
    };

    const Vec3 = packed struct {
        x: f32,
        y: f32,
        z: f32,
    };

    const NestedVec2 = packed struct {
        nested: Vec2,
    };

    const NestedVec3 = packed struct {
        nested: Vec3,
    };

    const vec2 = Vec2{
        .x = 1.0,
        .y = 2.0,
    };

    try std.testing.expectEqual(vec2.x, 1.0);
    try std.testing.expectEqual(vec2.y, 2.0);

    var vec2_o: Vec2 = undefined;
    const vec2_o_ptr: *Vec2 = &vec2_o;
    vec2_o_ptr.* = vec2;

    try std.testing.expectEqual(vec2_o.x, 1.0);
    try std.testing.expectEqual(vec2_o.y, 2.0);

    const nested_vec2 = NestedVec2{
        .nested = Vec2{
            .x = 1.0,
            .y = 2.0,
        },
    };

    try std.testing.expectEqual(nested_vec2.nested.x, 1.0);
    try std.testing.expectEqual(nested_vec2.nested.y, 2.0);

    var nested_o: NestedVec2 = undefined;
    const nested_o_ptr: *NestedVec2 = &nested_o;
    nested_o_ptr.* = nested_vec2;

    try std.testing.expectEqual(nested_o.nested.x, 1.0);
    try std.testing.expectEqual(nested_o.nested.y, 2.0);

    const vec3 = Vec3{
        .x = 1.0,
        .y = 2.0,
        .z = 3.0,
    };

    try std.testing.expectEqual(vec3.x, 1.0);
    try std.testing.expectEqual(vec3.y, 2.0);
    try std.testing.expectEqual(vec3.z, 3.0);

    var vec3_o: Vec3 = undefined;
    const vec3_o_ptr: *Vec3 = &vec3_o;
    vec3_o_ptr.* = vec3;

    try std.testing.expectEqual(vec3_o.x, 1.0);
    try std.testing.expectEqual(vec3_o.y, 2.0);
    try std.testing.expectEqual(vec3_o.z, 3.0);

    const nested_vec3 = NestedVec3{
        .nested = Vec3{
            .x = 1.0,
            .y = 2.0,
            .z = 3.0,
        },
    };

    try std.testing.expectEqual(nested_vec3.nested.x, 1.0);
    try std.testing.expectEqual(nested_vec3.nested.y, 2.0);
    try std.testing.expectEqual(nested_vec3.nested.z, 3.0);

    var nested_vec3_o: NestedVec3 = undefined;
    const nested_vec3_o_ptr: *NestedVec3 = &nested_vec3_o;
    nested_vec3_o_ptr.* = nested_vec3;

    try std.testing.expectEqual(nested_vec3_o.nested.x, 1.0);
    try std.testing.expectEqual(nested_vec3_o.nested.y, 2.0);
    try std.testing.expectEqual(nested_vec3_o.nested.z, 3.0);

    const hld = packed struct {
        c: u64,
        d: u32,
    };

    const mld = packed struct {
        h: u64,
        i: u64,
    };

    const a = packed struct {
        b: hld,
        g: mld,
    };

    var arg = a{ .b = hld{ .c = 1, .d = 2 }, .g = mld{ .h = 6, .i = 8 } };
    try std.testing.expect(arg.b.c == 1);
    try std.testing.expect(arg.b.d == 2);
    try std.testing.expect(arg.g.h == 6);
    try std.testing.expect(arg.g.i == 8);
}

test "runtime init of unnamed packed struct type" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    var z: u8 = 123;
    try (packed struct {
        x: u8,
        pub fn m(s: @This()) !void {
            try expect(s.x == 123);
        }
    }{ .x = z }).m();
}

test "packed struct passed to callconv(.C) function" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_sparc64) return error.SkipZigTest; // TODO

    const S = struct {
        const Packed = packed struct {
            a: u16,
            b: bool = true,
            c: bool = true,
            d: u46 = 0,
        };

        fn foo(p: Packed, a1: u64, a2: u64, a3: u64, a4: u64, a5: u64) callconv(.C) bool {
            return p.a == 12345 and p.b == true and p.c == true and p.d == 0 and a1 == 5 and a2 == 4 and a3 == 3 and a4 == 2 and a5 == 1;
        }
    };
    const result = S.foo(S.Packed{
        .a = 12345,
        .b = true,
        .c = true,
    }, 5, 4, 3, 2, 1);
    try expect(result);
}

test "overaligned pointer to packed struct" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;

    const S = packed struct { a: u32, b: u32 };
    var foo: S align(4) = .{ .a = 123, .b = 456 };
    const ptr: *align(4) S = &foo;
    switch (comptime builtin.cpu.arch.endian()) {
        .Little => {
            const ptr_to_b: *u32 = &ptr.b;
            try expect(ptr_to_b.* == 456);
        },
        .Big => {
            // Byte aligned packed struct field pointers have not been implemented yet.
            const ptr_to_a: *align(4:0:8) u32 = &ptr.a;
            try expect(ptr_to_a.* == 123);
        },
    }
}

test "packed struct initialized in bitcast" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest; // TODO

    const T = packed struct { val: u8 };
    var val: u8 = 123;
    const t = @bitCast(u8, T{ .val = val });
    try expect(t == val);
}

test "pointer to container level packed struct field" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_arm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_x86_64) return error.SkipZigTest;

    const S = packed struct(u32) {
        test_bit: bool,
        someother_data: u12,
        other_test_bit: bool,
        someother_more_different_data: u12,
        other_bits: packed struct(u6) {
            enable_1: bool,
            enable_2: bool,
            enable_3: bool,
            enable_4: bool,
            enable_5: bool,
            enable_6: bool,
        },
        var arr = [_]u32{0} ** 2;
    };
    @ptrCast(*S, &S.arr[0]).other_bits.enable_3 = true;
    try expect(S.arr[0] == 0x10000000);
}
