// Ported from:
//
// https://github.com/llvm/llvm-project/commit/d674d96bc56c0f377879d01c9d8dfdaaa7859cdb/compiler-rt/lib/builtins/arm/aeabi_dcmp.S

const ConditionalOperator = enum {
    Eq,
    Lt,
    Le,
    Ge,
    Gt,
};

pub fn __aeabi_dcmpeq() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Eq});
    unreachable;
}

pub fn __aeabi_dcmplt() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Lt});
    unreachable;
}

pub fn __aeabi_dcmple() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Le});
    unreachable;
}

pub fn __aeabi_dcmpge() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Ge});
    unreachable;
}

pub fn __aeabi_dcmpgt() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    @call(.{ .modifier = .always_inline }, aeabi_dcmp, .{.Gt});
    unreachable;
}

fn aeabi_dcmp(comptime cond: ConditionalOperator) void {
    @setRuntimeSafety(false);
    asm volatile (
        \\ push      { r4, lr }
    );

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
