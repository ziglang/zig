const builtin = @import("builtin");
const bits = @import("bits.zig");
const Register = bits.Register;

const callee_preserved_regs_impl = if (builtin.os.tag.isDarwin()) struct {
    pub const callee_preserved_regs = [_]Register{
        .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27,
        .x28,
    };
} else struct {
    pub const callee_preserved_regs = [_]Register{
        .x19, .x20, .x21, .x22, .x23,
        .x24, .x25, .x26, .x27, .x28,
    };
};
pub const callee_preserved_regs = callee_preserved_regs_impl.callee_preserved_regs;

pub const c_abi_int_param_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
pub const c_abi_int_return_regs = [_]Register{ .x0, .x1, .x2, .x3, .x4, .x5, .x6, .x7 };
