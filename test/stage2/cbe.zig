const std = @import("std");
const TestContext = @import("../../src/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    {
        var case = ctx.exeFromCompiledC("hello world with updates", .{});

        // Regular old hello world
        case.addCompareOutput(
            \\extern fn puts(s: [*:0]const u8) c_int;
            \\export fn main() c_int {
            \\    _ = puts("hello world!");
            \\    return 0;
            \\}
        , "hello world!" ++ std.cstr.line_sep);

        // Now change the message only
        // TODO fix C backend not supporting updates
        // https://github.com/ziglang/zig/issues/7589
        //case.addCompareOutput(
        //    \\extern fn puts(s: [*:0]const u8) c_int;
        //    \\export fn main() c_int {
        //    \\    _ = puts("yo");
        //    \\    return 0;
        //    \\}
        //, "yo" ++ std.cstr.line_sep);
    }

    ctx.c("empty start function", linux_x64,
        \\export fn _start() noreturn {
        \\    unreachable;
        \\}
    ,
        \\zig_noreturn void _start(void) {
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.h("simple header", linux_x64,
        \\export fn start() void{}
    ,
        \\void start(void);
        \\
    );
    ctx.c("less empty start function", linux_x64,
        \\fn main() noreturn {
        \\    unreachable;
        \\}
        \\
        \\export fn _start() noreturn {
        \\    main();
        \\}
    ,
        \\zig_noreturn void main(void);
        \\
        \\zig_noreturn void _start(void) {
        \\    main();
        \\}
        \\
        \\zig_noreturn void main(void) {
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    // TODO: implement return values
    // TODO: figure out a way to prevent asm constants from being generated
    ctx.c("inline asm", linux_x64,
        \\fn exitGood() noreturn {
        \\    asm volatile ("syscall"
        \\        :
        \\        : [number] "{rax}" (231),
        \\          [arg1] "{rdi}" (0)
        \\    );
        \\    unreachable;
        \\}
        \\
        \\export fn _start() noreturn {
        \\    exitGood();
        \\}
    ,
        \\zig_noreturn void exitGood(void);
        \\
        \\static uint8_t exitGood__anon_0[6] = "{rax}";
        \\static uint8_t exitGood__anon_1[6] = "{rdi}";
        \\static uint8_t exitGood__anon_2[8] = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exitGood();
        \\}
        \\
        \\zig_noreturn void exitGood(void) {
        \\    register uintptr_t rax_constant __asm__("rax") = 231;
        \\    register uintptr_t rdi_constant __asm__("rdi") = 0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.c("exit with parameter", linux_x64,
        \\export fn _start() noreturn {
        \\    exit(0);
        \\}
        \\
        \\fn exit(code: usize) noreturn {
        \\    asm volatile ("syscall"
        \\        :
        \\        : [number] "{rax}" (231),
        \\          [arg1] "{rdi}" (code)
        \\    );
        \\    unreachable;
        \\}
        \\
    ,
        \\zig_noreturn void exit(uintptr_t arg0);
        \\
        \\static uint8_t exit__anon_0[6] = "{rax}";
        \\static uint8_t exit__anon_1[6] = "{rdi}";
        \\static uint8_t exit__anon_2[8] = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exit(0);
        \\}
        \\
        \\zig_noreturn void exit(uintptr_t arg0) {
        \\    register uintptr_t rax_constant __asm__("rax") = 231;
        \\    register uintptr_t rdi_constant __asm__("rdi") = arg0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.c("exit with u8 parameter", linux_x64,
        \\export fn _start() noreturn {
        \\    exit(0);
        \\}
        \\
        \\fn exit(code: u8) noreturn {
        \\    asm volatile ("syscall"
        \\        :
        \\        : [number] "{rax}" (231),
        \\          [arg1] "{rdi}" (code)
        \\    );
        \\    unreachable;
        \\}
        \\
    ,
        \\zig_noreturn void exit(uint8_t arg0);
        \\
        \\static uint8_t exit__anon_0[6] = "{rax}";
        \\static uint8_t exit__anon_1[6] = "{rdi}";
        \\static uint8_t exit__anon_2[8] = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exit(0);
        \\}
        \\
        \\zig_noreturn void exit(uint8_t arg0) {
        \\    const uintptr_t __temp_0 = (uintptr_t)arg0;
        \\    register uintptr_t rax_constant __asm__("rax") = 231;
        \\    register uintptr_t rdi_constant __asm__("rdi") = __temp_0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.c("exit with u8 arithmetic", linux_x64,
        \\export fn _start() noreturn {
        \\    exitMath(1);
        \\}
        \\
        \\fn exitMath(a: u8) noreturn {
        \\    exit(0 + a - a);
        \\}
        \\
        \\fn exit(code: u8) noreturn {
        \\    asm volatile ("syscall"
        \\        :
        \\        : [number] "{rax}" (231),
        \\          [arg1] "{rdi}" (code)
        \\    );
        \\    unreachable;
        \\}
        \\
    ,
        \\zig_noreturn void exitMath(uint8_t arg0);
        \\zig_noreturn void exit(uint8_t arg0);
        \\
        \\static uint8_t exit__anon_0[6] = "{rax}";
        \\static uint8_t exit__anon_1[6] = "{rdi}";
        \\static uint8_t exit__anon_2[8] = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exitMath(1);
        \\}
        \\
        \\zig_noreturn void exitMath(uint8_t arg0) {
        \\    const uint8_t __temp_0 = 0 + arg0;
        \\    const uint8_t __temp_1 = __temp_0 - arg0;
        \\    exit(__temp_1);
        \\}
        \\
        \\zig_noreturn void exit(uint8_t arg0) {
        \\    const uintptr_t __temp_0 = (uintptr_t)arg0;
        \\    register uintptr_t rax_constant __asm__("rax") = 231;
        \\    register uintptr_t rdi_constant __asm__("rdi") = __temp_0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.c("exit with u8 arithmetic inverted", linux_x64,
        \\export fn _start() noreturn {
        \\    exitMath(1);
        \\}
        \\
        \\fn exitMath(a: u8) noreturn {
        \\    exit(a + 0 - a);
        \\}
        \\
        \\fn exit(code: u8) noreturn {
        \\    asm volatile ("syscall"
        \\        :
        \\        : [number] "{rax}" (231),
        \\          [arg1] "{rdi}" (code)
        \\    );
        \\    unreachable;
        \\}
        \\
    ,
        \\zig_noreturn void exitMath(uint8_t arg0);
        \\zig_noreturn void exit(uint8_t arg0);
        \\
        \\static uint8_t exit__anon_0[6] = "{rax}";
        \\static uint8_t exit__anon_1[6] = "{rdi}";
        \\static uint8_t exit__anon_2[8] = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exitMath(1);
        \\}
        \\
        \\zig_noreturn void exitMath(uint8_t arg0) {
        \\    const uint8_t __temp_0 = arg0 + 0;
        \\    const uint8_t __temp_1 = __temp_0 - arg0;
        \\    exit(__temp_1);
        \\}
        \\
        \\zig_noreturn void exit(uint8_t arg0) {
        \\    const uintptr_t __temp_0 = (uintptr_t)arg0;
        \\    register uintptr_t rax_constant __asm__("rax") = 231;
        \\    register uintptr_t rdi_constant __asm__("rdi") = __temp_0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_breakpoint();
        \\    zig_unreachable();
        \\}
        \\
    );
    ctx.h("header with single param function", linux_x64,
        \\export fn start(a: u8) void{}
    ,
        \\void start(uint8_t arg0);
        \\
    );
    ctx.h("header with multiple param function", linux_x64,
        \\export fn start(a: u8, b: u8, c: u8) void{}
    ,
        \\void start(uint8_t arg0, uint8_t arg1, uint8_t arg2);
        \\
    );
    ctx.h("header with u32 param function", linux_x64,
        \\export fn start(a: u32) void{}
    ,
        \\void start(uint32_t arg0);
        \\
    );
    ctx.h("header with usize param function", linux_x64,
        \\export fn start(a: usize) void{}
    ,
        \\void start(uintptr_t arg0);
        \\
    );
    ctx.h("header with bool param function", linux_x64,
        \\export fn start(a: bool) void{}
    ,
        \\void start(bool arg0);
        \\
    );
    ctx.h("header with noreturn function", linux_x64,
        \\export fn start() noreturn {
        \\    unreachable;
        \\}
    ,
        \\zig_noreturn void start(void);
        \\
    );
    ctx.h("header with multiple functions", linux_x64,
        \\export fn a() void{}
        \\export fn b() void{}
        \\export fn c() void{}
    ,
        \\void a(void);
        \\void b(void);
        \\void c(void);
        \\
    );
    ctx.h("header with multiple includes", linux_x64,
        \\export fn start(a: u32, b: usize) void{}
    ,
        \\void start(uint32_t arg0, uintptr_t arg1);
        \\
    );
}
