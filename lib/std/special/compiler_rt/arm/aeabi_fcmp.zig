// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_fcmp.S

const ConditionalOperator = enum {
    Eq,
    Lt,
    Le,
    Ge,
    Gt,
};

pub fn __aeabi_fcmpeq() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Eq});
    unreachable;
}

pub fn __aeabi_fcmplt() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Lt});
    unreachable;
}

pub fn __aeabi_fcmple() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Le});
    unreachable;
}

pub fn __aeabi_fcmpge() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Ge});
    unreachable;
}

pub fn __aeabi_fcmpgt() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_fcmp, .{.Gt});
    unreachable;
}

fn aeabi_fcmp(comptime cond: ConditionalOperator) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ push      { r4, lr }
    );

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
