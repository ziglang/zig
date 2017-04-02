// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");

const want_main_symbol = std.target.linking_libc;
const want_start_symbol = !want_main_symbol;

const exit = std.os.posix.exit;

var argc: usize = undefined;
var argv: &&u8 = undefined;

export nakedcc fn _start() -> noreturn {
    @setGlobalLinkage(_start, if (want_start_symbol) GlobalLinkage.Strong else GlobalLinkage.Internal);
    if (!want_start_symbol) {
        unreachable;
    }

    switch (@compileVar("arch")) {
        Arch.x86_64 => {
            argc = asm("mov %[argc], [rsp]": [argc] "=r" (-> usize));
            argv = asm("lea %[argv], [rsp + 8h]": [argv] "=r" (-> &&u8));
        },
        Arch.i386 => {
            argc = asm("mov %[argc], [esp]": [argc] "=r" (-> usize));
            argv = asm("lea %[argv], [esp + 4h]": [argv] "=r" (-> &&u8));
        },
        else => @compileError("unsupported arch"),
    }
    callMainAndExit()
}

fn callMain(envp: &?&u8) -> %void {
    const args = @alloca([]u8, argc);
    for (args) |_, i| {
        const ptr = argv[i];
        args[i] = ptr[0...std.cstr.len(ptr)];
    }

    var env_count: usize = 0;
    while (envp[env_count] != null; env_count += 1) {}
    const environ = @alloca(std.os.EnvPair, env_count);
    for (environ) |_, env_i| {
        const ptr = ??envp[env_i];

        var line_i: usize = 0;
        while (ptr[line_i] != 0 and ptr[line_i] != '='; line_i += 1) {}

        var end_i: usize = line_i;
        while (ptr[end_i] != 0; end_i += 1) {}

        environ[env_i] = std.os.EnvPair {
            .key = ptr[0...line_i],
            .value = ptr[line_i + 1...end_i],
        };
    }
    std.os.environ = environ;

    return root.main(args);
}

fn callMainAndExit() -> noreturn {
    const envp = @ptrcast(&?&u8, &argv[argc + 1]);
    callMain(envp) %% exit(1);
    exit(0);
}

export fn main(c_argc: i32, c_argv: &&u8, c_envp: &?&u8) -> i32 {
    @setGlobalLinkage(main, if (want_main_symbol) GlobalLinkage.Strong else GlobalLinkage.Internal);
    if (!want_main_symbol) {
        unreachable;
    }

    argc = usize(c_argc);
    argv = c_argv;
    callMain(c_envp) %% return 1;
    return 0;
}
