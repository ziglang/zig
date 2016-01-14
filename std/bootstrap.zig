use "syscall.zig";

// The compiler treats this file special by implicitly importing the function `main`
// from the root source file.

var env: &&u8;

#attribute("naked")
export fn _start() unreachable => {
    const argc = asm("mov (%%rsp), %[argc]": [argc] "=r" (-> isize));
    const argv = asm("lea 0x8(%%rsp), %[argv]": [argv] "=r" (-> &&u8));
    env = asm("lea 0x10(%%rsp,%%rdi,8), %[env]": [env] "=r" (-> &&u8));

    exit(main(argc, argv, env));

/*
    var args = @alloca_array([]u8, argc);
    var i : @typeof(argc) = 0;
    // TODO for in loop over the array
    while (i < argc) {
        const ptr = argv[i];
        args[i] = ptr[0...strlen(ptr)];
        i += 1;
    }
    exit(main(args))
    */
}

/*
fn strlen(ptr: &u8) isize => {
    var count: isize = 0;
    while (ptr[count]) {
        count += 1;
    }
    return count;
}
*/
