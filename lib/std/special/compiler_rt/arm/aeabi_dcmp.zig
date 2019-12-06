// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_dcmp.S

const compiler_rt_armhf_target = false; // TODO

const ConditionalOperator = enum {
    Eq,
    Lt,
    Le,
    Ge,
    Gt,
};

pub nakedcc fn __aeabi_dcmpeq() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Eq});
    unreachable;
}

pub nakedcc fn __aeabi_dcmplt() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Lt});
    unreachable;
}

pub nakedcc fn __aeabi_dcmple() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Le});
    unreachable;
}

pub nakedcc fn __aeabi_dcmpge() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Ge});
    unreachable;
}

pub nakedcc fn __aeabi_dcmpgt() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Gt});
    unreachable;
}

inline fn convert_dcmp_args_to_df2_args() void {
    asm volatile (
        \\ vmov      d0, r0, r1
        \\ vmov      d1, r2, r3
    );
}

fn aeabi_dcmp(comptime cond: ConditionalOperator) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ push      { r4, lr }
    );

    if (compiler_rt_armhf_target) {
        convert_dcmp_args_to_df2_args();
    }

    switch (cond) {
        .Eq => asm volatile (
            \\ bl        __eqdf2
            \\ cmp       r0, #0
            \\ beq 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Lt => asm volatile (
            \\ bl        __ltdf2
            \\ cmp       r0, #0
            \\ blt 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Le => asm volatile (
            \\ bl        __ledf2
            \\ cmp       r0, #0
            \\ ble 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Ge => asm volatile (
            \\ bl        __ltdf2
            \\ cmp       r0, #0
            \\ bge 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Gt => asm volatile (
            \\ bl        __gtdf2
            \\ cmp       r0, #0
            \\ bgt 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
    }
    asm volatile (
        \\ movs      r0, #1
        \\ pop       { r4, pc }
    );
}
