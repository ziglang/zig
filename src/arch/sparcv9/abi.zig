const bits = @import("bits.zig");
const Register = bits.Register;

// Register windowing mechanism will take care of preserving registers
// so no need to do it manually
pub const callee_preserved_regs = [_]Register{};

pub const c_abi_int_param_regs_caller_view = [_]Register{ .o0, .o1, .o2, .o3, .o4, .o5 };
pub const c_abi_int_param_regs_callee_view = [_]Register{ .@"i0", .@"i1", .@"i2", .@"i3", .@"i4", .@"i5" };

pub const c_abi_int_return_regs_caller_view = [_]Register{ .o0, .o1, .o2, .o3 };
pub const c_abi_int_return_regs_callee_view = [_]Register{ .@"i0", .@"i1", .@"i2", .@"i3" };
