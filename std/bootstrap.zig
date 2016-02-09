import "syscall.zig";

// The compiler treats this file special by implicitly importing the function `main`
// from the root source file.

var argc: isize = undefined;
var argv: &&u8 = undefined;
var env: &&u8 = undefined;

#attribute("naked")
export fn _start() -> unreachable {
    argc = asm("mov (%%esp), %[argc]": [argc] "=r" (-> isize));
    argv = asm("lea 0x4(%%esp), %[argv]": [argv] "=r" (-> &&u8));
    env = asm("lea 0x8(%%esp,%[argc],4), %[env]": [env] "=r" (-> &&u8): [argc] "r" (argc));
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
    main(args) %% exit(1);
    exit(0);
}
