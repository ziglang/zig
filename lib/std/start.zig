// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const uefi = std.os.uefi;
const elf = std.elf;
const tlcsprng = @import("crypto/tlcsprng.zig");
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
    builtin.zig_backend == .stage2_riscv64 or
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
            } else {
                if (!@hasDecl(root, "_start")) {
                    @export(_start2, .{ .name = "_start" });
                }
            }
        }
    } else {
        if (builtin.output_mode == .Lib and builtin.link_mode == .Dynamic) {
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
                if (!@hasDecl(root, wasm_start_sym)) {
                    @export(wasi_start, .{ .name = wasm_start_sym });
                }
            } else if (native_arch.isWasm() and native_os == .freestanding) {
                if (!@hasDecl(root, start_sym_name)) @export(wasm_freestanding_start, .{ .name = start_sym_name });
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

fn _start2() callconv(.Naked) noreturn {
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
            .riscv64 => {
                asm volatile ("ecall"
                    :
                    : [number] "{a7}" (94),
                      [arg1] "{a0}" (0),
                    : "rcx", "r11", "memory"
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
        .plan9 => switch (builtin.cpu.arch) {
            .x86_64 => {
                asm volatile (
                    \\push $0
                    \\push $0
                    \\syscall
                    :
                    : [syscall_number] "{rbp}" (8),
                    : "rcx", "r11", "memory"
                );
            },
            // TODO once we get stack setting with assembly on
            // arm, exit with 0 instead of stack garbage
            .aarch64 => {
                asm volatile ("svc #0"
                    :
                    : [exit] "{x0}" (0x08),
                    : "memory", "cc"
                );
            },
            else => @compileError("TODO"),
        },
        .windows => {
            ExitProcess(@truncate(u32, code));
        },
        else => @compileError("TODO"),
    }
    unreachable;
}

extern "kernel32" fn ExitProcess(exit_code: u32) callconv(.C) noreturn;

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
    switch (builtin.zig_backend) {
        .stage2_c => {
            @export(argc_argv_ptr, .{ .name = "argc_argv_ptr" });
            @export(posixCallMainAndExit, .{ .name = "_posixCallMainAndExit" });
            switch (native_arch) {
                .x86_64 => asm volatile (
                    \\ xorl %%ebp, %%ebp
                    \\ movq %%rsp, argc_argv_ptr
                    \\ andq $-16, %%rsp
                    \\ call _posixCallMainAndExit
                ),
                .x86 => asm volatile (
                    \\ xorl %%ebp, %%ebp
                    \\ movl %%esp, argc_argv_ptr
                    \\ andl $-16, %%esp
                    \\ jmp _posixCallMainAndExit
                ),
                .aarch64, .aarch64_be => asm volatile (
                    \\ mov fp, #0
                    \\ mov lr, #0
                    \\ mov x0, sp
                    \\ adrp x1, argc_argv_ptr
                    \\ str x0, [x1, :lo12:argc_argv_ptr]
                    \\ b _posixCallMainAndExit
                ),
                .arm, .armeb, .thumb => asm volatile (
                    \\ mov fp, #0
                    \\ mov lr, #0
                    \\ str sp, argc_argv_ptr
                    \\ and sp, #-16
                    \\ b _posixCallMainAndExit
                ),
                else => @compileError("unsupported arch"),
            }
            unreachable;
        },
        else => switch (native_arch) {
            .x86_64 => {
                argc_argv_ptr = asm volatile (
                    \\ xor %%ebp, %%ebp
                    : [argc] "={rsp}" (-> [*]usize),
                );
            },
            .x86 => {
                argc_argv_ptr = asm volatile (
                    \\ xor %%ebp, %%ebp
                    : [argc] "={esp}" (-> [*]usize),
                );
            },
            .aarch64, .aarch64_be, .arm, .armeb, .thumb => {
                argc_argv_ptr = asm volatile (
                    \\ mov fp, #0
                    \\ mov lr, #0
                    : [argc] "={sp}" (-> [*]usize),
                );
            },
            .riscv64 => {
                argc_argv_ptr = asm volatile (
                    \\ li s0, 0
                    \\ li ra, 0
                    : [argc] "={sp}" (-> [*]usize),
                );
            },
            .mips, .mipsel, .mips64, .mips64el => {
                // The lr is already zeroed on entry, as specified by the ABI.
                argc_argv_ptr = asm volatile (
                    \\ move $fp, $0
                    : [argc] "={sp}" (-> [*]usize),
                );
            },
            .powerpc => {
                // Setup the initial stack frame and clear the back chain pointer.
                argc_argv_ptr = asm volatile (
                    \\ mr 4, 1
                    \\ li 0, 0
                    \\ stwu 1,-16(1)
                    \\ stw 0, 0(1)
                    \\ mtlr 0
                    : [argc] "={r4}" (-> [*]usize),
                    :
                    : "r0"
                );
            },
            .powerpc64le => {
                // Setup the initial stack frame and clear the back chain pointer.
                // TODO: Support powerpc64 (big endian) on ELFv2.
                argc_argv_ptr = asm volatile (
                    \\ mr 4, 1
                    \\ li 0, 0
                    \\ stdu 0, -32(1)
                    \\ mtlr 0
                    : [argc] "={r4}" (-> [*]usize),
                    :
                    : "r0"
                );
            },
            .sparc64 => {
                // argc is stored after a register window (16 registers) plus stack bias
                argc_argv_ptr = asm (
                    \\ mov %%g0, %%i6
                    \\ add %%o6, 2175, %[argc]
                    : [argc] "=r" (-> [*]usize),
                );
            },
            else => @compileError("unsupported arch"),
        },
    }
    // If LLVM inlines stack variables into _start, they will overwrite
    // the command line argument data.
    @call(.never_inline, posixCallMainAndExit, .{});
}

fn WinStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    std.os.windows.kernel32.ExitProcess(initEventLoopAndCallMain());
}

fn wWinMainCRTStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded and !builtin.link_libc) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    const result: std.os.windows.INT = initEventLoopAndCallWinMain();
    std.os.windows.kernel32.ExitProcess(@bitCast(std.os.windows.UINT, result));
}

fn posixCallMainAndExit() callconv(.C) noreturn {
    @setAlignStack(16);

    const argc = argc_argv_ptr[0];
    const argv = @ptrCast([*][*:0]u8, argc_argv_ptr + 1);

    const envp_optional = @ptrCast([*:null]?[*:0]u8, @alignCast(@alignOf(usize), argv + argc + 1));
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @ptrCast([*][*:0]u8, envp_optional)[0..envp_count];

    if (native_os == .linux) {
        // Find the beginning of the auxiliary vector
        const auxv = @ptrCast([*]elf.Auxv, @alignCast(@alignOf(usize), envp.ptr + envp_count + 1));
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
            break :init @ptrFromInt([*]elf.Phdr, at_phdr)[0..at_phnum];
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
                    std.os.abort();
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

    std.os.exit(@call(.always_inline, callMainWithArgs, .{ argc, argv, envp }));
}

fn expandStackSize(phdrs: []elf.Phdr) void {
    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            elf.PT_GNU_STACK => {
                const wanted_stack_size = phdr.p_memsz;
                assert(wanted_stack_size % std.mem.page_size == 0);

                std.os.setrlimit(.STACK, .{
                    .cur = wanted_stack_size,
                    .max = wanted_stack_size,
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
                break;
            },
            else => {},
        }
    }
}

fn callMainWithArgs(argc: usize, argv: [*][*:0]u8, envp: [][*:0]u8) u8 {
    std.os.argv = argv[0..argc];
    std.os.environ = envp;

    std.debug.maybeEnableSegfaultHandler();
    std.os.maybeIgnoreSigpipe();

    return initEventLoopAndCallMain();
}

fn main(c_argc: c_int, c_argv: [*][*:0]c_char, c_envp: [*:null]?[*:0]c_char) callconv(.C) c_int {
    var env_count: usize = 0;
    while (c_envp[env_count] != null) : (env_count += 1) {}
    const envp = @ptrCast([*][*:0]u8, c_envp)[0..env_count];

    if (builtin.os.tag == .linux) {
        const at_phdr = std.c.getauxval(elf.AT_PHDR);
        const at_phnum = std.c.getauxval(elf.AT_PHNUM);
        const phdrs = (@ptrFromInt([*]elf.Phdr, at_phdr))[0..at_phnum];
        expandStackSize(phdrs);
    }

    return @call(.always_inline, callMainWithArgs, .{ @intCast(usize, c_argc), @ptrCast([*][*:0]u8, c_argv), envp });
}

fn mainWithoutEnv(c_argc: c_int, c_argv: [*][*:0]c_char) callconv(.C) c_int {
    std.os.argv = @ptrCast([*][*:0]u8, c_argv)[0..@intCast(usize, c_argc)];
    return @call(.always_inline, callMain, .{});
}

// General error message for a malformed return type
const bad_main_ret = "expected return type of main to be 'void', '!void', 'noreturn', 'u8', or '!u8'";

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn initEventLoopAndCallMain() u8 {
    if (std.event.Loop.instance) |loop| {
        if (loop == std.event.Loop.default_instance) {
            loop.init() catch |err| {
                std.log.err("{s}", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                return 1;
            };
            defer loop.deinit();

            var result: u8 = undefined;
            var frame: @Frame(callMainAsync) = undefined;
            _ = @asyncCall(&frame, &result, callMainAsync, .{loop});
            loop.run();
            return result;
        }
    }

    // This is marked inline because for some reason LLVM in release mode fails to inline it,
    // and we want fewer call frames in stack traces.
    return @call(.always_inline, callMain, .{});
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
// TODO This function is duplicated from initEventLoopAndCallMain instead of using generics
// because it is working around stage1 compiler bugs.
inline fn initEventLoopAndCallWinMain() std.os.windows.INT {
    if (std.event.Loop.instance) |loop| {
        if (loop == std.event.Loop.default_instance) {
            loop.init() catch |err| {
                std.log.err("{s}", .{@errorName(err)});
                if (@errorReturnTrace()) |trace| {
                    std.debug.dumpStackTrace(trace.*);
                }
                return 1;
            };
            defer loop.deinit();

            var result: std.os.windows.INT = undefined;
            var frame: @Frame(callWinMainAsync) = undefined;
            _ = @asyncCall(&frame, &result, callWinMainAsync, .{loop});
            loop.run();
            return result;
        }
    }

    // This is marked inline because for some reason LLVM in release mode fails to inline it,
    // and we want fewer call frames in stack traces.
    return @call(.always_inline, call_wWinMain, .{});
}

fn callMainAsync(loop: *std.event.Loop) callconv(.Async) u8 {
    // This prevents the event loop from terminating at least until main() has returned.
    // TODO This shouldn't be needed here; it should be in the event loop code.
    loop.beginOneEvent();
    defer loop.finishOneEvent();
    return callMain();
}

fn callWinMainAsync(loop: *std.event.Loop) callconv(.Async) std.os.windows.INT {
    // This prevents the event loop from terminating at least until main() has returned.
    // TODO This shouldn't be needed here; it should be in the event loop code.
    loop.beginOneEvent();
    defer loop.finishOneEvent();
    return call_wWinMain();
}

// This is not marked inline because it is called with @asyncCall when
// there is an event loop.
pub fn callMain() u8 {
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
    const MAIN_HINSTANCE = @typeInfo(@TypeOf(root.wWinMain)).Fn.params[0].type.?;
    const hInstance = @ptrCast(MAIN_HINSTANCE, std.os.windows.kernel32.GetModuleHandleW(null).?);
    const lpCmdLine = std.os.windows.kernel32.GetCommandLineW();

    // There's no (documented) way to get the nCmdShow parameter, so we're
    // using this fairly standard default.
    const nCmdShow = std.os.windows.user32.SW_SHOW;

    // second parameter hPrevInstance, MSDN: "This parameter is always NULL"
    return root.wWinMain(hInstance, null, lpCmdLine, nCmdShow);
}
