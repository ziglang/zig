const builtin = @import("builtin");
const endian = builtin.cpu.arch.endian();
const testing = @import("std").testing;
const ptr_size = @sizeOf(usize);

test "type pun signed and unsigned as single pointer" {
    comptime {
        var x: u32 = 0;
        const y = @ptrCast(*i32, &x);
        y.* = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), x);
    }
}

test "type pun signed and unsigned as many pointer" {
    comptime {
        var x: u32 = 0;
        const y = @ptrCast([*]i32, &x);
        y[0] = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), x);
    }
}

test "type pun signed and unsigned as array pointer" {
    comptime {
        var x: u32 = 0;
        const y = @ptrCast(*[1]i32, &x);
        y[0] = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), x);
    }
}

test "type pun signed and unsigned as offset many pointer" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        var x: u32 = 0;
        var y = @ptrCast([*]i32, &x);
        y -= 10;
        y[10] = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), x);
    }
}

test "type pun signed and unsigned as array pointer" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        var x: u32 = 0;
        const y = @ptrCast([*]i32, &x) - 10;
        const z: *[15]i32 = y[0..15];
        z[10] = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), x);
    }
}

test "type pun value and struct" {
    comptime {
        const StructOfU32 = extern struct { x: u32 };
        var inst: StructOfU32 = .{ .x = 0 };
        @ptrCast(*i32, &inst.x).* = -1;
        try testing.expectEqual(@as(u32, 0xFFFFFFFF), inst.x);
        @ptrCast(*i32, &inst).* = -2;
        try testing.expectEqual(@as(u32, 0xFFFFFFFE), inst.x);
    }
}

fn bigToNativeEndian(comptime T: type, v: T) T {
    return if (endian == .Big) v else @byteSwap(v);
}
test "type pun endianness" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO

    comptime {
        const StructOfBytes = extern struct { x: [4]u8 };
        var inst: StructOfBytes = .{ .x = [4]u8{ 0, 0, 0, 0 } };
        const structPtr = @ptrCast(*align(1) u32, &inst);
        const arrayPtr = @ptrCast(*align(1) u32, &inst.x);
        inst.x[0] = 0xFE;
        inst.x[2] = 0xBE;
        try testing.expectEqual(bigToNativeEndian(u32, 0xFE00BE00), structPtr.*);
        try testing.expectEqual(bigToNativeEndian(u32, 0xFE00BE00), arrayPtr.*);
        structPtr.* = bigToNativeEndian(u32, 0xDEADF00D);
        try testing.expectEqual(bigToNativeEndian(u32, 0xDEADF00D), structPtr.*);
        try testing.expectEqual(bigToNativeEndian(u32, 0xDEADF00D), arrayPtr.*);
        try testing.expectEqual(@as(u8, 0xDE), inst.x[0]);
        try testing.expectEqual(@as(u8, 0xAD), inst.x[1]);
        try testing.expectEqual(@as(u8, 0xF0), inst.x[2]);
        try testing.expectEqual(@as(u8, 0x0D), inst.x[3]);
    }
}

const Bits = packed struct {
    // Note: This struct has only single byte words so it
    // doesn't need to be byte swapped.
    p0: u1,
    p1: u4,
    p2: u3,
    p3: u2,
    p4: u6,
    p5: u8,
    p6: u7,
    p7: u1,
};
const ShuffledBits = packed struct {
    p1: u4,
    p3: u2,
    p7: u1,
    p0: u1,
    p5: u8,
    p2: u3,
    p6: u7,
    p4: u6,
};
fn shuffle(ptr: usize, comptime From: type, comptime To: type) usize {
    if (@sizeOf(From) != @sizeOf(To))
        @compileError("Mismatched sizes! " ++ @typeName(From) ++ " and " ++ @typeName(To) ++ " must have the same size!");
    const array_len = @divExact(ptr_size, @sizeOf(From));
    var result: usize = 0;
    const pSource = @ptrCast(*align(1) const [array_len]From, &ptr);
    const pResult = @ptrCast(*align(1) [array_len]To, &result);
    var i: usize = 0;
    while (i < array_len) : (i += 1) {
        inline for (@typeInfo(To).Struct.fields) |f| {
            @field(pResult[i], f.name) = @field(pSource[i], f.name);
        }
    }
    return result;
}

fn doTypePunBitsTest(as_bits: *Bits) !void {
    const as_u32 = @ptrCast(*align(1) u32, as_bits);
    const as_bytes = @ptrCast(*[4]u8, as_bits);
    as_u32.* = bigToNativeEndian(u32, 0xB0A7DEED);
    try testing.expectEqual(@as(u1, 0x00), as_bits.p0);
    try testing.expectEqual(@as(u4, 0x08), as_bits.p1);
    try testing.expectEqual(@as(u3, 0x05), as_bits.p2);
    try testing.expectEqual(@as(u2, 0x03), as_bits.p3);
    try testing.expectEqual(@as(u6, 0x29), as_bits.p4);
    try testing.expectEqual(@as(u8, 0xDE), as_bits.p5);
    try testing.expectEqual(@as(u7, 0x6D), as_bits.p6);
    try testing.expectEqual(@as(u1, 0x01), as_bits.p7);

    as_bits.p6 = 0x2D;
    as_bits.p1 = 0x0F;
    try testing.expectEqual(bigToNativeEndian(u32, 0xBEA7DEAD), as_u32.*);

    // clobbering one bit doesn't clobber the word
    as_bits.p7 = undefined;
    try testing.expectEqual(@as(u7, 0x2D), as_bits.p6);
    // even when read as a whole
    const u = as_u32.*;
    _ = u; // u is undefined
    try testing.expectEqual(@as(u7, 0x2D), as_bits.p6);
    // or if a field which shares the byte is modified
    as_bits.p6 = 0x6D;
    try testing.expectEqual(@as(u7, 0x6D), as_bits.p6);

    // but overwriting the undefined will clear it
    as_bytes[3] = 0xAF;
    try testing.expectEqual(bigToNativeEndian(u32, 0xBEA7DEAF), as_u32.*);
}

test "type pun bits" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        var v: u32 = undefined;
        try doTypePunBitsTest(@ptrCast(*Bits, &v));
    }
}

const imports = struct {
    var global_u32: u32 = 0;
};

// Make sure lazy values work on their own, before getting into more complex tests
test "basic pointer preservation" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        const lazy_address = @ptrToInt(&imports.global_u32);
        try testing.expectEqual(@ptrToInt(&imports.global_u32), lazy_address);
        try testing.expectEqual(&imports.global_u32, @intToPtr(*u32, lazy_address));
    }
}

test "byte copy preserves linker value" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    const ct_value = comptime blk: {
        const lazy = &imports.global_u32;
        var result: *u32 = undefined;
        const pSource = @ptrCast(*const [ptr_size]u8, &lazy);
        const pResult = @ptrCast(*[ptr_size]u8, &result);
        var i: usize = 0;
        while (i < ptr_size) : (i += 1) {
            pResult[i] = pSource[i];
            try testing.expectEqual(pSource[i], pResult[i]);
        }
        try testing.expectEqual(&imports.global_u32, result);
        break :blk result;
    };

    try testing.expectEqual(&imports.global_u32, ct_value);
}

test "unordered byte copy preserves linker value" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    const ct_value = comptime blk: {
        const lazy = &imports.global_u32;
        var result: *u32 = undefined;
        const pSource = @ptrCast(*const [ptr_size]u8, &lazy);
        const pResult = @ptrCast(*[ptr_size]u8, &result);
        if (ptr_size > 8) @compileError("This array needs to be expanded for platform with very big pointers");
        const shuffled_indices = [_]usize{ 4, 5, 2, 6, 1, 3, 0, 7 };
        for (shuffled_indices) |i| {
            pResult[i] = pSource[i];
            try testing.expectEqual(pSource[i], pResult[i]);
        }
        try testing.expectEqual(&imports.global_u32, result);
        break :blk result;
    };

    try testing.expectEqual(&imports.global_u32, ct_value);
}

test "shuffle chunks of linker value" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    const lazy_address = @ptrToInt(&imports.global_u32);
    const shuffled1_rt = shuffle(lazy_address, Bits, ShuffledBits);
    const unshuffled1_rt = shuffle(shuffled1_rt, ShuffledBits, Bits);
    try testing.expectEqual(lazy_address, unshuffled1_rt);
    const shuffled1_ct = comptime shuffle(lazy_address, Bits, ShuffledBits);
    const shuffled1_ct_2 = comptime shuffle(lazy_address, Bits, ShuffledBits);
    comptime try testing.expectEqual(shuffled1_ct, shuffled1_ct_2);
    const unshuffled1_ct = comptime shuffle(shuffled1_ct, ShuffledBits, Bits);
    comptime try testing.expectEqual(lazy_address, unshuffled1_ct);
    try testing.expectEqual(shuffled1_ct, shuffled1_rt);
}

test "dance on linker values" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        var arr: [2]usize = undefined;
        arr[0] = @ptrToInt(&imports.global_u32);
        arr[1] = @ptrToInt(&imports.global_u32);

        const weird_ptr = @ptrCast([*]Bits, @ptrCast([*]u8, &arr) + @sizeOf(usize) - 3);
        try doTypePunBitsTest(&weird_ptr[0]);
        if (ptr_size > @sizeOf(Bits))
            try doTypePunBitsTest(&weird_ptr[1]);

        var arr_bytes = @ptrCast(*[2][ptr_size]u8, &arr);

        var rebuilt_bytes: [ptr_size]u8 = undefined;
        var i: usize = 0;
        while (i < ptr_size - 3) : (i += 1) {
            rebuilt_bytes[i] = arr_bytes[0][i];
        }
        while (i < ptr_size) : (i += 1) {
            rebuilt_bytes[i] = arr_bytes[1][i];
        }

        try testing.expectEqual(&imports.global_u32, @intToPtr(*u32, @bitCast(usize, rebuilt_bytes)));
    }
}

test "offset array ptr by element size" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        const VirtualStruct = struct { x: u32 };
        var arr: [4]VirtualStruct = .{
            .{ .x = bigToNativeEndian(u32, 0x0004080c) },
            .{ .x = bigToNativeEndian(u32, 0x0105090d) },
            .{ .x = bigToNativeEndian(u32, 0x02060a0e) },
            .{ .x = bigToNativeEndian(u32, 0x03070b0f) },
        };

        const address = @ptrToInt(&arr);
        try testing.expectEqual(@ptrToInt(&arr[0]), address);
        try testing.expectEqual(@ptrToInt(&arr[0]) + 10, address + 10);
        try testing.expectEqual(@ptrToInt(&arr[1]), address + @sizeOf(VirtualStruct));
        try testing.expectEqual(@ptrToInt(&arr[2]), address + 2 * @sizeOf(VirtualStruct));
        try testing.expectEqual(@ptrToInt(&arr[3]), address + @sizeOf(VirtualStruct) * 3);

        const secondElement = @intToPtr(*VirtualStruct, @ptrToInt(&arr[0]) + 2 * @sizeOf(VirtualStruct));
        try testing.expectEqual(bigToNativeEndian(u32, 0x02060a0e), secondElement.x);
    }
}

test "offset instance by field size" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        const VirtualStruct = struct { x: u32, y: u32, z: u32, w: u32 };
        var inst = VirtualStruct{ .x = 0, .y = 1, .z = 2, .w = 3 };

        var ptr = @ptrToInt(&inst);
        ptr -= 4;
        ptr += @offsetOf(VirtualStruct, "x");
        try testing.expectEqual(@as(u32, 0), @intToPtr([*]u32, ptr)[1]);
        ptr -= @offsetOf(VirtualStruct, "x");
        ptr += @offsetOf(VirtualStruct, "y");
        try testing.expectEqual(@as(u32, 1), @intToPtr([*]u32, ptr)[1]);
        ptr = ptr - @offsetOf(VirtualStruct, "y") + @offsetOf(VirtualStruct, "z");
        try testing.expectEqual(@as(u32, 2), @intToPtr([*]u32, ptr)[1]);
        ptr = @ptrToInt(&inst.z) - 4 - @offsetOf(VirtualStruct, "z");
        ptr += @offsetOf(VirtualStruct, "w");
        try testing.expectEqual(@as(u32, 3), @intToPtr(*u32, ptr + 4).*);
    }
}

test "offset field ptr by enclosing array element size" {
    if (true) {
        // TODO https://github.com/ziglang/zig/issues/9646
        return error.SkipZigTest;
    }

    comptime {
        const VirtualStruct = struct { x: u32 };
        var arr: [4]VirtualStruct = .{
            .{ .x = bigToNativeEndian(u32, 0x0004080c) },
            .{ .x = bigToNativeEndian(u32, 0x0105090d) },
            .{ .x = bigToNativeEndian(u32, 0x02060a0e) },
            .{ .x = bigToNativeEndian(u32, 0x03070b0f) },
        };

        var i: usize = 0;
        while (i < 4) : (i += 1) {
            var ptr: [*]u8 = @ptrCast([*]u8, &arr[0]);
            ptr += i;
            ptr += @offsetOf(VirtualStruct, "x");
            var j: usize = 0;
            while (j < 4) : (j += 1) {
                const base = ptr + j * @sizeOf(VirtualStruct);
                try testing.expectEqual(@intCast(u8, i * 4 + j), base[0]);
            }
        }
    }
}

test "accessing reinterpreted memory of parent object" {
    if (builtin.zig_backend == .stage2_aarch64) return error.SkipZigTest; // TODO
    const S = extern struct {
        a: f32,
        b: [4]u8,
        c: f32,
    };
    const expected = if (endian == .Little) 102 else 38;

    comptime {
        const x = S{
            .a = 1.5,
            .b = [_]u8{ 1, 2, 3, 4 },
            .c = 2.6,
        };
        const ptr = &x.b[0];
        const b = @ptrCast([*c]const u8, ptr)[5];
        try testing.expect(b == expected);
    }
}

test "bitcast packed union to integer" {
    const U = packed union {
        x: u1,
        y: u2,
    };

    comptime {
        const a = U{ .x = 1 };
        const b = U{ .y = 2 };
        const cast_a = @bitCast(u2, a);
        const cast_b = @bitCast(u2, b);

        // truncated because the upper bit is garbage memory that we don't care about
        try testing.expectEqual(@as(u1, 1), @truncate(u1, cast_a));
        try testing.expectEqual(@as(u2, 2), cast_b);
    }
}
