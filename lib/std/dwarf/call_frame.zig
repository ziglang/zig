const builtin = @import("builtin");
const std = @import("../std.zig");
const mem = std.mem;
const debug = std.debug;
const leb = std.leb;
const dwarf = std.dwarf;
const abi = dwarf.abi;
const expressions = dwarf.expressions;
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
    const block_len = try leb.readULEB128(usize, reader);
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
    offset_extended: struct {
        register: u8,
        offset: u64,
    },
    restore: struct {
        register: u8,
    },
    restore_extended: struct {
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
                            .offset = try leb.readULEB128(u64, reader),
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
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readULEB128(u64, reader),
                        },
                    },
                    .restore_extended => .{
                        .restore_extended = .{
                            .register = try leb.readULEB128(u8, reader),
                        },
                    },
                    .undefined => .{
                        .undefined = .{
                            .register = try leb.readULEB128(u8, reader),
                        },
                    },
                    .same_value => .{
                        .same_value = .{
                            .register = try leb.readULEB128(u8, reader),
                        },
                    },
                    .register => .{
                        .register = .{
                            .register = try leb.readULEB128(u8, reader),
                            .target_register = try leb.readULEB128(u8, reader),
                        },
                    },
                    .remember_state => .{ .remember_state = {} },
                    .restore_state => .{ .restore_state = {} },
                    .def_cfa => .{
                        .def_cfa = .{
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readULEB128(u64, reader),
                        },
                    },
                    .def_cfa_register => .{
                        .def_cfa_register = .{
                            .register = try leb.readULEB128(u8, reader),
                        },
                    },
                    .def_cfa_offset => .{
                        .def_cfa_offset = .{
                            .offset = try leb.readULEB128(u64, reader),
                        },
                    },
                    .def_cfa_expression => .{
                        .def_cfa_expression = .{
                            .block = try readBlock(stream),
                        },
                    },
                    .expression => .{
                        .expression = .{
                            .register = try leb.readULEB128(u8, reader),
                            .block = try readBlock(stream),
                        },
                    },
                    .offset_extended_sf => .{
                        .offset_extended_sf = .{
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readILEB128(i64, reader),
                        },
                    },
                    .def_cfa_sf => .{
                        .def_cfa_sf = .{
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readILEB128(i64, reader),
                        },
                    },
                    .def_cfa_offset_sf => .{
                        .def_cfa_offset_sf = .{
                            .offset = try leb.readILEB128(i64, reader),
                        },
                    },
                    .val_offset => .{
                        .val_offset = .{
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readULEB128(u64, reader),
                        },
                    },
                    .val_offset_sf => .{
                        .val_offset_sf = .{
                            .register = try leb.readULEB128(u8, reader),
                            .offset = try leb.readILEB128(i64, reader),
                        },
                    },
                    .val_expression => .{
                        .val_expression = .{
                            .register = try leb.readULEB128(u8, reader),
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

/// Since register rules are applied (usually) during a panic,
/// checked addition / subtraction is used so that we can return
/// an error and fall back to FP-based unwinding.
pub fn applyOffset(base: usize, offset: i64) !usize {
    return if (offset >= 0)
        try std.math.add(usize, base, @as(usize, @intCast(offset)))
    else
        try std.math.sub(usize, base, @as(usize, @intCast(-offset)));
}

/// This is a virtual machine that runs DWARF call frame instructions.
pub const VirtualMachine = struct {
    /// See section 6.4.1 of the DWARF5 specification for details on each
    const RegisterRule = union(enum) {
        // The spec says that the default rule for each column is the undefined rule.
        // However, it also allows ABI / compiler authors to specify alternate defaults, so
        // there is a distinction made here.
        default: void,

        undefined: void,
        same_value: void,

        // offset(N)
        offset: i64,

        // val_offset(N)
        val_offset: i64,

        // register(R)
        register: u8,

        // expression(E)
        expression: []const u8,

        // val_expression(E)
        val_expression: []const u8,

        // Augmenter-defined rule
        architectural: void,
    };

    /// Each row contains unwinding rules for a set of registers.
    pub const Row = struct {
        /// Offset from `FrameDescriptionEntry.pc_begin`
        offset: u64 = 0,

        /// Special-case column that defines the CFA (Canonical Frame Address) rule.
        /// The register field of this column defines the register that CFA is derived from.
        cfa: Column = .{},

        /// The register fields in these columns define the register the rule applies to.
        columns: ColumnRange = .{},

        /// Indicates that the next write to any column in this row needs to copy
        /// the backing column storage first, as it may be referenced by previous rows.
        copy_on_write: bool = false,
    };

    pub const Column = struct {
        register: ?u8 = null,
        rule: RegisterRule = .{ .default = {} },

        /// Resolves the register rule and places the result into `out` (see dwarf.abi.regBytes)
        pub fn resolveValue(
            self: Column,
            context: *dwarf.UnwindContext,
            expression_context: dwarf.expressions.ExpressionContext,
            out: []u8,
        ) !void {
            switch (self.rule) {
                .default => {
                    const register = self.register orelse return error.InvalidRegister;
                    try abi.getRegDefaultValue(register, context, out);
                },
                .undefined => {
                    @memset(out, undefined);
                },
                .same_value => {
                    // TODO: This copy could be eliminated if callers always copy the state then call this function to update it
                    const register = self.register orelse return error.InvalidRegister;
                    const src = try abi.regBytes(context.thread_context, register, context.reg_context);
                    if (src.len != out.len) return error.RegisterSizeMismatch;
                    @memcpy(out, src);
                },
                .offset => |offset| {
                    if (context.cfa) |cfa| {
                        const addr = try applyOffset(cfa, offset);
                        if (expression_context.isValidMemory) |isValidMemory| if (!isValidMemory(addr)) return error.InvalidAddress;
                        const ptr: *const usize = @ptrFromInt(addr);
                        mem.writeIntSliceNative(usize, out, ptr.*);
                    } else return error.InvalidCFA;
                },
                .val_offset => |offset| {
                    if (context.cfa) |cfa| {
                        mem.writeIntSliceNative(usize, out, try applyOffset(cfa, offset));
                    } else return error.InvalidCFA;
                },
                .register => |register| {
                    const src = try abi.regBytes(context.thread_context, register, context.reg_context);
                    if (src.len != out.len) return error.RegisterSizeMismatch;
                    @memcpy(out, try abi.regBytes(context.thread_context, register, context.reg_context));
                },
                .expression => |expression| {
                    context.stack_machine.reset();
                    const value = try context.stack_machine.run(expression, context.allocator, expression_context, context.cfa.?);
                    const addr = if (value) |v| blk: {
                        if (v != .generic) return error.InvalidExpressionValue;
                        break :blk v.generic;
                    } else return error.NoExpressionValue;

                    if (!context.isValidMemory(addr)) return error.InvalidExpressionAddress;
                    const ptr: *usize = @ptrFromInt(addr);
                    mem.writeIntSliceNative(usize, out, ptr.*);
                },
                .val_expression => |expression| {
                    context.stack_machine.reset();
                    const value = try context.stack_machine.run(expression, context.allocator, expression_context, context.cfa.?);
                    if (value) |v| {
                        if (v != .generic) return error.InvalidExpressionValue;
                        mem.writeIntSliceNative(usize, out, v.generic);
                    } else return error.NoExpressionValue;
                },
                .architectural => return error.UnimplementedRegisterRule,
            }
        }
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

    pub fn deinit(self: *VirtualMachine, allocator: std.mem.Allocator) void {
        self.stack.deinit(allocator);
        self.columns.deinit(allocator);
        self.* = undefined;
    }

    pub fn reset(self: *VirtualMachine) void {
        self.stack.clearRetainingCapacity();
        self.columns.clearRetainingCapacity();
        self.current_row = .{};
        self.cie_row = null;
    }

    /// Return a slice backed by the row's non-CFA columns
    pub fn rowColumns(self: VirtualMachine, row: Row) []Column {
        return self.columns.items[row.columns.start..][0..row.columns.len];
    }

    /// Either retrieves or adds a column for `register` (non-CFA) in the current row.
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
    /// once the row that corresponds to `pc` is known, and the row is returned.
    pub fn runTo(
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

        var cie_stream = std.io.fixedBufferStream(cie.initial_instructions);
        var fde_stream = std.io.fixedBufferStream(fde.instructions);
        var streams = [_]*std.io.FixedBufferStream([]const u8){
            &cie_stream,
            &fde_stream,
        };

        for (&streams, 0..) |stream, i| {
            while (stream.pos < stream.buffer.len) {
                const instruction = try dwarf.call_frame.Instruction.read(stream, addr_size_bytes, endian);
                prev_row = try self.step(allocator, cie, i == 0, instruction);
                if (pc < fde.pc_begin + self.current_row.offset) return prev_row;
            }
        }

        return self.current_row;
    }

    pub fn runToNative(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        pc: u64,
        cie: dwarf.CommonInformationEntry,
        fde: dwarf.FrameDescriptionEntry,
    ) !Row {
        return self.runTo(allocator, pc, cie, fde, @sizeOf(usize), builtin.target.cpu.arch.endian());
    }

    fn resolveCopyOnWrite(self: *VirtualMachine, allocator: std.mem.Allocator) !void {
        if (!self.current_row.copy_on_write) return;

        const new_start = self.columns.items.len;
        if (self.current_row.columns.len > 0) {
            try self.columns.ensureUnusedCapacity(allocator, self.current_row.columns.len);
            self.columns.appendSliceAssumeCapacity(self.rowColumns(self.current_row));
            self.current_row.columns.start = new_start;
        }
    }

    /// Executes a single instruction.
    /// If this instruction is from the CIE, `is_initial` should be set.
    /// Returns the value of `current_row` before executing this instruction.
    pub fn step(
        self: *VirtualMachine,
        allocator: std.mem.Allocator,
        cie: dwarf.CommonInformationEntry,
        is_initial: bool,
        instruction: Instruction,
    ) !Row {
        // CIE instructions must be run before FDE instructions
        assert(!is_initial or self.cie_row == null);
        if (!is_initial and self.cie_row == null) {
            self.cie_row = self.current_row;
            self.current_row.copy_on_write = true;
        }

        const prev_row = self.current_row;
        switch (instruction) {
            .set_loc => |i| {
                if (i.address <= self.current_row.offset) return error.InvalidOperation;
                // TODO: Check cie.segment_selector_size != 0 for DWARFV4
                self.current_row.offset = i.address;
            },
            inline .advance_loc,
            .advance_loc1,
            .advance_loc2,
            .advance_loc4,
            => |i| {
                self.current_row.offset += i.delta * cie.code_alignment_factor;
                self.current_row.copy_on_write = true;
            },
            inline .offset,
            .offset_extended,
            .offset_extended_sf,
            => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor };
            },
            inline .restore,
            .restore_extended,
            => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.cie_row) |cie_row| {
                    const column = try self.getOrAddColumn(allocator, i.register);
                    column.rule = for (self.rowColumns(cie_row)) |cie_column| {
                        if (cie_column.register == i.register) break cie_column.rule;
                    } else .{ .default = {} };
                } else return error.InvalidOperation;
            },
            .nop => {},
            .undefined => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .undefined = {} };
            },
            .same_value => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .same_value = {} };
            },
            .register => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{ .register = i.target_register };
            },
            .remember_state => {
                try self.stack.append(allocator, self.current_row.columns);
                self.current_row.copy_on_write = true;
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
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa = .{
                    .register = i.register,
                    .rule = .{ .val_offset = @intCast(i.offset) },
                };
            },
            .def_cfa_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa = .{
                    .register = i.register,
                    .rule = .{ .val_offset = i.offset * cie.data_alignment_factor },
                };
            },
            .def_cfa_register => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.register = i.register;
            },
            .def_cfa_offset => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.rule = .{
                    .val_offset = @intCast(i.offset),
                };
            },
            .def_cfa_offset_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
                self.current_row.cfa.rule = .{
                    .val_offset = i.offset * cie.data_alignment_factor,
                };
            },
            .def_cfa_expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                self.current_row.cfa.register = undefined;
                self.current_row.cfa.rule = .{
                    .expression = i.block,
                };
            },
            .expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .expression = i.block,
                };
            },
            .val_offset => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor,
                };
            },
            .val_offset_sf => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_offset = i.offset * cie.data_alignment_factor,
                };
            },
            .val_expression => |i| {
                try self.resolveCopyOnWrite(allocator);
                const column = try self.getOrAddColumn(allocator, i.register);
                column.rule = .{
                    .val_expression = i.block,
                };
            },
        }

        return prev_row;
    }
};
