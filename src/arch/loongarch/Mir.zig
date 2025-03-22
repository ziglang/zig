//! Machine Intermediate Representation.
//! This data is produced by CodeGen.zig

const Mir = @This();
const std = @import("std");
const IntegerBitSet = std.bit_set.IntegerBitSet;

const bits = @import("bits.zig");
const Register = bits.Register;
const Lir = @import("Lir.zig");
const encoding = @import("encoding.zig");
const InternPool = @import("../../InternPool.zig");

instructions: std.MultiArrayList(Inst).Slice,
frame_locs: std.MultiArrayList(FrameLoc).Slice,

pub const Inst = struct {
    tag: Tag,
    /// The meaning of this depends on `tag`.
    data: Data,

    pub const Index = u32;

    pub const Tag = enum(u16) {
        _,

        pub fn fromInst(opcode: encoding.OpCode) Tag {
            return @enumFromInt(@intFromEnum(opcode));
        }

        pub fn fromPseudo(tag: PseudoTag) Tag {
            return @enumFromInt(@as(u16, @intFromEnum(tag)) | (1 << 15));
        }

        pub fn unwrap(tag: Tag) union(enum) { pseudo: PseudoTag, inst: encoding.OpCode } {
            if ((@intFromEnum(tag) & (1 << 15)) != 0) {
                return .{ .pseudo = @enumFromInt(@intFromEnum(tag) & ~@as(u16, @intCast((1 << 15)))) };
            } else {
                return .{ .inst = @enumFromInt(@intFromEnum(tag)) };
            }
        }
    };

    pub const PseudoTag = enum {
        /// Prologue of a function, uses `none` payload.
        func_prologue,
        /// Epilogue of a function, uses `none` payload.
        func_epilogue,
        /// Jump to epilogue, uses `none` payload.
        jump_to_epilogue,
        /// Spills general-purpose registers, uses `reg_list` payload.
        spill_gp_regs,
        /// Restores general-purpose registers, uses `reg_list` payload.
        restore_gp_regs,
    };

    pub const Data = union {
        pub const none = undefined;

        op: encoding.Data,

        /// Register list.
        reg_list: Mir.RegisterList,
        /// Debug line and column position.
        line_column: struct {
            line: u32,
            column: u32,
        },
    };

    pub fn initInst(opcode: encoding.OpCode, data: encoding.Data) Inst {
        return .{ .tag = .fromInst(opcode), .data = .{ .op = data } };
    }

    pub fn format(
        inst: Inst,
        comptime _: []const u8,
        _: std.fmt.FormatOptions,
        writer: anytype,
    ) @TypeOf(writer).Error!void {
        switch (inst.tag.unwrap()) {
            .pseudo => |tag| {
                switch (tag) {
                    else => try writer.print(".pseudo.{s}", .{@tagName(tag)}),
                }
            },
            .inst => |opcode| {
                try writer.print("{}", .{Lir.Inst{ .opcode = opcode, .data = inst.data.op }});
            },
        }
    }
};

pub fn deinit(mir: *Mir, gpa: std.mem.Allocator) void {
    mir.instructions.deinit(gpa);
    mir.frame_locs.deinit(gpa);
    mir.* = undefined;
}

pub const FrameLoc = struct {
    base: Register,
    offset: i32,
};

/// Used in conjunction with payload to transfer a list of used registers in a compact manner.
pub const RegisterList = struct {
    bitset: BitSet,

    const BitSet = IntegerBitSet(32);
    const Self = @This();

    pub const empty: RegisterList = .{ .bitset = .initEmpty() };

    fn getIndexForReg(registers: []const Register, reg: Register) BitSet.MaskInt {
        for (registers, 0..) |cpreg, i| {
            if (reg.id() == cpreg.id()) return @intCast(i);
        }
        unreachable; // register not in input register list!
    }

    pub fn push(self: *Self, registers: []const Register, reg: Register) void {
        const index = getIndexForReg(registers, reg);
        self.bitset.set(index);
    }

    pub fn isSet(self: Self, registers: []const Register, reg: Register) bool {
        const index = getIndexForReg(registers, reg);
        return self.bitset.isSet(index);
    }

    pub fn iterator(self: Self, comptime options: std.bit_set.IteratorOptions) BitSet.Iterator(options) {
        return self.bitset.iterator(options);
    }

    pub fn count(self: Self) i32 {
        return @intCast(self.bitset.count());
    }

    pub fn size(self: Self, target: *const std.Target) i32 {
        return @intCast(self.bitset.count() * @as(u4, switch (target.cpu.arch) {
            else => unreachable,
            .loongarch32 => 4,
            .loongarch64 => 8,
        }));
    }
};
