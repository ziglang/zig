const std = @import("std");
const expectEqual = std.testing.expectEqual;

pub const Register = enum(u8) {
    // zig fmt: off
    // integer registers
    r0, r1, r2, r3, r4, r5, r6, r7,
    r8, r9, r10, r11, r12, r13, r14, r15,
    r16, r17, r18, r19, r20, r21, r22, r23,
    r24, r25, r26, r27, r28, r29, r30, r31,

    // float-point registers
    f0, f1, f2, f3, f4, f5, f6, f7,
    f8, f9, f10, f11, f12, f13, f14, f15,
    f16, f17, f18, f19, f20, f21, f22, f23,
    f24, f25, f26, f27, f28, f29, f30, f31,

    // LSX registers
    v0, v1, v2, v3, v4, v5, v6, v7,
    v8, v9, v10, v11, v12, v13, v14, v15,
    v16, v17, v18, v19, v20, v21, v22, v23,
    v24, v25, v26, v27, v28, v29, v30, v31,

    // LASX registers
    x0, x1, x2, x3, x4, x5, x6, x7,
    x8, x9, x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,

    // float-point condition code registers
    fcc0, fcc1, fcc2, fcc3, fcc4, fcc5, fcc6, fcc7,
    // zig fmt: on

    pub const zero = Register.r0;
    pub const ra = Register.r1;
    pub const tp = Register.r2;
    pub const sp = Register.r3;
    pub const fp = Register.r22;

    pub const Class = enum {
        int,
        float,
        lsx,
        lasx,
        fcc,
    };

    pub fn class(reg: Register) Class {
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.r0)...@intFromEnum(Register.r31) => .int,
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31) => .float,
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31) => .lsx,
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31) => .lasx,
            @intFromEnum(Register.fcc0)...@intFromEnum(Register.fcc7) => .fcc,
            else => unreachable,
        };
    }

    pub fn id(reg: Register) u8 {
        // LSX and LASX registers are aliased to float-point registers
        // because their lower bits are shared
        const base: u8 = switch (@intFromEnum(reg)) {
            @intFromEnum(Register.r0)...@intFromEnum(Register.r31) => 0,
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31) => 32,
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31) => 32,
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31) => 32,
            @intFromEnum(Register.fcc0)...@intFromEnum(Register.fcc7) => 64,
            else => unreachable,
        };
        return @as(u8, @intCast(reg.enc())) + base;
    }

    pub fn enc(reg: Register) u5 {
        const base: u8 = switch (@intFromEnum(reg)) {
            @intFromEnum(Register.r0)...@intFromEnum(Register.r31) => @intFromEnum(Register.r0),
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31) => @intFromEnum(Register.f0),
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31) => @intFromEnum(Register.v0),
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31) => @intFromEnum(Register.x0),
            @intFromEnum(Register.fcc0)...@intFromEnum(Register.fcc7) => @intFromEnum(Register.fcc0),
            else => unreachable,
        };
        return @intCast(@intFromEnum(reg) - base);
    }

    pub fn bitSize(reg: Register) u10 {
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.r0)...@intFromEnum(Register.r31) => 64,
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31) => 64,
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31) => 128,
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31) => 256,
            @intFromEnum(Register.fcc0)...@intFromEnum(Register.fcc7) => 1,
            else => unreachable,
        };
    }

    pub fn dwarfNum(reg: Register) u6 {
        return switch (reg.class()) {
            .int => @as(u6, reg.id()),
            .float => 32 + @as(u6, reg.id()),
            // TODO
            .lsx, .lasx => unreachable,
            .fcc => unreachable,
        };
    }

    /// Converts a FP/LSX/LASX register to FP register.
    pub fn toFloat(reg: Register) Register {
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31) => reg,
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31),
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31),
            => @enumFromInt(@intFromEnum(Register.f0) + reg.enc()),
            else => unreachable,
        };
    }

    /// Converts a FP/LSX/LASX register to LSX register.
    pub fn toLsx(reg: Register) Register {
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31) => reg,
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31),
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31),
            => @enumFromInt(@intFromEnum(Register.v0) + reg.enc()),
            else => unreachable,
        };
    }

    /// Converts a FP/LSX/LASX register to LASX register.
    pub fn toLasx(reg: Register) Register {
        return switch (@intFromEnum(reg)) {
            @intFromEnum(Register.x0)...@intFromEnum(Register.x31) => reg,
            @intFromEnum(Register.f0)...@intFromEnum(Register.f31),
            @intFromEnum(Register.v0)...@intFromEnum(Register.v31),
            => @enumFromInt(@intFromEnum(Register.x0) + reg.enc()),
            else => unreachable,
        };
    }
};

test "register classes" {
    try expectEqual(.int, Register.r0.class());
    try expectEqual(.int, Register.r31.class());
    try expectEqual(.float, Register.f0.class());
    try expectEqual(.float, Register.f31.class());
    try expectEqual(.lsx, Register.v0.class());
    try expectEqual(.lsx, Register.v31.class());
    try expectEqual(.lasx, Register.x0.class());
    try expectEqual(.lasx, Register.x31.class());
    try expectEqual(.fcc, Register.fcc0.class());
    try expectEqual(.fcc, Register.fcc7.class());
}

test "register id" {
    try expectEqual(0, Register.r0.enc());
    try expectEqual(31, Register.r31.enc());
    try expectEqual(0, Register.f0.enc());
    try expectEqual(31, Register.f31.enc());
    try expectEqual(0, Register.v0.enc());
    try expectEqual(31, Register.v31.enc());
    try expectEqual(0, Register.x0.enc());
    try expectEqual(31, Register.x31.enc());
    try expectEqual(0, Register.fcc0.enc());
    try expectEqual(7, Register.fcc7.enc());
}

test "register encoding" {
    try expectEqual(0, Register.r0.id());
    try expectEqual(31, Register.r31.id());
    try expectEqual(32, Register.f0.id());
    try expectEqual(63, Register.f31.id());
    try expectEqual(32, Register.v0.id());
    try expectEqual(63, Register.v31.id());
    try expectEqual(32, Register.x0.id());
    try expectEqual(63, Register.x31.id());
    try expectEqual(64, Register.fcc0.id());
    try expectEqual(71, Register.fcc7.id());
}

pub const FrameIndex = enum(u32) {
    // This index refers to the start of the arguments passed to this function
    args_frame,
    // This index refers to the return address pushed in the prologue.
    ret_addr,
    // This index refers to the base pointer pushed in the prologue and popped in the epilogue.
    base_ptr,
    // This index refers to the entire stack frame.
    stack_frame,
    // This index refers to the start of the call frame for arguments passed to called functions
    call_frame,
    /// Other indices are used for local variable stack slots
    _,

    pub const named_count = @typeInfo(FrameIndex).@"enum".fields.len;

    pub fn isNamed(fi: FrameIndex) bool {
        return @intFromEnum(fi) < named_count;
    }

    pub fn format(
        fi: FrameIndex,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        try writer.writeAll("FrameIndex");
        if (fi.isNamed()) {
            try writer.writeByte('.');
            try writer.writeAll(@tagName(fi));
        } else {
            try writer.writeByte('(');
            try std.fmt.formatType(@intFromEnum(fi), fmt, options, writer, 0);
            try writer.writeByte(')');
        }
    }
};

pub const FrameAddr = struct { index: FrameIndex, off: i32 = 0 };

pub const RegisterOffset = struct { reg: Register, off: i32 = 0 };

pub const SymbolOffset = struct { index: u32, off: i32 = 0 };

pub const RegisterFrame = struct { reg: Register, frame: FrameAddr };
