const std = @import("std");
const TestContext = @import("../../src-self-hosted/test.zig").TestContext;

// These tests should work with all platforms, but we're using linux_x64 for
// now for consistency. Will be expanded eventually.
const linux_x64 = std.zig.CrossTarget{
    .cpu_arch = .x86_64,
    .os_tag = .linux,
};

pub fn addCases(ctx: *TestContext) !void {
    ctx.c("empty start function", linux_x64,
        \\export fn _start() noreturn {
        \\    unreachable;
        \\}
    ,
        \\zig_noreturn void _start(void) {
        \\    zig_unreachable();
        \\}
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
        \\#include <stddef.h>
        \\
        \\zig_noreturn void exitGood(void);
        \\
        \\const char *const exitGood__anon_0 = "{rax}";
        \\const char *const exitGood__anon_1 = "{rdi}";
        \\const char *const exitGood__anon_2 = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exitGood();
        \\}
        \\
        \\zig_noreturn void exitGood(void) {
        \\    register size_t rax_constant __asm__("rax") = 231;
        \\    register size_t rdi_constant __asm__("rdi") = 0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
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
        \\#include <stddef.h>
        \\
        \\zig_noreturn void exit(size_t arg0);
        \\
        \\const char *const exit__anon_0 = "{rax}";
        \\const char *const exit__anon_1 = "{rdi}";
        \\const char *const exit__anon_2 = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exit(0);
        \\}
        \\
        \\zig_noreturn void exit(size_t arg0) {
        \\    register size_t rax_constant __asm__("rax") = 231;
        \\    register size_t rdi_constant __asm__("rdi") = arg0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
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
        \\#include <stddef.h>
        \\#include <stdint.h>
        \\
        \\zig_noreturn void exit(uint8_t arg0);
        \\
        \\const char *const exit__anon_0 = "{rax}";
        \\const char *const exit__anon_1 = "{rdi}";
        \\const char *const exit__anon_2 = "syscall";
        \\
        \\zig_noreturn void _start(void) {
        \\    exit(0);
        \\}
        \\
        \\zig_noreturn void exit(uint8_t arg0) {
        \\    const size_t __temp_0 = (size_t)arg0;
        \\    register size_t rax_constant __asm__("rax") = 231;
        \\    register size_t rdi_constant __asm__("rdi") = __temp_0;
        \\    __asm volatile ("syscall" :: ""(rax_constant), ""(rdi_constant));
        \\    zig_unreachable();
        \\}
        \\
    );
}
