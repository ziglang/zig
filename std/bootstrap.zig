import "syscall.zig";

// The compiler treats this file special by implicitly importing the function `main`
// from the root source file as the symbol `zig_user_main`.

const want_start_symbol = switch(@compile_var("os")) {
    linux => true,
    else => false,
};
const want_main_symbol = !want_start_symbol;

var argc: isize = undefined;
var argv: &&u8 = undefined;

#attribute("naked")
#condition(want_start_symbol)
export fn _start() -> unreachable {
    switch (@compile_var("arch")) {
        x86_64 => {
            argc = asm("mov (%%rsp), %[argc]": [argc] "=r" (-> isize));
            argv = asm("lea 0x8(%%rsp), %[argv]": [argv] "=r" (-> &&u8));
        },
        i386 => {
            argc = asm("mov (%%esp), %[argc]": [argc] "=r" (-> isize));
            argv = asm("lea 0x4(%%esp), %[argv]": [argv] "=r" (-> &&u8));
        },
        else => unreachable{},
    }
    call_main()
}

fn strlen(ptr: &const u8) -> isize {
    var count: isize = 0;
    while (ptr[count] != 0) {
        count += 1;
    }
    return count;
}

fn call_main() -> unreachable {
    var args: [argc][]u8 = undefined;
    for (args) |arg, i| {
        const ptr = argv[i];
        args[i] = ptr[0...strlen(ptr)];
    }
    zig_user_main(args) %% exit(1);
    exit(0);
}

#condition(want_main_symbol)
export fn main(argc: i32, argv: &&u8) -> i32 {
    var args: [argc][]u8 = undefined;
    for (args) |arg, i| {
        const ptr = argv[i];
        args[i] = ptr[0...strlen(ptr)];
    }
    zig_user_main(args) %% return 1;
    return 0;
}
