// This is Zig's multi-target implementation of libc.
// When builtin.link_libc is true, we need to export all the functions and
// provide an entire C API.
// Otherwise, only the functions which LLVM generates calls to need to be generated,
// such as memcpy, memset, and some math functions.

const std = @import("std");
const builtin = @import("builtin");
const maxInt = std.math.maxInt;
const isNan = std.math.isNan;

const is_wasm = switch (builtin.arch) {
    .wasm32, .wasm64 => true,
    else => false,
};
const is_msvc = switch (builtin.abi) {
    .msvc => true,
    else => false,
};
const is_freestanding = switch (builtin.os.tag) {
    .freestanding => true,
    else => false,
};
comptime {
    if (is_freestanding and is_wasm and builtin.link_libc) {
        @export(wasm_start, .{ .name = "_start", .linkage = .Strong });
    }
    if (builtin.link_libc) {
        @export(strcmp, .{ .name = "strcmp", .linkage = .Strong });
        @export(strncmp, .{ .name = "strncmp", .linkage = .Strong });
        @export(strerror, .{ .name = "strerror", .linkage = .Strong });
        @export(strlen, .{ .name = "strlen", .linkage = .Strong });
    } else if (is_msvc) {
        @export(_fltused, .{ .name = "_fltused", .linkage = .Strong });
    }
}

extern var _fltused: c_int = 1;

extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;
fn wasm_start() callconv(.C) void {
    _ = main(0, undefined);
}

fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int {
    return std.cstr.cmp(s1, s2);
}

fn strlen(s: [*:0]const u8) callconv(.C) usize {
    return std.mem.len(s);
}

fn strncmp(_l: [*:0]const u8, _r: [*:0]const u8, _n: usize) callconv(.C) c_int {
    if (_n == 0) return 0;
    var l = _l;
    var r = _r;
    var n = _n - 1;
    while (l[0] != 0 and r[0] != 0 and n != 0 and l[0] == r[0]) {
        l += 1;
        r += 1;
        n -= 1;
    }
    return @as(c_int, l[0]) - @as(c_int, r[0]);
}

fn strerror(errnum: c_int) callconv(.C) [*:0]const u8 {
    return "TODO strerror implementation";
}

test "strncmp" {
    std.testing.expect(strncmp("a", "b", 1) == -1);
    std.testing.expect(strncmp("a", "c", 1) == -2);
    std.testing.expect(strncmp("b", "a", 1) == 1);
    std.testing.expect(strncmp("\xff", "\x02", 1) == 253);
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    if (builtin.is_test) {
        @setCold(true);
        std.debug.panic("{}", .{msg});
    }
    if (builtin.os.tag != .freestanding and builtin.os.tag != .other) {
        std.os.abort();
    }
    while (true) {}
}

export fn memset(dest: ?[*]u8, c: u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = c;

    return dest;
}

export fn memcpy(noalias dest: ?[*]u8, noalias src: ?[*]const u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1)
        dest.?[index] = src.?[index];

    return dest;
}

export fn memmove(dest: ?[*]u8, src: ?[*]const u8, n: usize) ?[*]u8 {
    @setRuntimeSafety(false);

    if (@ptrToInt(dest) < @ptrToInt(src)) {
        var index: usize = 0;
        while (index != n) : (index += 1) {
            dest.?[index] = src.?[index];
        }
    } else {
        var index = n;
        while (index != 0) {
            index -= 1;
            dest.?[index] = src.?[index];
        }
    }

    return dest;
}

export fn memcmp(vl: ?[*]const u8, vr: ?[*]const u8, n: usize) isize {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        const compare_val = @bitCast(i8, vl.?[index] -% vr.?[index]);
        if (compare_val != 0) {
            return compare_val;
        }
    }

    return 0;
}

test "test_memcmp" {
    const base_arr = []u8{ 1, 1, 1 };
    const arr1 = []u8{ 1, 1, 1 };
    const arr2 = []u8{ 1, 0, 1 };
    const arr3 = []u8{ 1, 2, 1 };

    std.testing.expect(memcmp(base_arr[0..].ptr, arr1[0..].ptr, base_arr.len) == 0);
    std.testing.expect(memcmp(base_arr[0..].ptr, arr2[0..].ptr, base_arr.len) > 0);
    std.testing.expect(memcmp(base_arr[0..].ptr, arr3[0..].ptr, base_arr.len) < 0);
}

export fn bcmp(vl: [*]allowzero const u8, vr: [*]allowzero const u8, n: usize) isize {
    @setRuntimeSafety(false);

    var index: usize = 0;
    while (index != n) : (index += 1) {
        if (vl[index] != vr[index]) {
            return 1;
        }
    }

    return 0;
}

test "test_bcmp" {
    const base_arr = []u8{ 1, 1, 1 };
    const arr1 = []u8{ 1, 1, 1 };
    const arr2 = []u8{ 1, 0, 1 };
    const arr3 = []u8{ 1, 2, 1 };

    std.testing.expect(bcmp(base_arr[0..].ptr, arr1[0..].ptr, base_arr.len) == 0);
    std.testing.expect(bcmp(base_arr[0..].ptr, arr2[0..].ptr, base_arr.len) != 0);
    std.testing.expect(bcmp(base_arr[0..].ptr, arr3[0..].ptr, base_arr.len) != 0);
}

comptime {
    if (builtin.mode != builtin.Mode.ReleaseFast and
        builtin.mode != builtin.Mode.ReleaseSmall and
        builtin.os.tag != .windows)
    {
        @export(__stack_chk_fail, .{ .name = "__stack_chk_fail" });
    }
    if (builtin.os.tag == .linux) {
        @export(clone, .{ .name = "clone" });
    }
}
fn __stack_chk_fail() callconv(.C) noreturn {
    @panic("stack smashing detected");
}

// TODO we should be able to put this directly in std/linux/x86_64.zig but
// it causes a segfault in release mode. this is a workaround of calling it
// across .o file boundaries. fix comptime @ptrCast of nakedcc functions.
fn clone() callconv(.Naked) void {
    switch (builtin.arch) {
        .i386 => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //         +8,   +12,   +16,   +20, +24,  +28, +32
            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //         eax,       ebx,   ecx,   edx,  esi, edi
            asm volatile (
                \\  push %%ebp
                \\  mov %%esp,%%ebp
                \\  push %%ebx
                \\  push %%esi
                \\  push %%edi
                \\  // Setup the arguments
                \\  mov 16(%%ebp),%%ebx
                \\  mov 12(%%ebp),%%ecx
                \\  and $-16,%%ecx
                \\  sub $20,%%ecx
                \\  mov 20(%%ebp),%%eax
                \\  mov %%eax,4(%%ecx)
                \\  mov 8(%%ebp),%%eax
                \\  mov %%eax,0(%%ecx)
                \\  mov 24(%%ebp),%%edx
                \\  mov 28(%%ebp),%%esi
                \\  mov 32(%%ebp),%%edi
                \\  mov $120,%%eax
                \\  int $128
                \\  test %%eax,%%eax
                \\  jnz 1f
                \\  pop %%eax
                \\  xor %%ebp,%%ebp
                \\  call *%%eax
                \\  mov %%eax,%%ebx
                \\  xor %%eax,%%eax
                \\  inc %%eax
                \\  int $128
                \\  hlt
                \\1:
                \\  pop %%edi
                \\  pop %%esi
                \\  pop %%ebx
                \\  pop %%ebp
                \\  ret
            );
        },
        .x86_64 => {
            asm volatile (
                \\      xor %%eax,%%eax
                \\      mov $56,%%al // SYS_clone
                \\      mov %%rdi,%%r11
                \\      mov %%rdx,%%rdi
                \\      mov %%r8,%%rdx
                \\      mov %%r9,%%r8
                \\      mov 8(%%rsp),%%r10
                \\      mov %%r11,%%r9
                \\      and $-16,%%rsi
                \\      sub $8,%%rsi
                \\      mov %%rcx,(%%rsi)
                \\      syscall
                \\      test %%eax,%%eax
                \\      jnz 1f
                \\      xor %%ebp,%%ebp
                \\      pop %%rdi
                \\      call *%%r9
                \\      mov %%eax,%%edi
                \\      xor %%eax,%%eax
                \\      mov $60,%%al // SYS_exit
                \\      syscall
                \\      hlt
                \\1:    ret
                \\
            );
        },
        .aarch64 => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //         x0,   x1,    w2,    x3,  x4,   x5,  x6

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //         x8,        x0,    x1,    x2,   x3,  x4
            asm volatile (
                \\      // align stack and save func,arg
                \\      and x1,x1,#-16
                \\      stp x0,x3,[x1,#-16]!
                \\
                \\      // syscall
                \\      uxtw x0,w2
                \\      mov x2,x4
                \\      mov x3,x5
                \\      mov x4,x6
                \\      mov x8,#220 // SYS_clone
                \\      svc #0
                \\
                \\      cbz x0,1f
                \\      // parent
                \\      ret
                \\      // child
                \\1:    ldp x1,x0,[sp],#16
                \\      blr x1
                \\      mov x8,#93 // SYS_exit
                \\      svc #0
            );
        },
        .arm => {
            asm volatile (
                \\    stmfd sp!,{r4,r5,r6,r7}
                \\    mov r7,#120
                \\    mov r6,r3
                \\    mov r5,r0
                \\    mov r0,r2
                \\    and r1,r1,#-16
                \\    ldr r2,[sp,#16]
                \\    ldr r3,[sp,#20]
                \\    ldr r4,[sp,#24]
                \\    svc 0
                \\    tst r0,r0
                \\    beq 1f
                \\    ldmfd sp!,{r4,r5,r6,r7}
                \\    bx lr
                \\
                \\1:  mov r0,r6
                \\    bl 3f
                \\2:  mov r7,#1
                \\    svc 0
                \\    b 2b
                \\3:  bx r5
            );
        },
        .riscv64 => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //           a0,    a1,    a2,  a3,   a4,  a5,   a6

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                a7     a0,    a1,   a2,  a3,   a4
            asm volatile (
                \\    # Save func and arg to stack
                \\    addi a1, a1, -16
                \\    sd a0, 0(a1)
                \\    sd a3, 8(a1)
                \\
                \\    # Call SYS_clone
                \\    mv a0, a2
                \\    mv a2, a4
                \\    mv a3, a5
                \\    mv a4, a6
                \\    li a7, 220 # SYS_clone
                \\    ecall
                \\
                \\    beqz a0, 1f
                \\    # Parent
                \\    ret
                \\
                \\    # Child
                \\1:  ld a1, 0(sp)
                \\    ld a0, 8(sp)
                \\    jalr a1
                \\
                \\    # Exit
                \\    li a7, 93 # SYS_exit
                \\    ecall
            );
        },
        .mips, .mipsel => {
            asm volatile (
                \\  # Save function pointer and argument pointer on new thread stack
                \\  and $5, $5, -8
                \\  subu $5, $5, 16
                \\  sw $4, 0($5)
                \\  sw $7, 4($5)
                \\  # Shuffle (fn,sp,fl,arg,ptid,tls,ctid) to (fl,sp,ptid,tls,ctid)
                \\  move $4, $6
                \\  lw $6, 16($sp)
                \\  lw $7, 20($sp)
                \\  lw $9, 24($sp)
                \\  subu $sp, $sp, 16
                \\  sw $9, 16($sp)
                \\  li $2, 4120
                \\  syscall
                \\  beq $7, $0, 1f
                \\  nop
                \\  addu $sp, $sp, 16
                \\  jr $ra
                \\  subu $2, $0, $2
                \\1:  beq $2, $0, 1f
                \\  nop
                \\  addu $sp, $sp, 16
                \\  jr $ra
                \\  nop
                \\1:  lw $25, 0($sp)
                \\  lw $4, 4($sp)
                \\  jalr $25
                \\  nop
                \\  move $4, $2
                \\  li $2, 4001
                \\  syscall
            );
        },
        else => @compileError("Implement clone() for this arch."),
    }
}

const math = std.math;

export fn fmodf(x: f32, y: f32) f32 {
    return generic_fmod(f32, x, y);
}
export fn fmod(x: f64, y: f64) f64 {
    return generic_fmod(f64, x, y);
}

// TODO add intrinsics for these (and probably the double version too)
// and have the math stuff use the intrinsic. same as @mod and @rem
export fn floorf(x: f32) f32 {
    return math.floor(x);
}

export fn ceilf(x: f32) f32 {
    return math.ceil(x);
}

export fn floor(x: f64) f64 {
    return math.floor(x);
}

export fn ceil(x: f64) f64 {
    return math.ceil(x);
}

export fn fma(a: f64, b: f64, c: f64) f64 {
    return math.fma(f64, a, b, c);
}

export fn fmaf(a: f32, b: f32, c: f32) f32 {
    return math.fma(f32, a, b, c);
}

export fn sin(a: f64) f64 {
    return math.sin(a);
}

export fn sinf(a: f32) f32 {
    return math.sin(a);
}

export fn cos(a: f64) f64 {
    return math.cos(a);
}

export fn cosf(a: f32) f32 {
    return math.cos(a);
}

export fn exp(a: f64) f64 {
    return math.exp(a);
}

export fn expf(a: f32) f32 {
    return math.exp(a);
}

export fn exp2(a: f64) f64 {
    return math.exp2(a);
}

export fn exp2f(a: f32) f32 {
    return math.exp2(a);
}

export fn log(a: f64) f64 {
    return math.ln(a);
}

export fn logf(a: f32) f32 {
    return math.ln(a);
}

export fn log2(a: f64) f64 {
    return math.log2(a);
}

export fn log2f(a: f32) f32 {
    return math.log2(a);
}

export fn log10(a: f64) f64 {
    return math.log10(a);
}

export fn log10f(a: f32) f32 {
    return math.log10(a);
}

export fn fabs(a: f64) f64 {
    return math.fabs(a);
}

export fn fabsf(a: f32) f32 {
    return math.fabs(a);
}

export fn trunc(a: f64) f64 {
    return math.trunc(a);
}

export fn truncf(a: f32) f32 {
    return math.trunc(a);
}

export fn round(a: f64) f64 {
    return math.round(a);
}

export fn roundf(a: f32) f32 {
    return math.round(a);
}

fn generic_fmod(comptime T: type, x: T, y: T) T {
    @setRuntimeSafety(false);

    const uint = std.meta.Int(false, T.bit_count);
    const log2uint = math.Log2Int(uint);
    const digits = if (T == f32) 23 else 52;
    const exp_bits = if (T == f32) 9 else 12;
    const bits_minus_1 = T.bit_count - 1;
    const mask = if (T == f32) 0xff else 0x7ff;
    var ux = @bitCast(uint, x);
    var uy = @bitCast(uint, y);
    var ex = @intCast(i32, (ux >> digits) & mask);
    var ey = @intCast(i32, (uy >> digits) & mask);
    const sx = if (T == f32) @intCast(u32, ux & 0x80000000) else @intCast(i32, ux >> bits_minus_1);
    var i: uint = undefined;

    if (uy << 1 == 0 or isNan(@bitCast(T, uy)) or ex == mask)
        return (x * y) / (x * y);

    if (ux << 1 <= uy << 1) {
        if (ux << 1 == uy << 1)
            return 0 * x;
        return x;
    }

    // normalize x and y
    if (ex == 0) {
        i = ux << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ex -= 1;
            i <<= 1;
        }) {}
        ux <<= @intCast(log2uint, @bitCast(u32, -ex + 1));
    } else {
        ux &= maxInt(uint) >> exp_bits;
        ux |= 1 << digits;
    }
    if (ey == 0) {
        i = uy << exp_bits;
        while (i >> bits_minus_1 == 0) : ({
            ey -= 1;
            i <<= 1;
        }) {}
        uy <<= @intCast(log2uint, @bitCast(u32, -ey + 1));
    } else {
        uy &= maxInt(uint) >> exp_bits;
        uy |= 1 << digits;
    }

    // x mod y
    while (ex > ey) : (ex -= 1) {
        i = ux -% uy;
        if (i >> bits_minus_1 == 0) {
            if (i == 0)
                return 0 * x;
            ux = i;
        }
        ux <<= 1;
    }
    i = ux -% uy;
    if (i >> bits_minus_1 == 0) {
        if (i == 0)
            return 0 * x;
        ux = i;
    }
    while (ux >> digits == 0) : ({
        ux <<= 1;
        ex -= 1;
    }) {}

    // scale result up
    if (ex > 0) {
        ux -%= 1 << digits;
        ux |= @as(uint, @bitCast(u32, ex)) << digits;
    } else {
        ux >>= @intCast(log2uint, @bitCast(u32, -ex + 1));
    }
    if (T == f32) {
        ux |= sx;
    } else {
        ux |= @intCast(uint, sx) << bits_minus_1;
    }
    return @bitCast(T, ux);
}

// NOTE: The original code is full of implicit signed -> unsigned assumptions and u32 wraparound
// behaviour. Most intermediate i32 values are changed to u32 where appropriate but there are
// potentially some edge cases remaining that are not handled in the same way.
export fn sqrt(x: f64) f64 {
    const tiny: f64 = 1.0e-300;
    const sign: u32 = 0x80000000;
    const u = @bitCast(u64, x);

    var ix0 = @intCast(u32, u >> 32);
    var ix1 = @intCast(u32, u & 0xFFFFFFFF);

    // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = nan
    if (ix0 & 0x7FF00000 == 0x7FF00000) {
        return x * x + x;
    }

    // sqrt(+-0) = +-0
    if (x == 0.0) {
        return x;
    }
    // sqrt(-ve) = snan
    if (ix0 & sign != 0) {
        return math.snan(f64);
    }

    // normalize x
    var m = @intCast(i32, ix0 >> 20);
    if (m == 0) {
        // subnormal
        while (ix0 == 0) {
            m -= 21;
            ix0 |= ix1 >> 11;
            ix1 <<= 21;
        }

        // subnormal
        var i: u32 = 0;
        while (ix0 & 0x00100000 == 0) : (i += 1) {
            ix0 <<= 1;
        }
        m -= @intCast(i32, i) - 1;
        ix0 |= ix1 >> @intCast(u5, 32 - i);
        ix1 <<= @intCast(u5, i);
    }

    // unbias exponent
    m -= 1023;
    ix0 = (ix0 & 0x000FFFFF) | 0x00100000;
    if (m & 1 != 0) {
        ix0 += ix0 + (ix1 >> 31);
        ix1 = ix1 +% ix1;
    }
    m >>= 1;

    // sqrt(x) bit by bit
    ix0 += ix0 + (ix1 >> 31);
    ix1 = ix1 +% ix1;

    var q: u32 = 0;
    var q1: u32 = 0;
    var s0: u32 = 0;
    var s1: u32 = 0;
    var r: u32 = 0x00200000;
    var t: u32 = undefined;
    var t1: u32 = undefined;

    while (r != 0) {
        t = s0 +% r;
        if (t <= ix0) {
            s0 = t + r;
            ix0 -= t;
            q += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    r = sign;
    while (r != 0) {
        t = s1 +% r;
        t = s0;
        if (t < ix0 or (t == ix0 and t1 <= ix1)) {
            s1 = t1 +% r;
            if (t1 & sign == sign and s1 & sign == 0) {
                s0 += 1;
            }
            ix0 -= t;
            if (ix1 < t1) {
                ix0 -= 1;
            }
            ix1 = ix1 -% t1;
            q1 += r;
        }
        ix0 = ix0 +% ix0 +% (ix1 >> 31);
        ix1 = ix1 +% ix1;
        r >>= 1;
    }

    // rounding direction
    if (ix0 | ix1 != 0) {
        var z = 1.0 - tiny; // raise inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (q1 == 0xFFFFFFFF) {
                q1 = 0;
                q += 1;
            } else if (z > 1.0) {
                if (q1 == 0xFFFFFFFE) {
                    q += 1;
                }
                q1 += 2;
            } else {
                q1 += q1 & 1;
            }
        }
    }

    ix0 = (q >> 1) + 0x3FE00000;
    ix1 = q1 >> 1;
    if (q & 1 != 0) {
        ix1 |= 0x80000000;
    }

    // NOTE: musl here appears to rely on signed twos-complement wraparound. +% has the same
    // behaviour at least.
    var iix0 = @intCast(i32, ix0);
    iix0 = iix0 +% (m << 20);

    const uz = (@intCast(u64, iix0) << 32) | ix1;
    return @bitCast(f64, uz);
}

test "sqrt" {
    const epsilon = 0.000001;

    std.testing.expect(sqrt(0.0) == 0.0);
    std.testing.expect(std.math.approxEq(f64, sqrt(2.0), 1.414214, epsilon));
    std.testing.expect(std.math.approxEq(f64, sqrt(3.6), 1.897367, epsilon));
    std.testing.expect(sqrt(4.0) == 2.0);
    std.testing.expect(std.math.approxEq(f64, sqrt(7.539840), 2.745877, epsilon));
    std.testing.expect(std.math.approxEq(f64, sqrt(19.230934), 4.385309, epsilon));
    std.testing.expect(sqrt(64.0) == 8.0);
    std.testing.expect(std.math.approxEq(f64, sqrt(64.1), 8.006248, epsilon));
    std.testing.expect(std.math.approxEq(f64, sqrt(8942.230469), 94.563367, epsilon));
}

test "sqrt special" {
    std.testing.expect(std.math.isPositiveInf(sqrt(std.math.inf(f64))));
    std.testing.expect(sqrt(0.0) == 0.0);
    std.testing.expect(sqrt(-0.0) == -0.0);
    std.testing.expect(std.math.isNan(sqrt(-1.0)));
    std.testing.expect(std.math.isNan(sqrt(std.math.nan(f64))));
}

export fn sqrtf(x: f32) f32 {
    const tiny: f32 = 1.0e-30;
    const sign: i32 = @bitCast(i32, @as(u32, 0x80000000));
    var ix: i32 = @bitCast(i32, x);

    if ((ix & 0x7F800000) == 0x7F800000) {
        return x * x + x; // sqrt(nan) = nan, sqrt(+inf) = +inf, sqrt(-inf) = snan
    }

    // zero
    if (ix <= 0) {
        if (ix & ~sign == 0) {
            return x; // sqrt (+-0) = +-0
        }
        if (ix < 0) {
            return math.snan(f32);
        }
    }

    // normalize
    var m = ix >> 23;
    if (m == 0) {
        // subnormal
        var i: i32 = 0;
        while (ix & 0x00800000 == 0) : (i += 1) {
            ix <<= 1;
        }
        m -= i - 1;
    }

    m -= 127; // unbias exponent
    ix = (ix & 0x007FFFFF) | 0x00800000;

    if (m & 1 != 0) { // odd m, double x to even
        ix += ix;
    }

    m >>= 1; // m = [m / 2]

    // sqrt(x) bit by bit
    ix += ix;
    var q: i32 = 0; // q = sqrt(x)
    var s: i32 = 0;
    var r: i32 = 0x01000000; // r = moving bit right -> left

    while (r != 0) {
        const t = s + r;
        if (t <= ix) {
            s = t + r;
            ix -= t;
            q += r;
        }
        ix += ix;
        r >>= 1;
    }

    // floating add to find rounding direction
    if (ix != 0) {
        var z = 1.0 - tiny; // inexact
        if (z >= 1.0) {
            z = 1.0 + tiny;
            if (z > 1.0) {
                q += 2;
            } else {
                if (q & 1 != 0) {
                    q += 1;
                }
            }
        }
    }

    ix = (q >> 1) + 0x3f000000;
    ix += m << 23;
    return @bitCast(f32, ix);
}

test "sqrtf" {
    const epsilon = 0.000001;

    std.testing.expect(sqrtf(0.0) == 0.0);
    std.testing.expect(std.math.approxEq(f32, sqrtf(2.0), 1.414214, epsilon));
    std.testing.expect(std.math.approxEq(f32, sqrtf(3.6), 1.897367, epsilon));
    std.testing.expect(sqrtf(4.0) == 2.0);
    std.testing.expect(std.math.approxEq(f32, sqrtf(7.539840), 2.745877, epsilon));
    std.testing.expect(std.math.approxEq(f32, sqrtf(19.230934), 4.385309, epsilon));
    std.testing.expect(sqrtf(64.0) == 8.0);
    std.testing.expect(std.math.approxEq(f32, sqrtf(64.1), 8.006248, epsilon));
    std.testing.expect(std.math.approxEq(f32, sqrtf(8942.230469), 94.563370, epsilon));
}

test "sqrtf special" {
    std.testing.expect(std.math.isPositiveInf(sqrtf(std.math.inf(f32))));
    std.testing.expect(sqrtf(0.0) == 0.0);
    std.testing.expect(sqrtf(-0.0) == -0.0);
    std.testing.expect(std.math.isNan(sqrtf(-1.0)));
    std.testing.expect(std.math.isNan(sqrtf(std.math.nan(f32))));
}
