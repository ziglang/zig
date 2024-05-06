//! This is Zig's multi-target implementation of libc.
//! When builtin.link_libc is true, we need to export all the functions and
//! provide an entire C API.

const std = @import("std");
const builtin = @import("builtin");
const math = std.math;
const isNan = std.math.isNan;
const maxInt = std.math.maxInt;
const native_os = builtin.os.tag;
const native_arch = builtin.cpu.arch;
const native_abi = builtin.abi;

const is_wasm = switch (native_arch) {
    .wasm32, .wasm64 => true,
    else => false,
};
const is_msvc = switch (native_abi) {
    .msvc => true,
    else => false,
};
const is_freestanding = switch (native_os) {
    .freestanding => true,
    else => false,
};

comptime {
    if (is_freestanding and is_wasm and builtin.link_libc) {
        @export(wasm_start, .{ .name = "_start", .linkage = .strong });
    }

    if (native_os == .linux) {
        @export(clone, .{ .name = "clone" });
    }

    if (builtin.link_libc) {
        @export(strcmp, .{ .name = "strcmp", .linkage = .strong });
        @export(strncmp, .{ .name = "strncmp", .linkage = .strong });
        @export(strerror, .{ .name = "strerror", .linkage = .strong });
        @export(strlen, .{ .name = "strlen", .linkage = .strong });
        @export(strcpy, .{ .name = "strcpy", .linkage = .strong });
        @export(strncpy, .{ .name = "strncpy", .linkage = .strong });
        @export(strcat, .{ .name = "strcat", .linkage = .strong });
        @export(strncat, .{ .name = "strncat", .linkage = .strong });
    } else if (is_msvc) {
        @export(_fltused, .{ .name = "_fltused", .linkage = .strong });
    }
}

// Avoid dragging in the runtime safety mechanisms into this .o file,
// unless we're trying to test this file.
pub fn panic(msg: []const u8, error_return_trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);
    _ = error_return_trace;
    if (builtin.is_test) {
        std.debug.panic("{s}", .{msg});
    }
    switch (native_os) {
        .freestanding, .other, .amdhsa, .amdpal => while (true) {},
        else => std.os.abort(),
    }
}

extern fn main(argc: c_int, argv: [*:null]?[*:0]u8) c_int;
fn wasm_start() callconv(.C) void {
    _ = main(0, undefined);
}

var _fltused: c_int = 1;

fn strcpy(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8 {
    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    dest[i] = 0;

    return dest;
}

test "strcpy" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcpy(&s1, "foobarbaz");
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strncpy(dest: [*:0]u8, src: [*:0]const u8, n: usize) callconv(.C) [*:0]u8 {
    var i: usize = 0;
    while (i < n and src[i] != 0) : (i += 1) {
        dest[i] = src[i];
    }
    while (i < n) : (i += 1) {
        dest[i] = 0;
    }

    return dest;
}

test "strncpy" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncpy(&s1, "foobarbaz", @sizeOf(@TypeOf(s1)));
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strcat(dest: [*:0]u8, src: [*:0]const u8) callconv(.C) [*:0]u8 {
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strcat" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strcat(&s1, "foo");
    _ = strcat(&s1, "bar");
    _ = strcat(&s1, "baz");
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strncat(dest: [*:0]u8, src: [*:0]const u8, avail: usize) callconv(.C) [*:0]u8 {
    var dest_end: usize = 0;
    while (dest[dest_end] != 0) : (dest_end += 1) {}

    var i: usize = 0;
    while (i < avail and src[i] != 0) : (i += 1) {
        dest[dest_end + i] = src[i];
    }
    dest[dest_end + i] = 0;

    return dest;
}

test "strncat" {
    var s1: [9:0]u8 = undefined;

    s1[0] = 0;
    _ = strncat(&s1, "foo1111", 3);
    _ = strncat(&s1, "bar1111", 3);
    _ = strncat(&s1, "baz1111", 3);
    try std.testing.expectEqualSlices(u8, "foobarbaz", std.mem.sliceTo(&s1, 0));
}

fn strcmp(s1: [*:0]const u8, s2: [*:0]const u8) callconv(.C) c_int {
    return switch (std.mem.orderZ(u8, s1, s2)) {
        .lt => -1,
        .eq => 0,
        .gt => 1,
    };
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
    _ = errnum;
    return "TODO strerror implementation";
}

test "strncmp" {
    try std.testing.expect(strncmp("a", "b", 1) < 0);
    try std.testing.expect(strncmp("a", "c", 1) < 0);
    try std.testing.expect(strncmp("b", "a", 1) > 0);
    try std.testing.expect(strncmp("\xff", "\x02", 1) > 0);
}

// TODO we should be able to put this directly in std/linux/x86_64.zig but
// it causes a segfault in release mode. this is a workaround of calling it
// across .o file boundaries. fix comptime @ptrCast of nakedcc functions.
fn clone() callconv(.Naked) void {
    switch (native_arch) {
        .x86 => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //         +8,   +12,   +16,   +20, +24,  +28, +32
            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //         eax,       ebx,   ecx,   edx,  esi, edi
            asm volatile (
                \\  pushl %%ebp
                \\  movl %%esp,%%ebp
                \\  pushl %%ebx
                \\  pushl %%esi
                \\  pushl %%edi
                \\  // Setup the arguments
                \\  movl 16(%%ebp),%%ebx
                \\  movl 12(%%ebp),%%ecx
                \\  andl $-16,%%ecx
                \\  subl $20,%%ecx
                \\  movl 20(%%ebp),%%eax
                \\  movl %%eax,4(%%ecx)
                \\  movl 8(%%ebp),%%eax
                \\  movl %%eax,0(%%ecx)
                \\  movl 24(%%ebp),%%edx
                \\  movl 28(%%ebp),%%esi
                \\  movl 32(%%ebp),%%edi
                \\  movl $120,%%eax
                \\  int $128
                \\  testl %%eax,%%eax
                \\  jnz 1f
                \\  popl %%eax
                \\  xorl %%ebp,%%ebp
                \\  calll *%%eax
                \\  movl %%eax,%%ebx
                \\  movl $1,%%eax
                \\  int $128
                \\1:
                \\  popl %%edi
                \\  popl %%esi
                \\  popl %%ebx
                \\  popl %%ebp
                \\  retl
            );
        },
        .x86_64 => {
            asm volatile (
                \\      movl $56,%%eax // SYS_clone
                \\      movq %%rdi,%%r11
                \\      movq %%rdx,%%rdi
                \\      movq %%r8,%%rdx
                \\      movq %%r9,%%r8
                \\      movq 8(%%rsp),%%r10
                \\      movq %%r11,%%r9
                \\      andq $-16,%%rsi
                \\      subq $8,%%rsi
                \\      movq %%rcx,(%%rsi)
                \\      syscall
                \\      testq %%rax,%%rax
                \\      jnz 1f
                \\      xorl %%ebp,%%ebp
                \\      popq %%rdi
                \\      callq *%%r9
                \\      movl %%eax,%%edi
                \\      movl $60,%%eax // SYS_exit
                \\      syscall
                \\1:    ret
                \\
            );
        },
        .aarch64, .aarch64_be => {
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
        .arm, .thumb => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //           r0,    r1,    r2,  r3,   +0,  +4,   +8

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                r7     r0,    r1,   r2,  r3,   r4
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
        .mips, .mipsel, .mips64, .mips64el => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //            3,     4,     5,   6,    7,   8,    9

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                 2      4,     5,    6,   7,    8
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
                \\1:
                \\  beq $2, $0, 1f
                \\  nop
                \\  addu $sp, $sp, 16
                \\  jr $ra
                \\  nop
                \\1:
                \\  lw $25, 0($sp)
                \\  lw $4, 4($sp)
                \\  jalr $25
                \\  nop
                \\  move $4, $2
                \\  li $2, 4001
                \\  syscall
            );
        },
        .powerpc, .powerpcle => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //            3,     4,     5,   6,    7,   8,    9

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                 0      3,     4,    5,   6,    7
            asm volatile (
                \\ # store non-volatile regs r30, r31 on stack in order to put our
                \\ # start func and its arg there
                \\ stwu 30, -16(1)
                \\ stw 31, 4(1)
                \\
                \\ # save r3 (func) into r30, and r6(arg) into r31
                \\ mr 30, 3
                \\ mr 31, 6
                \\
                \\ # create initial stack frame for new thread
                \\ clrrwi 4, 4, 4
                \\ li 0, 0
                \\ stwu 0, -16(4)
                \\
                \\ #move c into first arg
                \\ mr 3, 5
                \\ #mr 4, 4
                \\ mr 5, 7
                \\ mr 6, 8
                \\ mr 7, 9
                \\
                \\ # move syscall number into r0
                \\ li 0, 120
                \\
                \\ sc
                \\
                \\ # check for syscall error
                \\ bns+ 1f # jump to label 1 if no summary overflow.
                \\ #else
                \\ neg 3, 3 #negate the result (errno)
                \\ 1:
                \\ # compare sc result with 0
                \\ cmpwi cr7, 3, 0
                \\
                \\ # if not 0, jump to end
                \\ bne cr7, 2f
                \\
                \\ #else: we're the child
                \\ #call funcptr: move arg (d) into r3
                \\ mr 3, 31
                \\ #move r30 (funcptr) into CTR reg
                \\ mtctr 30
                \\ # call CTR reg
                \\ bctrl
                \\ # mov SYS_exit into r0 (the exit param is already in r3)
                \\ li 0, 1
                \\ sc
                \\
                \\ 2:
                \\
                \\ # restore stack
                \\ lwz 30, 0(1)
                \\ lwz 31, 4(1)
                \\ addi 1, 1, 16
                \\
                \\ blr
            );
        },
        .powerpc64, .powerpc64le => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //            3,     4,     5,   6,    7,   8,    9

            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                 0      3,     4,    5,   6,    7
            asm volatile (
                \\  # create initial stack frame for new thread
                \\  clrrdi 4, 4, 4
                \\  li     0, 0
                \\  stdu   0,-32(4)
                \\
                \\  # save fn and arg to child stack
                \\  std    3,  8(4)
                \\  std    6, 16(4)
                \\
                \\  # shuffle args into correct registers and call SYS_clone
                \\  mr    3, 5
                \\  #mr   4, 4
                \\  mr    5, 7
                \\  mr    6, 8
                \\  mr    7, 9
                \\  li    0, 120  # SYS_clone = 120
                \\  sc
                \\
                \\  # if error, negate return (errno)
                \\  bns+  1f
                \\  neg   3, 3
                \\
                \\1:
                \\  # if we're the parent, return
                \\  cmpwi cr7, 3, 0
                \\  bnelr cr7
                \\
                \\  # we're the child. call fn(arg)
                \\  ld     3, 16(1)
                \\  ld    12,  8(1)
                \\  mtctr 12
                \\  bctrl
                \\
                \\  # call SYS_exit. exit code is already in r3 from fn return value
                \\  li    0, 1    # SYS_exit = 1
                \\  sc
            );
        },
        .sparc64 => {
            // __clone(func, stack, flags, arg, ptid, tls, ctid)
            //           i0,    i1,    i2,  i3,   i4,  i5,   sp
            // syscall(SYS_clone, flags, stack, ptid, tls, ctid)
            //                g1     o0,    o1,   o2,  o3,   o4
            asm volatile (
                \\ save %%sp, -192, %%sp
                \\ # Save the func pointer and the arg pointer
                \\ mov %%i0, %%g2
                \\ mov %%i3, %%g3
                \\ # Shuffle the arguments
                \\ mov 217, %%g1
                \\ mov %%i2, %%o0
                \\ # Add some extra space for the initial frame
                \\ sub %%i1, 176 + 2047, %%o1
                \\ mov %%i4, %%o2
                \\ mov %%i5, %%o3
                \\ ldx [%%fp + 0x8af], %%o4
                \\ t 0x6d
                \\ bcs,pn %%xcc, 2f
                \\ nop
                \\ # The child pid is returned in o0 while o1 tells if this
                \\ # process is # the child (=1) or the parent (=0).
                \\ brnz %%o1, 1f
                \\ nop
                \\ # Parent process, return the child pid
                \\ mov %%o0, %%i0
                \\ ret
                \\ restore
                \\1:
                \\ # Child process, call func(arg)
                \\ mov %%g0, %%fp
                \\ call %%g2
                \\ mov %%g3, %%o0
                \\ # Exit
                \\ mov 1, %%g1
                \\ t 0x6d
                \\2:
                \\ # The syscall failed
                \\ sub %%g0, %%o0, %%i0
                \\ ret
                \\ restore
            );
        },
        else => @compileError("Implement clone() for this arch."),
    }
}
