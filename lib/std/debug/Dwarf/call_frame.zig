const builtin = @import("builtin");
const std = @import("../../std.zig");
const mem = std.mem;
const debug = std.debug;
const leb = std.leb;
const DW = std.dwarf;
const abi = std.debug.Dwarf.abi;
const assert = std.debug.assert;
const native_endian = builtin.cpu.arch.endian();

/// TODO merge with std.dwarf.CFA
const Opcode = enum(u8) {
    advance_loc = 0x1 << 6,
    offset = 0x2 << 6,
    restore = 0x3 << 6,

    nop = 0x00,
    set_loc = 0x01,
    advance_loc1 = 0x02,
    advance_loc2 = 0x03,
    advance_loc4 = 0x04,
    offset_extended = 0x05,
    restore_extended = 0x06,
    undefined = 0x07,
    same_value = 0x08,
    register = 0x09,
    remember_state = 0x0a,
    restore_state = 0x0b,
    def_cfa = 0x0c,
    def_cfa_register = 0x0d,
    def_cfa_offset = 0x0e,
    def_cfa_expression = 0x0f,
    expression = 0x10,
    offset_extended_sf = 0x11,
    def_cfa_sf = 0x12,
    def_cfa_offset_sf = 0x13,
    val_offset = 0x14,
    val_offset_sf = 0x15,
    val_expression = 0x16,

    // These opcodes encode an operand in the lower 6 bits of the opcode itself
    pub const lo_inline = @intFromEnum(Opcode.advance_loc);
    pub const hi_inline = @intFromEnum(Opcode.restore) | 0b111111;

    // These opcodes are trailed by zero or more operands
    pub const lo_reserved = @intFromEnum(Opcode.nop);
    pub const hi_reserved = @intFromEnum(Opcode.val_expression);

    // Vendor-specific opcodes
    pub const lo_user = 0x1c;
    pub const hi_user = 0x3f;
};

fn readBlock(stream: *std.io.FixedBufferStream([]const u8)) ![]const u8 {
    const reader = stream.reader();
    const block_len = try leb.readUleb128(usize, reader);
    if (stream.pos + block_len > stream.buffer.len) return error.InvalidOperand;

    const block = stream.buffer[stream.pos..][0..block_len];
    reader.context.pos += block_len;

    return block;
}

pub const Instruction = union(Opcode) {
    advance_loc: struct {
        delta: u8,
    },
    offset: struct {
        register: u8,
        offset: u64,
    },
    restore: struct {
        register: u8,
    },
    nop: void,
    set_loc: struct {
        address: u64,
    },
    advance_loc1: struct {
        delta: u8,
    },
    advance_loc2: struct {
        delta: u16,
    },
    advance_loc4: struct {
        delta: u32,
    },
    offset_extended: struct {
        register: u8,
        offset: u64,
    },
    restore_extended: struct {
        register: u8,
    },
    undefined: struct {
        register: u8,
    },
    same_value: struct {
        register: u8,
    },
    register: struct {
        register: u8,
        target_register: u8,
    },
    remember_state: void,
    restore_state: void,
    def_cfa: struct {
        register: u8,
        offset: u64,
    },
    def_cfa_register: struct {
        register: u8,
    },
    def_cfa_offset: struct {
        offset: u64,
    },
    def_cfa_expression: struct {
        block: []const u8,
    },
    expression: struct {
        register: u8,
        block: []const u8,
    },
    offset_extended_sf: struct {
        register: u8,
        offset: i64,
    },
    def_cfa_sf: struct {
        register: u8,
        offset: i64,
    },
    def_cfa_offset_sf: struct {
        offset: i64,
    },
    val_offset: struct {
        register: u8,
        offset: u64,
    },
    val_offset_sf: struct {
        register: u8,
        offset: i64,
    },
    val_expression: struct {
        register: u8,
        block: []const u8,
    },

    pub fn read(
        stream: *std.io.FixedBufferStream([]const u8),
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Instruction {
        const reader = stream.reader();
        switch (try reader.readByte()) {
            Opcode.lo_inline...Opcode.hi_inline => |opcode| {
                const e: Opcode = @enumFromInt(opcode & 0b11000000);
                const value: u6 = @intCast(opcode & 0b111111);
                return switch (e) {
                    .advance_loc => .{
                        .advance_loc = .{ .delta = value },
                    },
                    .offset => .{
                        .offset = .{
                            .register = value,
                            .offset = try leb.readUleb128(u64, reader),
                        },
                    },
                    .restore => .{
                        .restore = .{ .register = value },
                    },
                    else => unreachable,
                };
            },
            Opcode.lo_reserved...Opcode.hi_reserved => |opcode| {
                const e: Opcode = @enumFromInt(opcode);
                return switch (e) {
                    .advance_loc,
                    .offset,
                    .restore,
                    => unreachable,
                    .nop => .{ .nop = {} },
                    .set_loc => .{
                        .set_loc = .{
                            .address = switch (addr_size_bytes) {
                                2 => try reader.readInt(u16, endian),
                                4 => try reader.readInt(u32, endian),
                                8 => try reader.readInt(u64, endian),
                                else => return error.InvalidAddrSize,
                            },
                        },
                    },
                    .advance_loc1 => .{
                        .advance_loc1 = .{ .delta = try reader.readByte() },
                    },
                    .advance_loc2 => .{
                        .advance_loc2 = .{ .delta = try reader.readInt(u16, endian) },
                    },
                    .advance_loc4 => .{
                        .advance_loc4 = .{ .delta = try reader.readInt(u32, endian) },
                    },
                    .offset_extended => .{
                        .offset_extended = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readUleb128(u64, reader),
                        },
                    },
                    .restore_extended => .{
                        .restore_extended = .{
                            .register = try leb.readUleb128(u8, reader),
                        },
                    },
                    .undefined => .{
                        .undefined = .{
                            .register = try leb.readUleb128(u8, reader),
                        },
                    },
                    .same_value => .{
                        .same_value = .{
                            .register = try leb.readUleb128(u8, reader),
                        },
                    },
                    .register => .{
                        .register = .{
                            .register = try leb.readUleb128(u8, reader),
                            .target_register = try leb.readUleb128(u8, reader),
                        },
                    },
                    .remember_state => .{ .remember_state = {} },
                    .restore_state => .{ .restore_state = {} },
                    .def_cfa => .{
                        .def_cfa = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readUleb128(u64, reader),
                        },
                    },
                    .def_cfa_register => .{
                        .def_cfa_register = .{
                            .register = try leb.readUleb128(u8, reader),
                        },
                    },
                    .def_cfa_offset => .{
                        .def_cfa_offset = .{
                            .offset = try leb.readUleb128(u64, reader),
                        },
                    },
                    .def_cfa_expression => .{
                        .def_cfa_expression = .{
                            .block = try readBlock(stream),
                        },
                    },
                    .expression => .{
                        .expression = .{
                            .register = try leb.readUleb128(u8, reader),
                            .block = try readBlock(stream),
                        },
                    },
                    .offset_extended_sf => .{
                        .offset_extended_sf = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readIleb128(i64, reader),
                        },
                    },
                    .def_cfa_sf => .{
                        .def_cfa_sf = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readIleb128(i64, reader),
                        },
                    },
                    .def_cfa_offset_sf => .{
                        .def_cfa_offset_sf = .{
                            .offset = try leb.readIleb128(i64, reader),
                        },
                    },
                    .val_offset => .{
                        .val_offset = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readUleb128(u64, reader),
                        },
                    },
                    .val_offset_sf => .{
                        .val_offset_sf = .{
                            .register = try leb.readUleb128(u8, reader),
                            .offset = try leb.readIleb128(i64, reader),
                        },
                    },
                    .val_expression => .{
                        .val_expression = .{
                            .register = try leb.readUleb128(u8, reader),
                            .block = try readBlock(stream),
                        },
                    },
                };
            },
            Opcode.lo_user...Opcode.hi_user => return error.UnimplementedUserOpcode,
            else => return error.InvalidOpcode,
        }
    }
};
