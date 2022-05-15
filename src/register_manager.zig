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
    comptime tracked_registers: []const Register,
) type {
    // architectures which do not have a concept of registers should
    // refrain from using RegisterManager
    assert(tracked_registers.len > 0); // see note above

    return struct {
        /// Tracks the AIR instruction allocated to every register. If
        /// no instruction is allocated to a register (i.e. the
        /// register is free), the value in that slot is undefined.
        ///
        /// The key must be canonical register.
        registers: [tracked_registers.len]Air.Inst.Index = undefined,
        /// Tracks which registers are free (in which case the
        /// corresponding bit is set to 1)
        free_registers: FreeRegInt = math.maxInt(FreeRegInt),
        /// Tracks all registers allocated in the course of this
        /// function
        allocated_registers: FreeRegInt = 0,
        /// Tracks registers which are locked from being allocated
        locked_registers: FreeRegInt = 0,

        const Self = @This();

        /// An integer whose bits represent all the registers and
        /// whether they are free.
        const FreeRegInt = std.meta.Int(.unsigned, tracked_registers.len);
        const ShiftInt = math.Log2Int(FreeRegInt);

        fn getFunction(self: *Self) *Function {
            return @fieldParentPtr(Function, "register_manager", self);
        }

        fn getRegisterMask(reg: Register) ?FreeRegInt {
            const index = indexOfRegIntoTracked(reg) orelse return null;
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

        pub fn indexOfReg(comptime registers: []const Register, reg: Register) ?std.math.IntFittingRange(0, registers.len - 1) {
            inline for (tracked_registers) |cpreg, i| {
                if (reg.id() == cpreg.id()) return i;
            }
            return null;
        }

        pub fn indexOfRegIntoTracked(reg: Register) ?ShiftInt {
            return indexOfReg(tracked_registers, reg);
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

        /// Returns whether this register is locked
        ///
        /// Returns false when this register is not tracked
        pub fn isRegLocked(self: Self, reg: Register) bool {
            const mask = getRegisterMask(reg) orelse return false;
            return self.locked_registers & mask != 0;
        }

        pub const RegisterLock = struct {
            register: Register,
        };

        /// Prevents the register from being allocated until they are
        /// unlocked again.
        /// Returns `RegisterLock` if the register was not already
        /// locked, or `null` otherwise.
        /// Only the owner of the `RegisterLock` can unlock the
        /// register later.
        pub fn lockReg(self: *Self, reg: Register) ?RegisterLock {
            log.debug("locking {}", .{reg});
            if (self.isRegLocked(reg)) {
                log.debug("  register already locked", .{});
                return null;
            }
            const mask = getRegisterMask(reg) orelse return null;
            self.locked_registers |= mask;
            return RegisterLock{ .register = reg };
        }

        /// Like `lockReg` but asserts the register was unused always
        /// returning a valid lock.
        pub fn lockRegAssumeUnused(self: *Self, reg: Register) RegisterLock {
            log.debug("locking asserting free {}", .{reg});
            assert(!self.isRegLocked(reg));
            const mask = getRegisterMask(reg) orelse unreachable;
            self.locked_registers |= mask;
            return RegisterLock{ .register = reg };
        }

        /// Like `lockRegAssumeUnused` but locks multiple registers.
        pub fn lockRegsAssumeUnused(
            self: *Self,
            comptime count: comptime_int,
            regs: [count]Register,
        ) [count]RegisterLock {
            var buf: [count]RegisterLock = undefined;
            for (regs) |reg, i| {
                buf[i] = self.lockRegAssumeUnused(reg);
            }
            return buf;
        }

        /// Unlocks the register allowing its re-allocation and re-use.
        /// Requires `RegisterLock` to unlock a register.
        /// Call `lockReg` to obtain the lock first.
        pub fn unlockReg(self: *Self, lock: RegisterLock) void {
            log.debug("unlocking {}", .{lock.register});
            const mask = getRegisterMask(lock.register) orelse return;
            self.locked_registers &= ~mask;
        }

        /// Returns true when at least one register is locked
        pub fn lockedRegsExist(self: Self) bool {
            return self.locked_registers != 0;
        }

        /// Allocates a specified number of registers, optionally
        /// tracking them. Returns `null` if not enough registers are
        /// free.
        pub fn tryAllocRegs(
            self: *Self,
            comptime count: comptime_int,
            insts: [count]?Air.Inst.Index,
        ) ?[count]Register {
            comptime assert(count > 0 and count <= tracked_registers.len);

            const free_and_not_locked_registers = self.free_registers & ~self.locked_registers;
            const free_and_not_locked_registers_count = @popCount(FreeRegInt, free_and_not_locked_registers);
            if (free_and_not_locked_registers_count < count) return null;

            var regs: [count]Register = undefined;
            var i: usize = 0;
            for (tracked_registers) |reg| {
                if (i >= count) break;
                if (self.isRegLocked(reg)) continue;
                if (!self.isRegFree(reg)) continue;

                regs[i] = reg;
                i += 1;
            }
            assert(i == count);

            for (regs) |reg, j| {
                self.markRegAllocated(reg);

                if (insts[j]) |inst| {
                    // Track the register
                    const index = indexOfRegIntoTracked(reg).?; // indexOfReg() on a callee-preserved reg should never return null
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
            comptime assert(count > 0 and count <= tracked_registers.len);
            const locked_registers_count = @popCount(FreeRegInt, self.locked_registers);
            if (count > tracked_registers.len - locked_registers_count) return error.OutOfRegisters;

            const result = self.tryAllocRegs(count, insts) orelse blk: {
                // We'll take over the first count registers. Spill
                // the instructions that were previously there to a
                // stack allocations.
                var regs: [count]Register = undefined;
                var i: usize = 0;
                for (tracked_registers) |reg| {
                    if (i >= count) break;
                    if (self.isRegLocked(reg)) continue;

                    regs[i] = reg;
                    self.markRegAllocated(reg);
                    const index = indexOfRegIntoTracked(reg).?; // indexOfReg() on a callee-preserved reg should never return null
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
            const index = indexOfRegIntoTracked(reg) orelse return;
            log.debug("getReg {} for inst {}", .{ reg, inst });
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
            const index = indexOfRegIntoTracked(reg) orelse return;
            log.debug("getRegAssumeFree {} for inst {}", .{ reg, inst });
            self.markRegAllocated(reg);

            assert(self.isRegFree(reg));
            self.registers[index] = inst;
            self.markRegUsed(reg);
        }

        /// Marks the specified register as free
        pub fn freeReg(self: *Self, reg: Register) void {
            const index = indexOfRegIntoTracked(reg) orelse return;
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

    pub fn id(reg: MockRegister1) u2 {
        return @enumToInt(reg);
    }

    const allocatable_registers = [_]MockRegister1{ .r2, .r3 };
};

const MockRegister2 = enum(u2) {
    r0,
    r1,
    r2,
    r3,

    pub fn id(reg: MockRegister2) u2 {
        return @enumToInt(reg);
    }

    const allocatable_registers = [_]MockRegister2{ .r0, .r1, .r2, .r3 };
};

fn MockFunction(comptime Register: type) type {
    return struct {
        allocator: Allocator,
        register_manager: RegisterManager(Self, Register, &Register.allocatable_registers) = .{},
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

    // Locked registers
    function.register_manager.freeReg(.r3);
    {
        const lock = function.register_manager.lockReg(.r2);
        defer if (lock) |reg| function.register_manager.unlockReg(reg);

        try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction));
    }
    try expect(!function.register_manager.lockedRegsExist());
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

    // Locked registers
    function.register_manager.freeReg(.r0);
    function.register_manager.freeReg(.r2);
    function.register_manager.freeReg(.r3);
    {
        const lock = function.register_manager.lockReg(.r1);
        defer if (lock) |reg| function.register_manager.unlockReg(reg);

        try expectEqual([_]MockRegister2{ .r0, .r2, .r3 }, function.register_manager.tryAllocRegs(3, .{ null, null, null }).?);
    }
    try expect(!function.register_manager.lockedRegsExist());

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
        // result register, this is why we lock it.
        //
        // Using defer unlock right after lock is a good idea in
        // most cases as you probably are using the locked registers
        // in the remainder of this scope and don't need to use it
        // after the end of this scope. However, in some situations,
        // it may make sense to manually unlock registers before the
        // end of the scope when you are certain that they don't
        // contain any valuable data anymore and can be reused. For an
        // example of that, see `selectively reducing register
        // pressure`.
        const lock = function.register_manager.lockReg(result_reg);
        defer if (lock) |reg| function.register_manager.unlockReg(reg);

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

        const lock = function.register_manager.lockReg(result_reg);

        // Here, we don't defer unlock because we manually unlock
        // after genAdd
        const regs = try function.register_manager.allocRegs(2, .{ null, null });

        try function.genAdd(result_reg, regs[0], regs[1]);
        function.register_manager.unlockReg(lock.?);

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
