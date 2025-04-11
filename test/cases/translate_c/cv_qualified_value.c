typedef unsigned int uint;

typedef volatile int mmio_int;
typedef volatile uint mmio_uint;
typedef mmio_int *mmio_int_ptr;

typedef struct {
    mmio_int reg;
    mmio_uint regu;
    mmio_int regs[4];
    mmio_int regm[2][2];
    volatile int regx;
    mmio_int_ptr reg_ptr;
} hw_t;

extern hw_t *hw;
extern hw_t hw_arr[4];

extern const mmio_int reg;
extern mmio_int *regs;

static int hw_reg(void) {
    const hw_t *chw = (const hw_t *)(0xd0000000);
    (void) *(&chw->regx);
    (void) chw->regx;
    (void) *(&hw->reg);
    hw->reg = 0;

    (void) hw->regu;
    hw->regu = 0;

    return hw->reg;
}

static typeof(&hw->reg) hw_reg_ptr(void) {
    return &hw->reg;
}

static mmio_int_ptr hw_ptr(void) {
    return hw->reg_ptr;
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
// pub const uint = c_uint;
// pub const mmio_int = @import("std").zig.c_translation.Volatile(c_int);
// pub const mmio_uint = @import("std").zig.c_translation.Volatile(uint);
// pub const mmio_int_ptr = [*c]volatile mmio_int;
// pub const hw_t = extern struct {
//     reg: mmio_int = @import("std").mem.zeroes(mmio_int),
//     regu: mmio_uint = @import("std").mem.zeroes(mmio_uint),
//     regs: [4]mmio_int = @import("std").mem.zeroes([4]mmio_int),
//     regm: [2][2]mmio_int = @import("std").mem.zeroes([2][2]mmio_int),
//     regx: @import("std").zig.c_translation.Volatile(c_int) = @import("std").mem.zeroes(@import("std").zig.c_translation.Volatile(c_int)),
//     reg_ptr: mmio_int_ptr = @import("std").mem.zeroes(mmio_int_ptr),
// };
// pub extern var hw: [*c]hw_t;
// pub extern var hw_arr: [4]hw_t;
// pub extern const reg: mmio_int;
// pub extern var regs: [*c]volatile mmio_int;
// pub fn hw_reg() callconv(.c) c_int {
//     var chw: [*c]const hw_t = @as([*c]const hw_t, @ptrFromInt(@as(c_uint, 3489660928)));
//     _ = &chw;
//     _ = @as([*c]const volatile c_int, @ptrCast(@as([*c]const volatile c_int, @ptrCast(&chw.*.regx)))).*;
//     _ = @as([*c]const volatile c_int, @ptrCast(&chw.*.regx)).*;
//     _ = @as([*c]volatile mmio_int, @ptrCast(@as([*c]volatile mmio_int, @ptrCast(hw.*.reg.ptr())))).*;
//     hw.*.reg.ptr().* = 0;
//     _ = hw.*.regu.ptr().*;
//     hw.*.regu.ptr().* = 0;
//     return hw.*.reg.ptr().*;
// }
// pub fn hw_reg_ptr() callconv(.c) @TypeOf(@as([*c]volatile mmio_int, @ptrCast(hw.*.reg.ptr()))) {
//     return @as([*c]volatile mmio_int, @ptrCast(hw.*.reg.ptr()));
// }
// pub fn hw_ptr() callconv(.c) mmio_int_ptr {
//     return hw.*.reg_ptr;
// }
// pub fn reg_ptr() callconv(.c) @TypeOf(reg.constPtr()) {
//     return reg.constPtr();
// }
// pub fn hw_regs_0() callconv(.c) c_int {
//     return hw.*.regs[@as(c_uint, 0)].ptr().*;
// }
// pub fn hw_0_regs_0() callconv(.c) c_int {
//     return hw_arr[@as(c_uint, 0)].regs[@as(c_uint, 0)].ptr().*;
// }
// pub fn hw_regm_00() callconv(.c) c_int {
//     return hw.*.regm[@as(c_uint, 0)][@as(c_uint, 0)].ptr().*;
// }
// pub fn hw_regm_0_deref() callconv(.c) c_int {
//     return @as([*c]volatile mmio_int, @ptrCast(@as([*c]volatile mmio_int, @ptrCast(@alignCast(&hw.*.regm[@as(c_uint, 0)]))))).*;
// }
// pub fn ptr_arith() callconv(.c) c_int {
//     return @as([*c]volatile mmio_int, @ptrCast(regs + @as(c_uint, 1))).*;
// }
