import "syscall.zig";

// The compiler treats this file special by implicitly importing the function `main`
// from the root source file.

var argc: usize;
var argv: &&u8;
var env: &&u8;

#attribute("naked")
export fn _start() unreachable => {
    argc = asm("mov (%%rsp), %[argc]": [argc] "=r" (-> usize));
    argv = asm("lea 0x8(%%rsp), %[argv]": [argv] "=r" (-> &&u8));
    env = asm("lea 0x10(%%rsp,%%rdi,8), %[env]": [env] "=r" (-> &&u8));
    call_main()
}

fn strlen(ptr: &u8) usize => {
    var count: usize = 0;
    while (ptr[count] != 0) {
        count += 1;
    }
    return count;
}

fn call_main() unreachable => {
    var args: [argc][]u8;
    var i : @typeof(argc) = 0;
    // TODO for in loop over the array
    while (i < argc) {
        const ptr = argv[i];
        args[i] = ptr[0...strlen(ptr)];
        i += 1;
    }
    exit(main(args))
}
