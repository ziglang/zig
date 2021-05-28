// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std.zig");
const builtin = @import("builtin");
const assert = std.debug.assert;
const uefi = std.os.uefi;
const tlcsprng = @import("crypto/tlcsprng.zig");
const native_arch = builtin.cpu.arch;
const native_os = builtin.os.tag;

var argc_argv_ptr: [*]usize = undefined;

const start_sym_name = if (native_arch.isMIPS()) "__start" else "_start";

comptime {
    // No matter what, we import the root file, so that any export, test, comptime
    // decls there get run.
    _ = root;

    // The self-hosted compiler is not fully capable of handling all of this start.zig file.
    // Until then, we have simplified logic here for self-hosted. TODO remove this once
    // self-hosted is capable enough to handle all of the real start.zig logic.
    if (builtin.zig_is_stage2) {
        if (builtin.output_mode == .Exe) {
            if ((builtin.link_libc or builtin.object_format == .c) and @hasDecl(root, "main")) {
                if (@typeInfo(@TypeOf(root.main)).Fn.calling_convention != .C) {
                    @export(main2, .{ .name = "main" });
                }
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
                if (@typeInfo(@TypeOf(root.main)).Fn.calling_convention != .C) {
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
    root.main();
    exit2(0);
}

fn exit2(code: usize) noreturn {
    switch (builtin.stage2_arch) {
        .x86_64 => {
            asm volatile ("syscall"
                :
                : [number] "{rax}" (231),
                  [arg1] "{rdi}" (code)
                : "rcx", "r11", "memory"
            );
        },
        .arm => {
            asm volatile ("svc #0"
                :
                : [number] "{r7}" (1),
                  [arg1] "{r0}" (code)
                : "memory"
            );
        },
        .aarch64 => {
            asm volatile ("svc #0"
                :
                : [number] "{x8}" (93),
                  [arg1] "{x0}" (code)
                : "memory", "cc"
            );
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
    // This is marked inline because for some reason LLVM in release mode fails to inline it,
    // and we want fewer call frames in stack traces.
    _ = @call(.{ .modifier = .always_inline }, callMain, .{});
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
            return @enumToInt(root.main());
        },
        else => @compileError("expected return type of main to be 'void', 'noreturn', 'usize', or 'std.os.uefi.Status'"),
    }
}

fn _start() callconv(.Naked) noreturn {
    if (native_os == .wasi) {
        // This is marked inline because for some reason LLVM in release mode fails to inline it,
        // and we want fewer call frames in stack traces.
        std.os.wasi.proc_exit(@call(.{ .modifier = .always_inline }, callMain, .{}));
    }

    switch (native_arch) {
        .x86_64 => {
            argc_argv_ptr = asm volatile (
                \\ xor %%rbp, %%rbp
                : [argc] "={rsp}" (-> [*]usize)
            );
        },
        .i386 => {
            argc_argv_ptr = asm volatile (
                \\ xor %%ebp, %%ebp
                : [argc] "={esp}" (-> [*]usize)
            );
        },
        .aarch64, .aarch64_be, .arm, .armeb, .thumb => {
            argc_argv_ptr = asm volatile (
                \\ mov fp, #0
                \\ mov lr, #0
                : [argc] "={sp}" (-> [*]usize)
            );
        },
        .riscv64 => {
            argc_argv_ptr = asm volatile (
                \\ li s0, 0
                \\ li ra, 0
                : [argc] "={sp}" (-> [*]usize)
            );
        },
        .mips, .mipsel => {
            // The lr is already zeroed on entry, as specified by the ABI.
            argc_argv_ptr = asm volatile (
                \\ move $fp, $0
                : [argc] "={sp}" (-> [*]usize)
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
                : [argc] "={r4}" (-> [*]usize)
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
                : [argc] "={r4}" (-> [*]usize)
                :
                : "r0"
            );
        },
        .sparcv9 => {
            // argc is stored after a register window (16 registers) plus stack bias
            argc_argv_ptr = asm (
                \\ mov %%g0, %%i6
                \\ add %%o6, 2175, %[argc]
                : [argc] "=r" (-> [*]usize)
            );
        },
        else => @compileError("unsupported arch"),
    }
    // If LLVM inlines stack variables into _start, they will overwrite
    // the command line argument data.
    @call(.{ .modifier = .never_inline }, posixCallMainAndExit, .{});
}

fn WinStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    std.os.windows.kernel32.ExitProcess(initEventLoopAndCallMain());
}

fn wWinMainCRTStartup() callconv(std.os.windows.WINAPI) noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded) {
        _ = @import("start_windows_tls.zig");
    }

    std.debug.maybeEnableSegfaultHandler();

    const result: std.os.windows.INT = initEventLoopAndCallWinMain();
    std.os.windows.kernel32.ExitProcess(@bitCast(std.os.windows.UINT, result));
}

// TODO https://github.com/ziglang/zig/issues/265
fn posixCallMainAndExit() noreturn {
    @setAlignStack(16);

    const argc = argc_argv_ptr[0];
    const argv = @ptrCast([*][*:0]u8, argc_argv_ptr + 1);

    const envp_optional = @ptrCast([*:null]?[*:0]u8, @alignCast(@alignOf(usize), argv + argc + 1));
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @ptrCast([*][*:0]u8, envp_optional)[0..envp_count];

    if (native_os == .linux) {
        // Find the beginning of the auxiliary vector
        const auxv = @ptrCast([*]std.elf.Auxv, @alignCast(@alignOf(usize), envp.ptr + envp_count + 1));
        std.os.linux.elf_aux_maybe = auxv;

        // Do this as early as possible, the aux vector is needed
        if (builtin.position_independent_executable) {
            @import("os/linux/start_pie.zig").apply_relocations();
        }

        // Initialize the TLS area. We do a runtime check here to make sure
        // this code is truly being statically executed and not inside a dynamic
        // loader, otherwise this would clobber the thread ID register.
        const is_dynamic = @import("dynamic_library.zig").get_DYNAMIC() != null;
        if (!is_dynamic) {
            std.os.linux.tls.initStaticTLS();
        }

        // The way Linux executables represent stack size is via the PT_GNU_STACK
        // program header. However the kernel does not recognize it; it always gives 8 MiB.
        // Here we look for the stack size in our program headers and use setrlimit
        // to ask for more stack space.
        {
            var i: usize = 0;
            var at_phdr: usize = undefined;
            var at_phnum: usize = undefined;
            while (auxv[i].a_type != std.elf.AT_NULL) : (i += 1) {
                switch (auxv[i].a_type) {
                    std.elf.AT_PHNUM => at_phnum = auxv[i].a_un.a_val,
                    std.elf.AT_PHDR => at_phdr = auxv[i].a_un.a_val,
                    else => continue,
                }
            }
            expandStackSize(at_phdr, at_phnum);
        }
    }

    std.os.exit(@call(.{ .modifier = .always_inline }, callMainWithArgs, .{ argc, argv, envp }));
}

fn expandStackSize(at_phdr: usize, at_phnum: usize) void {
    const phdrs = (@intToPtr([*]std.elf.Phdr, at_phdr))[0..at_phnum];
    for (phdrs) |*phdr| {
        switch (phdr.p_type) {
            std.elf.PT_GNU_STACK => {
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

    return initEventLoopAndCallMain();
}

fn main(c_argc: i32, c_argv: [*][*:0]u8, c_envp: [*:null]?[*:0]u8) callconv(.C) i32 {
    var env_count: usize = 0;
    while (c_envp[env_count] != null) : (env_count += 1) {}
    const envp = @ptrCast([*][*:0]u8, c_envp)[0..env_count];

    if (builtin.os.tag == .linux) {
        const at_phdr = std.c.getauxval(std.elf.AT_PHDR);
        const at_phnum = std.c.getauxval(std.elf.AT_PHNUM);
        expandStackSize(at_phdr, at_phnum);
    }

    return @call(.{ .modifier = .always_inline }, callMainWithArgs, .{ @intCast(usize, c_argc), c_argv, envp });
}

// General error message for a malformed return type
const bad_main_ret = "expected return type of main to be 'void', '!void', 'noreturn', 'u8', or '!u8'";

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn initEventLoopAndCallMain() u8 {
    if (std.event.Loop.instance) |loop| {
        if (!@hasDecl(root, "event_loop")) {
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
    return @call(.{ .modifier = .always_inline }, callMain, .{});
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
// TODO This function is duplicated from initEventLoopAndCallMain instead of using generics
// because it is working around stage1 compiler bugs.
inline fn initEventLoopAndCallWinMain() std.os.windows.INT {
    if (std.event.Loop.instance) |loop| {
        if (!@hasDecl(root, "event_loop")) {
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
    return @call(.{ .modifier = .always_inline }, call_wWinMain, .{});
}

fn callMainAsync(loop: *std.event.Loop) callconv(.Async) u8 {
    // This prevents the event loop from terminating at least until main() has returned.
    // TODO This shouldn't be needed here; it should be in the event loop code.
    loop.beginOneEvent();
    defer loop.finishOneEvent();
    return callMain();
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
    const MAIN_HINSTANCE = @typeInfo(@TypeOf(root.wWinMain)).Fn.args[0].arg_type.?;
    const hInstance = @ptrCast(MAIN_HINSTANCE, std.os.windows.kernel32.GetModuleHandleW(null).?);
    const lpCmdLine = std.os.windows.kernel32.GetCommandLineW();

    // There's no (documented) way to get the nCmdShow parameter, so we're
    // using this fairly standard default.
    const nCmdShow = std.os.windows.user32.SW_SHOW;

    // second parameter hPrevInstance, MSDN: "This parameter is always NULL"
    return root.wWinMain(hInstance, null, lpCmdLine, nCmdShow);
}
