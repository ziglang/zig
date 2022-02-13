const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Air = @import("Air.zig");
const Type = @import("type.zig").Type;
const Module = @import("Module.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectEqualSlices = std.testing.expectEqualSlices;

const log = std.log.scoped(.register_manager);

pub const AllocateRegistersError = error{
    /// No registers are available anymore
    OutOfRegisters,
    /// Can happen when spilling an instruction in codegen runs out of
    /// memory, so we propagate that error
    OutOfMemory,
    /// Can happen when spilling an instruction triggers a codegen
    /// error, so we propagate that error
    CodegenFail,
};

pub fn RegisterManager(
    comptime Function: type,
    comptime Register: type,
    comptime callee_preserved_regs: []const Register,
) type {
    // architectures which do not have a concept of registers should
    // refrain from using RegisterManager
    assert(callee_preserved_regs.len > 0); // see note above

    return struct {
        /// Tracks the AIR instruction allocated to every register. If
        /// no instruction is allocated to a register (i.e. the
        /// register is free), the value in that slot is undefined.
        ///
        /// The key must be canonical register.
        registers: [callee_preserved_regs.len]Air.Inst.Index = undefined,
        /// Tracks which registers are free (in which case the
        /// corresponding bit is set to 1)
        free_registers: FreeRegInt = math.maxInt(FreeRegInt),
        /// Tracks all registers allocated in the course of this
        /// function
        allocated_registers: FreeRegInt = 0,
        /// Tracks registers which are temporarily blocked from being
        /// allocated
        frozen_registers: FreeRegInt = 0,

        const Self = @This();

        /// An integer whose bits represent all the registers and
        /// whether they are free.
        const FreeRegInt = std.meta.Int(.unsigned, callee_preserved_regs.len);
        const ShiftInt = math.Log2Int(FreeRegInt);

        fn getFunction(self: *Self) *Function {
            return @fieldParentPtr(Function, "register_manager", self);
        }

        fn getRegisterMask(reg: Register) ?FreeRegInt {
            const index = reg.allocIndex() orelse return null;
            const shift = @intCast(ShiftInt, index);
            const mask = @as(FreeRegInt, 1) << shift;
            return mask;
        }

        fn markRegAllocated(self: *Self, reg: Register) void {
            const mask = getRegisterMask(reg) orelse return;
            self.allocated_registers |= mask;
        }

        fn markRegUsed(self: *Self, reg: Register) void {
            const mask = getRegisterMask(reg) orelse return;
            self.free_registers &= ~mask;
        }

        fn markRegFree(self: *Self, reg: Register) void {
            const mask = getRegisterMask(reg) orelse return;
            self.free_registers |= mask;
        }

        /// Returns true when this register is not tracked
        pub fn isRegFree(self: Self, reg: Register) bool {
            const mask = getRegisterMask(reg) orelse return true;
            return self.free_registers & mask != 0;
        }

        /// Returns whether this register was allocated in the course
        /// of this function.
        ///
        /// Returns false when this register is not tracked
        pub fn isRegAllocated(self: Self, reg: Register) bool {
            const mask = getRegisterMask(reg) orelse return false;
            return self.allocated_registers & mask != 0;
        }

        /// Returns whether this register is frozen
        ///
        /// Returns false when this register is not tracked
        pub fn isRegFrozen(self: Self, reg: Register) bool {
            const mask = getRegisterMask(reg) orelse return false;
            return self.frozen_registers & mask != 0;
        }

        /// Prevents the registers from being allocated until they are
        /// unfrozen again
        pub fn freezeRegs(self: *Self, regs: []const Register) void {
            for (regs) |reg| {
                const mask = getRegisterMask(reg) orelse continue;
                self.frozen_registers |= mask;
            }
        }

        /// Enables the allocation of the registers
        pub fn unfreezeRegs(self: *Self, regs: []const Register) void {
            for (regs) |reg| {
                const mask = getRegisterMask(reg) orelse continue;
                self.frozen_registers &= ~mask;
            }
        }

        /// Returns true when at least one register is frozen
        pub fn frozenRegsExist(self: Self) bool {
            return self.frozen_registers != 0;
        }

        /// Allocates a specified number of registers, optionally
        /// tracking them. Returns `null` if not enough registers are
        /// free.
        pub fn tryAllocRegs(
            self: *Self,
            comptime count: comptime_int,
            insts: [count]?Air.Inst.Index,
        ) ?[count]Register {
            comptime assert(count > 0 and count <= callee_preserved_regs.len);

            const free_registers = @popCount(FreeRegInt, self.free_registers);
            if (free_registers < count) return null;

            var regs: [count]Register = undefined;
            var i: usize = 0;
            for (callee_preserved_regs) |reg| {
                if (i >= count) break;
                if (self.isRegFrozen(reg)) continue;
                if (self.isRegFree(reg)) {
                    regs[i] = reg;
                    i += 1;
                }
            }
            assert(i == count);

            for (regs) |reg, j| {
                self.markRegAllocated(reg);

                if (insts[j]) |inst| {
                    // Track the register
                    const index = reg.allocIndex().?; // allocIndex() on a callee-preserved reg should never return null
                    self.registers[index] = inst;
                    self.markRegUsed(reg);
                }
            }

            return regs;
        }

        /// Allocates a register and optionally tracks it with a
        /// corresponding instruction. Returns `null` if all registers
        /// are allocated.
        pub fn tryAllocReg(self: *Self, inst: ?Air.Inst.Index) ?Register {
            return if (tryAllocRegs(self, 1, .{inst})) |regs| regs[0] else null;
        }

        /// Allocates a specified number of registers, optionally
        /// tracking them. Asserts that count is not
        /// larger than the total number of registers available.
        pub fn allocRegs(
            self: *Self,
            comptime count: comptime_int,
            insts: [count]?Air.Inst.Index,
        ) AllocateRegistersError![count]Register {
            comptime assert(count > 0 and count <= callee_preserved_regs.len);
            if (count > callee_preserved_regs.len - @popCount(FreeRegInt, self.frozen_registers)) return error.OutOfRegisters;

            const result = self.tryAllocRegs(count, insts) orelse blk: {
                // We'll take over the first count registers. Spill
                // the instructions that were previously there to a
                // stack allocations.
                var regs: [count]Register = undefined;
                var i: usize = 0;
                for (callee_preserved_regs) |reg| {
                    if (i >= count) break;
                    if (self.isRegFrozen(reg)) continue;

                    regs[i] = reg;
                    self.markRegAllocated(reg);
                    const index = reg.allocIndex().?; // allocIndex() on a callee-preserved reg should never return null
                    if (insts[i]) |inst| {
                        // Track the register
                        if (self.isRegFree(reg)) {
                            self.markRegUsed(reg);
                        } else {
                            const spilled_inst = self.registers[index];
                            try self.getFunction().spillInstruction(reg, spilled_inst);
                        }
                        self.registers[index] = inst;
                    } else {
                        // Don't track the register
                        if (!self.isRegFree(reg)) {
                            const spilled_inst = self.registers[index];
                            try self.getFunction().spillInstruction(reg, spilled_inst);
                            self.freeReg(reg);
                        }
                    }

                    i += 1;
                }

                break :blk regs;
            };

            log.debug("allocated registers {any} for insts {any}", .{ result, insts });
            return result;
        }

        /// Allocates a register and optionally tracks it with a
        /// corresponding instruction.
        pub fn allocReg(self: *Self, inst: ?Air.Inst.Index) AllocateRegistersError!Register {
            return (try self.allocRegs(1, .{inst}))[0];
        }

        /// Spills the register if it is currently allocated. If a
        /// corresponding instruction is passed, will also track this
        /// register.
        pub fn getReg(self: *Self, reg: Register, inst: ?Air.Inst.Index) AllocateRegistersError!void {
            const index = reg.allocIndex() orelse return;
            self.markRegAllocated(reg);

            if (inst) |tracked_inst|
                if (!self.isRegFree(reg)) {
                    // Move the instruction that was previously there to a
                    // stack allocation.
                    const spilled_inst = self.registers[index];
                    self.registers[index] = tracked_inst;
                    try self.getFunction().spillInstruction(reg, spilled_inst);
                } else {
                    self.getRegAssumeFree(reg, tracked_inst);
                }
            else {
                if (!self.isRegFree(reg)) {
                    // Move the instruction that was previously there to a
                    // stack allocation.
                    const spilled_inst = self.registers[index];
                    try self.getFunction().spillInstruction(reg, spilled_inst);
                    self.freeReg(reg);
                }
            }
        }

        /// Allocates the specified register with the specified
        /// instruction. Asserts that the register is free and no
        /// spilling is necessary.
        pub fn getRegAssumeFree(self: *Self, reg: Register, inst: Air.Inst.Index) void {
            const index = reg.allocIndex() orelse return;
            self.markRegAllocated(reg);

            assert(self.isRegFree(reg));
            self.registers[index] = inst;
            self.markRegUsed(reg);
        }

        /// Marks the specified register as free
        pub fn freeReg(self: *Self, reg: Register) void {
            const index = reg.allocIndex() orelse return;
            log.debug("freeing register {}", .{reg});

            self.registers[index] = undefined;
            self.markRegFree(reg);
        }
    };
}

const MockRegister1 = enum(u2) {
    r0,
    r1,
    r2,
    r3,

    pub fn allocIndex(self: MockRegister1) ?u2 {
        inline for (callee_preserved_regs) |cpreg, i| {
            if (self == cpreg) return i;
        }
        return null;
    }

    const callee_preserved_regs = [_]MockRegister1{ .r2, .r3 };
};

const MockRegister2 = enum(u2) {
    r0,
    r1,
    r2,
    r3,

    pub fn allocIndex(self: MockRegister2) ?u2 {
        inline for (callee_preserved_regs) |cpreg, i| {
            if (self == cpreg) return i;
        }
        return null;
    }

    const callee_preserved_regs = [_]MockRegister2{ .r0, .r1, .r2, .r3 };
};

fn MockFunction(comptime Register: type) type {
    return struct {
        allocator: Allocator,
        register_manager: RegisterManager(Self, Register, &Register.callee_preserved_regs) = .{},
        spilled: std.ArrayListUnmanaged(Register) = .{},

        const Self = @This();

        pub fn deinit(self: *Self) void {
            self.spilled.deinit(self.allocator);
        }

        pub fn spillInstruction(self: *Self, reg: Register, inst: Air.Inst.Index) !void {
            _ = inst;
            try self.spilled.append(self.allocator, reg);
        }

        pub fn genAdd(self: *Self, res: Register, lhs: Register, rhs: Register) !void {
            _ = self;
            _ = res;
            _ = lhs;
            _ = rhs;
        }
    };
}

const MockFunction1 = MockFunction(MockRegister1);
const MockFunction2 = MockFunction(MockRegister2);

test "default state" {
    const allocator = std.testing.allocator;

    var function = MockFunction1{
        .allocator = allocator,
    };
    defer function.deinit();

    try expect(!function.register_manager.isRegAllocated(.r2));
    try expect(!function.register_manager.isRegAllocated(.r3));
    try expect(function.register_manager.isRegFree(.r2));
    try expect(function.register_manager.isRegFree(.r3));
}

test "tryAllocReg: no spilling" {
    const allocator = std.testing.allocator;

    var function = MockFunction1{
        .allocator = allocator,
    };
    defer function.deinit();

    const mock_instruction: Air.Inst.Index = 1;

    try expectEqual(@as(?MockRegister1, .r2), function.register_manager.tryAllocReg(mock_instruction));
    try expectEqual(@as(?MockRegister1, .r3), function.register_manager.tryAllocReg(mock_instruction));
    try expectEqual(@as(?MockRegister1, null), function.register_manager.tryAllocReg(mock_instruction));

    try expect(function.register_manager.isRegAllocated(.r2));
    try expect(function.register_manager.isRegAllocated(.r3));
    try expect(!function.register_manager.isRegFree(.r2));
    try expect(!function.register_manager.isRegFree(.r3));

    function.register_manager.freeReg(.r2);
    function.register_manager.freeReg(.r3);

    try expect(function.register_manager.isRegAllocated(.r2));
    try expect(function.register_manager.isRegAllocated(.r3));
    try expect(function.register_manager.isRegFree(.r2));
    try expect(function.register_manager.isRegFree(.r3));
}

test "allocReg: spilling" {
    const allocator = std.testing.allocator;

    var function = MockFunction1{
        .allocator = allocator,
    };
    defer function.deinit();

    const mock_instruction: Air.Inst.Index = 1;

    try expectEqual(@as(?MockRegister1, .r2), try function.register_manager.allocReg(mock_instruction));
    try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction));

    // Spill a register
    try expectEqual(@as(?MockRegister1, .r2), try function.register_manager.allocReg(mock_instruction));
    try expectEqualSlices(MockRegister1, &[_]MockRegister1{.r2}, function.spilled.items);

    // No spilling necessary
    function.register_manager.freeReg(.r3);
    try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction));
    try expectEqualSlices(MockRegister1, &[_]MockRegister1{.r2}, function.spilled.items);

    // Frozen registers
    function.register_manager.freeReg(.r3);
    {
        function.register_manager.freezeRegs(&.{.r2});
        defer function.register_manager.unfreezeRegs(&.{.r2});

        try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction));
    }
    try expect(!function.register_manager.frozenRegsExist());
}

test "tryAllocRegs" {
    const allocator = std.testing.allocator;

    var function = MockFunction2{
        .allocator = allocator,
    };
    defer function.deinit();

    try expectEqual([_]MockRegister2{ .r0, .r1, .r2 }, function.register_manager.tryAllocRegs(3, .{ null, null, null }).?);

    try expect(function.register_manager.isRegAllocated(.r0));
    try expect(function.register_manager.isRegAllocated(.r1));
    try expect(function.register_manager.isRegAllocated(.r2));
    try expect(!function.register_manager.isRegAllocated(.r3));

    // Frozen registers
    function.register_manager.freeReg(.r0);
    function.register_manager.freeReg(.r2);
    function.register_manager.freeReg(.r3);
    {
        function.register_manager.freezeRegs(&.{.r1});
        defer function.register_manager.unfreezeRegs(&.{.r1});

        try expectEqual([_]MockRegister2{ .r0, .r2, .r3 }, function.register_manager.tryAllocRegs(3, .{ null, null, null }).?);
    }
    try expect(!function.register_manager.frozenRegsExist());

    try expect(function.register_manager.isRegAllocated(.r0));
    try expect(function.register_manager.isRegAllocated(.r1));
    try expect(function.register_manager.isRegAllocated(.r2));
    try expect(function.register_manager.isRegAllocated(.r3));
}

test "allocRegs: normal usage" {
    // TODO: convert this into a decltest once that is supported

    const allocator = std.testing.allocator;

    var function = MockFunction2{
        .allocator = allocator,
    };
    defer function.deinit();

    {
        const result_reg: MockRegister2 = .r1;

        // The result register is known and fixed at this point, we
        // don't want to accidentally allocate lhs or rhs to the
        // result register, this is why we freeze it.
        //
        // Using defer unfreeze right after freeze is a good idea in
        // most cases as you probably are using the frozen registers
        // in the remainder of this scope and don't need to use it
        // after the end of this scope. However, in some situations,
        // it may make sense to manually unfreeze registers before the
        // end of the scope when you are certain that they don't
        // contain any valuable data anymore and can be reused. For an
        // example of that, see `selectively reducing register
        // pressure`.
        function.register_manager.freezeRegs(&.{result_reg});
        defer function.register_manager.unfreezeRegs(&.{result_reg});

        const regs = try function.register_manager.allocRegs(2, .{ null, null });
        try function.genAdd(result_reg, regs[0], regs[1]);
    }
}

test "allocRegs: selectively reducing register pressure" {
    // TODO: convert this into a decltest once that is supported

    const allocator = std.testing.allocator;

    var function = MockFunction2{
        .allocator = allocator,
    };
    defer function.deinit();

    {
        const result_reg: MockRegister2 = .r1;

        function.register_manager.freezeRegs(&.{result_reg});
        defer function.register_manager.unfreezeRegs(&.{result_reg});

        // Here, we don't defer unfreeze because we manually unfreeze
        // after genAdd
        const regs = try function.register_manager.allocRegs(2, .{ null, null });
        function.register_manager.freezeRegs(&.{result_reg});

        try function.genAdd(result_reg, regs[0], regs[1]);
        function.register_manager.unfreezeRegs(&regs);

        const extra_summand_reg = try function.register_manager.allocReg(null);
        try function.genAdd(result_reg, result_reg, extra_summand_reg);
    }
}

test "getReg" {
    const allocator = std.testing.allocator;

    var function = MockFunction1{
        .allocator = allocator,
    };
    defer function.deinit();

    const mock_instruction: Air.Inst.Index = 1;

    try function.register_manager.getReg(.r3, mock_instruction);

    try expect(!function.register_manager.isRegAllocated(.r2));
    try expect(function.register_manager.isRegAllocated(.r3));
    try expect(function.register_manager.isRegFree(.r2));
    try expect(!function.register_manager.isRegFree(.r3));

    // Spill r3
    try function.register_manager.getReg(.r3, mock_instruction);

    try expect(!function.register_manager.isRegAllocated(.r2));
    try expect(function.register_manager.isRegAllocated(.r3));
    try expect(function.register_manager.isRegFree(.r2));
    try expect(!function.register_manager.isRegFree(.r3));
    try expectEqualSlices(MockRegister1, &[_]MockRegister1{.r3}, function.spilled.items);
}
