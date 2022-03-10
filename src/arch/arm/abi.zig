const bits = @import("bits.zig");
const Register = bits.Register;

pub const callee_preserved_regs = [_]Register{ .r4, .r5, .r6, .r7, .r8, .r10 };
pub const c_abi_int_param_regs = [_]Register{ .r0, .r1, .r2, .r3 };
pub const c_abi_int_return_regs = [_]Register{ .r0, .r1 };
