// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");
const builtin = @import("builtin");

var argc_ptr: &usize = undefined;

comptime {
    const strong_linkage = builtin.GlobalLinkage.Strong;
    if (builtin.link_libc) {
        @export("main", main, strong_linkage);
    } else if (builtin.os == builtin.Os.windows) {
        @export("WinMainCRTStartup", WinMainCRTStartup, strong_linkage);
    } else if (builtin.os == builtin.Os.zen) {
        @export("_start", zen_start, strong_linkage);
    } else {
        @export("_start", _start, strong_linkage);
    }
}

extern fn zen_start() noreturn {
    std.os.posix.exit(@inlineCall(callMain));
}

nakedcc fn _start() noreturn {
    switch (builtin.arch) {
        builtin.Arch.x86_64 => {
            argc_ptr = asm("lea (%%rsp), %[argc]": [argc] "=r" (-> &usize));
        },
        builtin.Arch.i386 => {
            argc_ptr = asm("lea (%%esp), %[argc]": [argc] "=r" (-> &usize));
        },
        else => @compileError("unsupported arch"),
    }
    // If LLVM inlines stack variables into _start, they will overwrite
    // the command line argument data.
    @noInlineCall(posixCallMainAndExit);
}

extern fn WinMainCRTStartup() noreturn {
    @setAlignStack(16);

    std.os.windows.ExitProcess(callMain());
}

fn posixCallMainAndExit() noreturn {
    const argc = *argc_ptr;
    const argv = @ptrCast(&&u8, &argc_ptr[1]);
    const envp = @ptrCast(&?&u8, &argv[argc + 1]);
    std.os.posix.exit(callMainWithArgs(argc, argv, envp));
}

fn callMainWithArgs(argc: usize, argv: &&u8, envp: &?&u8) u8 {
    std.os.ArgIteratorPosix.raw = argv[0..argc];

    var env_count: usize = 0;
    while (envp[env_count] != null) : (env_count += 1) {}
    std.os.posix_environ_raw = @ptrCast(&&u8, envp)[0..env_count];

    return callMain();
}

extern fn main(c_argc: i32, c_argv: &&u8, c_envp: &?&u8) i32 {
    return callMainWithArgs(usize(c_argc), c_argv, c_envp);
}

fn callMain() u8 {
    switch (@typeId(@typeOf(root.main).ReturnType)) {
        builtin.TypeId.NoReturn => {
            root.main();
        },
        builtin.TypeId.Void => {
            root.main();
            return 0;
        },
        builtin.TypeId.Int => {
            if (@typeOf(root.main).ReturnType.bit_count != 8) {
                @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'");
            }
            return root.main();
        },
        builtin.TypeId.ErrorUnion => {
            root.main() catch |err| {
                std.debug.warn("error: {}\n", @errorName(err));
                if (builtin.os != builtin.Os.zen) {
                    if (@errorReturnTrace()) |trace| {
                        std.debug.dumpStackTrace(trace);
                    }
                }
                return 1;
            };
            return 0;
        },
        else => @compileError("expected return type of main to be 'u8', 'noreturn', 'void', or '!void'"),
    }
}
