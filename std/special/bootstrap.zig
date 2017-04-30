// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");

const want_main_symbol = std.target.linking_libc;
const want_start_symbol = !want_main_symbol;

const exit = std.os.posix.exit;

var argc_ptr: &usize = undefined;

export nakedcc fn _start() -> noreturn {
    if (!want_start_symbol) {
        @setGlobalLinkage(_start, GlobalLinkage.Internal);
        unreachable;
    }

    switch (@compileVar("arch")) {
        Arch.x86_64 => {
            argc_ptr = asm("lea (%%rsp), %[argc]": [argc] "=r" (-> &usize));
        },
        Arch.i386 => {
            argc_ptr = asm("lea (%%esp), %[argc]": [argc] "=r" (-> &usize));
        },
        else => @compileError("unsupported arch"),
    }
    callMainAndExit()
}

fn callMainAndExit() -> noreturn {
    const argc = *argc_ptr;
    const argv = @ptrCast(&&u8, &argc_ptr[1]);
    const envp = @ptrCast(&?&u8, &argv[argc + 1]);
    callMain(argc, argv, envp) %% exit(1);
    exit(0);
}

fn callMain(argc: usize, argv: &&u8, envp: &?&u8) -> %void {
    std.os.args.raw = argv[0...argc];

    var env_count: usize = 0;
    while (envp[env_count] != null; env_count += 1) {}
    std.os.environ_raw = @ptrCast(&&u8, envp)[0...env_count];

    std.debug.user_main_fn = root.main;

    return root.main();
}

export fn main(c_argc: i32, c_argv: &&u8, c_envp: &?&u8) -> i32 {
    if (!want_main_symbol) {
        @setGlobalLinkage(main, GlobalLinkage.Internal);
        unreachable;
    }

    callMain(usize(c_argc), c_argv, c_envp) %% return 1;
    return 0;
}
