/// Register state for the native architecture, used by `std.debug` for stack unwinding.
/// `noreturn` if there is no implementation for the native architecture.
/// This can be overriden by exposing a declaration `root.debug.CpuContext`.
pub const Native = if (@hasDecl(root, "debug") and @hasDecl(root.debug, "CpuContext"))
    root.debug.CpuContext
else switch (native_arch) {
    .aarch64, .aarch64_be => Aarch64,
    .arm, .armeb, .thumb, .thumbeb => Arm,
    .hexagon => Hexagon,
    .loongarch32, .loongarch64 => LoongArch,
    .mips, .mipsel, .mips64, .mips64el => Mips,
    .powerpc, .powerpcle, .powerpc64, .powerpc64le => Powerpc,
    .riscv32, .riscv32be, .riscv64, .riscv64be => Riscv,
    .s390x => S390x,
    .x86 => X86,
    .x86_64 => X86_64,
    else => noreturn,
};

pub const DwarfRegisterError = error{
    InvalidRegister,
    UnsupportedRegister,
};

pub fn fromPosixSignalContext(ctx_ptr: ?*const anyopaque) ?Native {
    if (signal_ucontext_t == void) return null;
    const uc: *const signal_ucontext_t = @ptrCast(@alignCast(ctx_ptr));
    return switch (native_arch) {
        .x86 => switch (native_os) {
            .linux, .netbsd, .illumos => .{ .gprs = .init(.{
                .eax = uc.mcontext.gregs[std.posix.REG.EAX],
                .ecx = uc.mcontext.gregs[std.posix.REG.ECX],
                .edx = uc.mcontext.gregs[std.posix.REG.EDX],
                .ebx = uc.mcontext.gregs[std.posix.REG.EBX],
                .esp = uc.mcontext.gregs[std.posix.REG.ESP],
                .ebp = uc.mcontext.gregs[std.posix.REG.EBP],
                .esi = uc.mcontext.gregs[std.posix.REG.ESI],
                .edi = uc.mcontext.gregs[std.posix.REG.EDI],
                .eip = uc.mcontext.gregs[std.posix.REG.EIP],
            }) },
            else => null,
        },
        .x86_64 => switch (native_os) {
            .linux, .solaris, .illumos => .{ .gprs = .init(.{
                .rax = uc.mcontext.gregs[std.posix.REG.RAX],
                .rdx = uc.mcontext.gregs[std.posix.REG.RDX],
                .rcx = uc.mcontext.gregs[std.posix.REG.RCX],
                .rbx = uc.mcontext.gregs[std.posix.REG.RBX],
                .rsi = uc.mcontext.gregs[std.posix.REG.RSI],
                .rdi = uc.mcontext.gregs[std.posix.REG.RDI],
                .rbp = uc.mcontext.gregs[std.posix.REG.RBP],
                .rsp = uc.mcontext.gregs[std.posix.REG.RSP],
                .r8 = uc.mcontext.gregs[std.posix.REG.R8],
                .r9 = uc.mcontext.gregs[std.posix.REG.R9],
                .r10 = uc.mcontext.gregs[std.posix.REG.R10],
                .r11 = uc.mcontext.gregs[std.posix.REG.R11],
                .r12 = uc.mcontext.gregs[std.posix.REG.R12],
                .r13 = uc.mcontext.gregs[std.posix.REG.R13],
                .r14 = uc.mcontext.gregs[std.posix.REG.R14],
                .r15 = uc.mcontext.gregs[std.posix.REG.R15],
                .rip = uc.mcontext.gregs[std.posix.REG.RIP],
            }) },
            .freebsd, .serenity => .{ .gprs = .init(.{
                .rax = uc.mcontext.rax,
                .rdx = uc.mcontext.rdx,
                .rcx = uc.mcontext.rcx,
                .rbx = uc.mcontext.rbx,
                .rsi = uc.mcontext.rsi,
                .rdi = uc.mcontext.rdi,
                .rbp = uc.mcontext.rbp,
                .rsp = uc.mcontext.rsp,
                .r8 = uc.mcontext.r8,
                .r9 = uc.mcontext.r9,
                .r10 = uc.mcontext.r10,
                .r11 = uc.mcontext.r11,
                .r12 = uc.mcontext.r12,
                .r13 = uc.mcontext.r13,
                .r14 = uc.mcontext.r14,
                .r15 = uc.mcontext.r15,
                .rip = uc.mcontext.rip,
            }) },
            .openbsd => .{ .gprs = .init(.{
                .rax = @bitCast(uc.sc_rax),
                .rdx = @bitCast(uc.sc_rdx),
                .rcx = @bitCast(uc.sc_rcx),
                .rbx = @bitCast(uc.sc_rbx),
                .rsi = @bitCast(uc.sc_rsi),
                .rdi = @bitCast(uc.sc_rdi),
                .rbp = @bitCast(uc.sc_rbp),
                .rsp = @bitCast(uc.sc_rsp),
                .r8 = @bitCast(uc.sc_r8),
                .r9 = @bitCast(uc.sc_r9),
                .r10 = @bitCast(uc.sc_r10),
                .r11 = @bitCast(uc.sc_r11),
                .r12 = @bitCast(uc.sc_r12),
                .r13 = @bitCast(uc.sc_r13),
                .r14 = @bitCast(uc.sc_r14),
                .r15 = @bitCast(uc.sc_r15),
                .rip = @bitCast(uc.sc_rip),
            }) },
            .driverkit, .macos, .ios => .{ .gprs = .init(.{
                .rax = uc.mcontext.ss.rax,
                .rdx = uc.mcontext.ss.rdx,
                .rcx = uc.mcontext.ss.rcx,
                .rbx = uc.mcontext.ss.rbx,
                .rsi = uc.mcontext.ss.rsi,
                .rdi = uc.mcontext.ss.rdi,
                .rbp = uc.mcontext.ss.rbp,
                .rsp = uc.mcontext.ss.rsp,
                .r8 = uc.mcontext.ss.r8,
                .r9 = uc.mcontext.ss.r9,
                .r10 = uc.mcontext.ss.r10,
                .r11 = uc.mcontext.ss.r11,
                .r12 = uc.mcontext.ss.r12,
                .r13 = uc.mcontext.ss.r13,
                .r14 = uc.mcontext.ss.r14,
                .r15 = uc.mcontext.ss.r15,
                .rip = uc.mcontext.ss.rip,
            }) },
            else => null,
        },
        .arm, .armeb, .thumb, .thumbeb => switch (builtin.os.tag) {
            .linux => .{
                .r = .{
                    uc.mcontext.arm_r0,
                    uc.mcontext.arm_r1,
                    uc.mcontext.arm_r2,
                    uc.mcontext.arm_r3,
                    uc.mcontext.arm_r4,
                    uc.mcontext.arm_r5,
                    uc.mcontext.arm_r6,
                    uc.mcontext.arm_r7,
                    uc.mcontext.arm_r8,
                    uc.mcontext.arm_r9,
                    uc.mcontext.arm_r10,
                    uc.mcontext.arm_fp, // r11 = fp
                    uc.mcontext.arm_ip, // r12 = ip
                    uc.mcontext.arm_sp, // r13 = sp
                    uc.mcontext.arm_lr, // r14 = lr
                    uc.mcontext.arm_pc, // r15 = pc
                },
            },
            else => null,
        },
        .aarch64, .aarch64_be => switch (builtin.os.tag) {
            .driverkit, .macos, .ios, .tvos, .watchos, .visionos => .{
                .x = uc.mcontext.ss.regs ++ @as([2]u64, .{
                    uc.mcontext.ss.fp, // x29 = fp
                    uc.mcontext.ss.lr, // x30 = lr
                }),
                .sp = uc.mcontext.ss.sp,
                .pc = uc.mcontext.ss.pc,
            },
            .netbsd => .{
                .x = uc.mcontext.gregs[0..31].*,
                .sp = uc.mcontext.gregs[31],
                .pc = uc.mcontext.gregs[32],
            },
            .freebsd => .{
                .x = uc.mcontext.gpregs.x ++ @as([1]u64, .{
                    uc.mcontext.gpregs.lr, // x30 = lr
                }),
                .sp = uc.mcontext.gpregs.sp,
                // On aarch64, the register ELR_LR1 defines the address to return to after handling
                // a CPU exception (ELR is "Exception Link Register"). FreeBSD's ucontext_t uses
                // this as the field name, but it's the same thing as the context's PC.
                .pc = uc.mcontext.gpregs.elr,
            },
            .openbsd => .{
                .x = uc.sc_x ++ .{uc.sc_lr},
                .sp = uc.sc_sp,
                // Not a bug; see freebsd above for explanation.
                .pc = uc.sc_elr,
            },
            .linux => .{
                .x = uc.mcontext.regs,
                .sp = uc.mcontext.sp,
                .pc = uc.mcontext.pc,
            },
            .serenity => .{
                .x = uc.mcontext.x,
                .sp = uc.mcontext.sp,
                .pc = uc.mcontext.pc,
            },
            else => null,
        },
        .hexagon => switch (builtin.os.tag) {
            .linux => .{
                .r = uc.mcontext.gregs,
                .pc = uc.mcontext.pc,
            },
            else => null,
        },
        .loongarch64 => switch (builtin.os.tag) {
            .linux => .{
                .r = uc.mcontext.regs, // includes r0 (hardwired zero)
                .pc = uc.mcontext.pc,
            },
            else => null,
        },
        .mips, .mipsel => switch (builtin.os.tag) {
            // The O32 kABI uses 64-bit fields for some reason...
            .linux => .{
                .r = s: {
                    var regs: [32]Mips.Gpr = undefined;
                    for (uc.mcontext.regs, 0..) |r, i| regs[i] = @truncate(r); // includes r0 (hardwired zero)
                    break :s regs;
                },
                .pc = @truncate(uc.mcontext.pc),
            },
            else => null,
        },
        .mips64, .mips64el => switch (builtin.os.tag) {
            .linux => .{
                .r = uc.mcontext.regs, // includes r0 (hardwired zero)
                .pc = uc.mcontext.pc,
            },
            else => null,
        },
        .powerpc, .powerpcle, .powerpc64, .powerpc64le => switch (builtin.os.tag) {
            .linux => .{
                .r = uc.mcontext.gp_regs[0..32].*,
                .pc = uc.mcontext.gp_regs[32],
                .lr = uc.mcontext.gp_regs[36],
            },
            else => null,
        },
        .riscv32, .riscv64 => switch (builtin.os.tag) {
            .linux => .{
                .r = [1]usize{0} ++ uc.mcontext.gregs[1..].*, // r0 position is used for pc; replace with zero
                .pc = uc.mcontext.gregs[0],
            },
            .serenity => if (native_arch == .riscv32) null else .{
                .r = [1]u64{0} ++ uc.mcontext.x,
                .pc = uc.mcontext.pc,
            },
            else => null,
        },
        .s390x => switch (builtin.os.tag) {
            .linux => .{
                .r = uc.mcontext.gregs,
                .psw = .{
                    .mask = uc.mcontext.psw.mask,
                    .addr = uc.mcontext.psw.addr,
                },
            },
            else => null,
        },
        else => null,
    };
}

pub fn fromWindowsContext(ctx: *const std.os.windows.CONTEXT) Native {
    return switch (native_arch) {
        .x86 => .{ .gprs = .init(.{
            .eax = ctx.Eax,
            .ecx = ctx.Ecx,
            .edx = ctx.Edx,
            .ebx = ctx.Ebx,
            .esp = ctx.Esp,
            .ebp = ctx.Ebp,
            .esi = ctx.Esi,
            .edi = ctx.Edi,
            .eip = ctx.Eip,
        }) },
        .x86_64 => .{ .gprs = .init(.{
            .rax = ctx.Rax,
            .rdx = ctx.Rdx,
            .rcx = ctx.Rcx,
            .rbx = ctx.Rbx,
            .rsi = ctx.Rsi,
            .rdi = ctx.Rdi,
            .rbp = ctx.Rbp,
            .rsp = ctx.Rsp,
            .r8 = ctx.R8,
            .r9 = ctx.R9,
            .r10 = ctx.R10,
            .r11 = ctx.R11,
            .r12 = ctx.R12,
            .r13 = ctx.R13,
            .r14 = ctx.R14,
            .r15 = ctx.R15,
            .rip = ctx.Rip,
        }) },
        .aarch64 => .{
            .x = ctx.DUMMYUNIONNAME.X[0..31].*,
            .sp = ctx.Sp,
            .pc = ctx.Pc,
        },
        .thumb => .{ .r = .{
            ctx.R0,  ctx.R1, ctx.R2,  ctx.R3,
            ctx.R4,  ctx.R5, ctx.R6,  ctx.R7,
            ctx.R8,  ctx.R9, ctx.R10, ctx.R11,
            ctx.R12, ctx.Sp, ctx.Lr,  ctx.Pc,
        } },
        else => comptime unreachable,
    };
}

const X86 = struct {
    /// The first 8 registers here intentionally match the order of registers in the x86 instruction
    /// encoding. This order is inherited by the PUSHA instruction and the DWARF register mappings,
    /// among other things.
    pub const Gpr = enum {
        // zig fmt: off
        eax, ecx, edx, ebx,
        esp, ebp, esi, edi,
        eip,
        // zig fmt: on
    };
    gprs: std.enums.EnumArray(Gpr, u32),

    pub inline fn current() X86 {
        var ctx: X86 = undefined;
        asm volatile (
            \\movl %%eax, 0x00(%%edi)
            \\movl %%ecx, 0x04(%%edi)
            \\movl %%edx, 0x08(%%edi)
            \\movl %%ebx, 0x0c(%%edi)
            \\movl %%esp, 0x10(%%edi)
            \\movl %%ebp, 0x14(%%edi)
            \\movl %%esi, 0x18(%%edi)
            \\movl %%edi, 0x1c(%%edi)
            \\call 1f
            \\1:
            \\popl 0x20(%%edi)
            :
            : [gprs] "{edi}" (&ctx.gprs.values),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *X86, register_num: u16) DwarfRegisterError![]u8 {
        // System V Application Binary Interface Intel386 Architecture Processor Supplement Version 1.1
        //   § 2.4.2 "DWARF Register Number Mapping"
        switch (register_num) {
            // The order of `Gpr` intentionally matches DWARF's mappings.
            //
            // x86-macos sometimes uses different mappings (ebp and esp are reversed when the unwind
            // information is from `__eh_frame`). This deviation is not considered here, because
            // x86-macos is a deprecated target which is not supported by the Zig Standard Library.
            0...8 => return @ptrCast(&ctx.gprs.values[register_num]),

            9 => return error.UnsupportedRegister, // eflags
            11...18 => return error.UnsupportedRegister, // st0 - st7
            21...28 => return error.UnsupportedRegister, // xmm0 - xmm7
            29...36 => return error.UnsupportedRegister, // mm0 - mm7
            39 => return error.UnsupportedRegister, // mxcsr
            40...45 => return error.UnsupportedRegister, // es, cs, ss, ds, fs, gs
            48 => return error.UnsupportedRegister, // tr
            49 => return error.UnsupportedRegister, // ldtr
            93...100 => return error.UnsupportedRegister, // k0 - k7 (AVX-512)

            else => return error.InvalidRegister,
        }
    }
};

const X86_64 = struct {
    /// The order here intentionally matches the order of the DWARF register mappings. It's unclear
    /// where those mappings actually originated from---the ordering of the first 4 registers seems
    /// quite unusual---but it is currently convenient for us to match DWARF.
    pub const Gpr = enum {
        // zig fmt: off
        rax, rdx, rcx, rbx,
        rsi, rdi, rbp, rsp,
        r8,  r9,  r10, r11,
        r12, r13, r14, r15,
        rip,
        // zig fmt: on
    };
    gprs: std.enums.EnumArray(Gpr, u64),

    pub inline fn current() X86_64 {
        var ctx: X86_64 = undefined;
        asm volatile (
            \\movq %%rax, 0x00(%%rdi)
            \\movq %%rdx, 0x08(%%rdi)
            \\movq %%rcx, 0x10(%%rdi)
            \\movq %%rbx, 0x18(%%rdi)
            \\movq %%rsi, 0x20(%%rdi)
            \\movq %%rdi, 0x28(%%rdi)
            \\movq %%rbp, 0x30(%%rdi)
            \\movq %%rsp, 0x38(%%rdi)
            \\movq %%r8,  0x40(%%rdi)
            \\movq %%r9,  0x48(%%rdi)
            \\movq %%r10, 0x50(%%rdi)
            \\movq %%r11, 0x58(%%rdi)
            \\movq %%r12, 0x60(%%rdi)
            \\movq %%r13, 0x68(%%rdi)
            \\movq %%r14, 0x70(%%rdi)
            \\movq %%r15, 0x78(%%rdi)
            \\leaq (%%rip), %%rax
            \\movq %%rax, 0x80(%%rdi)
            \\movq 0x00(%%rdi), %%rax
            :
            : [gprs] "{rdi}" (&ctx.gprs.values),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *X86_64, register_num: u16) DwarfRegisterError![]u8 {
        // System V Application Binary Interface AMD64 Architecture Processor Supplement
        //   § 3.6.2 "DWARF Register Number Mapping"
        switch (register_num) {
            // The order of `Gpr` intentionally matches DWARF's mappings.
            0...16 => return @ptrCast(&ctx.gprs.values[register_num]),

            17...32 => return error.UnsupportedRegister, // xmm0 - xmm15
            33...40 => return error.UnsupportedRegister, // st0 - st7
            41...48 => return error.UnsupportedRegister, // mm0 - mm7
            49 => return error.UnsupportedRegister, // rflags
            50...55 => return error.UnsupportedRegister, // es, cs, ss, ds, fs, gs
            58...59 => return error.UnsupportedRegister, // fs.base, gs.base
            62 => return error.UnsupportedRegister, // tr
            63 => return error.UnsupportedRegister, // ldtr
            64 => return error.UnsupportedRegister, // mxcsr
            65 => return error.UnsupportedRegister, // fcw
            66 => return error.UnsupportedRegister, // fsw
            67...82 => return error.UnsupportedRegister, // xmm16 - xmm31 (AVX-512)
            118...125 => return error.UnsupportedRegister, // k0 - k7 (AVX-512)
            130...145 => return error.UnsupportedRegister, // r16 - r31 (APX)

            else => return error.InvalidRegister,
        }
    }
};

const Arm = struct {
    /// The numbered general-purpose registers R0 - R15.
    r: [16]u32,

    pub inline fn current() Arm {
        var ctx: Arm = undefined;
        asm volatile (
            \\// For compatibility with Thumb, we can't write r13 (sp) or r15 (pc) with stm.
            \\stm r0, {r0-r12}
            \\str r13, [r0, #0x34]
            \\str r14, [r0, #0x38]
            \\str r15, [r0, #0x3c]
            :
            : [r] "{r0}" (&ctx.r),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Arm, register_num: u16) DwarfRegisterError![]u8 {
        // DWARF for the Arm(r) Architecture § 4.1 "DWARF register names"
        switch (register_num) {
            0...15 => return @ptrCast(&ctx.r[register_num]),

            64...95 => return error.UnsupportedRegister, // S0 - S31
            96...103 => return error.UnsupportedRegister, // F0 - F7
            104...111 => return error.UnsupportedRegister, // wCGR0 - wCGR7, or ACC0 - ACC7
            112...127 => return error.UnsupportedRegister, // wR0 - wR15
            128 => return error.UnsupportedRegister, // SPSR
            129 => return error.UnsupportedRegister, // SPSR_FIQ
            130 => return error.UnsupportedRegister, // SPSR_IRQ
            131 => return error.UnsupportedRegister, // SPSR_ABT
            132 => return error.UnsupportedRegister, // SPSR_UND
            133 => return error.UnsupportedRegister, // SPSR_SVC
            143 => return error.UnsupportedRegister, // RA_AUTH_CODE
            144...150 => return error.UnsupportedRegister, // R8_USR - R14_USR
            151...157 => return error.UnsupportedRegister, // R8_FIQ - R14_FIQ
            158...159 => return error.UnsupportedRegister, // R13_IRQ - R14_IRQ
            160...161 => return error.UnsupportedRegister, // R13_ABT - R14_ABT
            162...163 => return error.UnsupportedRegister, // R13_UND - R14_UND
            164...165 => return error.UnsupportedRegister, // R13_SVC - R14_SVC
            192...199 => return error.UnsupportedRegister, // wC0 - wC7
            256...287 => return error.UnsupportedRegister, // D0 - D31
            320 => return error.UnsupportedRegister, // TPIDRURO
            321 => return error.UnsupportedRegister, // TPIDRURW
            322 => return error.UnsupportedRegister, // TPIDPR
            323 => return error.UnsupportedRegister, // HTPIDPR
            8192...16383 => return error.UnsupportedRegister, // Unspecified vendor co-processor register

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const Aarch64 = extern struct {
    /// The numbered general-purpose registers X0 - X30.
    x: [31]u64,
    sp: u64,
    pc: u64,

    pub inline fn current() Aarch64 {
        var ctx: Aarch64 = undefined;
        asm volatile (
            \\stp x0,  x1,  [x0, #0x000]
            \\stp x2,  x3,  [x0, #0x010]
            \\stp x4,  x5,  [x0, #0x020]
            \\stp x6,  x7,  [x0, #0x030]
            \\stp x8,  x9,  [x0, #0x040]
            \\stp x10, x11, [x0, #0x050]
            \\stp x12, x13, [x0, #0x060]
            \\stp x14, x15, [x0, #0x070]
            \\stp x16, x17, [x0, #0x080]
            \\stp x18, x19, [x0, #0x090]
            \\stp x20, x21, [x0, #0x0a0]
            \\stp x22, x23, [x0, #0x0b0]
            \\stp x24, x25, [x0, #0x0c0]
            \\stp x26, x27, [x0, #0x0d0]
            \\stp x28, x29, [x0, #0x0e0]
            \\str x30, [x0, #0x0f0]
            \\mov x1, sp
            \\str x1, [x0, #0x0f8]
            \\adr x1, .
            \\str x1, [x0, #0x100]
            \\ldr x1, [x0, #0x008]
            :
            : [gprs] "{x0}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Aarch64, register_num: u16) DwarfRegisterError![]u8 {
        // DWARF for the Arm(r) 64-bit Architecture (AArch64) § 4.1 "DWARF register names"
        switch (register_num) {
            0...30 => return @ptrCast(&ctx.x[register_num]),
            31 => return @ptrCast(&ctx.sp),
            32 => return @ptrCast(&ctx.pc),

            33 => return error.UnsupportedRegister, // ELR_mode
            34 => return error.UnsupportedRegister, // RA_SIGN_STATE
            35 => return error.UnsupportedRegister, // TPIDRRO_ELO
            36 => return error.UnsupportedRegister, // TPIDR_ELO
            37 => return error.UnsupportedRegister, // TPIDR_EL1
            38 => return error.UnsupportedRegister, // TPIDR_EL2
            39 => return error.UnsupportedRegister, // TPIDR_EL3
            46 => return error.UnsupportedRegister, // VG
            47 => return error.UnsupportedRegister, // FFR
            48...63 => return error.UnsupportedRegister, // P0 - P15
            64...95 => return error.UnsupportedRegister, // V0 - V31
            96...127 => return error.UnsupportedRegister, // Z0 - Z31

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const Hexagon = extern struct {
    /// The numbered general-purpose registers r0 - r31.
    r: [32]u32,
    pc: u32,

    pub inline fn current() Hexagon {
        var ctx: Hexagon = undefined;
        asm volatile (
            \\ memw(r0 + #0) = r0
            \\ memw(r0 + #4) = r1
            \\ memw(r0 + #8) = r2
            \\ memw(r0 + #12) = r3
            \\ memw(r0 + #16) = r4
            \\ memw(r0 + #20) = r5
            \\ memw(r0 + #24) = r6
            \\ memw(r0 + #28) = r7
            \\ memw(r0 + #32) = r8
            \\ memw(r0 + #36) = r9
            \\ memw(r0 + #40) = r10
            \\ memw(r0 + #44) = r11
            \\ memw(r0 + #48) = r12
            \\ memw(r0 + #52) = r13
            \\ memw(r0 + #56) = r14
            \\ memw(r0 + #60) = r15
            \\ memw(r0 + #64) = r16
            \\ memw(r0 + #68) = r17
            \\ memw(r0 + #72) = r18
            \\ memw(r0 + #76) = r19
            \\ memw(r0 + #80) = r20
            \\ memw(r0 + #84) = r21
            \\ memw(r0 + #88) = r22
            \\ memw(r0 + #92) = r23
            \\ memw(r0 + #96) = r24
            \\ memw(r0 + #100) = r25
            \\ memw(r0 + #104) = r26
            \\ memw(r0 + #108) = r27
            \\ memw(r0 + #112) = r28
            \\ memw(r0 + #116) = r29
            \\ memw(r0 + #120) = r30
            \\ memw(r0 + #124) = r31
            \\ r1 = pc
            \\ memw(r0 + #128) = r1
            \\ r1 = memw(r0 + #4)
            :
            : [gprs] "{r0}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Hexagon, register_num: u16) DwarfRegisterError![]u8 {
        // Sourced from LLVM's HexagonRegisterInfo.td, which disagrees with LLDB...
        switch (register_num) {
            0...31 => return @ptrCast(&ctx.r[register_num]),
            76 => return @ptrCast(&ctx.pc),

            // This is probably covering some numbers that aren't actually mapped, but seriously,
            // look at that file. I really can't be bothered to make it more precise.
            32...75 => return error.UnsupportedRegister,
            77...259 => return error.UnsupportedRegister,
            // 999999...1000030 => return error.UnsupportedRegister,
            // 9999999...10000030 => return error.UnsupportedRegister,

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const LoongArch = extern struct {
    /// The numbered general-purpose registers r0 - r31. r0 must be zero.
    r: [32]Gpr,
    pc: Gpr,

    pub const Gpr = if (builtin.target.cpu.arch == .loongarch64) u64 else u32;

    pub inline fn current() LoongArch {
        var ctx: LoongArch = undefined;
        asm volatile (if (Gpr == u64)
                \\ st.d $zero, $t0, 0
                \\ st.d $ra, $t0, 8
                \\ st.d $tp, $t0, 16
                \\ st.d $sp, $t0, 24
                \\ st.d $a0, $t0, 32
                \\ st.d $a1, $t0, 40
                \\ st.d $a2, $t0, 48
                \\ st.d $a3, $t0, 56
                \\ st.d $a4, $t0, 64
                \\ st.d $a5, $t0, 72
                \\ st.d $a6, $t0, 80
                \\ st.d $a7, $t0, 88
                \\ st.d $t0, $t0, 96
                \\ st.d $t1, $t0, 104
                \\ st.d $t2, $t0, 112
                \\ st.d $t3, $t0, 120
                \\ st.d $t4, $t0, 128
                \\ st.d $t5, $t0, 136
                \\ st.d $t6, $t0, 144
                \\ st.d $t7, $t0, 152
                \\ st.d $t8, $t0, 160
                \\ st.d $r21, $t0, 168
                \\ st.d $fp, $t0, 176
                \\ st.d $s0, $t0, 184
                \\ st.d $s1, $t0, 192
                \\ st.d $s2, $t0, 200
                \\ st.d $s3, $t0, 208
                \\ st.d $s4, $t0, 216
                \\ st.d $s5, $t0, 224
                \\ st.d $s6, $t0, 232
                \\ st.d $s7, $t0, 240
                \\ st.d $s8, $t0, 248
                \\ bl 1f
                \\1:
                \\ st.d $ra, $t0, 256
                \\ ld.d $ra, $t0, 8
            else
                \\ st.w $zero, $t0, 0
                \\ st.w $ra, $t0, 4
                \\ st.w $tp, $t0, 8
                \\ st.w $sp, $t0, 12
                \\ st.w $a0, $t0, 16
                \\ st.w $a1, $t0, 20
                \\ st.w $a2, $t0, 24
                \\ st.w $a3, $t0, 28
                \\ st.w $a4, $t0, 32
                \\ st.w $a5, $t0, 36
                \\ st.w $a6, $t0, 40
                \\ st.w $a7, $t0, 44
                \\ st.w $t0, $t0, 48
                \\ st.w $t1, $t0, 52
                \\ st.w $t2, $t0, 56
                \\ st.w $t3, $t0, 60
                \\ st.w $t4, $t0, 64
                \\ st.w $t5, $t0, 68
                \\ st.w $t6, $t0, 72
                \\ st.w $t7, $t0, 76
                \\ st.w $t8, $t0, 80
                \\ st.w $r21, $t0, 84
                \\ st.w $fp, $t0, 88
                \\ st.w $s0, $t0, 92
                \\ st.w $s1, $t0, 96
                \\ st.w $s2, $t0, 100
                \\ st.w $s3, $t0, 104
                \\ st.w $s4, $t0, 108
                \\ st.w $s5, $t0, 112
                \\ st.w $s6, $t0, 116
                \\ st.w $s7, $t0, 120
                \\ st.w $s8, $t0, 124
                \\ bl 1f
                \\1:
                \\ st.w $ra, $t0, 128
                \\ ld.w $ra, $t0, 4
            :
            : [gprs] "{$r12}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *LoongArch, register_num: u16) DwarfRegisterError![]u8 {
        switch (register_num) {
            0...31 => return @ptrCast(&ctx.r[register_num]),
            64 => return @ptrCast(&ctx.pc),

            32...63 => return error.UnsupportedRegister, // f0 - f31

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const Mips = extern struct {
    /// The numbered general-purpose registers r0 - r31. r0 must be zero.
    r: [32]Gpr,
    pc: Gpr,

    pub const Gpr = if (builtin.target.cpu.arch.isMIPS64()) u64 else u32;

    pub inline fn current() Mips {
        var ctx: Mips = undefined;
        asm volatile (if (Gpr == u64)
                \\ .set push
                \\ .set noat
                \\ .set noreorder
                \\ .set nomacro
                \\ sd $zero, 0($t0)
                \\ sd $at, 8($t0)
                \\ sd $v0, 16($t0)
                \\ sd $v1, 24($t0)
                \\ sd $a0, 32($t0)
                \\ sd $a1, 40($t0)
                \\ sd $a2, 48($t0)
                \\ sd $a3, 56($t0)
                \\ sd $a4, 64($t0)
                \\ sd $a5, 72($t0)
                \\ sd $a6, 80($t0)
                \\ sd $a7, 88($t0)
                \\ sd $t0, 96($t0)
                \\ sd $t1, 104($t0)
                \\ sd $t2, 112($t0)
                \\ sd $t3, 120($t0)
                \\ sd $s0, 128($t0)
                \\ sd $s1, 136($t0)
                \\ sd $s2, 144($t0)
                \\ sd $s3, 152($t0)
                \\ sd $s4, 160($t0)
                \\ sd $s5, 168($t0)
                \\ sd $s6, 176($t0)
                \\ sd $s7, 184($t0)
                \\ sd $t8, 192($t0)
                \\ sd $t9, 200($t0)
                \\ sd $k0, 208($t0)
                \\ sd $k1, 216($t0)
                \\ sd $gp, 224($t0)
                \\ sd $sp, 232($t0)
                \\ sd $fp, 240($t0)
                \\ sd $ra, 248($t0)
                \\ bal 1f
                \\1:
                \\ sd $ra, 256($t0)
                \\ ld $ra, 248($t0)
                \\ .set pop
            else
                \\ .set push
                \\ .set noat
                \\ .set noreorder
                \\ .set nomacro
                \\ sw $zero, 0($t4)
                \\ sw $at, 4($t4)
                \\ sw $v0, 8($t4)
                \\ sw $v1, 12($t4)
                \\ sw $a0, 16($t4)
                \\ sw $a1, 20($t4)
                \\ sw $a2, 24($t4)
                \\ sw $a3, 28($t4)
                \\ sw $t0, 32($t4)
                \\ sw $t1, 36($t4)
                \\ sw $t2, 40($t4)
                \\ sw $t3, 44($t4)
                \\ sw $t4, 48($t4)
                \\ sw $t5, 52($t4)
                \\ sw $t6, 56($t4)
                \\ sw $t7, 60($t4)
                \\ sw $s0, 64($t4)
                \\ sw $s1, 68($t4)
                \\ sw $s2, 72($t4)
                \\ sw $s3, 76($t4)
                \\ sw $s4, 80($t4)
                \\ sw $s5, 84($t4)
                \\ sw $s6, 88($t4)
                \\ sw $s7, 92($t4)
                \\ sw $t8, 96($t4)
                \\ sw $t9, 100($t4)
                \\ sw $k0, 104($t4)
                \\ sw $k1, 108($t4)
                \\ sw $gp, 112($t4)
                \\ sw $sp, 116($t4)
                \\ sw $fp, 120($t4)
                \\ sw $ra, 124($t4)
                \\ bal 1f
                \\1:
                \\ sw $ra, 128($t4)
                \\ lw $ra, 124($t4)
                \\ .set pop
            :
            : [gprs] "{$12}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Mips, register_num: u16) DwarfRegisterError![]u8 {
        switch (register_num) {
            0...31 => return @ptrCast(&ctx.r[register_num]),
            66 => return @ptrCast(&ctx.pc),

            // Who the hell knows what numbers exist for this architecture? What's an ABI
            // specification anyway? We don't need that nonsense.
            32...63 => return error.UnsupportedRegister, // f0 - f31, w0 - w31
            64 => return error.UnsupportedRegister, // hi0 (ac0)
            65 => return error.UnsupportedRegister, // lo0 (ac0)
            176 => return error.UnsupportedRegister, // hi1 (ac1)
            177 => return error.UnsupportedRegister, // lo1 (ac1)
            178 => return error.UnsupportedRegister, // hi2 (ac2)
            179 => return error.UnsupportedRegister, // lo2 (ac2)
            180 => return error.UnsupportedRegister, // hi3 (ac3)
            181 => return error.UnsupportedRegister, // lo3 (ac3)

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const Powerpc = extern struct {
    /// The numbered general-purpose registers r0 - r31.
    r: [32]Gpr,
    pc: Gpr,
    lr: Gpr,

    pub const Gpr = if (builtin.target.cpu.arch.isPowerPC64()) u64 else u32;

    pub inline fn current() Powerpc {
        var ctx: Powerpc = undefined;
        asm volatile (if (Gpr == u64)
                \\ std 0, 0(10)
                \\ std 1, 8(10)
                \\ std 2, 16(10)
                \\ std 3, 24(10)
                \\ std 4, 32(10)
                \\ std 5, 40(10)
                \\ std 6, 48(10)
                \\ std 7, 56(10)
                \\ std 8, 64(10)
                \\ std 9, 72(10)
                \\ std 10, 80(10)
                \\ std 11, 88(10)
                \\ std 12, 96(10)
                \\ std 13, 104(10)
                \\ std 14, 112(10)
                \\ std 15, 120(10)
                \\ std 16, 128(10)
                \\ std 17, 136(10)
                \\ std 18, 144(10)
                \\ std 19, 152(10)
                \\ std 20, 160(10)
                \\ std 21, 168(10)
                \\ std 22, 176(10)
                \\ std 23, 184(10)
                \\ std 24, 192(10)
                \\ std 25, 200(10)
                \\ std 26, 208(10)
                \\ std 27, 216(10)
                \\ std 28, 224(10)
                \\ std 29, 232(10)
                \\ std 30, 240(10)
                \\ std 31, 248(10)
                \\ mflr 8
                \\ std 8, 264(10)
                \\ bl 1f
                \\1:
                \\ mflr 8
                \\ std 8, 256(10)
                \\ ld 8, 64(10)
            else
                \\ stw 0, 0(10)
                \\ stw 1, 4(10)
                \\ stw 2, 8(10)
                \\ stw 3, 12(10)
                \\ stw 4, 16(10)
                \\ stw 5, 20(10)
                \\ stw 6, 24(10)
                \\ stw 7, 28(10)
                \\ stw 8, 32(10)
                \\ stw 9, 36(10)
                \\ stw 10, 40(10)
                \\ stw 11, 44(10)
                \\ stw 12, 48(10)
                \\ stw 13, 52(10)
                \\ stw 14, 56(10)
                \\ stw 15, 60(10)
                \\ stw 16, 64(10)
                \\ stw 17, 68(10)
                \\ stw 18, 72(10)
                \\ stw 19, 76(10)
                \\ stw 20, 80(10)
                \\ stw 21, 84(10)
                \\ stw 22, 88(10)
                \\ stw 23, 92(10)
                \\ stw 24, 96(10)
                \\ stw 25, 100(10)
                \\ stw 26, 104(10)
                \\ stw 27, 108(10)
                \\ stw 28, 112(10)
                \\ stw 29, 116(10)
                \\ stw 30, 120(10)
                \\ stw 31, 124(10)
                \\ mflr 8
                \\ stw 8, 132(10)
                \\ bl 1f
                \\1:
                \\ mflr 8
                \\ stw 8, 128(10)
                \\ lwz 8, 32(10)
            :
            : [gprs] "{r10}" (&ctx),
            : .{ .lr = true, .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Powerpc, register_num: u16) DwarfRegisterError![]u8 {
        // References:
        //
        // * System V Application Binary Interface - PowerPC Processor Supplement §3-46
        // * Power Architecture 32-bit Application Binary Interface Supplement 1.0 - Linux & Embedded §3.4
        // * 64-bit ELF V2 ABI Specification - Power Architecture Revision 1.5 §2.4
        // * ??? AIX?
        //
        // Are we having fun yet?

        if (Gpr == u64) switch (register_num) {
            65 => return @ptrCast(&ctx.lr), // lr

            66 => return error.UnsupportedRegister, // ctr
            68...75 => return error.UnsupportedRegister, // cr0 - cr7
            76 => return error.UnsupportedRegister, // xer
            77...108 => return error.UnsupportedRegister, // vr0 - vr31
            109 => return error.UnsupportedRegister, // vrsave (LLVM)
            110 => return error.UnsupportedRegister, // vscr
            114 => return error.UnsupportedRegister, // tfhar
            115 => return error.UnsupportedRegister, // tfiar
            116 => return error.UnsupportedRegister, // texasr

            else => {},
        } else switch (register_num) {
            65 => return @ptrCast(&ctx.lr), // fpscr (SVR4 / EABI), or lr if you ask LLVM
            108 => return @ptrCast(&ctx.lr),

            64 => return error.UnsupportedRegister, // cr
            66 => return error.UnsupportedRegister, // msr (SVR4 / EABI), or ctr if you ask LLVM
            68...75 => return error.UnsupportedRegister, // cr0 - cr7 if you ask LLVM
            76 => return error.UnsupportedRegister, // xer if you ask LLVM
            99 => return error.UnsupportedRegister, // acc
            100 => return error.UnsupportedRegister, // mq
            101 => return error.UnsupportedRegister, // xer
            102...107 => return error.UnsupportedRegister, // SPRs
            109 => return error.UnsupportedRegister, // ctr
            110...111 => return error.UnsupportedRegister, // SPRs
            112 => return error.UnsupportedRegister, // spefscr
            113...1123 => return error.UnsupportedRegister, // SPRs
            1124...1155 => return error.UnsupportedRegister, // SPE v0 - v31
            1200...1231 => return error.UnsupportedRegister, // SPE upper r0 - r31
            3072...4095 => return error.UnsupportedRegister, // DCRs
            4096...5120 => return error.UnsupportedRegister, // PMRs

            else => {},
        }

        switch (register_num) {
            0...31 => return @ptrCast(&ctx.r[register_num]),
            67 => return @ptrCast(&ctx.pc),

            32...63 => return error.UnsupportedRegister, // f0 - f31

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const Riscv = extern struct {
    /// The numbered general-purpose registers r0 - r31. r0 must be zero.
    r: [32]Gpr,
    pc: Gpr,

    pub const Gpr = if (builtin.target.cpu.arch.isRiscv64()) u64 else u32;

    pub inline fn current() Riscv {
        var ctx: Riscv = undefined;
        asm volatile (if (Gpr == u64)
                \\ sd zero, 0(t0)
                \\ sd ra, 8(t0)
                \\ sd sp, 16(t0)
                \\ sd gp, 24(t0)
                \\ sd tp, 32(t0)
                \\ sd t0, 40(t0)
                \\ sd t1, 48(t0)
                \\ sd t2, 56(t0)
                \\ sd s0, 64(t0)
                \\ sd s1, 72(t0)
                \\ sd a0, 80(t0)
                \\ sd a1, 88(t0)
                \\ sd a2, 96(t0)
                \\ sd a3, 104(t0)
                \\ sd a4, 112(t0)
                \\ sd a5, 120(t0)
                \\ sd a6, 128(t0)
                \\ sd a7, 136(t0)
                \\ sd s2, 144(t0)
                \\ sd s3, 152(t0)
                \\ sd s4, 160(t0)
                \\ sd s5, 168(t0)
                \\ sd s6, 176(t0)
                \\ sd s7, 184(t0)
                \\ sd s8, 192(t0)
                \\ sd s9, 200(t0)
                \\ sd s10, 208(t0)
                \\ sd s11, 216(t0)
                \\ sd t3, 224(t0)
                \\ sd t4, 232(t0)
                \\ sd t5, 240(t0)
                \\ sd t6, 248(t0)
                \\ jal ra, 1f
                \\1:
                \\ sd ra, 256(t0)
                \\ ld ra, 8(t0)
            else
                \\ sw zero, 0(t0)
                \\ sw ra, 4(t0)
                \\ sw sp, 8(t0)
                \\ sw gp, 12(t0)
                \\ sw tp, 16(t0)
                \\ sw t0, 20(t0)
                \\ sw t1, 24(t0)
                \\ sw t2, 28(t0)
                \\ sw s0, 32(t0)
                \\ sw s1, 36(t0)
                \\ sw a0, 40(t0)
                \\ sw a1, 44(t0)
                \\ sw a2, 48(t0)
                \\ sw a3, 52(t0)
                \\ sw a4, 56(t0)
                \\ sw a5, 60(t0)
                \\ sw a6, 64(t0)
                \\ sw a7, 68(t0)
                \\ sw s2, 72(t0)
                \\ sw s3, 76(t0)
                \\ sw s4, 80(t0)
                \\ sw s5, 84(t0)
                \\ sw s6, 88(t0)
                \\ sw s7, 92(t0)
                \\ sw s8, 96(t0)
                \\ sw s9, 100(t0)
                \\ sw s10, 104(t0)
                \\ sw s11, 108(t0)
                \\ sw t3, 112(t0)
                \\ sw t4, 116(t0)
                \\ sw t5, 120(t0)
                \\ sw t6, 124(t0)
                \\ jal ra, 1f
                \\1:
                \\ sw ra, 128(t0)
                \\ lw ra, 4(t0)
            :
            : [gprs] "{t0}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *Riscv, register_num: u16) DwarfRegisterError![]u8 {
        switch (register_num) {
            0...31 => return @ptrCast(&ctx.r[register_num]),
            65 => return @ptrCast(&ctx.pc),

            32...63 => return error.UnsupportedRegister, // f0 - f31
            64 => return error.UnsupportedRegister, // Alternate Frame Return Column
            96...127 => return error.UnsupportedRegister, // v0 - v31
            3072...4095 => return error.UnsupportedRegister, // Custom extensions
            4096...8191 => return error.UnsupportedRegister, // CSRs

            else => return error.InvalidRegister,
        }
    }
};

/// This is an `extern struct` so that inline assembly in `current` can use field offsets.
const S390x = extern struct {
    /// The numbered general-purpose registers r0 - r15.
    r: [16]u64,
    /// The program counter.
    psw: extern struct {
        mask: u64,
        addr: u64,
    },

    pub inline fn current() S390x {
        var ctx: S390x = undefined;
        asm volatile (
            \\ stmg %%r0, %%r15, 0(%%r2)
            \\ epsw %%r0, %%r1
            \\ stm %%r0, %%r1, 128(%%r2)
            \\ larl %%r0, .
            \\ stg %%r0, 136(%%r2)
            \\ lg %%r0, 0(%%r2)
            \\ lg %%r1, 8(%%r2)
            :
            : [gprs] "{r2}" (&ctx),
            : .{ .memory = true });
        return ctx;
    }

    pub fn dwarfRegisterBytes(ctx: *S390x, register_num: u16) DwarfRegisterError![]u8 {
        switch (register_num) {
            0...15 => return @ptrCast(&ctx.r[register_num]),
            64 => return @ptrCast(&ctx.psw.mask),
            65 => return @ptrCast(&ctx.psw.addr),

            16...31 => return error.UnsupportedRegister, // f0 - f15
            32...47 => return error.UnsupportedRegister, // cr0 - cr15
            48...63 => return error.UnsupportedRegister, // a0 - a15
            66...67 => return error.UnsupportedRegister, // z/OS stuff???
            68...83 => return error.UnsupportedRegister, // v16 - v31

            else => return error.InvalidRegister,
        }
    }
};

const signal_ucontext_t = switch (native_os) {
    .linux => std.os.linux.ucontext_t,
    .emscripten => std.os.emscripten.ucontext_t,
    .freebsd => std.os.freebsd.ucontext_t,
    .driverkit, .macos, .ios, .tvos, .watchos, .visionos => extern struct {
        onstack: c_int,
        sigmask: std.c.sigset_t,
        stack: std.c.stack_t,
        link: ?*signal_ucontext_t,
        mcsize: u64,
        mcontext: *mcontext_t,
        const mcontext_t = switch (native_arch) {
            .aarch64 => extern struct {
                es: extern struct {
                    far: u64, // Virtual Fault Address
                    esr: u32, // Exception syndrome
                    exception: u32, // Number of arm exception taken
                },
                ss: extern struct {
                    /// General purpose registers
                    regs: [29]u64,
                    /// Frame pointer x29
                    fp: u64,
                    /// Link register x30
                    lr: u64,
                    /// Stack pointer x31
                    sp: u64,
                    /// Program counter
                    pc: u64,
                    /// Current program status register
                    cpsr: u32,
                    __pad: u32,
                },
                ns: extern struct {
                    q: [32]u128,
                    fpsr: u32,
                    fpcr: u32,
                },
            },
            .x86_64 => extern struct {
                es: extern struct {
                    trapno: u16,
                    cpu: u16,
                    err: u32,
                    faultvaddr: u64,
                },
                ss: extern struct {
                    rax: u64,
                    rbx: u64,
                    rcx: u64,
                    rdx: u64,
                    rdi: u64,
                    rsi: u64,
                    rbp: u64,
                    rsp: u64,
                    r8: u64,
                    r9: u64,
                    r10: u64,
                    r11: u64,
                    r12: u64,
                    r13: u64,
                    r14: u64,
                    r15: u64,
                    rip: u64,
                    rflags: u64,
                    cs: u64,
                    fs: u64,
                    gs: u64,
                },
                fs: extern struct {
                    reserved: [2]c_int,
                    fcw: u16,
                    fsw: u16,
                    ftw: u8,
                    rsrv1: u8,
                    fop: u16,
                    ip: u32,
                    cs: u16,
                    rsrv2: u16,
                    dp: u32,
                    ds: u16,
                    rsrv3: u16,
                    mxcsr: u32,
                    mxcsrmask: u32,
                    stmm: [8]stmm_reg,
                    xmm: [16]xmm_reg,
                    rsrv4: [96]u8,
                    reserved1: c_int,

                    const stmm_reg = [16]u8;
                    const xmm_reg = [16]u8;
                },
            },
            else => void,
        };
    },
    .solaris, .illumos => extern struct {
        flags: u64,
        link: ?*signal_ucontext_t,
        sigmask: std.c.sigset_t,
        stack: std.c.stack_t,
        mcontext: mcontext_t,
        brand_data: [3]?*anyopaque,
        filler: [2]i64,
        const mcontext_t = extern struct {
            gregs: [28]u64,
            fpregs: std.c.fpregset_t,
        };
    },
    .openbsd => switch (builtin.cpu.arch) {
        .x86_64 => extern struct {
            sc_rdi: c_long,
            sc_rsi: c_long,
            sc_rdx: c_long,
            sc_rcx: c_long,
            sc_r8: c_long,
            sc_r9: c_long,
            sc_r10: c_long,
            sc_r11: c_long,
            sc_r12: c_long,
            sc_r13: c_long,
            sc_r14: c_long,
            sc_r15: c_long,
            sc_rbp: c_long,
            sc_rbx: c_long,
            sc_rax: c_long,
            sc_gs: c_long,
            sc_fs: c_long,
            sc_es: c_long,
            sc_ds: c_long,
            sc_trapno: c_long,
            sc_err: c_long,
            sc_rip: c_long,
            sc_cs: c_long,
            sc_rflags: c_long,
            sc_rsp: c_long,
            sc_ss: c_long,

            sc_fpstate: *anyopaque, // struct fxsave64 *
            __sc_unused: c_int,
            sc_mask: c_int,
            sc_cookie: c_long,
        },
        .aarch64 => extern struct {
            __sc_unused: c_int,
            sc_mask: c_int,
            sc_sp: c_ulong,
            sc_lr: c_ulong,
            sc_elr: c_ulong,
            sc_spsr: c_ulong,
            sc_x: [30]c_ulong,
            sc_cookie: c_long,
        },
        else => void,
    },
    .netbsd => extern struct {
        flags: u32,
        link: ?*signal_ucontext_t,
        sigmask: std.c.sigset_t,
        stack: std.c.stack_t,
        mcontext: mcontext_t,
        __pad: [
            switch (builtin.cpu.arch) {
                .x86 => 4,
                .mips, .mipsel, .mips64, .mips64el => 14,
                .arm, .armeb, .thumb, .thumbeb => 1,
                .sparc, .sparc64 => if (@sizeOf(usize) == 4) 43 else 8,
                else => 0,
            }
        ]u32,
        const mcontext_t = switch (builtin.cpu.arch) {
            .aarch64, .aarch64_be => extern struct {
                gregs: [35]u64,
                fregs: [528]u8 align(16),
                spare: [8]u64,
            },
            .x86 => extern struct {
                gregs: [19]u32,
                fpregs: [161]u32,
                mc_tlsbase: u32,
            },
            .x86_64 => extern struct {
                gregs: [26]u64,
                mc_tlsbase: u64,
                fpregs: [512]u8 align(8),
            },
            else => void,
        };
    },
    .dragonfly => extern struct {
        sigmask: std.c.sigset_t,
        mcontext: mcontext_t,
        link: ?*signal_ucontext_t,
        stack: std.c.stack_t,
        cofunc: ?*fn (?*signal_ucontext_t, ?*anyopaque) void,
        arg: ?*void,
        _spare: [4]c_int,
        const mcontext_t = extern struct {
            const register_t = isize;
            onstack: register_t, // XXX - sigcontext compat.
            rdi: register_t,
            rsi: register_t,
            rdx: register_t,
            rcx: register_t,
            r8: register_t,
            r9: register_t,
            rax: register_t,
            rbx: register_t,
            rbp: register_t,
            r10: register_t,
            r11: register_t,
            r12: register_t,
            r13: register_t,
            r14: register_t,
            r15: register_t,
            xflags: register_t,
            trapno: register_t,
            addr: register_t,
            flags: register_t,
            err: register_t,
            rip: register_t,
            cs: register_t,
            rflags: register_t,
            rsp: register_t, // machine state
            ss: register_t,

            len: c_uint, // sizeof(mcontext_t)
            fpformat: c_uint,
            ownedfp: c_uint,
            reserved: c_uint,
            unused: [8]c_uint,

            // NOTE! 64-byte aligned as of here. Also must match savefpu structure.
            fpregs: [256]c_int align(64),
        };
    },
    .serenity => extern struct {
        link: ?*signal_ucontext_t,
        sigmask: std.c.sigset_t,
        stack: std.c.stack_t,
        mcontext: mcontext_t,
        const mcontext_t = switch (builtin.cpu.arch) {
            // https://github.com/SerenityOS/serenity/blob/200e91cd7f1ec5453799a2720d4dc114a59cc289/Kernel/Arch/aarch64/mcontext.h#L15-L19
            .aarch64 => extern struct {
                x: [31]u64,
                sp: u64,
                pc: u64,
            },
            // https://github.com/SerenityOS/serenity/blob/66f8d0f031ef25c409dbb4fecaa454800fecae0f/Kernel/Arch/riscv64/mcontext.h#L15-L18
            .riscv64 => extern struct {
                x: [31]u64,
                pc: u64,
            },
            // https://github.com/SerenityOS/serenity/blob/7b9ea3efdec9f86a1042893e8107d0b23aad8727/Kernel/Arch/x86_64/mcontext.h#L15-L40
            .x86_64 => extern struct {
                rax: u64,
                rcx: u64,
                rdx: u64,
                rbx: u64,
                rsp: u64,
                rbp: u64,
                rsi: u64,
                rdi: u64,
                rip: u64,
                r8: u64,
                r9: u64,
                r10: u64,
                r11: u64,
                r12: u64,
                r13: u64,
                r14: u64,
                r15: u64,
                rflags: u64,
                cs: u32,
                ss: u32,
                ds: u32,
                es: u32,
                fs: u32,
                gs: u32,
            },
            else => void,
        };
    },
    .haiku => extern struct {
        link: ?*signal_ucontext_t,
        sigmask: std.c.sigset_t,
        stack: std.c.stack_t,
        mcontext: mcontext_t,
        const mcontext_t = switch (builtin.cpu.arch) {
            .arm, .thumb => extern struct {
                r0: u32,
                r1: u32,
                r2: u32,
                r3: u32,
                r4: u32,
                r5: u32,
                r6: u32,
                r7: u32,
                r8: u32,
                r9: u32,
                r10: u32,
                r11: u32,
                r12: u32,
                r13: u32,
                r14: u32,
                r15: u32,
                cpsr: u32,
            },
            .aarch64 => extern struct {
                x: [10]u64,
                lr: u64,
                sp: u64,
                elr: u64,
                spsr: u64,
                fp_q: [32]u128,
                fpsr: u32,
                fpcr: u32,
            },
            .m68k => extern struct {
                pc: u32,
                d0: u32,
                d1: u32,
                d2: u32,
                d3: u32,
                d4: u32,
                d5: u32,
                d6: u32,
                d7: u32,
                a0: u32,
                a1: u32,
                a2: u32,
                a3: u32,
                a4: u32,
                a5: u32,
                a6: u32,
                a7: u32,
                ccr: u8,
                f0: f64,
                f1: f64,
                f2: f64,
                f3: f64,
                f4: f64,
                f5: f64,
                f6: f64,
                f7: f64,
                f8: f64,
                f9: f64,
                f10: f64,
                f11: f64,
                f12: f64,
                f13: f64,
            },
            .mipsel => extern struct {
                r0: u32,
            },
            .powerpc => extern struct {
                pc: u32,
                r0: u32,
                r1: u32,
                r2: u32,
                r3: u32,
                r4: u32,
                r5: u32,
                r6: u32,
                r7: u32,
                r8: u32,
                r9: u32,
                r10: u32,
                r11: u32,
                r12: u32,
                f0: f64,
                f1: f64,
                f2: f64,
                f3: f64,
                f4: f64,
                f5: f64,
                f6: f64,
                f7: f64,
                f8: f64,
                f9: f64,
                f10: f64,
                f11: f64,
                f12: f64,
                f13: f64,
                reserved: u32,
                fpscr: u32,
                ctr: u32,
                xer: u32,
                cr: u32,
                msr: u32,
                lr: u32,
            },
            .riscv64 => extern struct {
                x: [31]u64,
                pc: u64,
                f: [32]f64,
                fcsr: u64,
            },
            .sparc64 => extern struct {
                g1: u64,
                g2: u64,
                g3: u64,
                g4: u64,
                g5: u64,
                g6: u64,
                g7: u64,
                o0: u64,
                o1: u64,
                o2: u64,
                o3: u64,
                o4: u64,
                o5: u64,
                sp: u64,
                o7: u64,
                l0: u64,
                l1: u64,
                l2: u64,
                l3: u64,
                l4: u64,
                l5: u64,
                l6: u64,
                l7: u64,
                i0: u64,
                i1: u64,
                i2: u64,
                i3: u64,
                i4: u64,
                i5: u64,
                fp: u64,
                i7: u64,
            },
            .x86 => extern struct {
                pub const old_extended_regs = extern struct {
                    control: u16,
                    reserved1: u16,
                    status: u16,
                    reserved2: u16,
                    tag: u16,
                    reserved3: u16,
                    eip: u32,
                    cs: u16,
                    opcode: u16,
                    datap: u32,
                    ds: u16,
                    reserved4: u16,
                    fp_mmx: [8][10]u8,
                };

                pub const fp_register = extern struct { value: [10]u8, reserved: [6]u8 };

                pub const xmm_register = extern struct { value: [16]u8 };

                pub const new_extended_regs = extern struct {
                    control: u16,
                    status: u16,
                    tag: u16,
                    opcode: u16,
                    eip: u32,
                    cs: u16,
                    reserved1: u16,
                    datap: u32,
                    ds: u16,
                    reserved2: u16,
                    mxcsr: u32,
                    reserved3: u32,
                    fp_mmx: [8]fp_register,
                    xmmx: [8]xmm_register,
                    reserved4: [224]u8,
                };

                pub const extended_regs = extern struct {
                    state: extern union {
                        old_format: old_extended_regs,
                        new_format: new_extended_regs,
                    },
                    format: u32,
                };

                eip: u32,
                eflags: u32,
                eax: u32,
                ecx: u32,
                edx: u32,
                esp: u32,
                ebp: u32,
                reserved: u32,
                xregs: extended_regs,
                edi: u32,
                esi: u32,
                ebx: u32,
            },
            .x86_64 => extern struct {
                pub const fp_register = extern struct {
                    value: [10]u8,
                    reserved: [6]u8,
                };

                pub const xmm_register = extern struct {
                    value: [16]u8,
                };

                pub const fpu_state = extern struct {
                    control: u16,
                    status: u16,
                    tag: u16,
                    opcode: u16,
                    rip: u64,
                    rdp: u64,
                    mxcsr: u32,
                    mscsr_mask: u32,

                    fp_mmx: [8]fp_register,
                    xmm: [16]xmm_register,
                    reserved: [96]u8,
                };

                pub const xstate_hdr = extern struct {
                    bv: u64,
                    xcomp_bv: u64,
                    reserved: [48]u8,
                };

                pub const savefpu = extern struct {
                    fxsave: fpu_state,
                    xstate: xstate_hdr,
                    ymm: [16]xmm_register,
                };

                rax: u64,
                rbx: u64,
                rcx: u64,
                rdx: u64,
                rdi: u64,
                rsi: u64,
                rbp: u64,
                r8: u64,
                r9: u64,
                r10: u64,
                r11: u64,
                r12: u64,
                r13: u64,
                r14: u64,
                r15: u64,
                rsp: u64,
                rip: u64,
                rflags: u64,
                fpu: savefpu,
            },
            else => void,
        };
    },
    else => void,
};

const std = @import("../std.zig");
const root = @import("root");
const builtin = @import("builtin");
const native_arch = @import("builtin").target.cpu.arch;
const native_os = @import("builtin").target.os.tag;
