const builtin = @import("builtin");
const std = @import("../std.zig");
const debug = std.debug;
const leb = @import("../leb128.zig");
const abi = @import("abi.zig");
const dwarf = @import("../dwarf.zig");
const expressions = @import("expressions.zig");
const assert = std.debug.assert;

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
    pub const hi_inline = @enumToInt(Opcode.restore) | 0b111111;

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
            .opcode_delta, .opcode_register => u8,
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
    assert(definition_type == .Struct);

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
    offset_extended: InstructionType(.{ .register = .uleb128_register, .offset = .uleb128_offset }),
    restore: InstructionType(.{ .register = .opcode_register }),
    restore_extended: InstructionType(.{ .register = .uleb128_register }),
    nop: InstructionType(.{}),
    set_loc: InstructionType(.{ .address = .address }),
    advance_loc1: InstructionType(.{ .delta = .u8_delta }),
    advance_loc2: InstructionType(.{ .delta = .u16_delta }),
    advance_loc4: InstructionType(.{ .delta = .u32_delta }),
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
            inline @enumToInt(Opcode.lo_inline)...Opcode.hi_inline => |opcode| blk: {
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
            else => |opcode| blk: {
                std.debug.print("Opcode {x}\n", .{opcode});

                break :blk error.InvalidOpcode;
            },
        };
    }
};

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

    /// Each row contains unwinding rules for a set of registers at a specific location in the
    pub const Row = struct {
        /// Offset from pc_begin
        offset: u64 = 0,
        /// Special-case column that defines the CFA (Canonical Frame Address) rule.
        /// The register field of this column defines the register that CFA is derived
        /// from, while other columns define registers in terms of the CFA.
        cfa: Column = .{},
        columns: ColumnRange = .{},
    };

    pub const Column = struct {
        /// Register can only null in the case of the CFA column
        register: ?u8 = null,
        rule: RegisterRule = .{ .undefined = {} },
    };

    const ColumnRange = struct {
        /// Index into `columns` of the first column in this row.
        start: usize = undefined,
        len: u8 = 0,
    };

    columns: std.ArrayListUnmanaged(Column) = .{},
    stack: std.ArrayListUnmanaged(ColumnRange) = .{},
    current_row: Row = .{},

    /// The result of executing the CIE's initial_instructions
    cie_row: ?Row = null,

    pub fn reset(self: *VirtualMachine) void {
        self.stack.clearRetainingCapacity();
        self.columns.clearRetainingCapacity();
        self.current_row = .{};
        self.cie_row = null;
    }

    pub fn deinit(self: *VirtualMachine, allocator: std.mem.Allocator) void {
        self.stack.deinit(allocator);
        self.columns.deinit(allocator);
        self.* = undefined;
    }

    /// Return a slice backed by the row's non-CFA columns
    pub fn rowColumns(self: VirtualMachine, row: Row) []Column {
        return self.columns.items[row.columns.start..][0..row.columns.len];
    }

    /// Either retrieves or adds a column for `register` (non-CFA) in the current row
    fn getOrAddColumn(self: *VirtualMachine, allocator: std.mem.Allocator, register: u8) !*Column {
        for (self.rowColumns(self.current_row)) |*c| {
            if (c.register == register) return c;
        }

        if (self.current_row.columns.len == 0) {
            self.current_row.columns.start = self.columns.items.len;
        }
        self.current_row.columns.len += 1;

        const column = try self.columns.addOne(allocator);
        column.* = .{
            .register = register,
        };

        return column;
    }

    /// Runs the CIE instructions, then the FDE instructions. Execution halts
    /// once the row that corresponds to `pc` is known, and it is returned.
    pub fn unwindTo(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        pc: u64,
        cie: dwarf.CommonInformationEntry,
        fde: dwarf.FrameDescriptionEntry,
        addr_size_bytes: u8,
        endian: std.builtin.Endian,
    ) !Row {
        assert(self.cie_row == null);
        if (pc < fde.pc_begin or pc >= fde.pc_begin + fde.pc_range) return error.AddressOutOfRange;

        var prev_row: Row = self.current_row;
        const streams = .{
            std.io.fixedBufferStream(cie.initial_instructions),
            std.io.fixedBufferStream(fde.instructions),
        };

        outer: for (streams, 0..) |*stream, i| {
            while (stream.pos < stream.buffer.len) {
                const instruction = try dwarf.call_frame.Instruction.read(stream, addr_size_bytes, endian);
                prev_row = try self.step(allocator, cie, i == 0, instruction);
                if (pc < fde.pc_begin + self.current_row.offset) {
                    break :outer;
                }
            }
        }

        return prev_row;
    }

    pub fn unwindToNative(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        pc: u64,
        cie: dwarf.CommonInformationEntry,
        fde: dwarf.FrameDescriptionEntry,
    ) void {
        self.stepTo(allocator, pc, cie, fde, @sizeOf(usize), builtin.target.cpu.arch.endian());
    }

    /// Executes a single instruction.
    /// If this instruction is from the CIE, `is_initial` should be set.
    /// Returns the value of `current_row` before executing this instruction
    pub fn step(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        cie: dwarf.CommonInformationEntry,
        is_initial: bool,
        instruction: Instruction,
    ) !Row {
        // CIE instructions must be run before FDE instructions
        assert(!is_initial or self.cie_row == null);
        if (!is_initial and self.cie_row == null) self.cie_row = self.current_row;

        const prev_row = self.current_row;
        switch (instruction) {
            inline .advance_loc, .advance_loc1, .advance_loc2, .advance_loc4 => |i| {
                self.current_row.offset += i.operands.delta * cie.code_alignment_factor;
            },
            inline .offset, .offset_extended => |i| {
                const column = try self.getOrAddColumn(allocator, i.operands.register);
                column.rule = .{ .offset = @intCast(i64, i.operands.offset) * cie.data_alignment_factor };
            },
            inline .restore, .restore_extended => |i| {
                if (self.cie_row) |cie_row| {
                    const column = try self.getOrAddColumn(allocator, i.operands.register);
                    column.rule = for (self.rowColumns(cie_row)) |cie_column| {
                        if (cie_column.register == i.operands.register) break cie_column.rule;
                    } else .{ .undefined = {} };
                } else return error.InvalidOperation;
            },
            .nop => {},
            .set_loc => {},
            .undefined => {},
            .same_value => {},
            .register => {},
            .remember_state => {
                try self.stack.append(allocator, self.current_row.columns);
                errdefer _ = self.stack.pop();

                const new_start = self.columns.items.len;
                if (self.current_row.columns.len > 0) {
                    try self.columns.ensureUnusedCapacity(allocator, self.current_row.columns.len);
                    self.columns.appendSliceAssumeCapacity(self.rowColumns(self.current_row));
                    self.current_row.columns.start = new_start;
                }
            },
            .restore_state => {
                const restored_columns = self.stack.popOrNull() orelse return error.InvalidOperation;
                self.columns.shrinkRetainingCapacity(self.columns.items.len - self.current_row.columns.len);
                try self.columns.ensureUnusedCapacity(allocator, restored_columns.len);

                self.current_row.columns.start = self.columns.items.len;
                self.current_row.columns.len = restored_columns.len;
                self.columns.appendSliceAssumeCapacity(self.columns.items[restored_columns.start..][0..restored_columns.len]);
            },
            .def_cfa => |i| {
                self.current_row.cfa = .{
                    .register = i.operands.register,
                    .rule = .{ .offset = @intCast(i64, i.operands.offset) },
                };
            },
            .def_cfa_register => |i| {
                // TODO: Verify the the current row is using a register and offset (validation)
                self.current_row.cfa.register = i.operands.register;
            },
            .def_cfa_offset => |i| {
                // TODO: Verify the the current row is using a register and offset (validation)
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

        return prev_row;
    }
};
