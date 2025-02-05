const expect = @import("std").testing.expect;
const builtin = @import("builtin");

test "@fieldParentPtr struct" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = struct {
        a: bool = true,
        b: f32 = 3.14,
        c: struct { u8 } = .{42},
        d: i32 = 12345,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr extern struct" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = extern struct {
        a: bool = true,
        b: f32 = 3.14,
        c: extern struct { x: u8 } = .{ .x = 42 },
        d: i32 = 12345,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr extern struct first zero-bit field" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = extern struct {
        a: u0 = 0,
        b: f32 = 3.14,
        c: i32 = 12345,
    };

    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr extern struct middle zero-bit field" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = extern struct {
        a: f32 = 3.14,
        b: u0 = 0,
        c: i32 = 12345,
    };

    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr extern struct last zero-bit field" {
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = extern struct {
        a: f32 = 3.14,
        b: i32 = 12345,
        c: u0 = 0,
    };

    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = 0 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = 0 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = 0 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = 0 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr unaligned packed struct" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = packed struct {
        a: bool = true,
        b: f32 = 3.14,
        c: packed struct { x: u8 } = .{ .x = 42 },
        d: i32 = 12345,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr aligned packed struct" {
    if (builtin.zig_backend == .stage2_c) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = packed struct {
        a: f32 = 3.14,
        b: i32 = 12345,
        c: packed struct { x: u8 } = .{ .x = 42 },
        d: bool = true,
    };

    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = false };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = false };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = false };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = false };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr nested packed struct" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    {
        const C = packed struct {
            a: u8,
            b: packed struct {
                a: u8,
                b: packed struct {
                    a: u8,
                },
            },
        };

        {
            const c: C = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            const pcbba = &c.b.b.a;
            const pcbb: @TypeOf(&c.b.b) = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            const pcb: @TypeOf(&c.b) = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            const pc: *const C = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }

        {
            var c: C = undefined;
            c = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            var pcbba: @TypeOf(&c.b.b.a) = undefined;
            pcbba = &c.b.b.a;
            var pcbb: @TypeOf(&c.b.b) = undefined;
            pcbb = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            var pcb: @TypeOf(&c.b) = undefined;
            pcb = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            var pc: *C = undefined;
            pc = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }
    }

    {
        const C = packed struct {
            a: u8,
            b: packed struct {
                a: u9,
                b: packed struct {
                    a: u8,
                },
            },
        };

        {
            const c: C = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            const pcbba = &c.b.b.a;
            const pcbb: @TypeOf(&c.b.b) = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            const pcb: @TypeOf(&c.b) = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            const pc: *const C = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }

        {
            var c: C = undefined;
            c = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            var pcbba: @TypeOf(&c.b.b.a) = undefined;
            pcbba = &c.b.b.a;
            var pcbb: @TypeOf(&c.b.b) = undefined;
            pcbb = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            var pcb: @TypeOf(&c.b) = undefined;
            pcb = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            var pc: *C = undefined;
            pc = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }
    }

    {
        const C = packed struct {
            a: u9,
            b: packed struct {
                a: u7,
                b: packed struct {
                    a: u8,
                },
            },
        };

        {
            const c: C = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            const pcbba = &c.b.b.a;
            const pcbb: @TypeOf(&c.b.b) = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            const pcb: @TypeOf(&c.b) = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            const pc: *const C = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }

        {
            var c: C = undefined;
            c = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            var pcbba: @TypeOf(&c.b.b.a) = undefined;
            pcbba = &c.b.b.a;
            var pcbb: @TypeOf(&c.b.b) = undefined;
            pcbb = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            var pcb: @TypeOf(&c.b) = undefined;
            pcb = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            var pc: *C = undefined;
            pc = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }
    }

    {
        const C = packed struct {
            a: u9,
            b: packed struct {
                a: u8,
                b: packed struct {
                    a: u8,
                },
            },
        };

        {
            const c: C = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            const pcbba = &c.b.b.a;
            const pcbb: @TypeOf(&c.b.b) = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            const pcb: @TypeOf(&c.b) = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            const pc: *const C = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }

        {
            var c: C = undefined;
            c = .{ .a = 0, .b = .{ .a = 0, .b = .{ .a = 0 } } };
            var pcbba: @TypeOf(&c.b.b.a) = undefined;
            pcbba = &c.b.b.a;
            var pcbb: @TypeOf(&c.b.b) = undefined;
            pcbb = @alignCast(@fieldParentPtr("a", pcbba));
            try expect(pcbb == &c.b.b);
            var pcb: @TypeOf(&c.b) = undefined;
            pcb = @alignCast(@fieldParentPtr("b", pcbb));
            try expect(pcb == &c.b);
            var pc: *C = undefined;
            pc = @alignCast(@fieldParentPtr("b", pcb));
            try expect(pc == &c);
        }
    }
}

test "@fieldParentPtr packed struct first zero-bit field" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = packed struct {
        a: u0 = 0,
        b: f32 = 3.14,
        c: i32 = 12345,
    };

    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 666.667 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr packed struct middle zero-bit field" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = packed struct {
        a: f32 = 3.14,
        b: u0 = 0,
        c: i32 = 12345,
    };

    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = -1111111111 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr packed struct last zero-bit field" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = packed struct {
        a: f32 = 3.14,
        b: i32 = 12345,
        c: u0 = 0,
    };

    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 666.667 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = -1111111111 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = 0 };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = 0 };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = 0 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = 0 };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr tagged union" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = union(enum) {
        a: bool,
        b: f32,
        c: struct { u8 },
        d: i32,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr untagged union" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = union {
        a: bool,
        b: f32,
        c: struct { u8 },
        d: i32,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{255} };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr extern union" {
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = extern union {
        a: bool,
        b: f32,
        c: extern struct { x: u8 },
        d: i32,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr packed union" {
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_spirv64) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;
    if (builtin.target.cpu.arch.endian() == .big) return error.SkipZigTest; // TODO

    const C = packed union {
        a: bool,
        b: f32,
        c: packed struct { x: u8 },
        d: i32,
    };

    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = false };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        const pc: *const C = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        const pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .c = .{ .x = 255 } };
        var pcf: @TypeOf(&c.c) = undefined;
        pcf = &c.c;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("c", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        const pc: *const C = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        const pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .d = -1111111111 };
        var pcf: @TypeOf(&c.d) = undefined;
        pcf = &c.d;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("d", pcf));
        try expect(pc == &c);
    }
}

test "@fieldParentPtr tagged union all zero-bit fields" {
    if (builtin.zig_backend == .stage2_llvm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_wasm) return error.SkipZigTest;
    if (builtin.zig_backend == .stage2_riscv64) return error.SkipZigTest;

    const C = union(enum) {
        a: u0,
        b: i0,
    };

    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        const pc: *const C = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        const pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .a = 0 };
        var pcf: @TypeOf(&c.a) = undefined;
        pcf = &c.a;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("a", pcf));
        try expect(pc == &c);
    }

    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        const pc: *const C = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        const pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        const c: C = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *const C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
    {
        var c: C = undefined;
        c = .{ .b = 0 };
        var pcf: @TypeOf(&c.b) = undefined;
        pcf = &c.b;
        var pc: *C = undefined;
        pc = @alignCast(@fieldParentPtr("b", pcf));
        try expect(pc == &c);
    }
}
