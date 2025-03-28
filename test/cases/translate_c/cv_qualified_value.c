typedef volatile int mmio_int;

typedef mmio_int *mmio_int_ptr;

typedef struct {
    mmio_int reg;
    mmio_int regs[4];
    mmio_int regm[2][2];
    mmio_int_ptr ptr;
} hw_t;

extern hw_t *hw;
extern hw_t hw_arr[4];

extern const mmio_int reg;
extern mmio_int *regs;

// Check name mangling
typedef volatile unsigned int mmio_uint;
typedef unsigned int volatile_mmio_uint;
static unsigned int check_typenames(void) {
    const mmio_uint x = 0u;
    return (volatile_mmio_uint)x;
}

static int hw_reg(void) {
    return hw->reg;
}

static typeof(&hw->reg) hw_reg_ptr(void) {
    return &hw->reg;
}

static mmio_int_ptr hw_ptr(void) {
    return hw->ptr;
}

static typeof(&reg) reg_ptr(void) {
    return &reg;
}

static int hw_regs_0(void) {
    return hw->regs[0u];
}

static int hw_0_regs_0(void) {
    return hw_arr[0u].regs[0u];
}

static int hw_regm_00(void) {
    return hw->regm[0u][0u];
}

static int hw_regm_0_deref(void) {
    return *(hw->regm[0u]);
}

static int ptr_arith(void) {
    return *(regs+1u);
}

// translate-c
// c_frontend=clang
//
// pub const volatile_mmio_int = c_int;
// pub const mmio_int_ptr = [*c]volatile volatile_mmio_int;
// pub const hw_t = extern struct {
//     reg: volatile_mmio_int = @import("std").mem.zeroes(volatile_mmio_int),
//     regs: [4]volatile_mmio_int = @import("std").mem.zeroes([4]volatile_mmio_int),
//     regm: [2][2]volatile_mmio_int = @import("std").mem.zeroes([2][2]volatile_mmio_int),
//     ptr: mmio_int_ptr = @import("std").mem.zeroes(mmio_int_ptr),
// };
// pub extern var hw: [*c]hw_t;
// pub extern var hw_arr: [4]hw_t;
// pub extern const reg: volatile_mmio_int;
// pub extern var regs: [*c]volatile volatile_mmio_int;
// pub const volatile_mmio_uint_1 = c_uint;
// pub const volatile_mmio_uint = c_uint;
// pub fn check_typenames() callconv(.c) c_uint {
//     const x: volatile_mmio_uint_1 = 0;
//     _ = &x;
//     return @as(volatile_mmio_uint, @bitCast(x));
// }
// pub fn hw_reg() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(&hw.*.reg)).*;
// }
// pub fn hw_reg_ptr() callconv(.c) @TypeOf(@as([*c]volatile volatile_mmio_int, @ptrCast(&@as([*c]volatile volatile_mmio_int, @ptrCast(&hw.*.reg)).*))) {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(&@as([*c]volatile volatile_mmio_int, @ptrCast(&hw.*.reg)).*));
// }
// pub fn hw_ptr() callconv(.c) mmio_int_ptr {
//     return hw.*.ptr;
// }
// pub fn reg_ptr() callconv(.c) @TypeOf(@as([*c]const volatile volatile_mmio_int, @ptrCast(&reg))) {
//     return @as([*c]const volatile volatile_mmio_int, @ptrCast(&reg));
// }
// pub fn hw_regs_0() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(&hw.*.regs[@as(c_uint, 0)])).*;
// }
// pub fn hw_0_regs_0() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(&hw_arr[@as(c_uint, 0)].regs[@as(c_uint, 0)])).*;
// }
// pub fn hw_regm_00() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(&hw.*.regm[@as(c_uint, 0)][@as(c_uint, 0)])).*;
// }
// pub fn hw_regm_0_deref() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(@as([*c]volatile volatile_mmio_int, @ptrCast(@alignCast(&hw.*.regm[@as(c_uint, 0)]))))).*;
// }
// pub fn ptr_arith() callconv(.c) c_int {
//     return @as([*c]volatile volatile_mmio_int, @ptrCast(regs + @as(c_uint, 1))).*;
// }
