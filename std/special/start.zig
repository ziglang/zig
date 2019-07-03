// This file is included in the compilation unit when exporting an executable.

const root = @import("root");
const std = @import("std");
const builtin = @import("builtin");
const assert = std.debug.assert;

var argc_ptr: [*]usize = undefined;

const is_wasm = switch (builtin.arch) {
    .wasm32, .wasm64 => true,
    else => false,
};

comptime {
    if (builtin.link_libc) {
        @export("main", main, .Strong);
    } else if (builtin.os == .windows) {
        @export("WinMainCRTStartup", WinMainCRTStartup, .Strong);
    } else if (is_wasm and builtin.os == .freestanding) {
        @export("_start", wasm_freestanding_start, .Strong);
    } else {
        @export("_start", _start, .Strong);
    }
}

fn enableSegfaultHandler() void {
    const enable_segfault_handler: bool = if (@hasDecl(root, "enable_segfault_handler"))
        root.enable_segfault_handler
    else
        std.debug.runtime_safety and std.debug.have_segfault_handling_support;
    if (enable_segfault_handler) {
        std.debug.attachSegfaultHandler();
    }
}

extern fn wasm_freestanding_start() void {
    _ = callMain();
}

nakedcc fn _start() noreturn {
    if (builtin.os == builtin.Os.wasi) {
        std.os.wasi.proc_exit(callMain());
    }

    switch (builtin.arch) {
        .x86_64 => {
            argc_ptr = asm ("lea (%%rsp), %[argc]"
                : [argc] "=r" (-> [*]usize)
            );
        },
        .i386 => {
            argc_ptr = asm ("lea (%%esp), %[argc]"
                : [argc] "=r" (-> [*]usize)
            );
        },
        .aarch64, .aarch64_be => {
            argc_ptr = asm ("mov %[argc], sp"
                : [argc] "=r" (-> [*]usize)
            );
        },
        else => @compileError("unsupported arch"),
    }
    // If LLVM inlines stack variables into _start, they will overwrite
    // the command line argument data.
    @noInlineCall(posixCallMainAndExit);
}

extern fn WinMainCRTStartup() noreturn {
    @setAlignStack(16);
    if (!builtin.single_threaded) {
        _ = @import("start_windows_tls.zig");
    }

    enableSegfaultHandler();
    
    std.os.windows.kernel32.ExitProcess(callMain());
}

// TODO https://github.com/ziglang/zig/issues/265
fn posixCallMainAndExit() noreturn {
    if (builtin.os == builtin.Os.freebsd) {
        @setAlignStack(16);
    }
    const argc = argc_ptr[0];
    const argv = @ptrCast([*][*]u8, argc_ptr + 1);

    const envp_optional = @ptrCast([*]?[*]u8, argv + argc + 1);
    var envp_count: usize = 0;
    while (envp_optional[envp_count]) |_| : (envp_count += 1) {}
    const envp = @ptrCast([*][*]u8, envp_optional)[0..envp_count];

    if (builtin.os == .linux) {
        // Find the beginning of the auxiliary vector
        const auxv = @ptrCast([*]std.elf.Auxv, envp.ptr + envp_count + 1);
        std.os.linux.elf_aux_maybe = auxv;
        // Initialize the TLS area
        std.os.linux.tls.initTLS();

        if (std.os.linux.tls.tls_image) |tls_img| {
            const tls_addr = std.os.linux.tls.allocateTLS(tls_img.alloc_size);
            const tp = std.os.linux.tls.copyTLS(tls_addr);
            std.os.linux.tls.setThreadPointer(tp);
        }
    }

    std.os.exit(callMainWithArgs(argc, argv, envp));
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn callMainWithArgs(argc: usize, argv: [*][*]u8, envp: [][*]u8) u8 {
    std.os.argv = argv[0..argc];
    std.os.environ = envp;

    enableSegfaultHandler();

    return callMain();
}

extern fn main(c_argc: i32, c_argv: [*][*]u8, c_envp: [*]?[*]u8) i32 {
    var env_count: usize = 0;
    while (c_envp[env_count] != null) : (env_count += 1) {}
    const envp = @ptrCast([*][*]u8, c_envp)[0..env_count];
    return callMainWithArgs(@intCast(usize, c_argc), c_argv, envp);
}

// This is marked inline because for some reason LLVM in release mode fails to inline it,
// and we want fewer call frames in stack traces.
inline fn callMain() u8 {
    switch (@typeId(@typeOf(root.main).ReturnType)) {
        .NoReturn => {
            root.main();
        },
        .Void => {
            root.main();
            return 0;
        },
        .Int => {
            if (@typeOf(root.main).ReturnType.bit_count != 8) {
                @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'");
            }
            return root.main();
        },
        .ErrorUnion => {
            root.main() catch |err| {
                std.debug.warn("error: {}\n", @errorName(err));
                if (builtin.os != builtin.Os.zen) {
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace.*);
                    }
                }
                return 1;
            };
            return 0;
        },
        else => @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'"),
    }
}

const main_thread_tls_align = 32;
var main_thread_tls_bytes: [64]u8 align(main_thread_tls_align) = [1]u8{0} ** 64;
