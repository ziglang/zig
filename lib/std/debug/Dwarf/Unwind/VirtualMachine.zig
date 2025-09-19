//! Virtual machine that evaluates DWARF call frame instructions

/// See section 6.4.1 of the DWARF5 specification for details on each
pub const RegisterRule = union(enum) {
    /// The spec says that the default rule for each column is the undefined rule.
    /// However, it also allows ABI / compiler authors to specify alternate defaults, so
    /// there is a distinction made here.
    default: void,
    undefined: void,
    same_value: void,
    /// offset(N)
    offset: i64,
    /// val_offset(N)
    val_offset: i64,
    /// register(R)
    register: u8,
    /// expression(E)
    expression: []const u8,
    /// val_expression(E)
    val_expression: []const u8,
    /// Augmenter-defined rule
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
};

const ColumnRange = struct {
    /// Index into `columns` of the first column in this row.
    start: usize = undefined,
    len: u8 = 0,
};

columns: std.ArrayList(Column) = .empty,
stack: std.ArrayList(struct {
    cfa: Column,
    columns: ColumnRange,
}) = .empty,
current_row: Row = .{},

/// The result of executing the CIE's initial_instructions
cie_row: ?Row = null,

pub fn deinit(self: *VirtualMachine, gpa: Allocator) void {
    self.stack.deinit(gpa);
    self.columns.deinit(gpa);
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
    if (row.columns.len == 0) return &.{};
    return self.columns.items[row.columns.start..][0..row.columns.len];
}

/// Either retrieves or adds a column for `register` (non-CFA) in the current row.
fn getOrAddColumn(self: *VirtualMachine, gpa: Allocator, register: u8) !*Column {
    for (self.rowColumns(self.current_row)) |*c| {
        if (c.register == register) return c;
    }

    if (self.current_row.columns.len == 0) {
        self.current_row.columns.start = self.columns.items.len;
    }
    self.current_row.columns.len += 1;

    const column = try self.columns.addOne(gpa);
    column.* = .{
        .register = register,
    };

    return column;
}

/// Runs the CIE instructions, then the FDE instructions. Execution halts
/// once the row that corresponds to `pc` is known, and the row is returned.
pub fn runTo(
    self: *VirtualMachine,
    gpa: Allocator,
    pc: u64,
    cie: Dwarf.Unwind.CommonInformationEntry,
    fde: Dwarf.Unwind.FrameDescriptionEntry,
    addr_size_bytes: u8,
    endian: std.builtin.Endian,
) !Row {
    assert(self.cie_row == null);
    assert(pc >= fde.pc_begin);
    assert(pc < fde.pc_begin + fde.pc_range);

    var prev_row: Row = self.current_row;

    const instruction_slices: [2][]const u8 = .{
        cie.initial_instructions,
        fde.instructions,
    };
    for (instruction_slices, [2]bool{ true, false }) |slice, is_cie_stream| {
        var stream: std.Io.Reader = .fixed(slice);
        while (stream.seek < slice.len) {
            const instruction: Dwarf.call_frame.Instruction = try .read(&stream, addr_size_bytes, endian);
            prev_row = try self.step(gpa, cie, is_cie_stream, instruction);
            if (pc < fde.pc_begin + self.current_row.offset) return prev_row;
        }
    }

    return self.current_row;
}

fn resolveCopyOnWrite(self: *VirtualMachine, gpa: Allocator) !void {
    if (!self.current_row.copy_on_write) return;

    const new_start = self.columns.items.len;
    if (self.current_row.columns.len > 0) {
        try self.columns.ensureUnusedCapacity(gpa, self.current_row.columns.len);
        self.columns.appendSliceAssumeCapacity(self.rowColumns(self.current_row));
        self.current_row.columns.start = new_start;
    }
}

/// Executes a single instruction.
/// If this instruction is from the CIE, `is_initial` should be set.
/// Returns the value of `current_row` before executing this instruction.
pub fn step(
    self: *VirtualMachine,
    gpa: Allocator,
    cie: Dwarf.Unwind.CommonInformationEntry,
    is_initial: bool,
    instruction: Dwarf.call_frame.Instruction,
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
            if (cie.segment_selector_size != 0) return error.InvalidOperation; // unsupported
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
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{ .offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor };
        },
        inline .restore,
        .restore_extended,
        => |i| {
            try self.resolveCopyOnWrite(gpa);
            if (self.cie_row) |cie_row| {
                const column = try self.getOrAddColumn(gpa, i.register);
                column.rule = for (self.rowColumns(cie_row)) |cie_column| {
                    if (cie_column.register == i.register) break cie_column.rule;
                } else .{ .default = {} };
            } else return error.InvalidOperation;
        },
        .nop => {},
        .undefined => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{ .undefined = {} };
        },
        .same_value => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{ .same_value = {} };
        },
        .register => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{ .register = i.target_register };
        },
        .remember_state => {
            try self.stack.append(gpa, .{
                .cfa = self.current_row.cfa,
                .columns = self.current_row.columns,
            });
            self.current_row.copy_on_write = true;
        },
        .restore_state => {
            const restored = self.stack.pop() orelse return error.InvalidOperation;
            self.columns.shrinkRetainingCapacity(self.columns.items.len - self.current_row.columns.len);
            try self.columns.ensureUnusedCapacity(gpa, restored.columns.len);

            self.current_row.cfa = restored.cfa;
            self.current_row.columns.start = self.columns.items.len;
            self.current_row.columns.len = restored.columns.len;
            self.columns.appendSliceAssumeCapacity(self.columns.items[restored.columns.start..][0..restored.columns.len]);
        },
        .def_cfa => |i| {
            try self.resolveCopyOnWrite(gpa);
            self.current_row.cfa = .{
                .register = i.register,
                .rule = .{ .val_offset = @intCast(i.offset) },
            };
        },
        .def_cfa_sf => |i| {
            try self.resolveCopyOnWrite(gpa);
            self.current_row.cfa = .{
                .register = i.register,
                .rule = .{ .val_offset = i.offset * cie.data_alignment_factor },
            };
        },
        .def_cfa_register => |i| {
            try self.resolveCopyOnWrite(gpa);
            if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
            self.current_row.cfa.register = i.register;
        },
        .def_cfa_offset => |i| {
            try self.resolveCopyOnWrite(gpa);
            if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
            self.current_row.cfa.rule = .{
                .val_offset = @intCast(i.offset),
            };
        },
        .def_cfa_offset_sf => |i| {
            try self.resolveCopyOnWrite(gpa);
            if (self.current_row.cfa.register == null or self.current_row.cfa.rule != .val_offset) return error.InvalidOperation;
            self.current_row.cfa.rule = .{
                .val_offset = i.offset * cie.data_alignment_factor,
            };
        },
        .def_cfa_expression => |i| {
            try self.resolveCopyOnWrite(gpa);
            self.current_row.cfa.register = undefined;
            self.current_row.cfa.rule = .{
                .expression = i.block,
            };
        },
        .expression => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{
                .expression = i.block,
            };
        },
        .val_offset => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{
                .val_offset = @as(i64, @intCast(i.offset)) * cie.data_alignment_factor,
            };
        },
        .val_offset_sf => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{
                .val_offset = i.offset * cie.data_alignment_factor,
            };
        },
        .val_expression => |i| {
            try self.resolveCopyOnWrite(gpa);
            const column = try self.getOrAddColumn(gpa, i.register);
            column.rule = .{
                .val_expression = i.block,
            };
        },
    }

    return prev_row;
}

const std = @import("../../../std.zig");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Dwarf = std.debug.Dwarf;

const VirtualMachine = @This();
