// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const uefi = std.os.uefi;
const elf = std.elf;
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;

var argc_argv_ptr: [*]usize = undefined;

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
    builtin.cpu.arch == .spirv64 or
    builtin.zig_backend == .stage2_riscv64;

comptime {
    // No matter what, we import the root file, so that any export, test, comptime
    // decls there get run.
    _ = root;

    if (simplified_logic) {
        if (builtin.output_mode == .Exe) {
            if ((builtin.link_libc or builtin.object_format == .c) and @hasDecl(root, "main")) {
                if (@typeInfo(@TypeOf(root.main)).Fn.calling_convention != .C) {
                    @export(main2, .{ .name = "main" });
                }
            } else if (builtin.os.tag == .windows) {
                if (!@hasDecl(root, "wWinMainCRTStartup") and !@hasDecl(root, "mainCRTStartup")) {
                    @export(wWinMainCRTStartup2, .{ .name = "wWinMainCRTStartup" });
                }
            } else if (builtin.os.tag == .opencl) {
                if (@hasDecl(root, "main"))
                    @export(spirvMain2, .{ .name = "main" });
            } else if (native_arch.isRISCV()) {
                if (!@hasDecl(root, "_start")) {
                    @export(riscv_start, .{ .name = "_start" });
                }
            } else {
                if (!@hasDecl(root, "_start")) {
                    @export(_start2, .{ .name = "_start" });
                }
            }
        }
    } else {
        if (builtin.output_mode == .Lib and builtin.link_mode == .dynamic) {
            if (native_os == .windows and !@hasDecl(root, "_DllMainCRTStartup")) {
                @export(_DllMainCRTStartup, .{ .name = "_DllMainCRTStartup" });
            }
        } else if (builtin.output_mode == .Exe or @hasDecl(root, "main")) {
            if (builtin.link_libc and @hasDecl(root, "main")) {
                if (native_arch.isWasm()) {
                    @export(mainWithoutEnv, .{ .name = "main" });
                } else if (@typeInfo(@TypeOf(root.main)).Fn.calling_convention != .C) {
                    @export(main, .{ .name = "main" });
                }
            } else if (native_os == .windows) {
                if (!@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup") and
                    !@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup"))
                {
                    @export(WinStartup, .{ .name = "wWinMainCRTStartup" });
                } else if (@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup") and
                    !@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup"))
                {
                    @compileError("WinMain not supported; declare wWinMain or main instead");
                } else if (@hasDecl(root, "wWinMain") and !@hasDecl(root, "wWinMainCRTStartup") and
                    !@hasDecl(root, "WinMain") and !@hasDecl(root, "WinMainCRTStartup"))
                {
                    @export(wWinMainCRTStartup, .{ .name = "wWinMainCRTStartup" });
                }
            } else if (native_os == .uefi) {
                if (!@hasDecl(root, "EfiMain")) @export(EfiMain, .{ .name = "EfiMain" });
            } else if (native_os == .wasi) {
                const wasm_start_sym = switch (builtin.wasi_exec_model) {
                    .reactor => "_initialize",
                    .command => "_start",
                };
                if (!@hasDecl(root, wasm_start_sym) and @hasDecl(root, "main")) {
                    // Only call main when defined. For WebAssembly it's allowed to pass `-fno-entry` in which
                    // case it's not required to provide an entrypoint such as main.
                    @export(wasi_start, .{ .name = wasm_start_sym });
                }
            } else if (native_arch.isWasm() and native_os == .freestanding) {
                // Only call main when defined. For WebAssembly it's allowed to pass `-fno-entry` in which
                // case it's not required to provide an entrypoint such as main.
                if (!@hasDecl(root, start_sym_name) and @hasDecl(root, "main")) @export(wasm_freestanding_start, .{ .name = start_sym_name });
            } else if (native_os != .other and native_os != .freestanding) {
                if (!@hasDecl(root, start_sym_name)) @export(_start, .{ .name = start_sym_name });
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
        _ = @import("start_windows_tls.zig");
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

fn riscv_start() callconv(.C) noreturn {
    std.process.exit(switch (@typeInfo(@typeInfo(@TypeOf(root.main)).Fn.return_type.?)) {
        .NoReturn => root.main(),
        .Void => ret: {
            root.main();
            break :ret 0;
        },
        .Int => |info| ret: {
            if (info.bits != 8 or info.signedness == .signed) {
                @compileError(bad_main_ret);
            }
            break :ret root.main();
        },
        else => @compileError("expected return type of main to be 'void', 'noreturn', 'u8'"),
    });
}

fn EfiMain(handle: uefi.Handle, system_table: *uefi.tables.SystemTable) callconv(.C) usize {
    uefi.handle = handle;
    uefi.system_table = system_table;

    switch (@typeInfo(@TypeOf(root.main)).Fn.return_type.?) {
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
    switch (native_arch) {
        // https://github.com/ziglang/zig/issues/16799
        .riscv64 => @export(argc_argv_ptr, .{
            .name = "__zig_argc_argv_ptr",
            .visibility = .hidden,
        }),
        else => {},
    }
    asm volatile (switch (native_arch) {
            .x86_64 =>
            \\ xorl %%ebp, %%ebp
            \\ movq %%rsp, %[argc_argv_ptr]
            \\ andq $-16, %%rsp
            \\ callq %[posixCallMainAndExit:P]
            ,
            .x86 =>
            \\ xorl %%ebp, %%ebp
            \\ movl %%esp, %[argc_argv_ptr]
            \\ andl $-16, %%esp
            \\ calll %[posixCallMainAndExit:P]
            ,
            .aarch64, .aarch64_be =>
            \\ mov fp, #0
            \\ mov lr, #0
            \\ mov x0, sp
            \\ str x0, %[argc_argv_ptr]
            \\ b %[posixCallMainAndExit]
            ,
            .arm, .armeb, .thumb, .thumbeb =>
            \\ mov fp, #0
            \\ mov lr, #0
            \\ str sp, %[argc_argv_ptr]
            \\ and sp, #-16
            \\ b %[posixCallMainAndExit]
            ,
            .riscv64 =>
            \\ li s0, 0
            \\ li ra, 0
            \\ lui a0, %hi(__zig_argc_argv_ptr)
            \\ sd sp, %lo(__zig_argc_argv_ptr)(a0)
            \\ andi sp, sp, -16
            \\ tail %[posixCallMainAndExit]@plt
            ,
            .mips, .mipsel =>
            // The lr is already zeroed on entry, as specified by the ABI.
            \\ addiu $fp, $zero, 0
            \\ sw $sp, %[argc_argv_ptr]
            \\ .set push
            \\ .set noat
            \\ addiu $1, $zero, -16
            \\ and $sp, $sp, $1
            \\ .set pop
            \\ j %[posixCallMainAndExit]
            ,
            .mips64, .mips64el =>
            // The lr is already zeroed on entry, as specified by the ABI.
            \\ addiu $fp, $zero, 0
            \\ sd $sp, %[argc_argv_ptr]
            \\ .set push
            \\ .set noat
            \\ daddiu $1, $zero, -16
            \\ and $sp, $sp, $1
            \\ .set pop
            \\ j %[posixCallMainAndExit]
            ,
            .powerpc, .powerpcle =>
            // Setup the initial stack frame and clear the back chain pointer.
            \\ stw 1, %[argc_argv_ptr]
            \\ li 0, 0
            \\ stwu 1, -16(1)
            \\ stw 0, 0(1)
            \\ mtlr 0
            \\ b %[posixCallMainAndExit]
            ,
            .powerpc64, .powerpc64le =>
            // Setup the initial stack frame and clear the back chain pointer.
            // TODO: Support powerpc64 (big endian) on ELFv2.
            \\ std 1, %[argc_argv_ptr]
            \\ li 0, 0
            \\ stdu 0, -32(1)
            \\ mtlr 0
            \\ b %[posixCallMainAndExit]
            ,
            .sparc64 =>
            // argc is stored after a register window (16 registers) plus stack bias
            \\ mov %%g0, %%i6
            \\ add %%o6, 2175, %%l0
            \\ ba %[posixCallMainAndExit]
            \\  stx %%l0, %[argc_argv_ptr]
            ,
            else => @compileError("unsupported arch"),
        }
        : [argc_argv_ptr] "=m" (argc_argv_ptr),
        : [posixCallMainAndExit] "X" (&posixCallMainAndExit),
    );
}

fn WinStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    std.os.windows.ntdll.RtlExitUserProcess(callMain());
}

fn wWinMainCRTStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    const result: std.os.windows.INT = call_wWinMain();
    std.os.windows.ntdll.RtlExitUserProcess(@as(std.os.windows.UINT, @bitCast(result)));
}

fn posixCallMainAndExit() callconv(.C) noreturn {
    const argc = argc_argv_ptr[0];
    const argv = @as([*][*:0]u8, @ptrCast(argc_argv_ptr + 1));

    const envp_optional: [*:null]?[*:0]u8 = @ptrCast(@alignCast(argv + argc + 1));
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @as([*][*:0]u8, @ptrCast(envp_optional))[0..envp_count];

    if (native_os == .linux) {
        // Find the beginning of the auxiliary vector
        const auxv: [*]elf.Auxv = @ptrCast(@alignCast(envp.ptr + envp_count + 1));
        std.os.linux.elf_aux_maybe = auxv;

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

        // Apply the initial relocations as early as possible in the startup
        // process.
        if (builtin.position_independent_executable) {
            std.os.linux.pie.relocate(phdrs);
        }

        if (!builtin.single_threaded) {
            // ARMv6 targets (and earlier) have no support for TLS in hardware.
            // FIXME: Elide the check for targets >= ARMv7 when the target feature API
            // becomes less verbose (and more usable).
            if (comptime native_arch.isARM()) {
                if (at_hwcap & std.os.linux.HWCAP.TLS == 0) {
                    // FIXME: Make __aeabi_read_tp call the kernel helper kuser_get_tls
                    // For the time being use a simple abort instead of a @panic call to
                    // keep the binary bloat under control.
                    std.posix.abort();
                }
            }

            // Initialize the TLS area.
            std.os.linux.tls.initStaticTLS(phdrs);
        }

        // The way Linux executables represent stack size is via the PT_GNU_STACK
        // program header. However the kernel does not recognize it; it always gives 8 MiB.
        // Here we look for the stack size in our program headers and use setrlimit
        // to ask for more stack space.
        expandStackSize(phdrs);
    }

    std.posix.exit(callMainWithArgs(argc, argv, envp));
}

fn expandStackSize(phdrs: []elf.Phdr) void {
    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            elf.PT_GNU_STACK => {
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
    switch (@typeInfo(@typeInfo(@TypeOf(root.main)).Fn.return_type.?)) {
        .NoReturn => {
            root.main();
        },
        .Void => {
            root.main();
            return 0;
        },
        .Int => |info| {
            if (info.bits != 8 or info.signedness == .signed) {
                @compileError(bad_main_ret);
            }
            return root.main();
        },
        .ErrorUnion => {
            const result = root.main() catch |err| {
                std.log.err("{s}", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                return 1;
            };
            switch (@typeInfo(@TypeOf(result))) {
                .Void => return 0,
                .Int => |info| {
                    if (info.bits != 8 or info.signedness == .signed) {
                        @compileError(bad_main_ret);
                    }
                    return result;
                },
                else => @compileError(bad_main_ret),
            }
        },
        else => @compileError(bad_main_ret),
    }
}

pub fn call_wWinMain() std.os.windows.INT {
    const peb = std.os.windows.peb();
    const MAIN_HINSTANCE = @typeInfo(@TypeOf(root.wWinMain)).Fn.params[0].type.?;
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
        posix.sigaction(posix.SIG.PIPE, &act, null) catch |err|
            std.debug.panic("failed to set noop SIGPIPE handler: {s}", .{@errorName(err)});
    }
}

fn noopSigHandler(_: i32) callconv(.C) void {}
