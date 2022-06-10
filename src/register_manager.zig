const std = @import("std");
const math = std.math;
const mem = std.mem;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const Air = @import("Air.zig");
const StaticBitSet = std.bit_set.StaticBitSet;
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
        registers: TrackedRegisters = undefined,
        /// Tracks which registers are free (in which case the
        /// corresponding bit is set to 1)
        free_registers: RegisterBitSet = RegisterBitSet.initFull(),
        /// Tracks all registers allocated in the course of this
        /// function
        allocated_registers: RegisterBitSet = RegisterBitSet.initEmpty(),
        /// Tracks registers which are locked from being allocated
        locked_registers: RegisterBitSet = RegisterBitSet.initEmpty(),

        const Self = @This();

        pub const TrackedRegisters = [tracked_registers.len]Air.Inst.Index;
        pub const RegisterBitSet = StaticBitSet(tracked_registers.len);

        fn getFunction(self: *Self) *Function {
            return @fieldParentPtr(Function, "register_manager", self);
        }

        fn excludeRegister(reg: Register, register_class: RegisterBitSet) bool {
            const index = indexOfRegIntoTracked(reg) orelse return true;
            return !register_class.isSet(index);
        }

        fn markRegAllocated(self: *Self, reg: Register) void {
            const index = indexOfRegIntoTracked(reg) orelse return;
            self.allocated_registers.set(index);
        }

        fn markRegUsed(self: *Self, reg: Register) void {
            const index = indexOfRegIntoTracked(reg) orelse return;
            self.free_registers.unset(index);
        }

        fn markRegFree(self: *Self, reg: Register) void {
            const index = indexOfRegIntoTracked(reg) orelse return;
            self.free_registers.set(index);
        }

        pub fn indexOfReg(
            comptime registers: []const Register,
            reg: Register,
        ) ?std.math.IntFittingRange(0, registers.len - 1) {
            inline for (tracked_registers) |cpreg, i| {
                if (reg.id() == cpreg.id()) return i;
            }
            return null;
        }

        pub fn indexOfRegIntoTracked(reg: Register) ?RegisterBitSet.ShiftInt {
            return indexOfReg(tracked_registers, reg);
        }

        /// Returns true when this register is not tracked
        pub fn isRegFree(self: Self, reg: Register) bool {
            const index = indexOfRegIntoTracked(reg) orelse return true;
            return self.free_registers.isSet(index);
        }

        /// Returns whether this register was allocated in the course
        /// of this function.
        ///
        /// Returns false when this register is not tracked
        pub fn isRegAllocated(self: Self, reg: Register) bool {
            const index = indexOfRegIntoTracked(reg) orelse return false;
            return self.allocated_registers.isSet(index);
        }

        /// Returns whether this register is locked
        ///
        /// Returns false when this register is not tracked
        pub fn isRegLocked(self: Self, reg: Register) bool {
            const index = indexOfRegIntoTracked(reg) orelse return false;
            return self.locked_registers.isSet(index);
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
            const index = indexOfRegIntoTracked(reg) orelse return null;
            self.locked_registers.set(index);
            return RegisterLock{ .register = reg };
        }

        /// Like `lockReg` but asserts the register was unused always
        /// returning a valid lock.
        pub fn lockRegAssumeUnused(self: *Self, reg: Register) RegisterLock {
            log.debug("locking asserting free {}", .{reg});
            assert(!self.isRegLocked(reg));
            const index = indexOfRegIntoTracked(reg) orelse unreachable;
            self.locked_registers.set(index);
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
            const index = indexOfRegIntoTracked(lock.register) orelse return;
            self.locked_registers.unset(index);
        }

        /// Returns true when at least one register is locked
        pub fn lockedRegsExist(self: Self) bool {
            return self.locked_registers.count() > 0;
        }

        /// Allocates a specified number of registers, optionally
        /// tracking them. Returns `null` if not enough registers are
        /// free.
        pub fn tryAllocRegs(
            self: *Self,
            comptime count: comptime_int,
            insts: [count]?Air.Inst.Index,
            register_class: RegisterBitSet,
        ) ?[count]Register {
            comptime assert(count > 0 and count <= tracked_registers.len);

            var free_and_not_locked_registers = self.free_registers;
            free_and_not_locked_registers.setIntersection(register_class);

            var unlocked_registers = self.locked_registers;
            unlocked_registers.toggleAll();

            free_and_not_locked_registers.setIntersection(unlocked_registers);

            if (free_and_not_locked_registers.count() < count) return null;

            var regs: [count]Register = undefined;
            var i: usize = 0;
            for (tracked_registers) |reg| {
                if (i >= count) break;
                if (excludeRegister(reg, register_class)) continue;
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
        pub fn tryAllocReg(self: *Self, inst: ?Air.Inst.Index, register_class: RegisterBitSet) ?Register {
            return if (tryAllocRegs(self, 1, .{inst}, register_class)) |regs| regs[0] else null;
        }

        /// Allocates a specified number of registers, optionally
        /// tracking them. Asserts that count is not
        /// larger than the total number of registers available.
        pub fn allocRegs(
            self: *Self,
            comptime count: comptime_int,
            insts: [count]?Air.Inst.Index,
            register_class: RegisterBitSet,
        ) AllocateRegistersError![count]Register {
            comptime assert(count > 0 and count <= tracked_registers.len);

            var locked_registers = self.locked_registers;
            locked_registers.setIntersection(register_class);

            if (count > register_class.count() - locked_registers.count()) return error.OutOfRegisters;

            const result = self.tryAllocRegs(count, insts, register_class) orelse blk: {
                // We'll take over the first count registers. Spill
                // the instructions that were previously there to a
                // stack allocations.
                var regs: [count]Register = undefined;
                var i: usize = 0;
                for (tracked_registers) |reg| {
                    if (i >= count) break;
                    if (excludeRegister(reg, register_class)) break;
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
        pub fn allocReg(
            self: *Self,
            inst: ?Air.Inst.Index,
            register_class: RegisterBitSet,
        ) AllocateRegistersError!Register {
            return (try self.allocRegs(1, .{inst}, register_class))[0];
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

    const RM = RegisterManager(
        MockFunction1,
        MockRegister1,
        &MockRegister1.allocatable_registers,
    );

    const gp: RM.RegisterBitSet = blk: {
        var set = RM.RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = allocatable_registers.len,
        }, true);
        break :blk set;
    };
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

    const RM = RegisterManager(
        MockFunction2,
        MockRegister2,
        &MockRegister2.allocatable_registers,
    );

    const gp: RM.RegisterBitSet = blk: {
        var set = RM.RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = allocatable_registers.len,
        }, true);
        break :blk set;
    };
};

const MockRegister3 = enum(u3) {
    r0,
    r1,
    r2,
    r3,
    x0,
    x1,
    x2,
    x3,

    pub fn id(reg: MockRegister3) u3 {
        return switch (@enumToInt(reg)) {
            0...3 => @as(u3, @truncate(u2, @enumToInt(reg))),
            4...7 => @enumToInt(reg),
        };
    }

    pub fn enc(reg: MockRegister3) u2 {
        return @truncate(u2, @enumToInt(reg));
    }

    const gp_regs = [_]MockRegister3{ .r0, .r1, .r2, .r3 };
    const ext_regs = [_]MockRegister3{ .x0, .x1, .x2, .x3 };
    const allocatable_registers = gp_regs ++ ext_regs;

    const RM = RegisterManager(
        MockFunction3,
        MockRegister3,
        &MockRegister3.allocatable_registers,
    );

    const gp: RM.RegisterBitSet = blk: {
        var set = RM.RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = gp_regs.len,
        }, true);
        break :blk set;
    };
    const ext: RM.RegisterBitSet = blk: {
        var set = RM.RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = gp_regs.len,
            .end = allocatable_registers.len,
        }, true);
        break :blk set;
    };
};

fn MockFunction(comptime Register: type) type {
    return struct {
        allocator: Allocator,
        register_manager: Register.RM = .{},
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
const MockFunction3 = MockFunction(MockRegister3);

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
    const gp = MockRegister1.gp;

    try expectEqual(@as(?MockRegister1, .r2), function.register_manager.tryAllocReg(mock_instruction, gp));
    try expectEqual(@as(?MockRegister1, .r3), function.register_manager.tryAllocReg(mock_instruction, gp));
    try expectEqual(@as(?MockRegister1, null), function.register_manager.tryAllocReg(mock_instruction, gp));

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
    const gp = MockRegister1.gp;

    try expectEqual(@as(?MockRegister1, .r2), try function.register_manager.allocReg(mock_instruction, gp));
    try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction, gp));

    // Spill a register
    try expectEqual(@as(?MockRegister1, .r2), try function.register_manager.allocReg(mock_instruction, gp));
    try expectEqualSlices(MockRegister1, &[_]MockRegister1{.r2}, function.spilled.items);

    // No spilling necessary
    function.register_manager.freeReg(.r3);
    try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction, gp));
    try expectEqualSlices(MockRegister1, &[_]MockRegister1{.r2}, function.spilled.items);

    // Locked registers
    function.register_manager.freeReg(.r3);
    {
        const lock = function.register_manager.lockReg(.r2);
        defer if (lock) |reg| function.register_manager.unlockReg(reg);

        try expectEqual(@as(?MockRegister1, .r3), try function.register_manager.allocReg(mock_instruction, gp));
    }
    try expect(!function.register_manager.lockedRegsExist());
}

test "tryAllocRegs" {
    const allocator = std.testing.allocator;

    var function = MockFunction2{
        .allocator = allocator,
    };
    defer function.deinit();

    const gp = MockRegister2.gp;

    try expectEqual([_]MockRegister2{ .r0, .r1, .r2 }, function.register_manager.tryAllocRegs(3, .{
        null,
        null,
        null,
    }, gp).?);

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

        try expectEqual([_]MockRegister2{ .r0, .r2, .r3 }, function.register_manager.tryAllocRegs(3, .{
            null,
            null,
            null,
        }, gp).?);
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

    const gp = MockRegister2.gp;

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

        const regs = try function.register_manager.allocRegs(2, .{ null, null }, gp);
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

    const gp = MockRegister2.gp;

    {
        const result_reg: MockRegister2 = .r1;

        const lock = function.register_manager.lockReg(result_reg);

        // Here, we don't defer unlock because we manually unlock
        // after genAdd
        const regs = try function.register_manager.allocRegs(2, .{ null, null }, gp);

        try function.genAdd(result_reg, regs[0], regs[1]);
        function.register_manager.unlockReg(lock.?);

        const extra_summand_reg = try function.register_manager.allocReg(null, gp);
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

test "allocReg with multiple, non-overlapping register classes" {
    const allocator = std.testing.allocator;

    var function = MockFunction3{
        .allocator = allocator,
    };
    defer function.deinit();

    const gp = MockRegister3.gp;
    const ext = MockRegister3.ext;

    const gp_reg = try function.register_manager.allocReg(null, gp);

    try expect(function.register_manager.isRegAllocated(.r0));
    try expect(!function.register_manager.isRegAllocated(.x0));

    const ext_reg = try function.register_manager.allocReg(null, ext);

    try expect(function.register_manager.isRegAllocated(.r0));
    try expect(!function.register_manager.isRegAllocated(.r1));
    try expect(function.register_manager.isRegAllocated(.x0));
    try expect(!function.register_manager.isRegAllocated(.x1));
    try expect(gp_reg.enc() == ext_reg.enc());

    const ext_lock = function.register_manager.lockRegAssumeUnused(ext_reg);
    defer function.register_manager.unlockReg(ext_lock);

    const ext_reg2 = try function.register_manager.allocReg(null, ext);

    try expect(function.register_manager.isRegAllocated(.r0));
    try expect(function.register_manager.isRegAllocated(.x0));
    try expect(!function.register_manager.isRegAllocated(.r1));
    try expect(function.register_manager.isRegAllocated(.x1));
    try expect(ext_reg2.enc() == MockRegister3.r1.enc());
}
