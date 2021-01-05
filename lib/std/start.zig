// SPDX-License-Identifier: MIT
// Copyright (c) 2015-2021 Zig Contributors
// This file is part of [zig](https://ziglang.org/), which is MIT licensed.
// The MIT license requires this copyright notice to be included in all copies
// and substantial portions of the software.
// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std.zig");
const builtin = std.builtin;
const assert = std.debug.assert;
const uefi = std.os.uefi;
const tlcsprng = @import("crypto/tlcsprng.zig");

var argc_argv_ptr: [*]usize = undefined;

const start_sym_name = if (builtin.arch.isMIPS()) "__start" else "_start";

comptime {
    if (builtin.output_mode == .Lib and builtin.link_mode == .Dynamic) {
        if (builtin.os.tag == .windows and !@hasDecl(root, "_DllMainCRTStartup")) {
            @export(_DllMainCRTStartup, .{ .name = "_DllMainCRTStartup" });
        }
    } else if (builtin.output_mode == .Exe or @hasDecl(root, "main")) {
        if (builtin.link_libc and @hasDecl(root, "main")) {
            if (@typeInfo(@TypeOf(root.main)).Fn.calling_convention != .C) {
                @export(main, .{ .name = "main", .linkage = .Weak });
            }
        } else if (builtin.os.tag == .windows) {
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
        } else if (builtin.os.tag == .uefi) {
            if (!@hasDecl(root, "EfiMain")) @export(EfiMain, .{ .name = "EfiMain" });
        } else if (builtin.arch.isWasm() and builtin.os.tag == .freestanding) {
            if (!@hasDecl(root, start_sym_name)) @export(wasm_freestanding_start, .{ .name = start_sym_name });
        } else if (builtin.os.tag != .other and builtin.os.tag != .freestanding) {
            if (!@hasDecl(root, start_sym_name)) @export(_start, .{ .name = start_sym_name });
        }
    }
}

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
    if (builtin.os.tag == .wasi) {
        // This is marked inline because for some reason LLVM in release mode fails to inline it,
        // and we want fewer call frames in stack traces.
        std.os.wasi.proc_exit(@call(.{ .modifier = .always_inline }, callMain, .{}));
    }

    switch (builtin.arch) {
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
        .aarch64, .aarch64_be, .arm, .armeb => {
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

    if (builtin.os.tag == .linux) {
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

        // TODO This is disabled because what should we do when linking libc and this code
        // does not execute? And also it's causing a test failure in stack traces in release modes.

        //// Linux ignores the stack size from the ELF file, and instead always does 8 MiB. A further
        //// problem is that it uses PROT_GROWSDOWN which prevents stores to addresses too far down
        //// the stack and requires "probing". So here we allocate our own stack.
        //const wanted_stack_size = gnu_stack_phdr.p_memsz;
        //assert(wanted_stack_size % std.mem.page_size == 0);
        //// Allocate an extra page as the guard page.
        //const total_size = wanted_stack_size + std.mem.page_size;
        //const new_stack = std.os.mmap(
        //    null,
        //    total_size,
        //    std.os.PROT_READ | std.os.PROT_WRITE,
        //    std.os.MAP_PRIVATE | std.os.MAP_ANONYMOUS,
        //    -1,
        //    0,
        //) catch @panic("out of memory");
        //std.os.mprotect(new_stack[0..std.mem.page_size], std.os.PROT_NONE) catch {};
        //std.os.exit(@call(.{.stack = new_stack}, callMainWithArgs, .{argc, argv, envp}));
    }

    std.os.exit(@call(.{ .modifier = .always_inline }, callMainWithArgs, .{ argc, argv, envp }));
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
