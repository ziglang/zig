const builtin = @import("builtin");

const std = @import("../../std.zig");
const mem = std.mem;
const posix = std.posix;
const Arch = std.Target.Cpu.Arch;

/// Tells whether unwinding for this target is supported by the Dwarf standard.
///
/// See also `std.debug.SelfInfo.supportsUnwinding` which tells whether the Zig
/// standard library has a working implementation of unwinding for this target.
pub fn supportsUnwinding(target: std.Target) bool {
    return switch (target.cpu.arch) {
        .amdgcn,
        .nvptx,
        .nvptx64,
        .spirv,
        .spirv32,
        .spirv64,
        .spu_2,
        => false,

        // Enabling this causes relocation errors such as:
        // error: invalid relocation type R_RISCV_SUB32 at offset 0x20
        .riscv64, .riscv32 => false,

        // Conservative guess. Feel free to update this logic with any targets
        // that are known to not support Dwarf unwinding.
        else => true,
    };
}

/// Returns `null` for CPU architectures without an instruction pointer register.
pub fn ipRegNum(arch: Arch) ?u8 {
    return switch (arch) {
        .x86 => 8,
        .x86_64 => 16,
        .arm => 15,
        .aarch64 => 32,
        else => null,
    };
}

pub fn fpRegNum(arch: Arch, reg_context: RegisterContext) u8 {
    return switch (arch) {
        // GCC on OS X historically did the opposite of ELF for these registers
        // (only in .eh_frame), and that is now the convention for MachO
        .x86 => if (reg_context.eh_frame and reg_context.is_macho) 4 else 5,
        .x86_64 => 6,
        .arm => 11,
        .aarch64 => 29,
        else => unreachable,
    };
}

pub fn spRegNum(arch: Arch, reg_context: RegisterContext) u8 {
    return switch (arch) {
        .x86 => if (reg_context.eh_frame and reg_context.is_macho) 5 else 4,
        .x86_64 => 7,
        .arm => 13,
        .aarch64 => 31,
        else => unreachable,
    };
}

pub const RegisterContext = struct {
    eh_frame: bool,
    is_macho: bool,
};

pub const RegBytesError = error{
    InvalidRegister,
    UnimplementedArch,
    UnimplementedOs,
    RegisterContextRequired,
    ThreadContextNotSupported,
};

/// Returns a slice containing the backing storage for `reg_number`.
///
/// This function assumes the Dwarf information corresponds not necessarily to
/// the current executable, but at least with a matching CPU architecture and
/// OS. It is planned to lift this limitation with a future enhancement.
///
/// `reg_context` describes in what context the register number is used, as it can have different
/// meanings depending on the DWARF container. It is only required when getting the stack or
/// frame pointer register on some architectures.
pub fn regBytes(
    thread_context_ptr: *std.debug.ThreadContext,
    reg_number: u8,
    reg_context: ?RegisterContext,
) RegBytesError![]u8 {
    if (builtin.os.tag == .windows) {
        return switch (builtin.cpu.arch) {
            .x86 => switch (reg_number) {
                0 => mem.asBytes(&thread_context_ptr.Eax),
                1 => mem.asBytes(&thread_context_ptr.Ecx),
                2 => mem.asBytes(&thread_context_ptr.Edx),
                3 => mem.asBytes(&thread_context_ptr.Ebx),
                4 => mem.asBytes(&thread_context_ptr.Esp),
                5 => mem.asBytes(&thread_context_ptr.Ebp),
                6 => mem.asBytes(&thread_context_ptr.Esi),
                7 => mem.asBytes(&thread_context_ptr.Edi),
                8 => mem.asBytes(&thread_context_ptr.Eip),
                9 => mem.asBytes(&thread_context_ptr.EFlags),
                10 => mem.asBytes(&thread_context_ptr.SegCs),
                11 => mem.asBytes(&thread_context_ptr.SegSs),
                12 => mem.asBytes(&thread_context_ptr.SegDs),
                13 => mem.asBytes(&thread_context_ptr.SegEs),
                14 => mem.asBytes(&thread_context_ptr.SegFs),
                15 => mem.asBytes(&thread_context_ptr.SegGs),
                else => error.InvalidRegister,
            },
            .x86_64 => switch (reg_number) {
                0 => mem.asBytes(&thread_context_ptr.Rax),
                1 => mem.asBytes(&thread_context_ptr.Rdx),
                2 => mem.asBytes(&thread_context_ptr.Rcx),
                3 => mem.asBytes(&thread_context_ptr.Rbx),
                4 => mem.asBytes(&thread_context_ptr.Rsi),
                5 => mem.asBytes(&thread_context_ptr.Rdi),
                6 => mem.asBytes(&thread_context_ptr.Rbp),
                7 => mem.asBytes(&thread_context_ptr.Rsp),
                8 => mem.asBytes(&thread_context_ptr.R8),
                9 => mem.asBytes(&thread_context_ptr.R9),
                10 => mem.asBytes(&thread_context_ptr.R10),
                11 => mem.asBytes(&thread_context_ptr.R11),
                12 => mem.asBytes(&thread_context_ptr.R12),
                13 => mem.asBytes(&thread_context_ptr.R13),
                14 => mem.asBytes(&thread_context_ptr.R14),
                15 => mem.asBytes(&thread_context_ptr.R15),
                16 => mem.asBytes(&thread_context_ptr.Rip),
                else => error.InvalidRegister,
            },
            .aarch64 => switch (reg_number) {
                0...30 => mem.asBytes(&thread_context_ptr.DUMMYUNIONNAME.X[reg_number]),
                31 => mem.asBytes(&thread_context_ptr.Sp),
                32 => mem.asBytes(&thread_context_ptr.Pc),
                else => error.InvalidRegister,
            },
            else => error.UnimplementedArch,
        };
    }

    if (!std.debug.have_ucontext) return error.ThreadContextNotSupported;

    const ucontext_ptr = thread_context_ptr;
    return switch (builtin.cpu.arch) {
        .x86 => switch (builtin.os.tag) {
            .linux, .netbsd, .solaris, .illumos => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EAX]),
                1 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.ECX]),
                2 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EDX]),
                3 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EBX]),
                4...5 => if (reg_context) |r| bytes: {
                    if (reg_number == 4) {
                        break :bytes if (r.eh_frame and r.is_macho)
                            mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EBP])
                        else
                            mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.ESP]);
                    } else {
                        break :bytes if (r.eh_frame and r.is_macho)
                            mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.ESP])
                        else
                            mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EBP]);
                    }
                } else error.RegisterContextRequired,
                6 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.ESI]),
                7 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EDI]),
                8 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EIP]),
                9 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.EFL]),
                10 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.CS]),
                11 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.SS]),
                12 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.DS]),
                13 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.ES]),
                14 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.FS]),
                15 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.GS]),
                16...23 => error.InvalidRegister, // TODO: Support loading ST0-ST7 from mcontext.fpregs
                32...39 => error.InvalidRegister, // TODO: Support loading XMM0-XMM7 from mcontext.fpregs
                else => error.InvalidRegister,
            },
            else => error.UnimplementedOs,
        },
        .x86_64 => switch (builtin.os.tag) {
            .linux, .solaris, .illumos => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RAX]),
                1 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RDX]),
                2 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RCX]),
                3 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RBX]),
                4 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RSI]),
                5 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RDI]),
                6 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RBP]),
                7 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RSP]),
                8 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R8]),
                9 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R9]),
                10 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R10]),
                11 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R11]),
                12 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R12]),
                13 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R13]),
                14 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R14]),
                15 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.R15]),
                16 => mem.asBytes(&ucontext_ptr.mcontext.gregs[posix.REG.RIP]),
                17...32 => |i| if (builtin.os.tag.isSolarish())
                    mem.asBytes(&ucontext_ptr.mcontext.fpregs.chip_state.xmm[i - 17])
                else
                    mem.asBytes(&ucontext_ptr.mcontext.fpregs.xmm[i - 17]),
                else => error.InvalidRegister,
            },
            .freebsd => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.mcontext.rax),
                1 => mem.asBytes(&ucontext_ptr.mcontext.rdx),
                2 => mem.asBytes(&ucontext_ptr.mcontext.rcx),
                3 => mem.asBytes(&ucontext_ptr.mcontext.rbx),
                4 => mem.asBytes(&ucontext_ptr.mcontext.rsi),
                5 => mem.asBytes(&ucontext_ptr.mcontext.rdi),
                6 => mem.asBytes(&ucontext_ptr.mcontext.rbp),
                7 => mem.asBytes(&ucontext_ptr.mcontext.rsp),
                8 => mem.asBytes(&ucontext_ptr.mcontext.r8),
                9 => mem.asBytes(&ucontext_ptr.mcontext.r9),
                10 => mem.asBytes(&ucontext_ptr.mcontext.r10),
                11 => mem.asBytes(&ucontext_ptr.mcontext.r11),
                12 => mem.asBytes(&ucontext_ptr.mcontext.r12),
                13 => mem.asBytes(&ucontext_ptr.mcontext.r13),
                14 => mem.asBytes(&ucontext_ptr.mcontext.r14),
                15 => mem.asBytes(&ucontext_ptr.mcontext.r15),
                16 => mem.asBytes(&ucontext_ptr.mcontext.rip),
                // TODO: Extract xmm state from mcontext.fpstate?
                else => error.InvalidRegister,
            },
            .openbsd => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.sc_rax),
                1 => mem.asBytes(&ucontext_ptr.sc_rdx),
                2 => mem.asBytes(&ucontext_ptr.sc_rcx),
                3 => mem.asBytes(&ucontext_ptr.sc_rbx),
                4 => mem.asBytes(&ucontext_ptr.sc_rsi),
                5 => mem.asBytes(&ucontext_ptr.sc_rdi),
                6 => mem.asBytes(&ucontext_ptr.sc_rbp),
                7 => mem.asBytes(&ucontext_ptr.sc_rsp),
                8 => mem.asBytes(&ucontext_ptr.sc_r8),
                9 => mem.asBytes(&ucontext_ptr.sc_r9),
                10 => mem.asBytes(&ucontext_ptr.sc_r10),
                11 => mem.asBytes(&ucontext_ptr.sc_r11),
                12 => mem.asBytes(&ucontext_ptr.sc_r12),
                13 => mem.asBytes(&ucontext_ptr.sc_r13),
                14 => mem.asBytes(&ucontext_ptr.sc_r14),
                15 => mem.asBytes(&ucontext_ptr.sc_r15),
                16 => mem.asBytes(&ucontext_ptr.sc_rip),
                // TODO: Extract xmm state from sc_fpstate?
                else => error.InvalidRegister,
            },
            .macos, .ios => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.mcontext.ss.rax),
                1 => mem.asBytes(&ucontext_ptr.mcontext.ss.rdx),
                2 => mem.asBytes(&ucontext_ptr.mcontext.ss.rcx),
                3 => mem.asBytes(&ucontext_ptr.mcontext.ss.rbx),
                4 => mem.asBytes(&ucontext_ptr.mcontext.ss.rsi),
                5 => mem.asBytes(&ucontext_ptr.mcontext.ss.rdi),
                6 => mem.asBytes(&ucontext_ptr.mcontext.ss.rbp),
                7 => mem.asBytes(&ucontext_ptr.mcontext.ss.rsp),
                8 => mem.asBytes(&ucontext_ptr.mcontext.ss.r8),
                9 => mem.asBytes(&ucontext_ptr.mcontext.ss.r9),
                10 => mem.asBytes(&ucontext_ptr.mcontext.ss.r10),
                11 => mem.asBytes(&ucontext_ptr.mcontext.ss.r11),
                12 => mem.asBytes(&ucontext_ptr.mcontext.ss.r12),
                13 => mem.asBytes(&ucontext_ptr.mcontext.ss.r13),
                14 => mem.asBytes(&ucontext_ptr.mcontext.ss.r14),
                15 => mem.asBytes(&ucontext_ptr.mcontext.ss.r15),
                16 => mem.asBytes(&ucontext_ptr.mcontext.ss.rip),
                else => error.InvalidRegister,
            },
            else => error.UnimplementedOs,
        },
        .arm => switch (builtin.os.tag) {
            .linux => switch (reg_number) {
                0 => mem.asBytes(&ucontext_ptr.mcontext.arm_r0),
                1 => mem.asBytes(&ucontext_ptr.mcontext.arm_r1),
                2 => mem.asBytes(&ucontext_ptr.mcontext.arm_r2),
                3 => mem.asBytes(&ucontext_ptr.mcontext.arm_r3),
                4 => mem.asBytes(&ucontext_ptr.mcontext.arm_r4),
                5 => mem.asBytes(&ucontext_ptr.mcontext.arm_r5),
                6 => mem.asBytes(&ucontext_ptr.mcontext.arm_r6),
                7 => mem.asBytes(&ucontext_ptr.mcontext.arm_r7),
                8 => mem.asBytes(&ucontext_ptr.mcontext.arm_r8),
                9 => mem.asBytes(&ucontext_ptr.mcontext.arm_r9),
                10 => mem.asBytes(&ucontext_ptr.mcontext.arm_r10),
                11 => mem.asBytes(&ucontext_ptr.mcontext.arm_fp),
                12 => mem.asBytes(&ucontext_ptr.mcontext.arm_ip),
                13 => mem.asBytes(&ucontext_ptr.mcontext.arm_sp),
                14 => mem.asBytes(&ucontext_ptr.mcontext.arm_lr),
                15 => mem.asBytes(&ucontext_ptr.mcontext.arm_pc),
                // CPSR is not allocated a register number (See: https://github.com/ARM-software/abi-aa/blob/main/aadwarf32/aadwarf32.rst, Section 4.1)
                else => error.InvalidRegister,
            },
            else => error.UnimplementedOs,
        },
        .aarch64 => switch (builtin.os.tag) {
            .macos, .ios => switch (reg_number) {
                0...28 => mem.asBytes(&ucontext_ptr.mcontext.ss.regs[reg_number]),
                29 => mem.asBytes(&ucontext_ptr.mcontext.ss.fp),
                30 => mem.asBytes(&ucontext_ptr.mcontext.ss.lr),
                31 => mem.asBytes(&ucontext_ptr.mcontext.ss.sp),
                32 => mem.asBytes(&ucontext_ptr.mcontext.ss.pc),

                // TODO: Find storage for this state
                //34 => mem.asBytes(&ucontext_ptr.ra_sign_state),

                // V0-V31
                64...95 => mem.asBytes(&ucontext_ptr.mcontext.ns.q[reg_number - 64]),
                else => error.InvalidRegister,
            },
            .netbsd => switch (reg_number) {
                0...34 => mem.asBytes(&ucontext_ptr.mcontext.gregs[reg_number]),
                else => error.InvalidRegister,
            },
            .freebsd => switch (reg_number) {
                0...29 => mem.asBytes(&ucontext_ptr.mcontext.gpregs.x[reg_number]),
                30 => mem.asBytes(&ucontext_ptr.mcontext.gpregs.lr),
                31 => mem.asBytes(&ucontext_ptr.mcontext.gpregs.sp),

                // TODO: This seems wrong, but it was in the previous debug.zig code for mapping PC, check this
                32 => mem.asBytes(&ucontext_ptr.mcontext.gpregs.elr),

                else => error.InvalidRegister,
            },
            .openbsd => switch (reg_number) {
                0...30 => mem.asBytes(&ucontext_ptr.sc_x[reg_number]),
                31 => mem.asBytes(&ucontext_ptr.sc_sp),
                32 => mem.asBytes(&ucontext_ptr.sc_lr),
                33 => mem.asBytes(&ucontext_ptr.sc_elr),
                34 => mem.asBytes(&ucontext_ptr.sc_spsr),
                else => error.InvalidRegister,
            },
            else => switch (reg_number) {
                0...30 => mem.asBytes(&ucontext_ptr.mcontext.regs[reg_number]),
                31 => mem.asBytes(&ucontext_ptr.mcontext.sp),
                32 => mem.asBytes(&ucontext_ptr.mcontext.pc),
                else => error.InvalidRegister,
            },
        },
        else => error.UnimplementedArch,
    };
}

/// Returns a pointer to a register stored in a ThreadContext, preserving the
/// pointer attributes of the context.
pub fn regValueNative(
    thread_context_ptr: *std.debug.ThreadContext,
    reg_number: u8,
    reg_context: ?RegisterContext,
) !*align(1) usize {
    const reg_bytes = try regBytes(thread_context_ptr, reg_number, reg_context);
    if (@sizeOf(usize) != reg_bytes.len) return error.IncompatibleRegisterSize;
    return mem.bytesAsValue(usize, reg_bytes[0..@sizeOf(usize)]);
}
