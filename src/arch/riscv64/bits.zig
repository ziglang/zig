const std = @import("std");
const DW = std.dwarf;
const assert = std.debug.assert;
const testing = std.testing;
const Encoding = @import("Encoding.zig");
const Mir = @import("Mir.zig");

pub const Memory = struct {
    base: Base,
    mod: Mod,

    pub const Base = union(enum) {
        reg: Register,
        frame: FrameIndex,
        reloc: Symbol,
    };

    pub const Mod = union(enum(u1)) {
        rm: struct {
            size: Size,
            disp: i32 = 0,
        },
        off: i32,
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
                1 => .byte,
                2 => .hword,
                4 => .word,
                8 => .dword,
                else => unreachable,
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
        const offset: i32 = switch (mem.mod) {
            .off => |off| off,
            .rm => |rm| rm.disp,
        };

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
            .reloc => unreachable,
        }
    }
};

pub const Immediate = union(enum) {
    signed: i32,
    unsigned: u32,

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

    pub fn asUnsigned(imm: Immediate, bit_size: u64) u64 {
        return switch (imm) {
            .signed => |x| switch (bit_size) {
                1, 8 => @as(u8, @bitCast(@as(i8, @intCast(x)))),
                16 => @as(u16, @bitCast(@as(i16, @intCast(x)))),
                32, 64 => @as(u32, @bitCast(x)),
                else => unreachable,
            },
            .unsigned => |x| switch (bit_size) {
                1, 8 => @as(u8, @intCast(x)),
                16 => @as(u16, @intCast(x)),
                32 => @as(u32, @intCast(x)),
                64 => x,
                else => unreachable,
            },
        };
    }

    pub fn asBits(imm: Immediate, comptime T: type) T {
        const int_info = @typeInfo(T).Int;
        if (int_info.signedness != .unsigned) @compileError("Immediate.asBits needs unsigned T");
        return switch (imm) {
            .signed => |x| @bitCast(@as(std.meta.Int(.signed, int_info.bits), @intCast(x))),
            .unsigned => |x| @intCast(x),
        };
    }
};

pub const Register = enum(u6) {
    // zig fmt: off
    x0,  x1,  x2,  x3,  x4,  x5,  x6,  x7,
    x8,  x9,  x10, x11, x12, x13, x14, x15,
    x16, x17, x18, x19, x20, x21, x22, x23,
    x24, x25, x26, x27, x28, x29, x30, x31,

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
    // zig fmt: on

    /// Returns the unique 5-bit ID of this register which is used in
    /// the machine code
    pub fn id(self: Register) u5 {
        return @as(u5, @truncate(@intFromEnum(self)));
    }

    pub fn dwarfLocOp(reg: Register) u8 {
        return @as(u8, reg.id());
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
    /// This index referes to the frame where callee saved registers are spilled and restore
    /// from.
    spill_frame,
    /// Other indices are used for local variable stack slots
    _,

    pub const named_count = @typeInfo(FrameIndex).Enum.fields.len;

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
