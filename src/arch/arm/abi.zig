const std = @import("std");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;

pub const callee_preserved_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r10 };
pub const caller_preserved_regs = [_]Register{ .r0, .r1, .r2, .r3 };

pub const c_abi_int_param_regs = [_]Register{ .r0, .r1, .r2, .r3 };
pub const c_abi_int_return_regs = [_]Register{ .r0, .r1 };

const allocatable_registers = callee_preserved_regs ++ caller_preserved_regs;
pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &allocatable_registers);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
pub const RegisterClass = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = caller_preserved_regs.len + callee_preserved_regs.len,
        }, true);
        break :blk set;
    };
};
