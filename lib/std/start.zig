// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const uefi = std.os.uefi;
const elf = std.elf;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;

const start_sym_name = if (native_arch.isMIPS()) "__start" else "_start";

// The self-hosted compiler is not fully capable of handling all of this start.zig file.
// Until then, we have simplified logic here for self-hosted. TODO remove this once
// self-hosted is capable enough to handle all of the real start.zig logic.
pub const simplified_logic =
    builtin.zig_backend == .stage2_x86 or
    builtin.zig_backend == .stage2_aarch64 or
    builtin.zig_backend == .stage2_arm or
    builtin.zig_backend == .stage2_sparc64 or
    builtin.cpu.arch == .spirv32 or
    builtin.cpu.arch == .spirv64;

comptime {
    // No matter what, we import the root file, so that any export, test, comptime
    // decls there get run.
    _ = root;

    if (simplified_logic) {
        if (builtin.output_mode == .Exe) {
            if ((builtin.link_libc or builtin.object_format == .c) and @hasDecl(root, "main")) {
                if (@typeInfo(@TypeOf(root.main)).@"fn".calling_convention != .C) {
                    @export(&main2, .{ .name = "main" });
                }
            } else if (builtin.os.tag == .windows) {
                if (!@hasDecl(root, "wWinMainCRTStartup") and !@hasDecl(root, "mainCRTStartup")) {
                    @export(&wWinMainCRTStartup2, .{ .name = "wWinMainCRTStartup" });
                }
            } else if (builtin.os.tag == .opencl) {
                if (@hasDecl(root, "main"))
                    @export(&spirvMain2, .{ .name = "main" });
            } else {
                if (!@hasDecl(root, "_start")) {
                    @export(&_start2, .{ .name = "_start" });
                }
            }
        }
    } else {
        if (builtin.output_mode == .Lib and builtin.link_mode == .dynamic) {
            if (native_os == .windows and !@hasDecl(root, "_DllMainCRTStartup")) {
                @export(&_DllMainCRTStartup, .{ .name = "_DllMainCRTStartup" });
            }
        } else if (builtin.output_mode == .Exe or @hasDecl(root, "main")) {
            if (builtin.link_libc and @hasDecl(root, "main")) {
                if (native_arch.isWasm()) {
                    @export(&mainWithoutEnv, .{ .name = "main" });
                } else if (@typeInfo(@TypeOf(root.main)).@"fn".calling_convention != .C) {
                    @export(&main, .{ .name = "main" });
                }
            } else if (native_os == .windows) {
                if (!@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup") and
                    !@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup"))
                {
                    @export(&WinStartup, .{ .name = "wWinMainCRTStartup" });
                } else if (@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup") and
                    !@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup"))
                {
                    @compileError("WinMain not supported; declare wWinMain or main instead");
                } else if (@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup") and
                    !@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup"))
                {
                    @export(&wWinMainCRTStartup, .{ .name = "wWinMainCRTStartup" });
                }
            } else if (native_os == .uefi) {
                if (!@hasDecl(root, "EfiMain")) @export(&EfiMain, .{ .name = "EfiMain" });
            } else if (native_os == .wasi) {
                const wasm_start_sym = switch (builtin.wasi_exec_model) {
                    .reactor => "_initialize",
                    .command => "_start",
                };
                if (!@hasDecl(root, wasm_start_sym) and @hasDecl(root, "main")) {
                    // Only call main when defined. For WebAssembly it's allowed to pass `-fno-entry` in which
                    // case it's not required to provide an entrypoint such as main.
                    @export(&wasi_start, .{ .name = wasm_start_sym });
                }
            } else if (native_arch.isWasm() and native_os == .freestanding) {
                // Only call main when defined. For WebAssembly it's allowed to pass `-fno-entry` in which
                // case it's not required to provide an entrypoint such as main.
                if (!@hasDecl(root, start_sym_name) and @hasDecl(root, "main")) @export(&wasm_freestanding_start, .{ .name = start_sym_name });
            } else if (native_os != .other and native_os != .freestanding) {
                if (!@hasDecl(root, start_sym_name)) @export(&_start, .{ .name = start_sym_name });
            }
        }
    }
}

// Simplified start code for stage2 until it supports more language features ///

fn main2() callconv(.C) c_int {
    root.main();
    return 0;
}

fn _start2() callconv(.C) noreturn {
    callMain2();
}

fn callMain2() noreturn {
    @setAlignStack(16);
    root.main();
    exit2(0);
}

fn spirvMain2() callconv(.Kernel) void {
    root.main();
}

fn wWinMainCRTStartup2() callconv(.C) noreturn {
    root.main();
    exit2(0);
}

fn exit2(code: usize) noreturn {
    switch (native_os) {
        .linux => switch (builtin.cpu.arch) {
            .x86_64 => {
                asm volatile ("syscall"
                    :
                    : [number] "{rax}" (231),
                      [arg1] "{rdi}" (code),
                    : "rcx", "r11", "memory"
                );
            },
            .arm => {
                asm volatile ("svc #0"
                    :
                    : [number] "{r7}" (1),
                      [arg1] "{r0}" (code),
                    : "memory"
                );
            },
            .aarch64 => {
                asm volatile ("svc #0"
                    :
                    : [number] "{x8}" (93),
                      [arg1] "{x0}" (code),
                    : "memory", "cc"
                );
            },
            .sparc64 => {
                asm volatile ("ta 0x6d"
                    :
                    : [number] "{g1}" (1),
                      [arg1] "{o0}" (code),
                    : "o0", "o1", "o2", "o3", "o4", "o5", "o6", "o7", "memory"
                );
            },
            else => @compileError("TODO"),
        },
        // exits(0)
        .plan9 => std.os.plan9.exits(null),
        .windows => {
            std.os.windows.ntdll.RtlExitUserProcess(@as(u32, @truncate(code)));
        },
        else => @compileError("TODO"),
    }
    unreachable;
}

////////////////////////////////////////////////////////////////////////////////

fn _DllMainCRTStartup(
    hinstDLL: std.os.windows.HINSTANCE,
    fdwReason: std.os.windows.DWORD,
    lpReserved: std.os.windows.LPVOID,
) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("os/windows/tls.zig");
    }

    if (@hasDecl(root, "DllMain")) {
        return root.DllMain(hinstDLL, fdwReason, lpReserved);
    }

    return std.os.windows.TRUE;
}

fn wasm_freestanding_start() callconv(.C) void {
    // This is marked inline because for some reason LLVM in
    // release mode fails to inline it, and we want fewer call frames in stack traces.
    _ = @call(.always_inline, callMain, .{});
}

fn wasi_start() callconv(.C) void {
    // The function call is marked inline because for some reason LLVM in
    // release mode fails to inline it, and we want fewer call frames in stack traces.
    switch (builtin.wasi_exec_model) {
        .reactor => _ = @call(.always_inline, callMain, .{}),
        .command => std.os.wasi.proc_exit(@call(.always_inline, callMain, .{})),
    }
}

fn EfiMain(handle: uefi.Handle, system_table: *uefi.tables.SystemTable) callconv(.C) usize {
    uefi.handle = handle;
    uefi.system_table = system_table;

    switch (@typeInfo(@TypeOf(root.main)).@"fn".return_type.?) {
        noreturn => {
            root.main();
        },
        void => {
            root.main();
            return 0;
        },
        usize => {
            return root.main();
        },
        uefi.Status => {
            return @intFromEnum(root.main());
        },
        else => @compileError("expected return type of main to be 'void', 'noreturn', 'usize', or 'std.os.uefi.Status'"),
    }
}

fn _start() callconv(.Naked) noreturn {
    // TODO set Top of Stack on non x86_64-plan9
    if (native_os == .plan9 and native_arch == .x86_64) {
        // from /sys/src/libc/amd64/main9.s
        std.os.plan9.tos = asm volatile (""
            : [tos] "={rax}" (-> *std.os.plan9.Tos),
        );
    }

    // Move this to the riscv prong below when this is resolved: https://github.com/ziglang/zig/issues/20918
    if (builtin.cpu.arch.isRISCV() and builtin.zig_backend != .stage2_riscv64) asm volatile (
        \\ .weak __global_pointer$
        \\ .hidden __global_pointer$
        \\ .option push
        \\ .option norelax
        \\ lla gp, __global_pointer$
        \\ .option pop
    );

    // Note that we maintain a very low level of trust with regards to ABI guarantees at this point.
    // We will redundantly align the stack, clear the link register, etc. While e.g. the Linux
    // kernel is usually good about upholding the ABI guarantees, the same cannot be said of dynamic
    // linkers; musl's ldso, for example, opts to not align the stack when invoking the dynamic
    // linker explicitly.
    asm volatile (switch (native_arch) {
            .x86_64 =>
            \\ .cfi_undefined %%rip
            \\ xorl %%ebp, %%ebp
            \\ movq %%rsp, %%rdi
            \\ andq $-16, %%rsp
            \\ callq %[posixCallMainAndExit:P]
            ,
            .x86 =>
            \\ xorl %%ebp, %%ebp
            \\ movl %%esp, %%eax
            \\ andl $-16, %%esp
            \\ subl $12, %%esp
            \\ pushl %%eax
            \\ calll %[posixCallMainAndExit:P]
            ,
            .aarch64, .aarch64_be =>
            \\ mov fp, #0
            \\ mov lr, #0
            \\ mov x0, sp
            \\ and sp, x0, #-16
            \\ b %[posixCallMainAndExit]
            ,
            .arc =>
            // The `arc` tag currently means ARC v1 and v2, which have an unusually low stack
            // alignment requirement. ARC v3 increases it from 4 to 16, but we don't support v3 yet.
            \\ mov fp, 0
            \\ mov blink, 0
            \\ mov r0, sp
            \\ and sp, sp, -4
            \\ b %[posixCallMainAndExit]
            ,
            .arm, .armeb, .thumb, .thumbeb =>
            // Note that this code must work for Thumb-1.
            \\ movs v1, #0
            \\ mov fp, v1
            \\ mov lr, v1
            \\ mov a1, sp
            \\ subs v1, #16
            \\ ands v1, a1
            \\ mov sp, v1
            \\ b %[posixCallMainAndExit]
            ,
            .csky =>
            // The CSKY ABI assumes that `gb` is set to the address of the GOT in order for
            // position-independent code to work. We depend on this in `std.os.linux.start_pie`
            // to locate `_DYNAMIC` as well.
            \\ grs t0, 1f
            \\ 1:
            \\ lrw gb, 1b@GOTPC
            \\ addu gb, t0
            \\ movi lr, 0
            \\ mov a0, sp
            \\ andi sp, sp, -8
            \\ jmpi %[posixCallMainAndExit]
            ,
            .hexagon =>
            // r29 = SP, r30 = FP
            \\ r30 = #0
            \\ r0 = r29
            \\ r29 = and(r29, #-16)
            \\ memw(r29 + #-8) = r29
            \\ r29 = add(r29, #-8)
            \\ call %[posixCallMainAndExit]
            ,
            .loongarch32, .loongarch64 =>
            \\ move $fp, $zero
            \\ move $a0, $sp
            \\ bstrins.d $sp, $zero, 3, 0
            \\ b %[posixCallMainAndExit]
            ,
            .riscv32, .riscv64 =>
            \\ li s0, 0
            \\ li ra, 0
            \\ mv a0, sp
            \\ andi sp, sp, -16
            \\ tail %[posixCallMainAndExit]@plt
            ,
            .m68k =>
            // Note that the - 8 is needed because pc in the jsr instruction points into the middle
            // of the jsr instruction. (The lea is 6 bytes, the jsr is 4 bytes.)
            \\ suba.l %%fp, %%fp
            \\ move.l %%sp, -(%%sp)
            \\ lea %[posixCallMainAndExit] - . - 8, %%a0
            \\ jsr (%%pc, %%a0)
            ,
            .mips, .mipsel =>
            \\ move $fp, $0
            \\ bal 1f
            \\ .gpword .
            \\ .gpword %[posixCallMainAndExit]
            \\ 1:
            // The `gp` register on MIPS serves a similar purpose to `r2` (ToC pointer) on PPC64.
            \\ lw $gp, 0($ra)
            \\ subu $gp, $ra, $gp
            \\ lw $25, 4($ra)
            \\ addu $25, $25, $gp
            \\ move $ra, $0
            \\ move $a0, $sp
            \\ and $sp, -8
            \\ subu $sp, $sp, 16
            \\ jalr $25
            ,
            .mips64, .mips64el =>
            \\ move $fp, $0
            // This is needed because early MIPS versions don't support misaligned loads. Without
            // this directive, the hidden `nop` inserted to fill the delay slot after `bal` would
            // cause the two doublewords to be aligned to 4 bytes instead of 8.
            \\ .balign 8
            \\ bal 1f
            \\ .gpdword .
            \\ .gpdword %[posixCallMainAndExit]
            \\ 1:
            // The `gp` register on MIPS serves a similar purpose to `r2` (ToC pointer) on PPC64.
            \\ ld $gp, 0($ra)
            \\ dsubu $gp, $ra, $gp
            \\ ld $25, 8($ra)
            \\ daddu $25, $25, $gp
            \\ move $ra, $0
            \\ move $a0, $sp
            \\ and $sp, -16
            \\ dsubu $sp, $sp, 16
            \\ jalr $25
            ,
            .powerpc, .powerpcle =>
            // Set up the initial stack frame, and clear the back chain pointer.
            \\ mr 3, 1
            \\ clrrwi 1, 1, 4
            \\ li 0, 0
            \\ stwu 1, -16(1)
            \\ stw 0, 0(1)
            \\ mtlr 0
            \\ b %[posixCallMainAndExit]
            ,
            .powerpc64, .powerpc64le =>
            // Set up the ToC and initial stack frame, and clear the back chain pointer.
            \\ addis 2, 12, .TOC. - %[_start]@ha
            \\ addi 2, 2, .TOC. - %[_start]@l
            \\ mr 3, 1
            \\ clrrdi 1, 1, 4
            \\ li 0, 0
            \\ stdu 0, -32(1)
            \\ mtlr 0
            \\ b %[posixCallMainAndExit]
            \\ nop
            ,
            .s390x =>
            // Set up the stack frame (register save area and cleared back-chain slot).
            \\ lgr %%r2, %%r15
            \\ lghi %%r0, -16
            \\ ngr %%r15, %%r0
            \\ aghi %%r15, -160
            \\ lghi %%r0, 0
            \\ stg  %%r0, 0(%%r15)
            \\ jg %[posixCallMainAndExit]
            ,
            .sparc =>
            // argc is stored after a register window (16 registers * 4 bytes).
            \\ mov %%g0, %%fp
            \\ add %%sp, 64, %%o0
            \\ and %%sp, -8, %%sp
            \\ ba,a %[posixCallMainAndExit]
            ,
            .sparc64 =>
            // argc is stored after a register window (16 registers * 8 bytes) plus the stack bias
            // (2047 bytes).
            \\ mov %%g0, %%fp
            \\ add %%sp, 2175, %%o0
            \\ add %%sp, 2047, %%sp
            \\ and %%sp, -16, %%sp
            \\ sub %%sp, 2047, %%sp
            \\ ba,a %[posixCallMainAndExit]
            ,
            else => @compileError("unsupported arch"),
        }
        :
        : [_start] "X" (&_start),
          [posixCallMainAndExit] "X" (&posixCallMainAndExit),
    );
}

fn WinStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("os/windows/tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    std.os.windows.ntdll.RtlExitUserProcess(callMain());
}

fn wWinMainCRTStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("os/windows/tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    const result: std.os.windows.INT = call_wWinMain();
    std.os.windows.ntdll.RtlExitUserProcess(@as(std.os.windows.UINT, @bitCast(result)));
}

fn posixCallMainAndExit(argc_argv_ptr: [*]usize) callconv(.C) noreturn {
    // We're not ready to panic until thread local storage is initialized.
    @setRuntimeSafety(false);
    // Code coverage instrumentation might try to use thread local variables.
    @disableInstrumentation();
    const argc = argc_argv_ptr[0];
    const argv = @as([*][*:0]u8, @ptrCast(argc_argv_ptr + 1));

    const envp_optional: [*:null]?[*:0]u8 = @ptrCast(@alignCast(argv + argc + 1));
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @as([*][*:0]u8, @ptrCast(envp_optional))[0..envp_count];

    if (native_os == .linux) {
        // Find the beginning of the auxiliary vector
        const auxv: [*]elf.Auxv = @ptrCast(@alignCast(envp.ptr + envp_count + 1));

        var at_hwcap: usize = 0;
        const phdrs = init: {
            var i: usize = 0;
            var at_phdr: usize = 0;
            var at_phnum: usize = 0;
            while (auxv[i].a_type != elf.AT_NULL) : (i += 1) {
                switch (auxv[i].a_type) {
                    elf.AT_PHNUM => at_phnum = auxv[i].a_un.a_val,
                    elf.AT_PHDR => at_phdr = auxv[i].a_un.a_val,
                    elf.AT_HWCAP => at_hwcap = auxv[i].a_un.a_val,
                    else => continue,
                }
            }
            break :init @as([*]elf.Phdr, @ptrFromInt(at_phdr))[0..at_phnum];
        };

        // Apply the initial relocations as early as possible in the startup process. We cannot
        // make calls yet on some architectures (e.g. MIPS) *because* they haven't been applied yet,
        // so this must be fully inlined.
        if (builtin.position_independent_executable) {
            @call(.always_inline, std.os.linux.pie.relocate, .{phdrs});
        }

        // This must be done after PIE relocations have been applied or we may crash
        // while trying to access the global variable (happens on MIPS at least).
        std.os.linux.elf_aux_maybe = auxv;

        if (!builtin.single_threaded) {
            // ARMv6 targets (and earlier) have no support for TLS in hardware.
            // FIXME: Elide the check for targets >= ARMv7 when the target feature API
            // becomes less verbose (and more usable).
            if (comptime native_arch.isArmOrThumb()) {
                if (at_hwcap & std.os.linux.HWCAP.TLS == 0) {
                    // FIXME: Make __aeabi_read_tp call the kernel helper kuser_get_tls
                    // For the time being use a simple trap instead of a @panic call to
                    // keep the binary bloat under control.
                    @trap();
                }
            }

            // Initialize the TLS area.
            std.os.linux.tls.initStatic(phdrs);
        }

        // The way Linux executables represent stack size is via the PT_GNU_STACK
        // program header. However the kernel does not recognize it; it always gives 8 MiB.
        // Here we look for the stack size in our program headers and use setrlimit
        // to ask for more stack space.
        expandStackSize(phdrs);

        const opt_init_array_start = @extern([*]*const fn () callconv(.C) void, .{
            .name = "__init_array_start",
            .linkage = .weak,
        });
        const opt_init_array_end = @extern([*]*const fn () callconv(.C) void, .{
            .name = "__init_array_end",
            .linkage = .weak,
        });
        if (opt_init_array_start) |init_array_start| {
            const init_array_end = opt_init_array_end.?;
            const slice = init_array_start[0 .. init_array_end - init_array_start];
            for (slice) |func| func();
        }
    }

    std.posix.exit(callMainWithArgs(argc, argv, envp));
}

fn expandStackSize(phdrs: []elf.Phdr) void {
    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            elf.PT_GNU_STACK => {
                if (phdr.p_memsz == 0) break;
                assert(phdr.p_memsz % std.mem.page_size == 0);

                // Silently fail if we are unable to get limits.
                const limits = std.posix.getrlimit(.STACK) catch break;

                // Clamp to limits.max .
                const wanted_stack_size = @min(phdr.p_memsz, limits.max);

                if (wanted_stack_size > limits.cur) {
                    std.posix.setrlimit(.STACK, .{
                        .cur = wanted_stack_size,
                        .max = limits.max,
                    }) catch {
                        // Because we could not increase the stack size to the upper bound,
                        // depending on what happens at runtime, a stack overflow may occur.
                        // However it would cause a segmentation fault, thanks to stack probing,
                        // so we do not have a memory safety issue here.
                        // This is intentional silent failure.
                        // This logic should be revisited when the following issues are addressed:
                        // https://github.com/ziglang/zig/issues/157
                        // https://github.com/ziglang/zig/issues/1006
                    };
                }
                break;
            },
            else => {},
        }
    }
}

inline fn callMainWithArgs(argc: usize, argv: [*][*:0]u8, envp: [][*:0]u8) u8 {
    std.os.argv = argv[0..argc];
    std.os.environ = envp;

    std.debug.maybeEnableSegfaultHandler();
    maybeIgnoreSigpipe();

    return callMain();
}

fn main(c_argc: c_int, c_argv: [*][*:0]c_char, c_envp: [*:null]?[*:0]c_char) callconv(.C) c_int {
    var env_count: usize = 0;
    while (c_envp[env_count] != null) : (env_count += 1) {}
    const envp = @as([*][*:0]u8, @ptrCast(c_envp))[0..env_count];

    if (builtin.os.tag == .linux) {
        const at_phdr = std.c.getauxval(elf.AT_PHDR);
        const at_phnum = std.c.getauxval(elf.AT_PHNUM);
        const phdrs = (@as([*]elf.Phdr, @ptrFromInt(at_phdr)))[0..at_phnum];
        expandStackSize(phdrs);
    }

    return callMainWithArgs(@as(usize, @intCast(c_argc)), @as([*][*:0]u8, @ptrCast(c_argv)), envp);
}

fn mainWithoutEnv(c_argc: c_int, c_argv: [*][*:0]c_char) callconv(.C) c_int {
    std.os.argv = @as([*][*:0]u8, @ptrCast(c_argv))[0..@as(usize, @intCast(c_argc))];
    return callMain();
}

// General error message for a malformed return type
const bad_main_ret = "expected return type of main to be 'void', '!void', 'noreturn', 'u8', or '!u8'";

pub inline fn callMain() u8 {
    const ReturnType = @typeInfo(@TypeOf(root.main)).@"fn".return_type.?;

    switch (ReturnType) {
        void => {
            root.main();
            return 0;
        },
        noreturn, u8 => {
            return root.main();
        },
        else => {
            if (@typeInfo(ReturnType) != .error_union) @compileError(bad_main_ret);

            const result = root.main() catch |err| {
                if (builtin.zig_backend == .stage2_riscv64) {
                    std.debug.print("error: failed with error\n", .{});
                    return 1;
                }
                std.log.err("{s}", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                return 1;
            };

            return switch (@TypeOf(result)) {
                void => 0,
                u8 => result,
                else => @compileError(bad_main_ret),
            };
        },
    }
}

pub fn call_wWinMain() std.os.windows.INT {
    const peb = std.os.windows.peb();
    const MAIN_HINSTANCE = @typeInfo(@TypeOf(root.wWinMain)).@"fn".params[0].type.?;
    const hInstance = @as(MAIN_HINSTANCE, @ptrCast(peb.ImageBaseAddress));
    const lpCmdLine: [*:0]u16 = @ptrCast(peb.ProcessParameters.CommandLine.Buffer);

    // There are various types used for the 'show window' variable through the Win32 APIs:
    // - u16 in STARTUPINFOA.wShowWindow / STARTUPINFOW.wShowWindow
    // - c_int in ShowWindow
    // - u32 in PEB.ProcessParameters.dwShowWindow
    // Since STARTUPINFO is the bottleneck for the allowed values, we use `u16` as the
    // type which can coerce into i32/c_int/u32 depending on how the user defines their wWinMain
    // (the Win32 docs show wWinMain with `int` as the type for nCmdShow).
    const nCmdShow: u16 = nCmdShow: {
        // This makes Zig match the nCmdShow behavior of a C program with a WinMain symbol:
        // - With STARTF_USESHOWWINDOW set in STARTUPINFO.dwFlags of the CreateProcess call:
        //   - Compiled with subsystem:console -> nCmdShow is always SW_SHOWDEFAULT
        //   - Compiled with subsystem:windows -> nCmdShow is STARTUPINFO.wShowWindow from
        //     the parent CreateProcess call
        // - With STARTF_USESHOWWINDOW unset:
        //   - nCmdShow is always SW_SHOWDEFAULT
        const SW_SHOWDEFAULT = 10;
        const STARTF_USESHOWWINDOW = 1;
        // root having a wWinMain means that std.builtin.subsystem will always have a non-null value.
        if (std.builtin.subsystem.? == .Windows and peb.ProcessParameters.dwFlags & STARTF_USESHOWWINDOW != 0) {
            break :nCmdShow @truncate(peb.ProcessParameters.dwShowWindow);
        }
        break :nCmdShow SW_SHOWDEFAULT;
    };

    // second parameter hPrevInstance, MSDN: "This parameter is always NULL"
    return root.wWinMain(hInstance, null, lpCmdLine, nCmdShow);
}

fn maybeIgnoreSigpipe() void {
    const have_sigpipe_support = switch (builtin.os.tag) {
        .linux,
        .plan9,
        .solaris,
        .netbsd,
        .openbsd,
        .haiku,
        .macos,
        .ios,
        .watchos,
        .tvos,
        .visionos,
        .dragonfly,
        .freebsd,
        => true,

        else => false,
    };

    if (have_sigpipe_support and !std.options.keep_sigpipe) {
        const posix = std.posix;
        const act: posix.Sigaction = .{
            // Set handler to a noop function instead of `SIG.IGN` to prevent
            // leaking signal disposition to a child process.
            .handler = .{ .handler = noopSigHandler },
            .mask = posix.empty_sigset,
            .flags = 0,
        };
        posix.sigaction(posix.SIG.PIPE, &act, null);
    }
}

fn noopSigHandler(_: i32) callconv(.C) void {}
