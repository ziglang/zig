use "std.zig";

#attribute("naked")
export fn _start() -> unreachable {
    const argc = asm("mov (%%rsp), %[argc]" : [argc] "=r" (-> isize));
    const argv = asm("lea 0x8(%%rsp), %[argv]" : [argv] "=r" (-> &&u8));
    const env = asm("lea 0x10(%%rsp,%%rdi,8), %[env]" : [env] "=r" (-> &&u8));
    exit(main(argc, argv, env))
}
