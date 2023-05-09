const std = @import("../std.zig");
const debug = std.debug;
const leb = @import("../leb128.zig");
const abi = @import("abi.zig");
const dwarf = @import("../dwarf.zig");
const expressions = @import("expressions.zig");

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
    pub const lo_inline = Opcode.advance_loc;
    pub const hi_inline = Opcode.restore;

    // These opcodes are trailed by zero or more operands
    pub const lo_reserved = Opcode.nop;
    pub const hi_reserved = Opcode.val_expression;

    // Vendor-specific opcodes
    pub const lo_user = 0x1c;
    pub const hi_user = 0x3f;
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
        stream: *std.io.FixedBufferStream([]const u8),
        opcode_value: ?u6,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Storage(self) {
        const reader = stream.reader();
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
                if (stream.pos + block_len > stream.buffer.len) return error.InvalidOperand;

                const block = stream.buffer[stream.pos..][0..block_len];
                reader.context.pos += block_len;

                return block;
            },
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

        pub fn read(
            stream: *std.io.FixedBufferStream([]const u8),
            opcode_value: ?u6,
            addr_size_bytes: u8,
            endian: std.builtin.Endian,
        ) !Self {
            var operands: InstructionOperands = undefined;
            inline for (definition_type.Struct.fields) |definition_field| {
                const operand = comptime std.enums.nameCast(Operand, @field(definition, definition_field.name));
                @field(operands, definition_field.name) = try operand.read(stream, opcode_value, addr_size_bytes, endian);
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

    pub fn read(
        stream: *std.io.FixedBufferStream([]const u8),
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Instruction {
        @setEvalBranchQuota(1800);

        return switch (try stream.reader().readByte()) {
            inline @enumToInt(Opcode.lo_inline)...@enumToInt(Opcode.hi_inline) => |opcode| blk: {
                const e = @intToEnum(Opcode, opcode & 0b11000000);
                const payload_type = std.meta.TagPayload(Instruction, e);
                const value = try payload_type.read(stream, @intCast(u6, opcode & 0b111111), addr_size_bytes, endian);
                break :blk @unionInit(Instruction, @tagName(e), value);
            },
            inline @enumToInt(Opcode.lo_reserved)...@enumToInt(Opcode.hi_reserved) => |opcode| blk: {
                const e = @intToEnum(Opcode, opcode);
                const payload_type = std.meta.TagPayload(Instruction, e);
                const value = try payload_type.read(stream, null, addr_size_bytes, endian);
                break :blk @unionInit(Instruction, @tagName(e), value);
            },
            Opcode.lo_user...Opcode.hi_user => error.UnimplementedUserOpcode,
            else => error.InvalidOpcode,
        };
    }

    pub fn writeOperands(
        self: Instruction,
        writer: anytype,
        cie: dwarf.CommonInformationEntry,
        arch: ?std.Target.Cpu.Arch,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !void {
        switch (self) {
            inline .advance_loc, .advance_loc1, .advance_loc2, .advance_loc4 => |i| try writer.print("{}", .{i.operands.delta * cie.code_alignment_factor}),
            .offset => |i| {
                try abi.writeRegisterName(writer, arch, i.operands.register);
                try writer.print(" {}", .{@intCast(i64, i.operands.offset) * cie.data_alignment_factor});
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
                try writer.print(" {d:<1}", .{@intCast(i64, i.operands.offset)});
            },
            .def_cfa_register => {},
            .def_cfa_offset => |i| {
                try writer.print("{d:<1}", .{@intCast(i64, i.operands.offset)});
            },
            .def_cfa_expression => |i| {
                try writeExpression(writer, i.operands.block, arch, addr_size_bytes, endian);
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

fn writeExpression(
    writer: anytype,
    block: []const u8,
    arch: ?std.Target.Cpu.Arch,
    addr_size_bytes: u8,
    endian: std.builtin.Endian,
) !void {
    var stream = std.io.fixedBufferStream(block);

    // Generate a lookup table from opcode value to name
    const opcode_lut_len = 256;
    const opcode_lut: [opcode_lut_len]?[]const u8 = comptime blk: {
        var lut: [opcode_lut_len]?[]const u8 = [_]?[]const u8{null} ** opcode_lut_len;
        for (@typeInfo(dwarf.OP).Struct.decls) |decl| {
            lut[@as(u8, @field(dwarf.OP, decl.name))] = decl.name;
        }

        break :blk lut;
    };

    switch (endian) {
        inline .Little, .Big => |e| {
            switch (addr_size_bytes) {
                inline 2, 4, 8 => |size| {
                    const StackMachine = expressions.StackMachine(.{
                        .addr_size = size,
                        .endian = e,
                        .call_frame_mode = true,
                    });

                    const reader = stream.reader();
                    while (stream.pos < stream.buffer.len) {
                        if (stream.pos > 0) try writer.writeAll(", ");

                        const opcode = try reader.readByte();
                        if (opcode_lut[opcode]) |opcode_name| {
                            try writer.print("DW_OP_{s}", .{opcode_name});
                        } else {
                            // TODO: See how llvm-dwarfdump prints these?
                            if (opcode >= dwarf.OP.lo_user and opcode <= dwarf.OP.lo_user) {
                                try writer.print("<unknown vendor opcode: 0x{x}>", .{opcode});
                            } else {
                                try writer.print("<invalid opcode: 0x{x}>", .{opcode});
                            }
                        }

                        if (try StackMachine.readOperand(&stream, opcode)) |value| {
                            switch (value) {
                                //.generic => |v| try writer.print("{d}", .{v}),
                                .generic => {}, // Constant values are implied by the opcode name
                                .register => |v| try writer.print(" {}", .{ abi.fmtRegister(v, arch) }),
                                .base_register => |v| try writer.print(" {}{d:<1}", .{ abi.fmtRegister(v.base_register, arch), v.offset }),
                                else => try writer.print(" TODO({s})", .{@tagName(value)}),
                            }
                        }
                    }
                },
                else => return error.InvalidAddrSize,
            }
        },
    }
}

// fn formatOffset(data: i64, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
//     _ = fmt;
//     if (data >= 0) try writer.writeByte('+');
//     return std.fmt.formatInt(data, 10, .lower, options, writer);
// }

// fn fmtOffset(offset: i64) std.fmt.Formatter(formatOffset) {
//     return .{ .data = offset };
// }

/// See section 6.4.1 of the DWARF5 specification
pub const VirtualMachine = struct {
    const RegisterRule = union(enum) {
        undefined: void,
        same_value: void,
        offset: i64,
        val_offset: i64,
        register: u8,
        expression: []const u8,
        val_expression: []const u8,
        architectural: void,
    };

    pub const Column = struct {
        register: u8 = undefined,
        rule: RegisterRule = .{ .undefined = {} },

        pub fn writeRule(
            self: Column,
            writer: anytype,
            is_cfa: bool,
            arch: ?std.Target.Cpu.Arch,
            addr_size_bytes: u8,
            endian: std.builtin.Endian,
        ) !void {
            if (is_cfa) {
                try writer.writeAll("CFA");
            } else {
                try abi.writeRegisterName(writer, arch, self.register);
            }

            try writer.writeByte('=');
            switch (self.rule) {
                .undefined => {},
                .same_value => try writer.writeAll("S"),
                .offset => |offset| {
                    if (is_cfa) {
                        try abi.writeRegisterName(writer, arch, self.register);
                        try writer.print("{d:<1}", .{offset});
                    } else {
                        try writer.print("[CFA{d:<1}]", .{offset});
                    }
                },
                .val_offset => |offset| {
                    if (is_cfa) {
                        try abi.writeRegisterName(writer, arch, self.register);
                        try writer.print("{d:<1}", .{offset});
                    } else {
                        try writer.print("CFA{d:<1}", .{offset});
                    }
                },
                .register => |register| try abi.writeRegisterName(writer, arch, register),
                .expression => |expression| try writeExpression(writer, expression, arch, addr_size_bytes, endian),
                .val_expression => try writer.writeAll("TODO(val_expression)"),
                .architectural => try writer.writeAll("TODO(architectural)"),
            }
        }
    };

    /// Each row contains unwinding rules for a set of registers at a specific location in the program.
    pub const Row = struct {
        /// Offset from pc_begin
        offset: u64 = 0,
        /// Special-case column that defines the CFA (Canonical Frame Address) rule.
        /// The register field of this column defines the register that CFA is derived
        /// from, while other columns define registers in terms of the CFA.
        cfa: Column = .{},
        /// Index into `columns` of the first column in this row.
        columns_start: usize = undefined,
        columns_len: u8 = 0,
    };

    columns: std.ArrayListUnmanaged(Column) = .{},
    row_stack: std.ArrayListUnmanaged(Row) = .{},
    current_row: Row = .{},

    // TODO: Add stack machine stack

    pub fn reset(self: *VirtualMachine) void {
        self.row_stack.clearRetainingCapacity();
        self.columns.clearRetainingCapacity();
        self.current_row = .{};
    }

    pub fn deinit(self: *VirtualMachine, allocator: std.mem.Allocator) void {
        self.row_stack.deinit(allocator);
        self.columns.deinit(allocator);
        self.* = undefined;
    }

    pub fn getColumns(self: VirtualMachine, row: Row) []Column {
        return self.columns.items[row.columns_start..][0..row.columns_len];
    }

    fn getOrAddColumn(self: *VirtualMachine, allocator: std.mem.Allocator, register: u8) !*Column {
        for (self.getColumns(self.current_row)) |*c| {
            if (c.register == register) return c;
        }

        if (self.current_row.columns_len == 0) {
            self.current_row.columns_start = self.columns.items.len;
        }
        self.current_row.columns_len += 1;

        const column = try self.columns.addOne(allocator);
        column.* = .{
            .register = register,
        };

        return column;
    }

    pub fn step(self: *VirtualMachine, allocator: std.mem.Allocator, cie: dwarf.CommonInformationEntry, instruction: Instruction) !void {
        switch (instruction) {
            inline .advance_loc, .advance_loc1, .advance_loc2, .advance_loc4 => |i| {
                self.current_row.offset += i.operands.delta;
            },
            .offset => |i| {
                const column = try self.getOrAddColumn(allocator, i.operands.register);
                column.rule = .{ .offset = @intCast(i64, i.operands.offset) * cie.data_alignment_factor };
            },
            .restore => {},
            .nop => {},
            .set_loc => {},
            .offset_extended => {},
            .restore_extended => {},
            .undefined => {},
            .same_value => {},
            .register => {},
            .remember_state => {

                // TODO: The row stack only actually needs the column information
                // TODO: Also it needs to copy the columns because changes can edit the referenced columns
                // TODO: This function could push the column range onto the stack, the copy the columns and update current row

                try self.row_stack.append(allocator, self.current_row);
            },
            .restore_state => {
                if (self.row_stack.items.len == 0) return error.InvalidOperation;
                const row = self.row_stack.pop();
                self.current_row.columns_len = row.columns_len;
                self.current_row.columns_start = row.columns_start;
            },
            .def_cfa => |i| {
                self.current_row.cfa = .{
                    .register = i.operands.register,
                    .rule = .{ .offset = @intCast(i64, i.operands.offset) },
                };
            },
            .def_cfa_register => {},
            .def_cfa_offset => |i| {
                self.current_row.cfa.rule = .{ .offset = @intCast(i64, i.operands.offset) };
            },
            .def_cfa_expression => |i| {
                self.current_row.cfa.register = undefined;
                self.current_row.cfa.rule = .{
                    .expression = i.operands.block,
                };
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
