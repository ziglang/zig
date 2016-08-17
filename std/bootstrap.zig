// This file is in a package which has the root source file exposed as "@root".

const root = @import("@root");
const linux = @import("linux.zig");
const cstr = @import("cstr.zig");

const want_start_symbol = switch(@compileVar("os")) {
    linux => true,
    else => false,
};
const want_main_symbol = !want_start_symbol;

var argc: usize = undefined;
var argv: &&u8 = undefined;

#attribute("naked")
#condition(want_start_symbol)
export fn _start() -> unreachable {
    switch (@compileVar("arch")) {
        x86_64 => {
            argc = asm("mov (%%rsp), %[argc]": [argc] "=r" (-> usize));
            argv = asm("lea 0x8(%%rsp), %[argv]": [argv] "=r" (-> &&u8));
        },
        i386 => {
            argc = asm("mov (%%esp), %[argc]": [argc] "=r" (-> usize));
            argv = asm("lea 0x4(%%esp), %[argv]": [argv] "=r" (-> &&u8));
        },
        else => @compileErr("unsupported arch"),
    }
    callMainAndExit()
}

fn callMain() -> %void {
    var args: [argc][]u8 = undefined;
    for (args) |arg, i| {
        const ptr = argv[i];
        args[i] = ptr[0...cstr.len(ptr)];
    }
    return root.main(args);
}

fn callMainAndExit() -> unreachable {
    callMain() %% linux.exit(1);
    linux.exit(0);
}

#condition(want_main_symbol)
export fn main(c_argc: i32, c_argv: &&u8) -> i32 {
    argc = usize(c_argc);
    argv = c_argv;
    callMain() %% return 1;
    return 0;
}
