// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");
const builtin = @import("builtin");

const is_windows = builtin.os == builtin.Os.windows;
const want_main_symbol = builtin.link_libc;
const want_start_symbol = !want_main_symbol and !is_windows;
const want_WinMainCRTStartup = is_windows and !builtin.link_libc;

var argc_ptr: &usize = undefined;


export nakedcc fn _start() -> noreturn {
    if (!want_start_symbol) {
        @setGlobalLinkage(_start, builtin.GlobalLinkage.Internal);
        unreachable;
    }

    switch (builtin.arch) {
        builtin.Arch.x86_64 => {
            argc_ptr = asm("lea (%%rsp), %[argc]": [argc] "=r" (-> &usize));
        },
        builtin.Arch.i386 => {
            argc_ptr = asm("lea (%%esp), %[argc]": [argc] "=r" (-> &usize));
        },
        else => @compileError("unsupported arch"),
    }
    posixCallMainAndExit()
}

export fn WinMainCRTStartup() -> noreturn {
    if (!want_WinMainCRTStartup) {
        @setGlobalLinkage(WinMainCRTStartup, builtin.GlobalLinkage.Internal);
        unreachable;
    }
    @setAlignStack(16);

    std.debug.user_main_fn = root.main;
    root.main() %% std.os.windows.ExitProcess(1);
    std.os.windows.ExitProcess(0);
}

fn posixCallMainAndExit() -> noreturn {
    const argc = *argc_ptr;
    const argv = @ptrCast(&&u8, &argc_ptr[1]);
    const envp = @ptrCast(&?&u8, &argv[argc + 1]);
    callMain(argc, argv, envp) %% std.os.posix.exit(1);
    std.os.posix.exit(0);
}

fn callMain(argc: usize, argv: &&u8, envp: &?&u8) -> %void {
    std.os.ArgIteratorPosix.raw = argv[0..argc];

    var env_count: usize = 0;
    while (envp[env_count] != null) : (env_count += 1) {}
    std.os.environ_raw = @ptrCast(&&u8, envp)[0..env_count];

    std.debug.user_main_fn = root.main;

    return root.main();
}

export fn main(c_argc: i32, c_argv: &&u8, c_envp: &?&u8) -> i32 {
    if (!want_main_symbol) {
        @setGlobalLinkage(main, builtin.GlobalLinkage.Internal);
        unreachable;
    }

    callMain(usize(c_argc), c_argv, c_envp) %% return 1;
    return 0;
}
