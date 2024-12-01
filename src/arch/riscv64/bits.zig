const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;
const Target = std.Target;

const Zcu = @import("../../Zcu.zig");
const Mir = @import("Mir.zig");
const abi = @import("abi.zig");

pub const Memory = struct {
    base: Base,
    mod: Mod,

    pub const Base = union(enum) {
        reg: Register,
        frame: FrameIndex,
    };

    pub const Mod = struct {
        size: Size,
        unsigned: bool,
        disp: i32 = 0,
    };

    pub const Size = enum(u4) {
        /// Byte, 1 byte
        byte,
        /// Half word, 2 bytes
        hword,
        /// Word, 4 bytes
        word,
        /// Double word, 8 Bytes
        dword,

        pub fn fromByteSize(size: u64) Size {
            return switch (size) {
                1...1 => .byte,
                2...2 => .hword,
                3...4 => .word,
                5...8 => .dword,
                else => std.debug.panic("fromByteSize {}", .{size}),
            };
        }

        pub fn fromBitSize(bit_size: u64) Size {
            return switch (bit_size) {
                8 => .byte,
                16 => .hword,
                32 => .word,
                64 => .dword,
                else => unreachable,
            };
        }

        pub fn bitSize(s: Size) u64 {
            return switch (s) {
                .byte => 8,
                .hword => 16,
                .word => 32,
                .dword => 64,
            };
        }
    };

    /// Asserts `mem` can be represented as a `FrameLoc`.
    pub fn toFrameLoc(mem: Memory, mir: Mir) Mir.FrameLoc {
        const offset: i32 = mem.mod.disp;

        switch (mem.base) {
            .reg => |reg| {
                return .{
                    .base = reg,
                    .disp = offset,
                };
            },
            .frame => |index| {
                const base_loc = mir.frame_locs.get(@intFromEnum(index));
                return .{
                    .base = base_loc.base,
                    .disp = base_loc.disp + offset,
                };
            },
        }
    }
};

pub const Immediate = union(enum) {
    signed: i32,
    unsigned: u64,

    pub fn u(x: u64) Immediate {
        return .{ .unsigned = x };
    }

    pub fn s(x: i32) Immediate {
        return .{ .signed = x };
    }

    pub fn asSigned(imm: Immediate, bit_size: u64) i64 {
        return switch (imm) {
            .signed => |x| switch (bit_size) {
                1, 8 => @as(i8, @intCast(x)),
                16 => @as(i16, @intCast(x)),
                32, 64 => x,
                else => unreachable,
            },
            .unsigned => |x| switch (bit_size) {
                1, 8 => @as(i8, @bitCast(@as(u8, @intCast(x)))),
                16 => @as(i16, @bitCast(@as(u16, @intCast(x)))),
                32 => @as(i32, @bitCast(@as(u32, @intCast(x)))),
                64 => @bitCast(x),
                else => unreachable,
            },
        };
    }

    pub fn asBits(imm: Immediate, comptime T: type) T {
        const int_info = @typeInfo(T).int;
        if (int_info.signedness != .unsigned) @compileError("Immediate.asBits needs unsigned T");
        return switch (imm) {
            .signed => |x| @bitCast(@as(std.meta.Int(.signed, int_info.bits), @intCast(x))),
            .unsigned => |x| @intCast(x),
        };
    }
};

pub const CSR = enum(u12) {
    vl = 0xC20,
    vtype = 0xC21,
    vlenb = 0xC22,
};

pub const Register = enum(u8) {
    // zig fmt: off

    // base extension registers

    zero, // zero
    ra, // return address. caller saved
    sp, // stack pointer. callee saved.
    gp, // global pointer
    tp, // thread pointer
    t0, t1, t2, // temporaries. caller saved.
    s0, // s0/fp, callee saved.
    s1, // callee saved.
    a0, a1, // fn args/return values. caller saved.
    a2, a3, a4, a5, a6, a7, // fn args. caller saved.
    s2, s3, s4, s5, s6, s7, s8, s9, s10, s11, // saved registers. callee saved.
    t3, t4, t5, t6, // caller saved

    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
    x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,


    // F extension registers

    ft0, ft1, ft2, ft3, ft4, ft5, ft6, ft7, // float temporaries. caller saved.
    fs0, fs1, // float saved. callee saved.
    fa0, fa1, // float arg/ret. caller saved.
    fa2, fa3, fa4, fa5, fa6, fa7, // float arg. called saved.
    fs2, fs3, fs4, fs5, fs6, fs7, fs8, fs9, fs10, fs11,  // float saved. callee saved.
    ft8, ft9, ft10, ft11, // foat temporaries. calller saved.

    // this register is accessed only through API instructions instead of directly
    // fcsr, 

    f0, f1,  f2,  f3,  f4,  f5,  f6,  f7,  
    f8, f9,  f10, f11, f12, f13, f14, f15, 
    f16, f17, f18, f19, f20, f21, f22, f23, 
    f24, f25, f26, f27, f28, f29, f30, f31, 


    // V extension registers
    v0,  v1,  v2,  v3,  v4,  v5,  v6,  v7,
    v8,  v9,  v10, v11, v12, v13, v14, v15,
    v16, v17, v18, v19, v20, v21, v22, v23,
    v24, v25, v26, v27, v28, v29, v30, v31,

    // zig fmt: on

    /// in RISC-V registers are stored as 5 bit IDs and a register can have
    /// two names. Example being `zero` and `x0` are the same register and have the
    /// same ID, but are two different entries in the enum. We store floating point
    /// registers in the same enum. RISC-V uses the same IDs for `f0` and `x0` by
    /// infering which register is being talked about given the instruction it's in.
    ///
    /// The goal of this function is to return the same ID for `zero` and `x0` but two
    /// seperate IDs for `x0` and `f0`. We will assume that each register set has 32 registers
    /// and is repeated twice, once for the named version, once for the number version.
    pub fn id(reg: Register) std.math.IntFittingRange(0, @typeInfo(Register).@"enum".fields.len) {
        const base = switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.zero) ... @intFromEnum(Register.x31) => @intFromEnum(Register.zero),
            @intFromEnum(Register.ft0)  ... @intFromEnum(Register.f31) => @intFromEnum(Register.ft0),
            @intFromEnum(Register.v0)   ... @intFromEnum(Register.v31) => @intFromEnum(Register.v0),
            else => unreachable,
            // zig fmt: on
        };

        return @intCast(base + reg.encodeId());
    }

    pub fn encodeId(reg: Register) u5 {
        return @truncate(@intFromEnum(reg));
    }

    pub fn dwarfNum(reg: Register) u8 {
        return reg.id();
    }

    pub fn bitSize(reg: Register, zcu: *const Zcu) u32 {
        const features = zcu.getTarget().cpu.features;

        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.zero) ... @intFromEnum(Register.x31) => 64,
            @intFromEnum(Register.ft0)  ... @intFromEnum(Register.f31) => if (Target.riscv.featureSetHas(features, .d)) 64 else 32,
            @intFromEnum(Register.v0)   ... @intFromEnum(Register.v31) => 256, // TODO: look at suggestVectorSize
            else => unreachable,
            // zig fmt: on
        };
    }

    pub fn class(reg: Register) abi.RegisterClass {
        return switch (@intFromEnum(reg)) {
            // zig fmt: off
            @intFromEnum(Register.zero) ... @intFromEnum(Register.x31) => .int,
            @intFromEnum(Register.ft0)  ... @intFromEnum(Register.f31) => .float,
            @intFromEnum(Register.v0)   ... @intFromEnum(Register.v31) => .vector,
            else => unreachable,
            // zig fmt: on
        };
    }
};

pub const FrameIndex = enum(u32) {
    /// This index refers to the return address.
    ret_addr,
    /// This index refers to the frame pointer.
    base_ptr,
    /// This index refers to the entire stack frame.
    stack_frame,
    /// This index referes to where in the stack frame the args are spilled to.
    args_frame,
    /// This index referes to a frame dedicated to setting up args for function called
    /// in this function. Useful for aligning args separately.
    call_frame,
    /// This index referes to the frame where callee saved registers are spilled and restored from.
    spill_frame,
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

/// A linker symbol not yet allocated in VM.
pub const Symbol = struct {
    /// Index of the containing atom.
    atom_index: u32,
    /// Index into the linker's symbol table.
    sym_index: u32,
};

pub const VType = packed struct(u8) {
    vlmul: VlMul,
    vsew: VSew,
    vta: bool,
    vma: bool,
};

const VSew = enum(u3) {
    @"8" = 0b000,
    @"16" = 0b001,
    @"32" = 0b010,
    @"64" = 0b011,
};

const VlMul = enum(u3) {
    mf8 = 0b101,
    mf4 = 0b110,
    mf2 = 0b111,
    m1 = 0b000,
    m2 = 0b001,
    m4 = 0b010,
    m8 = 0b011,
};
