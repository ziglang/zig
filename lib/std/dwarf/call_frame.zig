const std = @import("../std.zig");
const debug = std.debug;
const leb = @import("../leb128.zig");
const abi = @import("abi.zig");
const dwarf = @import("../dwarf.zig");

// These enum values correspond to the opcode encoding itself, with
// the exception of the opcodes that include data in the opcode itself.
// For those, the enum value is the opcode with the lower 6 bits (the data) masked to 0.
const Opcode = enum(u8) {
    // These are placeholders that define the range of vendor-specific opcodes
    const lo_user = 0x1c;
    const hi_user = 0x3f;

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

    _,
};

const Operand = enum {
    opcode_delta,
    opcode_register,
    uleb128_register,
    uleb128_offset,
    sleb128_offset,
    address,
    u8_delta,
    u16_delta,
    u32_delta,
    block,

    fn Storage(comptime self: Operand) type {
        return switch (self) {
            .opcode_delta, .opcode_register => u6,
            .uleb128_register => u8,
            .uleb128_offset => u64,
            .sleb128_offset => i64,
            .address => u64,
            .u8_delta => u8,
            .u16_delta => u16,
            .u32_delta => u32,
            .block => []const u8,
        };
    }

    fn read(
        comptime self: Operand,
        reader: anytype,
        opcode_value: ?u6,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Storage(self) {
        return switch (self) {
            .opcode_delta, .opcode_register => opcode_value orelse return error.InvalidOperand,
            .uleb128_register => try leb.readULEB128(u8, reader),
            .uleb128_offset => try leb.readULEB128(u64, reader),
            .sleb128_offset => try leb.readILEB128(i64, reader),
            .address => switch (addr_size_bytes) {
                2 => try reader.readInt(u16, endian),
                4 => try reader.readInt(u32, endian),
                8 => try reader.readInt(u64, endian),
                else => return error.InvalidAddrSize,
            },
            .u8_delta => try reader.readByte(),
            .u16_delta => try reader.readInt(u16, endian),
            .u32_delta => try reader.readInt(u32, endian),
            .block => {
                const block_len = try leb.readULEB128(u64, reader);

                // TODO: This feels like a kludge, change to FixedBufferStream param?
                const block = reader.context.buffer[reader.context.pos..][0..block_len];
                reader.context.pos += block_len;

                return block;
            }
        };
    }
};

fn InstructionType(comptime definition: anytype) type {
    const definition_type = @typeInfo(@TypeOf(definition));
    debug.assert(definition_type == .Struct);

    const definition_len = definition_type.Struct.fields.len;
    comptime var fields: [definition_len]std.builtin.Type.StructField = undefined;
    inline for (definition_type.Struct.fields, &fields) |definition_field, *operands_field| {
        const opcode = std.enums.nameCast(Operand, @field(definition, definition_field.name));
        const storage_type = opcode.Storage();
        operands_field.* = .{
            .name = definition_field.name,
            .type = storage_type,
            .default_value = null,
            .is_comptime = false,
            .alignment = @alignOf(storage_type),
        };
    }

    const InstructionOperands = @Type(.{
        .Struct = .{
            .layout = .Auto,
            .fields = &fields,
            .decls = &.{},
            .is_tuple = false,
        },
    });

    return struct {
        const Self = @This();
        operands: InstructionOperands,

        pub fn read(reader: anytype, opcode_value: ?u6, addr_size_bytes: u8, endian: std.builtin.Endian) !Self {
            var operands: InstructionOperands = undefined;
            inline for (definition_type.Struct.fields) |definition_field| {
                const operand = comptime std.enums.nameCast(Operand, @field(definition, definition_field.name));
                @field(operands, definition_field.name) = try operand.read(reader, opcode_value, addr_size_bytes, endian);
            }

            return .{ .operands = operands };
        }
    };
}

pub const Instruction = union(Opcode) {
    advance_loc: InstructionType(.{ .delta = .opcode_delta }),
    offset: InstructionType(.{ .register = .opcode_register, .offset = .uleb128_offset }),
    restore: InstructionType(.{ .register = .opcode_register }),
    nop: InstructionType(.{}),
    set_loc: InstructionType(.{ .address = .address }),
    advance_loc1: InstructionType(.{ .delta = .u8_delta }),
    advance_loc2: InstructionType(.{ .delta = .u16_delta }),
    advance_loc4: InstructionType(.{ .delta = .u32_delta }),
    offset_extended: InstructionType(.{ .register = .uleb128_register, .offset = .uleb128_offset }),
    restore_extended: InstructionType(.{ .register = .uleb128_register }),
    undefined: InstructionType(.{ .register = .uleb128_register }),
    same_value: InstructionType(.{ .register = .uleb128_register }),
    register: InstructionType(.{ .register = .uleb128_register, .offset = .uleb128_offset }),
    remember_state: InstructionType(.{}),
    restore_state: InstructionType(.{}),
    def_cfa: InstructionType(.{ .register = .uleb128_register, .offset = .uleb128_offset }),
    def_cfa_register: InstructionType(.{ .register = .uleb128_register }),
    def_cfa_offset: InstructionType(.{ .offset = .uleb128_offset }),
    def_cfa_expression: InstructionType(.{ .block = .block }),
    expression: InstructionType(.{ .register = .uleb128_register, .block = .block }),
    offset_extended_sf: InstructionType(.{ .register = .uleb128_register, .offset = .sleb128_offset }),
    def_cfa_sf: InstructionType(.{ .register = .uleb128_register, .offset = .sleb128_offset }),
    def_cfa_offset_sf: InstructionType(.{ .offset = .sleb128_offset }),
    val_offset: InstructionType(.{ .a = .uleb128_offset, .b = .uleb128_offset }),
    val_offset_sf: InstructionType(.{ .a = .uleb128_offset, .b = .sleb128_offset }),
    val_expression: InstructionType(.{ .a = .uleb128_offset, .block = .block }),

    pub fn read(reader: anytype, addr_size_bytes: u8, endian: std.builtin.Endian) !Instruction {
        const opcode = try reader.readByte();
        const upper = opcode & 0b11000000;
        return switch (upper) {
            inline @enumToInt(Opcode.advance_loc), @enumToInt(Opcode.offset), @enumToInt(Opcode.restore) => |u| @unionInit(
                Instruction,
                @tagName(@intToEnum(Opcode, u)),
                try std.meta.TagPayload(Instruction, @intToEnum(Opcode, u)).read(reader, @intCast(u6, opcode & 0b111111), addr_size_bytes, endian),
            ),
            0 => blk: {
                inline for (@typeInfo(Opcode).Enum.fields) |field| {
                    if (field.value == opcode) {
                        break :blk @unionInit(
                            Instruction,
                            @tagName(@intToEnum(Opcode, field.value)),
                            try std.meta.TagPayload(Instruction, @intToEnum(Opcode, field.value)).read(reader, null, addr_size_bytes, endian),
                        );
                    }
                }
                break :blk error.UnknownOpcode;
            },
            else => error.UnknownOpcode,
        };
    }

    pub fn writeOperands(self: Instruction, writer: anytype, cie: dwarf.CommonInformationEntry, arch: ?std.Target.Cpu.Arch) !void {
        switch (self) {
            inline .advance_loc, .advance_loc1, .advance_loc2, .advance_loc4 => |i| try writer.print("{}", .{ i.operands.delta * cie.code_alignment_factor }),
            .offset => |i| {
                try abi.writeRegisterName(writer, arch, i.operands.register);
                try writer.print(" {}", .{ @intCast(i64, i.operands.offset) * cie.data_alignment_factor });
            },
            .restore => {},
            .nop => {},
            .set_loc => {},
            .offset_extended => {},
            .restore_extended => {},
            .undefined => {},
            .same_value => {},
            .register => {},
            .remember_state => {},
            .restore_state => {},
            .def_cfa => |i| {
                try abi.writeRegisterName(writer, arch, i.operands.register);
                try writer.print(" +{}", .{ i.operands.offset });
            },
            .def_cfa_register => {},
            .def_cfa_offset => {},
            .def_cfa_expression => |i| {
                try writer.print("TODO parse expressions: {x}", .{ std.fmt.fmtSliceHexLower(i.operands.block) });
            },
            .expression => {},
            .offset_extended_sf => {},
            .def_cfa_sf => {},
            .def_cfa_offset_sf => {},
            .val_offset => {},
            .val_offset_sf => {},
            .val_expression => {},
        }
    }

};
