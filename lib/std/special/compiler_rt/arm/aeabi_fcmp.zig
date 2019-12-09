// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_fcmp.S

const compiler_rt_armhf_target = false; // TODO

const ConditionalOperator = enum {
    Eq,
    Lt,
    Le,
    Ge,
    Gt,
};

pub nakedcc fn __aeabi_fcmpeq() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Eq});
    unreachable;
}

pub nakedcc fn __aeabi_fcmplt() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Lt});
    unreachable;
}

pub nakedcc fn __aeabi_fcmple() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Le});
    unreachable;
}

pub nakedcc fn __aeabi_fcmpge() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Ge});
    unreachable;
}

pub nakedcc fn __aeabi_fcmpgt() noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Gt});
    unreachable;
}

inline fn convert_fcmp_args_to_sf2_args() void {
    asm volatile (
        \\ vmov      s0, r0
        \\ vmov      s1, r1
    );
}

fn aeabi_fcmp(comptime cond: ConditionalOperator) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ push      { r4, lr }
    );

    if (compiler_rt_armhf_target) {
        convert_fcmp_args_to_sf2_args();
    }

    switch (cond) {
        .Eq => asm volatile (
            \\ bl        __eqsf2
            \\ cmp       r0, #0
            \\ beq 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Lt => asm volatile (
            \\ bl        __ltsf2
            \\ cmp       r0, #0
            \\ blt 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Le => asm volatile (
            \\ bl        __lesf2
            \\ cmp       r0, #0
            \\ ble 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Ge => asm volatile (
            \\ bl        __ltsf2
            \\ cmp       r0, #0
            \\ bge 1f
            \\ movs      r0, #0
            \\ pop       { r4, pc }
            \\ 1:
        ),
        .Gt => asm volatile (
            \\ bl        __gtsf2
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
