const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const ir = @import("ir.zig");
const Type = @import("type.zig").Type;
const log = std.log.scoped(.register_manager);

pub fn RegisterManager(
    comptime Function: type,
    comptime Register: type,
    comptime callee_preserved_regs: []const Register,
) type {
    return struct {
        /// The key must be canonical register.
        registers: std.AutoHashMapUnmanaged(Register, *ir.Inst) = .{},
        free_registers: FreeRegInt = math.maxInt(FreeRegInt),
        /// Tracks all registers allocated in the course of this function
        allocated_registers: FreeRegInt = 0,

        const Self = @This();

        /// An integer whose bits represent all the registers and whether they are free.
        const FreeRegInt = std.meta.Int(.unsigned, callee_preserved_regs.len);

        fn getFunction(self: *Self) *Function {
            return @fieldParentPtr(Function, "register_manager", self);
        }

        pub fn deinit(self: *Self, allocator: *Allocator) void {
            self.registers.deinit(allocator);
        }

        fn markRegUsed(self: *Self, reg: Register) void {
            if (FreeRegInt == u0) return;
            const index = reg.allocIndex() orelse return;
            const ShiftInt = math.Log2Int(FreeRegInt);
            const shift = @intCast(ShiftInt, index);
            const mask = @as(FreeRegInt, 1) << shift;
            self.free_registers &= ~mask;
            self.allocated_registers |= mask;
        }

        fn markRegFree(self: *Self, reg: Register) void {
            if (FreeRegInt == u0) return;
            const index = reg.allocIndex() orelse return;
            const ShiftInt = math.Log2Int(FreeRegInt);
            const shift = @intCast(ShiftInt, index);
            self.free_registers |= @as(FreeRegInt, 1) << shift;
        }

        /// Returns whether this register was allocated in the course
        /// of this function
        pub fn isRegAllocated(self: Self, reg: Register) bool {
            if (FreeRegInt == u0) return false;
            const index = reg.allocIndex() orelse return false;
            const ShiftInt = math.Log2Int(FreeRegInt);
            const shift = @intCast(ShiftInt, index);
            return self.free_registers & @as(FreeRegInt, 1) << shift != 0;
        }

        /// Before calling, must ensureCapacity + 1 on self.registers.
        /// Returns `null` if all registers are allocated.
        pub fn tryAllocReg(self: *Self, inst: *ir.Inst) ?Register {
            const free_index = @ctz(FreeRegInt, self.free_registers);
            if (free_index >= callee_preserved_regs.len) {
                return null;
            }
            const mask = @as(FreeRegInt, 1) << free_index;
            self.free_registers &= ~mask;
            self.allocated_registers |= mask;
            const reg = callee_preserved_regs[free_index];
            self.registers.putAssumeCapacityNoClobber(reg, inst);
            log.debug("alloc {} => {*}", .{ reg, inst });
            return reg;
        }

        /// Before calling, must ensureCapacity + 1 on self.registers.
        pub fn allocReg(self: *Self, inst: *ir.Inst) !Register {
            return self.tryAllocReg(inst) orelse b: {
                // We'll take over the first register. Move the instruction that was previously
                // there to a stack allocation.
                const reg = callee_preserved_regs[0];
                const regs_entry = self.registers.getEntry(reg).?;
                const spilled_inst = regs_entry.value;
                regs_entry.value = inst;
                try self.getFunction().spillInstruction(spilled_inst.src, reg, spilled_inst);

                break :b reg;
            };
        }

        /// Does not track the register.
        /// Returns `null` if all registers are allocated.
        pub fn findUnusedReg(self: *Self) ?Register {
            const free_index = @ctz(FreeRegInt, self.free_registers);
            if (free_index >= callee_preserved_regs.len) {
                return null;
            }
            return callee_preserved_regs[free_index];
        }

        /// Does not track the register.
        pub fn allocRegWithoutTracking(self: *Self) !Register {
            return self.findUnusedReg() orelse b: {
                // We'll take over the first register. Move the instruction that was previously
                // there to a stack allocation.
                const reg = callee_preserved_regs[0];
                const regs_entry = self.registers.remove(reg).?;
                const spilled_inst = regs_entry.value;
                try self.getFunction().spillInstruction(spilled_inst.src, reg, spilled_inst);

                break :b reg;
            };
        }

        pub fn getRegAssumeFree(self: *Self, reg: Register, inst: *ir.Inst) !void {
            try self.registers.putNoClobber(self.getFunction().gpa, reg, inst);
            self.markRegUsed(reg);
        }

        pub fn freeReg(self: *Self, reg: Register) void {
            _ = self.registers.remove(reg);
            self.markRegFree(reg);
        }
    };
}
