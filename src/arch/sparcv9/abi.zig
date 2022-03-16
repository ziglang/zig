const bits = @import("bits.zig");
const Register = bits.Register;

// Register windowing mechanism will take care of preserving registers
// so no need to do it manually
pub const callee_preserved_regs = [_]Register{};

// pub const c_abi_int_param_regs = [_]Register{};
// pub const c_abi_int_return_regs = [_]Register{};
