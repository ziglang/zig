// ARM specific builtins
const builtin = @import("builtin");
const is_test = builtin.is_test;

const use_thumb_1 = usesThumb1(builtin.arch);

const __divmodsi4 = @import("int.zig").__divmodsi4;
const __udivmodsi4 = @import("int.zig").__udivmodsi4;
const __divmoddi4 = @import("int.zig").__divmoddi4;
const __udivmoddi4 = @import("int.zig").__udivmoddi4;

fn usesThumb1(arch: builtin.Arch) bool {
    return switch (arch) {
        .arm => |sub_arch| switch (sub_arch) {
            .v6m => true,
            else => false,
        },
        .armeb => |sub_arch| switch (sub_arch) {
            .v6m => true,
            else => false,
        },
        .thumb => |sub_arch| switch (sub_arch) {
            .v5,
            .v5te,
            .v4t,
            .v6,
            .v6m,
            .v6k,
            => true,
            else => false,
        },
        .thumbeb => |sub_arch| switch (sub_arch) {
            .v5,
            .v5te,
            .v4t,
            .v6,
            .v6m,
            .v6k,
            => true,
            else => false,
        },
        else => false,
    };
}

test "usesThumb1" {
    testing.expect(usesThumb1(builtin.Arch{ .arm = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .arm = .v5 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .armeb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .armeb = .v5 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v5 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v5te }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v4t }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6k }));
    testing.expect(usesThumb1(builtin.Arch{ .thumb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .thumb = .v6t2 }));
    //etc.

    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v5 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v5te }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v4t }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6 }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6k }));
    testing.expect(usesThumb1(builtin.Arch{ .thumbeb = .v6m }));
    testing.expect(!usesThumb1(builtin.Arch{ .thumbeb = .v6t2 }));
    //etc.

    testing.expect(!usesThumb1(builtin.Arch{ .aarch64 = .v8 }));
    testing.expect(!usesThumb1(builtin.Arch{ .aarch64_be = .v8 }));
    testing.expect(!usesThumb1(builtin.Arch.x86_64));
    testing.expect(!usesThumb1(builtin.Arch.riscv32));
    //etc.
}

const use_thumb_1_pre_armv6 = usesThumb1PreArmv6(builtin.arch);

fn usesThumb1PreArmv6(arch: builtin.Arch) bool {
    return switch (arch) {
        .thumb => |sub_arch| switch (sub_arch) {
            .v5, .v5te, .v4t => true,
            else => false,
        },
        .thumbeb => |sub_arch| switch (sub_arch) {
            .v5, .v5te, .v4t => true,
            else => false,
        },
        else => false,
    };
}

pub fn __aeabi_memcpy() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memcpy
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memcpy
        );
    }
    unreachable;
}

pub fn __aeabi_memmove() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memmove
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memmove
        );
    }
    unreachable;
}

pub fn __aeabi_memset() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1_pre_armv6) {
        asm volatile (
            \\ eors    r1, r2
            \\ eors    r2, r1
            \\ eors    r1, r2
            \\ push    {r7, lr}
            \\ b       memset
            \\ pop     {r7, pc}
        );
    } else if (use_thumb_1) {
        asm volatile (
            \\ mov     r3, r1
            \\ mov     r1, r2
            \\ mov     r2, r3
            \\ push    {r7, lr}
            \\ b       memset
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ mov     r3, r1
            \\ mov     r1, r2
            \\ mov     r2, r3
            \\ b       memset
        );
    }
    unreachable;
}

pub fn __aeabi_memclr() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1_pre_armv6) {
        asm volatile (
            \\ adds    r2, r1, #0
            \\ movs    r1, #0
            \\ push    {r7, lr}
            \\ bl      memset
            \\ pop     {r7, pc}
        );
    } else if (use_thumb_1) {
        asm volatile (
            \\ mov     r2, r1
            \\ movs    r1, #0
            \\ push    {r7, lr}
            \\ bl      memset
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ mov     r2, r1
            \\ movs    r1, #0
            \\ b       memset
        );
    }
    unreachable;
}

pub fn __aeabi_memcmp() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    if (use_thumb_1) {
        asm volatile (
            \\ push    {r7, lr}
            \\ bl      memcmp
            \\ pop     {r7, pc}
        );
    } else {
        asm volatile (
            \\ b       memcmp
        );
    }
    unreachable;
}

pub fn __aeabi_unwind_cpp_pr0() callconv(.C) void {
    unreachable;
}
pub fn __aeabi_unwind_cpp_pr1() callconv(.C) void {
    unreachable;
}
pub fn __aeabi_unwind_cpp_pr2() callconv(.C) void {
    unreachable;
}

pub fn __aeabi_uidivmod(n: u32, d: u32) callconv(.C) extern struct {
    q: u32,
    r: u32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uidivmod).ReturnType = undefined;
    result.q = __udivmodsi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_uldivmod(n: u64, d: u64) callconv(.C) extern struct {
    q: u64,
    r: u64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_uldivmod).ReturnType = undefined;
    result.q = __udivmoddi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_idivmod(n: i32, d: i32) callconv(.C) extern struct {
    q: i32,
    r: i32,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_idivmod).ReturnType = undefined;
    result.q = __divmodsi4(n, d, &result.r);
    return result;
}

pub fn __aeabi_ldivmod(n: i64, d: i64) callconv(.C) extern struct {
    q: i64,
    r: i64,
} {
    @setRuntimeSafety(is_test);

    var result: @TypeOf(__aeabi_ldivmod).ReturnType = undefined;
    result.q = __divmoddi4(n, d, &result.r);
    return result;
}
