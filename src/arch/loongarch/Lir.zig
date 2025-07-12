//! Lower Intermediate Representation.
//! This IR have 1:1 correspondence with machine instructions,
//! while keeping instruction encoding unknown.
//! The purpose is to keep the lowering process unaware of instruction format.

const std = @import("std");
const Writer = std.Io.Writer;
const expectEqual = std.testing.expectEqual;
const expectEqualStrings = std.testing.expectEqualStrings;

const encoding = @import("encoding.zig");
const bits = @import("bits.zig");
const Register = bits.Register;

pub const Inst = struct {
    opcode: encoding.OpCode,
    data: encoding.Data,

    pub fn encode(inst: Inst) u32 {
        const opcode = inst.opcode.enc();
        return opcode | inst.data.enc();
    }

    pub fn format(inst: Inst, writer: *Writer) Writer.Error!void {
        try writer.print("{s}", .{@tagName(inst.opcode)});
        inline for (@typeInfo(encoding.Format).@"enum".fields) |enum_field| {
            if (enum_field.value == @intFromEnum(std.meta.activeTag(inst.data))) {
                const data_ty = @FieldType(encoding.Data, enum_field.name);
                const data_ty_info = @typeInfo(data_ty);
                switch (data_ty_info) {
                    .void => {},
                    .@"struct" => |struct_info| {
                        inline for (struct_info.fields) |field| {
                            const data_val = @field(@field(inst.data, enum_field.name), field.name);
                            if (field.type == Register) {
                                try writer.print(" {s}", .{@tagName(data_val)});
                            } else {
                                switch (@typeInfo(field.type)) {
                                    .int => try writer.print(" {}", .{data_val}),
                                    else => unreachable,
                                }
                            }
                        }
                    },
                    else => unreachable,
                }
            }
        }
    }

    pub fn fromInst(inst: encoding.Inst) Inst {
        return .{ .opcode = inst.opcode, .data = inst.data };
    }
};

test "instruction encoding" {
    try expectEqual(0x02c02808, (Inst{ .opcode = .addi_d, .data = .{
        .DJSk12 = .{ .r8, .r0, 10 },
    } }).encode());
    try expectEqual(0x01140841, (Inst{ .opcode = .fabs_d, .data = .{
        .DJ = .{ .f1, .f2 },
    } }).encode());
    try expectEqual(0x002a0000, (Inst{ .opcode = .@"break", .data = .{
        .Ud15 = .{0},
    } }).encode());
    try expectEqual(0x00160c41, (Inst{ .opcode = .orn, .data = .{
        .DJK = .{ .r1, .r2, .r3 },
    } }).encode());
    try expectEqual(0x0c100820, (Inst{ .opcode = .fcmp_caf_s, .data = .{
        .DJK = .{ .fcc0, .f1, .f2 },
    } }).encode());
    try expectEqual(0x0c100820, Inst.fromInst(.fcmp_caf_s(.fcc0, .f1, .f2)).encode());
    try expectEqual(0x06483800, Inst.fromInst(.eret()).encode());
}

test "instruction formatting" {
    try expectEqualStrings("addi_d r8 r0 10", std.fmt.comptimePrint("{f}", .{Inst{ .opcode = .addi_d, .data = .{
        .DJSk12 = .{ .r8, .r0, 10 },
    } }}));
    try expectEqualStrings("fabs_d f1 f2", std.fmt.comptimePrint("{f}", .{Inst{ .opcode = .fabs_d, .data = .{
        .DJ = .{ .f1, .f2 },
    } }}));
    try expectEqualStrings("break 0", std.fmt.comptimePrint("{f}", .{Inst{ .opcode = .@"break", .data = .{
        .Ud15 = .{0},
    } }}));
    try expectEqualStrings("fcmp_caf_s fcc0 f1 f2", std.fmt.comptimePrint("{f}", .{Inst{ .opcode = .fcmp_caf_s, .data = .{
        .DJK = .{ .fcc0, .f1, .f2 },
    } }}));
}

pub const MemOp = enum { store, load };

pub const SizedMemOp = struct {
    op: MemOp,
    size: bits.Memory.Size,
    signedness: std.builtin.Signedness,

    pub fn toOpCodeRI(op: SizedMemOp) encoding.OpCode {
        return switch (op.op) {
            .store => switch (op.size) {
                .byte => .st_b,
                .hword => .st_h,
                .word => .st_w,
                .dword => .st_d,
            },
            .load => switch (op.size) {
                .byte => switch (op.signedness) {
                    .signed => .ld_b,
                    .unsigned => .ld_bu,
                },
                .hword => switch (op.signedness) {
                    .signed => .ld_h,
                    .unsigned => .ld_hu,
                },
                .word => switch (op.signedness) {
                    .signed => .ld_w,
                    .unsigned => .ld_wu,
                },
                .dword => .ld_d,
            },
        };
    }

    pub fn toOpCodeRR(op: SizedMemOp) encoding.OpCode {
        return switch (op.op) {
            .store => switch (op.size) {
                .byte => .stx_b,
                .hword => .stx_h,
                .word => .stx_w,
                .dword => .stx_d,
            },
            .load => switch (op.size) {
                .byte => switch (op.signedness) {
                    .signed => .ldx_b,
                    .unsigned => .ldx_bu,
                },
                .hword => switch (op.signedness) {
                    .signed => .ldx_h,
                    .unsigned => .ldx_hu,
                },
                .word => switch (op.signedness) {
                    .signed => .ldx_w,
                    .unsigned => .ldx_wu,
                },
                .dword => .ldx_d,
            },
        };
    }

    pub fn format(op: SizedMemOp, writer: *Writer) Writer.Error!void {
        try writer.print("{s}", .{@tagName(op.toOpCodeRI())});
    }
};
