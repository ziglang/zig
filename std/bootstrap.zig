// This file is in a package which has the root source file exposed as "@root".
// It is included in the compilation unit when exporting an executable.

const root = @import("@root");
const std = @import("std");

const want_main_symbol = std.build.linking_libc;
const want_start_symbol = !want_main_symbol;

const exit = switch(@compileVar("os")) {
    Os.linux => std.linux.exit,
    Os.darwin => std.darwin.exit,
    else => @compileError("Unsupported OS"),
};

var argc: usize = undefined;
var argv: &&u8 = undefined;

export nakedcc fn _start() -> unreachable {
    @setFnVisible(this, want_start_symbol);
    if (!want_start_symbol) {
        @unreachable();
    }

    switch (@compileVar("arch")) {
        Arch.x86_64 => {
            argc = asm("mov (%%rsp), %[argc]": [argc] "=r" (-> usize));
            argv = asm("lea 0x8(%%rsp), %[argv]": [argv] "=r" (-> &&u8));
        },
        Arch.i386 => {
            argc = asm("mov (%%esp), %[argc]": [argc] "=r" (-> usize));
            argv = asm("lea 0x4(%%esp), %[argv]": [argv] "=r" (-> &&u8));
        },
        else => @compileError("unsupported arch"),
    }
    callMainAndExit()
}

fn callMain() -> %void {
    const args = @alloca([]u8, argc);
    for (args) |_, i| {
        const ptr = argv[i];
        args[i] = ptr[0...std.cstr.len(ptr)];
    }
    return root.main(args);
}

fn callMainAndExit() -> unreachable {
    callMain() %% exit(1);
    exit(0);
}

export fn main(c_argc: i32, c_argv: &&u8) -> i32 {
    @setFnVisible(this, want_main_symbol);
    if (!want_main_symbol) {
        @unreachable();
    }

    argc = usize(c_argc);
    argv = c_argv;
    callMain() %% return 1;
    return 0;
}
