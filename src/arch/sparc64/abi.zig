const std = @import("std");
const bits = @import("bits.zig");
const Register = bits.Register;
const RegisterManagerFn = @import("../../register_manager.zig").RegisterManager;

// SPARCv9 stack constants.
// See: Registers and the Stack Frame, page 3P-8, SCD 2.4.1.

// On SPARCv9, %sp points to top of stack + stack bias,
// and %fp points to top of previous frame + stack bias.
pub const stack_bias = 2047;

// The first 176 bytes of the stack is reserved for register saving purposes.
// SPARCv9 requires to reserve space in the stack for the first six arguments,
// even though they are usually passed in registers.
pub const stack_save_area = 176;

// There are no callee-preserved registers since the windowing
// mechanism already takes care of them.
// We still need to preserve %o0-%o5, %g1, %g4, and %g5 before calling
// something, though, as those are shared with the callee and might be
// thrashed by it.
pub const caller_preserved_regs = [_]Register{ .o0, .o1, .o2, .o3, .o4, .o5, .g1, .g4, .g5 };

// Try to allocate i, l, o, then g sets of registers, in order of priority.
const allocatable_regs = [_]Register{
    // zig fmt: off
    .@"i0", .@"i1", .@"i2", .@"i3", .@"i4", .@"i5",
      .l0,    .l1,    .l2,    .l3,    .l4,    .l5,    .l6,    .l7,
      .o0,    .o1,    .o2,    .o3,    .o4,    .o5,
              .g1,                    .g4,    .g5,
    // zig fmt: on
};

pub const c_abi_int_param_regs_caller_view = [_]Register{ .o0, .o1, .o2, .o3, .o4, .o5 };
pub const c_abi_int_param_regs_callee_view = [_]Register{ .@"i0", .@"i1", .@"i2", .@"i3", .@"i4", .@"i5" };

pub const c_abi_int_return_regs_caller_view = [_]Register{ .o0, .o1, .o2, .o3 };
pub const c_abi_int_return_regs_callee_view = [_]Register{ .@"i0", .@"i1", .@"i2", .@"i3" };

pub const RegisterManager = RegisterManagerFn(@import("CodeGen.zig"), Register, &allocatable_regs);

// Register classes
const RegisterBitSet = RegisterManager.RegisterBitSet;
pub const RegisterClass = struct {
    pub const gp: RegisterBitSet = blk: {
        var set = RegisterBitSet.initEmpty();
        set.setRangeValue(.{
            .start = 0,
            .end = allocatable_regs.len,
        }, true);
        break :blk set;
    };
};
